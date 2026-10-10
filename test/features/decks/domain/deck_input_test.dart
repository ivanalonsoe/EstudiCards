import 'package:estudicards/features/decks/domain/deck.dart';
import 'package:estudicards/features/decks/domain/deck_input.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DeckInput.validate', () {
    test('a deck with a name and no colour is valid', () {
      expect(const DeckInput(name: 'Verbos').validate(), isEmpty);
    });

    test('counts the name without surrounding spaces', () {
      final input = DeckInput(name: '  ${'a' * 60}  ');

      expect(input.validate(), isEmpty);
      expect(input.trimmedName, 'a' * 60);
    });

    test('a blank description becomes null', () {
      const input = DeckInput(name: 'Verbos', description: '  ');

      expect(input.trimmedDescription, isNull);
    });

    test('a new deck is general', () {
      expect(const DeckInput(name: 'Verbos').type, DeckType.general);
    });

    test('a language deck without a source or target language is invalid', () {
      const missingSource = DeckInput(
        name: 'Verbos',
        type: DeckType.language,
        targetLang: 'es-ES',
      );
      const missingTarget = DeckInput(
        name: 'Verbos',
        type: DeckType.language,
        sourceLang: 'en-GB',
      );
      const blankTarget = DeckInput(
        name: 'Verbos',
        type: DeckType.language,
        sourceLang: 'en-GB',
        targetLang: '  ',
      );

      for (final input in [missingSource, missingTarget, blankTarget]) {
        expect(input.validate(), [DeckInputError.languagesMissing]);
      }
    });

    test('a language deck can use the same language on both sides', () {
      // Word → definition, e.g. English → English.
      const input = DeckInput(
        name: 'Definitions',
        type: DeckType.language,
        sourceLang: 'en-GB',
        targetLang: 'en-GB',
      );

      expect(input.validate(), isEmpty);
    });

    test('a general deck needs no languages', () {
      const input = DeckInput(name: 'Célula', sourceLang: 'en-GB');

      expect(input.validate(), isEmpty);
    });

    test('reports every error at once', () {
      const input = DeckInput(name: ' ', type: DeckType.language);

      expect(input.validate(), [
        DeckInputError.nameMissing,
        DeckInputError.languagesMissing,
      ]);
    });
  });

  test('DeckType.fromStored falls back to general for unknown values', () {
    expect(DeckType.fromStored('language'), DeckType.language);
    expect(DeckType.fromStored('unknown'), DeckType.general);
  });

  test('InvalidDeckException lists the errors in its message', () {
    expect(
      const InvalidDeckException([DeckInputError.nameTooLong]).toString(),
      'InvalidDeckException([DeckInputError.nameTooLong])',
    );
  });
}
