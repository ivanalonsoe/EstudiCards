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
    test("contains the template's exact header row", () {
      expect(aiPrompt, contains('\n  ${csvColumns.join(';')}\n'));
    });

    test('is the text of SPEC §8.5, with the brackets to fill in', () {
      expect(
        aiPrompt,
        startsWith(
          'Generate [NUMBER] flashcards about [TOPIC] in CSV format to '
          'import into the EstudiCards app.\n',
        ),
      );
      for (final placeholder in ['[LANGUAGE]', '[PERCENTAGE]', '[LEVEL]']) {
        expect(aiPrompt, contains(placeholder));
      }
      expect(
        aiPrompt,
        endsWith(
          'Return only the CSV, with no explanations and no code blocks.',
        ),
      );
    });
  });
}
