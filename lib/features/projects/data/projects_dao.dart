// A DAO (Data Access Object) groups the SQL queries for one table. It only
// reads and writes rows; validation, IDs and the clock live in the
// repository, which is what the rest of the app uses.
//
// `@DriftAccessor` makes `build_runner` generate `_$ProjectsDaoMixin`, which
// gives the DAO the `projects` table accessor.
import 'package:drift/drift.dart';
import 'package:estudicards/core/db/app_database.dart';

part 'projects_dao.g.dart';

@DriftAccessor(tables: [Projects])
class ProjectsDao extends DatabaseAccessor<AppDatabase>
    with _$ProjectsDaoMixin {
  new(super.attachedDatabase);

  Future<ProjectRow> insertProject(ProjectsCompanion project) =>
      into(projects).insertReturning(project);

  /// Writes the given columns and returns the updated row, or null if there
  /// is no project with that [id].
  Future<ProjectRow?> updateProject(
    String id,
    ProjectsCompanion changes,
  ) async {
    final rows = await (update(
      projects,
    )..where((p) => p.id.equals(id))).writeReturning(changes);
    return rows.singleOrNull;
  }

  Future<ProjectRow?> findById(String id) =>
      (select(projects)..where((p) => p.id.equals(id))).getSingleOrNull();

  /// The dashboard list (US-05 AC1): not archived and not in the trash,
  /// favourites first, then the most recently used. A project never used
  /// counts from its creation time. Each row comes with its number of decks
  /// and cards, leaving out decks in the trash.
  ///
  /// `watch()` returns a stream that emits a new list every time one of the
  /// tables it reads changes, so the screen updates by itself.
  Stream<List<ProjectWithCounts>> watchActive() {
    final decks = attachedDatabase.decks;
    final cards = attachedDatabase.cards;

    // Subqueries: small SELECTs run for every project row.
    final deckCount = subqueryExpression<int>(
      selectOnly(decks)
        ..addColumns([countAll()])
        ..where(decks.projectId.equalsExp(projects.id))
        ..where(decks.deletedAt.isNull()),
    );
    final cardCount = subqueryExpression<int>(
      selectOnly(cards).join([
          innerJoin(decks, decks.id.equalsExp(cards.deckId), useColumns: false),
        ])
        ..addColumns([countAll()])
        ..where(decks.projectId.equalsExp(projects.id))
        ..where(decks.deletedAt.isNull()),
    );

    final query = select(projects).join([])
      ..addColumns([deckCount, cardCount])
      ..where(projects.isArchived.not() & projects.deletedAt.isNull())
      ..orderBy([
        OrderingTerm.desc(projects.isFavorite),
        OrderingTerm.desc(coalesce([projects.lastUsedAt, projects.createdAt])),
        OrderingTerm.asc(projects.name),
      ]);
    return query.watch().map(
      (rows) => [
        for (final row in rows)
          (
            project: row.readTable(projects),
            deckCount: row.read(deckCount)!,
            cardCount: row.read(cardCount)!,
          ),
      ],
    );
  }
}

/// A project row with how many decks and cards it has.
typedef ProjectWithCounts = ({
  ProjectRow project,
  int deckCount,
  int cardCount,
});
