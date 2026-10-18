// Drift queries for importing (see `ProjectsDao` for what a DAO is).
import 'package:drift/drift.dart';
import 'package:estudicards/core/db/app_database.dart';

part 'import_dao.g.dart';

@DriftAccessor(tables: [Projects, Decks, Cards, CardOptions])
class ImportDao extends DatabaseAccessor<AppDatabase> with _$ImportDaoMixin {
  new(super.attachedDatabase);

  Future<DeckRow?> deckById(String id) =>
      (select(decks)..where((d) => d.id.equals(id))).getSingleOrNull();

  /// The cards of [deckId] with their options, in their editing order.
  Future<List<CardRow>> cardsOf(String deckId) =>
      (select(cards)..where((c) => c.deckId.equals(deckId))).get();

  Future<List<CardOptionRow>> optionsOf(Iterable<String> cardIds) =>
      (select(cardOptions)
            ..where((o) => o.cardId.isIn(cardIds))
            ..orderBy([(o) => OrderingTerm.asc(o.position)]))
          .get();

  /// Which of [ids] are already card IDs in the database.
  Future<Set<String>> existingCardIds(Iterable<String> ids) async {
    final rows =
        await (selectOnly(cards)
              ..addColumns([cards.id])
              ..where(cards.id.isIn(ids)))
            .get();
    return {for (final row in rows) row.read(cards.id)!};
  }

  Future<void> insertProject(ProjectsCompanion project) =>
      into(projects).insert(project);

  Future<void> insertDeck(DecksCompanion deck) => into(decks).insert(deck);

  Future<void> insertCard(CardsCompanion card) => into(cards).insert(card);

  Future<void> insertOption(CardOptionsCompanion option) =>
      into(cardOptions).insert(option);

  /// Records that the deck and its project were used now (R 7.7).
  Future<void> markDeckAndProjectUsed(String deckId, DateTime now) async {
    final deck = await deckById(deckId);
    if (deck == null) return;
    await (update(decks)..where((d) => d.id.equals(deckId))).write(
      DecksCompanion(lastUsedAt: Value(now)),
    );
    await (update(projects)..where((p) => p.id.equals(deck.projectId))).write(
      ProjectsCompanion(lastUsedAt: Value(now)),
    );
  }
}
