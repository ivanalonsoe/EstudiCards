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

  /// The project with [id], emitted again every time it changes; null if
  /// there is none.
  Stream<ProjectRow?> watchById(String id) =>
      (select(projects)..where((p) => p.id.equals(id))).watchSingleOrNull();

  /// The dashboard list (US-05 AC1): not archived and not in the trash,
  /// favourites first, then the most recently used. A project never used
  /// counts from its creation time. Each row comes with its number of decks
  /// and cards, leaving out decks in the trash.
  ///
  /// `watch()` returns a stream that emits a new list every time one of the
  /// tables it reads changes, so the screen updates by itself.
  Stream<List<ProjectWithCounts>> watchActive() => _watchWithCounts(
    where: projects.isArchived.not() & projects.deletedAt.isNull(),
    orderBy: [
      OrderingTerm.desc(projects.isFavorite),
      OrderingTerm.desc(coalesce([projects.lastUsedAt, projects.createdAt])),
      OrderingTerm.asc(projects.name),
    ],
  );

  /// The Archived list (US-05 AC2): archived and not in the trash, the most
  /// recently archived first. Projects archived before `archived_at`
  /// existed have no date and go last.
  Stream<List<ProjectWithCounts>> watchArchived() => _watchWithCounts(
    where: projects.isArchived & projects.deletedAt.isNull(),
    orderBy: [
      OrderingTerm(expression: projects.archivedAt, mode: OrderingMode.desc),
      OrderingTerm.asc(projects.name),
    ],
  );

  /// The "Por proyecto" list of the global statistics (P13): every project
  /// not in the trash, in dashboard order, archived ones last (they count in
  /// the global statistics, R 7.6 and assumption 45).
  Stream<List<ProjectWithCounts>> watchNotDeleted() => _watchWithCounts(
    where: projects.deletedAt.isNull(),
    orderBy: [
      OrderingTerm.asc(projects.isArchived),
      OrderingTerm.desc(projects.isFavorite),
      OrderingTerm.desc(coalesce([projects.lastUsedAt, projects.createdAt])),
      OrderingTerm.asc(projects.name),
    ],
  );

  /// The projects that match [where], in [orderBy] order, each with its
  /// number of decks and cards, leaving out decks in the trash.
  Stream<List<ProjectWithCounts>> _watchWithCounts({
    required Expression<bool> where,
    required List<OrderingTerm> orderBy,
  }) {
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

    // The same, over the `card_stats` rows of those cards (R 7.6). SQLite
    // adds them up; no statistics row is read into Dart.
    final stats = attachedDatabase.cardStats;
    Expression<T> overStats<T extends Object>(
      Expression<T> column, {
      Expression<bool>? filter,
    }) => subqueryExpression<T>(
      selectOnly(stats).join([
          innerJoin(cards, cards.id.equalsExp(stats.cardId), useColumns: false),
          innerJoin(decks, decks.id.equalsExp(cards.deckId), useColumns: false),
        ])
        ..addColumns([column])
        ..where(decks.projectId.equalsExp(projects.id))
        ..where(decks.deletedAt.isNull())
        ..where(filter ?? const Constant(true)),
    );
    final correct = overStats(stats.correctCount.sum());
    final wrong = overStats(stats.wrongCount.sum());
    final errors = overStats(countAll(), filter: stats.inErrorList);
    final lastStudied = overStats(stats.lastAttemptAt.max());

    final query = select(projects).join([])
      ..addColumns([deckCount, cardCount, correct, wrong, errors, lastStudied])
      ..where(where)
      ..orderBy(orderBy);
    return query.watch().map(
      (rows) => [
        for (final row in rows)
          (
            project: row.readTable(projects),
            deckCount: row.read(deckCount)!,
            cardCount: row.read(cardCount)!,
            // `sum` is null when there are no statistics yet.
            correctCount: row.read(correct) ?? 0,
            wrongCount: row.read(wrong) ?? 0,
            errorCount: row.read(errors)!,
            lastStudiedAt: row.read(lastStudied),
          ),
      ],
    );
  }
}

/// A project row with how many decks and cards it has, and the totals of
/// their statistics.
typedef ProjectWithCounts = ({
  ProjectRow project,
  int deckCount,
  int cardCount,
  int correctCount,
  int wrongCount,
  int errorCount,
  DateTime? lastStudiedAt,
});
