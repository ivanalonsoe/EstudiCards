import 'package:estudicards/features/cards/domain/card_transfer.dart';
import 'package:estudicards/features/cards/domain/flashcard.dart';
import 'package:estudicards/features/decks/domain/deck.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime.utc(2026, 10, 11);

Deck deck(
  String id, {
  DeckType type = DeckType.general,
  String? sourceLang,
  String? targetLang,
}) => Deck(
  id: id,
  projectId: 'project',
  name: id,
  color: 'blue',
  inheritsColor: true,
  type: type,
  sourceLang: sourceLang,
  targetLang: targetLang,
  createdAt: _now,
  updatedAt: _now,
);

Deck language(String id, String source, String target) =>
    deck(id, type: DeckType.language, sourceLang: source, targetLang: target);

Flashcard card(String question, {String? example, String? notes}) => Flashcard(
  id: question,
  deckId: 'from',
  type: CardType.simple,
  question: question,
  answer: 'x',
  allowMultiple: false,
  example: example,
  notes: notes,
  createdAt: _now,
  updatedAt: _now,
);

void main() {
  final english = language('english', 'en-GB', 'es-ES');
  final general = deck('general');

  test('from a language deck to a general one, counts the cards whose example '
      'or notes will be hidden', () {
    final warning = transferWarning(
      from: english,
      to: general,
      cards: [
        card('to bring', example: 'Can you bring me some water?'),
        card('to seek', notes: 'Verbo irregular'),
        card('to bind'),
      ],
    );

    expect(warning, isA<ToGeneralDeck>());
    expect((warning! as ToGeneralDeck).cardsWithLanguageFields, 2);
  });

  test('to a general deck with no example or notes still warns about voice '
      'and reverse mode', () {
    final warning = transferWarning(
      from: english,
      to: general,
      cards: [card('to bind')],
    );

    expect((warning! as ToGeneralDeck).cardsWithLanguageFields, 0);
  });

  test(
    "from a general deck to a language one, gives the target's languages",
    () {
      final warning = transferWarning(
        from: general,
        to: english,
        cards: [card('to bind')],
      );

      expect(warning, isA<ToLanguageDeck>());
      final toLanguage = warning! as ToLanguageDeck;
      expect(toLanguage.sourceLang, 'en-GB');
      expect(toLanguage.targetLang, 'es-ES');
    },
  );

  test('between language decks with other languages, gives both pairs', () {
    final warning = transferWarning(
      from: english,
      to: language('definitions', 'en-GB', 'en-GB'),
      cards: [card('to bind')],
    );

    expect(warning, isA<LanguagesChange>());
    final change = warning! as LanguagesChange;
    expect(change.fromSourceLang, 'en-GB');
    expect(change.fromTargetLang, 'es-ES');
    expect(change.toSourceLang, 'en-GB');
    expect(change.toTargetLang, 'en-GB');
  });

  test('decks of the same type and languages need no warning', () {
    final cards = [card('to bring', example: 'Can you bring it?')];

    expect(
      transferWarning(
        from: english,
        to: language('phrasal', 'en-GB', 'es-ES'),
        cards: cards,
      ),
      isNull,
    );
    expect(
      transferWarning(from: general, to: deck('other'), cards: cards),
      isNull,
    );
    // A general deck that kept hidden languages is still general.
    expect(
      transferWarning(
        from: deck('was language', sourceLang: 'de-DE', targetLang: 'es-ES'),
        to: general,
        cards: cards,
      ),
      isNull,
    );
  });
}
