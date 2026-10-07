// Drift queries for the trash (SPEC §7.1). See `ProjectsDao` for what a
// DAO is.
import 'package:drift/drift.dart';
import 'package:estudicards/core/db/app_database.dart';

part 'trash_dao.g.dart';

/// A project in the trash with how many decks and cards it holds, leaving
/// out decks that are in the trash themselves.
typedef TrashedProject = ({ProjectRow project, int deckCount, int cardCount});

/// A deck in the trash with its project and number of cards.
typedef TrashedDeck = ({DeckRow deck, ProjectRow project, int cardCount});

@DriftAccessor(tables: [Projects, Decks, Cards])
class TrashDao extends DatabaseAccessor<AppDatabase> with _$TrashDaoMixin {
  new(super.attachedDatabase);

  /// Sets a project's `deleted_at`: a time moves it to the trash, null
  /// restores it.
  Future<void> setProjectDeletedAt(String id, DateTime? deletedAt) =>
      (update(projects)..where((p) => p.id.equals(id))).write(
        ProjectsCompanion(deletedAt: Value(deletedAt)),
      );

  /// Same as [setProjectDeletedAt], for a deck.
  Future<void> setDeckDeletedAt(String id, DateTime? deletedAt) =>
      (update(decks)..where((d) => d.id.equals(id))).write(
        DecksCompanion(deletedAt: Value(deletedAt)),
      );

  Future<DeckRow?> findDeck(String id) =>
      (select(decks)..where((d) => d.id.equals(id))).getSingleOrNull();

  /// IDs of the projects in the trash; with [deletedUpTo], only those
  /// deleted at that time or earlier.
  Future<List<String>> trashedProjectIds({DateTime? deletedUpTo}) {
    final query = selectOnly(projects)
      ..addColumns([projects.id])
      ..where(
        deletedUpTo == null
            ? projects.deletedAt.isNotNull()
            : projects.deletedAt.isSmallerOrEqualValue(deletedUpTo),
      );
    return query.map((row) => row.read(projects.id)!).get();
  }

  /// Same as [trashedProjectIds], for decks.
  Future<List<String>> trashedDeckIds({DateTime? deletedUpTo}) {
    final query = selectOnly(decks)
      ..addColumns([decks.id])
      ..where(
        deletedUpTo == null
            ? decks.deletedAt.isNotNull()
            : decks.deletedAt.isSmallerOrEqualValue(deletedUpTo),
      );
    return query.map((row) => row.read(decks.id)!).get();
  }

  /// The image paths of every card in these projects or decks.
  Future<List<String>> imagePaths({
    Iterable<String> projectIds = const [],
    Iterable<String> deckIds = const [],
  }) async {
    final query =
        selectOnly(cards).join([
            innerJoin(
              decks,
              decks.id.equalsExp(cards.deckId),
              useColumns: false,
            ),
          ])
          ..addColumns([cards.questionImage, cards.answerImage])
          ..where(decks.projectId.isIn(projectIds) | decks.id.isIn(deckIds));
    final rows = await query.get();
    return [
      for (final row in rows) ...[
        ?row.read(cards.questionImage),
        ?row.read(cards.answerImage),
      ],
    ];
  }

  /// Deletes these projects for good. The foreign keys cascade the delete
  /// to their decks, cards, options, statistics, sessions and attempts.
  Future<void> deleteProjects(Iterable<String> ids) =>
      (delete(projects)..where((p) => p.id.isIn(ids))).go();

  /// Deletes these decks for good, with their cards and everything that
  /// hangs from them. Past sessions keep their totals.
  Future<void> deleteDecks(Iterable<String> ids) =>
      (delete(decks)..where((d) => d.id.isIn(ids))).go();

  /// Emits every time projects, decks or cards change, so the trash list
  /// can be read again.
  Stream<void> watchChanges() => attachedDatabase.tableUpdates(
    TableUpdateQuery.onAllTables([projects, decks, cards]),
  );

  Future<List<TrashedProject>> trashedProjects() async {
    // Subqueries, as in `ProjectsDao.watchActive`.
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
      ..where(projects.deletedAt.isNotNull());
    return [
      for (final row in await query.get())
        (
          project: row.readTable(projects),
          deckCount: row.read(deckCount)!,
          cardCount: row.read(cardCount)!,
        ),
    ];
  }

  Future<List<TrashedDeck>> trashedDecks() async {
    final cardCount = subqueryExpression<int>(
      selectOnly(cards)
        ..addColumns([countAll()])
        ..where(cards.deckId.equalsExp(decks.id)),
    );
    final query =
        select(decks)
            .join([innerJoin(projects, projects.id.equalsExp(decks.projectId))])
          ..addColumns([cardCount])
          ..where(decks.deletedAt.isNotNull());
    return [
      for (final row in await query.get())
        (
          deck: row.readTable(decks),
          project: row.readTable(projects),
          cardCount: row.read(cardCount)!,
        ),
    ];
  }
}
