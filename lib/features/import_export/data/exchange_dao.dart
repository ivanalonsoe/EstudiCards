// Drift queries for exporting (see `ProjectsDao` for what a DAO is).
import 'package:drift/drift.dart';
import 'package:estudicards/core/db/app_database.dart';

part 'exchange_dao.g.dart';

@DriftAccessor(tables: [Projects, Decks, Cards, CardOptions])
class ExchangeDao extends DatabaseAccessor<AppDatabase>
    with _$ExchangeDaoMixin {
  new(super.attachedDatabase);

  Future<ProjectRow?> projectById(String id) =>
      (select(projects)..where((p) => p.id.equals(id))).getSingleOrNull();

  /// The decks of [projectId] that are not in the trash, oldest first, as
  /// the project screen lists them.
  Future<List<DeckRow>> activeDecksOf(String projectId) =>
      (select(decks)
            ..where((d) => d.projectId.equals(projectId) & d.deletedAt.isNull())
            ..orderBy([
              (d) => OrderingTerm.asc(d.createdAt),
              (d) => OrderingTerm.asc(d.rowId),
            ]))
          .get();

  Future<DeckRow?> deckById(String id) =>
      (select(decks)..where((d) => d.id.equals(id))).getSingleOrNull();

  /// The cards of these decks, oldest first, so a file lists them in the
  /// order they were created. Cards created at the same instant keep the
  /// order they were inserted in (SQLite's `rowid`).
  Future<List<CardRow>> cardsOf(Iterable<String> deckIds) =>
      (select(cards)
            ..where((c) => c.deckId.isIn(deckIds))
            ..orderBy([
              (c) => OrderingTerm.asc(c.createdAt),
              (c) => OrderingTerm.asc(c.rowId),
            ]))
          .get();

  /// The options of these cards, in their editing order.
  Future<List<CardOptionRow>> optionsOf(Iterable<String> cardIds) =>
      (select(cardOptions)
            ..where((o) => o.cardId.isIn(cardIds))
            ..orderBy([(o) => OrderingTerm.asc(o.position)]))
          .get();
}
