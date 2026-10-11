import 'package:estudicards/features/cards/domain/card_speech.dart';
import 'package:estudicards/features/cards/domain/flashcard.dart';
import 'package:estudicards/features/decks/domain/deck.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime.utc(2026, 10, 11);

Deck deck({
  DeckType type = DeckType.language,
  String? sourceLang = 'en-GB',
  String? targetLang = 'es-ES',
}) => Deck(
  id: 'deck',
  projectId: 'project',
  name: 'Verbos',
  color: 'blue',
  inheritsColor: true,
  type: type,
  sourceLang: sourceLang,
  targetLang: targetLang,
  createdAt: _now,
  updatedAt: _now,
);

Flashcard card({
  CardType type = CardType.simple,
  String question = 'to **bring**',
  String? answer = 'traer',
  String? example,
}) => Flashcard(
  id: 'card',
  deckId: 'deck',
  type: type,
  question: question,
  answer: answer,
  allowMultiple: false,
  example: example,
  createdAt: _now,
  updatedAt: _now,
);

void main() {
  group('speechLanguagesOf', () {
    test("is the language deck's source and target languages", () {
      expect(speechLanguagesOf(deck()), (source: 'en-GB', target: 'es-ES'));
    });

    test('is null for a general deck, even with languages kept hidden', () {
      expect(speechLanguagesOf(deck(type: DeckType.general)), isNull);
    });

    test('is null for a language deck without both languages', () {
      expect(speechLanguagesOf(deck(targetLang: null)), isNull);
    });
  });

  group('speechFor', () {
    const languages = (source: 'en-GB', target: 'es-ES');

    test('reads the question in the source language and the answer in the '
        'target language, without bold or italic marks', () {
      expect(speechFor(card(), SpeechPart.question, languages), (
        text: 'to bring',
        language: 'en-GB',
      ));
      expect(speechFor(card(answer: '*traer*'), SpeechPart.answer, languages), (
        text: 'traer',
        language: 'es-ES',
      ));
    });

    test('reads the example in the source language', () {
      expect(
        speechFor(
          card(example: 'Can you **bring** me some water?'),
          SpeechPart.example,
          languages,
        ),
        (text: 'Can you bring me some water?', language: 'en-GB'),
      );
    });

    test('has nothing to read for a missing text or a test card answer', () {
      expect(speechFor(card(), SpeechPart.example, languages), isNull);
      expect(
        speechFor(
          card(type: CardType.test, answer: null),
          SpeechPart.answer,
          languages,
        ),
        isNull,
      );
      expect(
        speechFor(card(question: '  '), SpeechPart.question, languages),
        isNull,
      );
    });
  });
}
