// Drift queries for exporting (see `ProjectsDao` for what a DAO is).
import 'package:drift/drift.dart';
import 'package:estudicards/core/db/app_database.dart';

part 'exchange_dao.g.dart';

@DriftAccessor(
  tables: [
    Projects,
    Decks,
    Cards,
    CardOptions,
    CardStats,
    StudySessions,
    SessionDecks,
    Attempts,
    Settings,
  ],
)
class ExchangeDao extends DatabaseAccessor<AppDatabase>
    with _$ExchangeDaoMixin {
  new(super.attachedDatabase);

  // For a backup: every row, archived and in the trash too. Rows come in
  // the order they were inserted (`rowid`), so a restore inserts them in
  // the same order; the `card_stats` recalculation uses it to break ties.

  Future<List<ProjectRow>> allProjects() =>
      (select(projects)..orderBy([(p) => OrderingTerm.asc(p.rowId)])).get();

  /// Every deck of [projectId], in the trash too, in insertion order.
  Future<List<DeckRow>> allDecksOf(String projectId) =>
      (select(decks)
            ..where((d) => d.projectId.equals(projectId))
            ..orderBy([(d) => OrderingTerm.asc(d.rowId)]))
          .get();

  /// Every card, in decks in the trash too.
  Future<List<CardRow>> allCards() => select(cards).get();

  Future<List<StudySessionRow>> allSessions() => (select(
    studySessions,
  )..orderBy([(s) => OrderingTerm.asc(s.rowId)])).get();

  Future<List<SessionDeckRow>> allSessionDecks() =>
      (select(sessionDecks)..orderBy([(s) => OrderingTerm.asc(s.rowId)])).get();

  Future<List<AttemptRow>> allAttempts() =>
      (select(attempts)..orderBy([(a) => OrderingTerm.asc(a.rowId)])).get();

  Future<List<CardStatsRow>> allCardStats() =>
      (select(cardStats)..orderBy([
            (s) => OrderingTerm.asc(s.cardId),
            (s) => OrderingTerm.asc(s.direction),
          ]))
          .get();

  Future<List<SettingRow>> allSettings() =>
      (select(settings)..orderBy([(s) => OrderingTerm.asc(s.key)])).get();

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
