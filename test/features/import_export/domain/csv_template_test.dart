import 'dart:convert';

import 'package:estudicards/features/cards/domain/flashcard.dart';
import 'package:estudicards/features/import_export/domain/cards_csv.dart';
import 'package:estudicards/features/import_export/domain/csv_template.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('the template', () {
    test('imports with no errors', () {
      final csv = parseCardsCsv(csvTemplate());

      expect(csv.errors, isEmpty);
      expect(csv.separator, ';');
      expect(csv.cards, hasLength(3));
      expect([for (final card in csv.cards) ...card.input.validate()], isEmpty);
    });

    test('has one example of each kind of card (SPEC §8.3)', () {
      final [bring, australia, primes] = [
        for (final card in parseCardsCsv(csvTemplate()).cards) card.input,
      ];

      expect(bring.type, CardType.simple);
      expect(bring.example, 'Can you bring me some water?');
      expect(australia.type, CardType.test);
      expect(australia.allowMultiple, isFalse);
      expect(primes.allowMultiple, isTrue);
    });

    test('is a CSV for Excel: BOM, ";" and the column names', () {
      final bytes = csvTemplate();

      expect(bytes.sublist(0, 3), [0xEF, 0xBB, 0xBF]);
      expect(
        utf8.decode(bytes.sublist(3)).split('\r\n').first,
        csvColumns.join(';'),
      );
      expect(csvTemplateFileName, 'estudicards_template.csv');
    });
  });

  group('the AI prompt', () {
    const languages = (source: 'en-GB', target: 'es-ES');

    String prompt(
      AiPromptMode mode,
      AiPromptLanguage language, {
      String deckName = 'Verbos irregulares',
      DeckLanguages? deckLanguages,
    }) => aiPrompt(
      mode: mode,
      language: language,
      deckName: deckName,
      deckLanguages: deckLanguages,
    );

    final every = [
      for (final mode in AiPromptMode.values)
        for (final language in AiPromptLanguage.values)
          for (final deckLanguages in [null, languages])
            (mode, language, deckLanguages),
    ];

    test("every prompt contains the template's exact header row and asks "
        'for a file named after the deck', () {
      for (final (mode, language, deckLanguages) in every) {
        final text = prompt(mode, language, deckLanguages: deckLanguages);
        final which = '$mode $language $deckLanguages';
        expect(text, contains('\n  ${csvColumns.join(';')}\n'), reason: which);
        expect(text, contains('"Verbos irregulares.csv"'), reason: which);
      }
    });

    test('the file name drops what a file name cannot have', () {
      expect(
        prompt(.fromData, .english, deckName: 'Tema 1/2: Célula?'),
        contains('"Tema 12 Célula.csv"'),
      );
    });

    test('with new content, the AI writes the cards about a topic, with the '
        'brackets to fill in', () {
      final english = prompt(.newContent, .english);
      expect(
        english,
        startsWith(
          'Generate [NUMBER] flashcards about [TOPIC] in CSV format to '
          'import into the EstudiCards app.\n',
        ),
      );
      for (final placeholder in ['[LANGUAGE]', '[PERCENTAGE]', '[LEVEL]']) {
        expect(english, contains(placeholder));
      }

      final spanish = prompt(.newContent, .spanish);
      expect(
        spanish,
        startsWith(
          'Genera [NÚMERO] tarjetas sobre [TEMA] en formato CSV para '
          'importarlas en la app EstudiCards.\n',
        ),
      );
      for (final placeholder in ['[IDIOMA]', '[PORCENTAJE]', '[NIVEL]']) {
        expect(spanish, contains(placeholder));
      }
    });

    test('from data, the AI only uses the data pasted at the end', () {
      final english = prompt(.fromData, .english);
      expect(english, contains('using only the information I give you'));
      expect(english, isNot(contains('[TOPIC]')));
      expect(english, endsWith('My data:\n[PASTE YOUR DATA HERE]'));

      final spanish = prompt(.fromData, .spanish);
      expect(spanish, contains('usando solo la información que te doy'));
      expect(spanish, isNot(contains('[TEMA]')));
      expect(spanish, endsWith('Mis datos:\n[PEGA AQUÍ TUS DATOS]'));
    });

    test('it says whether the deck is general or of languages, and which', () {
      for (final mode in AiPromptMode.values) {
        expect(prompt(mode, .english), contains('This is a general deck'));
        expect(
          prompt(mode, .english, deckLanguages: languages),
          allOf(
            contains('This is a language deck'),
            contains('en-GB'),
            contains('es-ES'),
          ),
        );
        expect(prompt(mode, .spanish), contains('Es una baraja general'));
        expect(
          prompt(mode, .spanish, deckLanguages: languages),
          allOf(
            contains('Es una baraja de idiomas'),
            contains('en-GB'),
            contains('es-ES'),
          ),
        );
      }
    });
  });
}
