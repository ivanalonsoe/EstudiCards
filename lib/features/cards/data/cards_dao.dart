// Drift queries for cards and their options (see `ProjectsDao` for what a
// DAO is).
import 'package:drift/drift.dart';
import 'package:estudicards/core/db/app_database.dart';

part 'cards_dao.g.dart';

/// A card row with its first-attempt results, both directions added up, and
/// its last answer.
typedef CardWithResults = ({
  CardRow card,
  int correctCount,
  int wrongCount,
  DateTime? lastAttemptAt,
});

@DriftAccessor(tables: [Cards, CardOptions, CardStats, Decks, Projects])
class CardsDao extends DatabaseAccessor<AppDatabase> with _$CardsDaoMixin {
  new(super.attachedDatabase);

  Future<void> insertCard(CardsCompanion card) => into(cards).insert(card);

  /// Writes the given columns; returns how many rows changed (0 if there is
  /// no card with that [id]).
  Future<int> updateCard(String id, CardsCompanion changes) =>
      (update(cards)..where((c) => c.id.equals(id))).write(changes);

  Future<CardRow?> findById(String id) =>
      (select(cards)..where((c) => c.id.equals(id))).getSingleOrNull();

  /// Deletes the card for good. The foreign keys cascade the delete to its
  /// options, statistics and attempts.
  Future<void> deleteCard(String id) =>
      (delete(cards)..where((c) => c.id.equals(id))).go();

  /// The options of these cards, in their editing order.
  Future<List<CardOptionRow>> optionsOf(Iterable<String> cardIds) =>
      (select(cardOptions)
            ..where((o) => o.cardId.isIn(cardIds))
            ..orderBy([(o) => OrderingTerm.asc(o.position)]))
          .get();

  /// Inserts the option, or replaces the stored one with the same ID.
  Future<void> saveOption(CardOptionsCompanion option) =>
      into(cardOptions).insertOnConflictUpdate(option);

  /// Deletes the options of [cardId] whose ID is not in [keep].
  Future<void> deleteOtherOptions(String cardId, Iterable<String> keep) =>
      (delete(
        cardOptions,
      )..where((o) => o.cardId.equals(cardId) & o.id.isNotIn(keep))).go();

  /// A deck's cards, each with its correct and wrong first attempts in both
  /// directions (`card_stats` has one row per direction).
  Future<List<CardWithResults>> cardsWithResults(String deckId) async {
    // Subqueries, as in `ProjectsDao.watchActive`. `sum` is null when the
    // card has no statistics yet.
    Expression<int> total(GeneratedColumn<int> column) =>
        subqueryExpression<int>(
          selectOnly(cardStats)
            ..addColumns([column.sum()])
            ..where(cardStats.cardId.equalsExp(cards.id)),
        );
    final correct = total(cardStats.correctCount);
    final wrong = total(cardStats.wrongCount);
    final lastAttempt = subqueryExpression<DateTime>(
      selectOnly(cardStats)
        ..addColumns([cardStats.lastAttemptAt.max()])
        ..where(cardStats.cardId.equalsExp(cards.id)),
    );
    final query = select(cards).join([])
      ..addColumns([correct, wrong, lastAttempt])
      ..where(cards.deckId.equals(deckId));
    return [
      for (final row in await query.get())
        (
          card: row.readTable(cards),
          correctCount: row.read(correct) ?? 0,
          wrongCount: row.read(wrong) ?? 0,
          lastAttemptAt: row.read(lastAttempt),
        ),
    ];
  }

  /// Emits every time cards, their options or their statistics change, so
  /// the card list can be read again.
  Stream<void> watchChanges() => attachedDatabase.tableUpdates(
    TableUpdateQuery.onAllTables([cards, cardOptions, cardStats]),
  );

  /// Records that the deck and its project were used now (R 7.7).
  Future<void> markDeckAndProjectUsed(String deckId, DateTime now) async {
    final deck = await (select(
      decks,
    )..where((d) => d.id.equals(deckId))).getSingleOrNull();
    if (deck == null) return;
    await (update(decks)..where((d) => d.id.equals(deckId))).write(
      DecksCompanion(lastUsedAt: Value(now)),
    );
    await (update(projects)..where((p) => p.id.equals(deck.projectId))).write(
      ProjectsCompanion(lastUsedAt: Value(now)),
    );
  }
}
