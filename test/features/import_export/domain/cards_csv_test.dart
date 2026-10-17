import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:estudicards/features/cards/domain/card_input.dart';
import 'package:estudicards/features/cards/domain/flashcard.dart';
import 'package:estudicards/features/import_export/domain/cards_csv.dart';
import 'package:estudicards/features/import_export/domain/import_limits.dart';
import 'package:flutter_test/flutter_test.dart';

/// A file from `test/fixtures/`, read byte for byte.
Uint8List _fixture(String name) =>
    File('test/fixtures/$name').readAsBytesSync();

CsvImport _parseFixture(String name) => parseCardsCsv(_fixture(name));

/// The CSV [text] as UTF-8 bytes, without a BOM.
CsvImport _parse(String text) => parseCardsCsv(utf8.encode(text));

const _header =
    'question;answer;option1;option2;option3;option4;option5;option6;'
    'correct;explanation;example;notes';

/// The card that came from [row].
CardInput _card(CsvImport csv, int row) =>
    csv.cards.singleWhere((card) => card.row == row).input;

List<(String, bool)> _options(CardInput card) => [
  for (final option in card.filledOptions) (option.text, option.isCorrect),
];

Matcher _failsWith(CsvError error) =>
    throwsA(isA<CsvFormatException>().having((e) => e.error, 'error', error));

void main() {
  group('separator', () {
    test('detects ";" in an Excel file', () {
      final csv = _parseFixture('excel_es.csv');

      expect(csv.separator, ';');
      expect(csv.errors, isEmpty);
      expect(csv.cards, hasLength(5));
    });

    test('detects "," in a Google Sheets file', () {
      final csv = _parseFixture('google_sheets.csv');

      expect(csv.separator, ',');
      expect(csv.errors, isEmpty);
      expect(_card(csv, 2).question, 'to seek');
      expect(_card(csv, 2).answer, 'buscar (sought, sought)');
      expect(_card(csv, 2).example, "I'm seeking a new job.");
    });
  });

  group('text', () {
    test('reads accents and "ñ" in UTF-8 with a BOM', () {
      final csv = _parseFixture('excel_es.csv');

      expect(_card(csv, 3).question, '¿Capital de Australia?');
      expect(_options(_card(csv, 3)).first, ('Sídney', false));
      expect(_card(csv, 6).question, 'pequeño');
    });

    test('reads accents and "ñ" in UTF-8 without a BOM', () {
      final csv = _parseFixture('google_sheets.csv');

      expect(_card(csv, 4).question, 'pequeño');
      expect(_card(csv, 4).example, 'A "small" house');
    });

    test('reads a Windows-1252 file from plain "CSV" in Excel', () {
      final csv = _parseFixture('excel_ansi.csv');

      expect(csv.errors, isEmpty);
      expect(_card(csv, 2).question, 'niño');
      expect(_card(csv, 2).notes, 'Lleva ñ');
      expect(_card(csv, 3).question, '“comillas”');
      expect(_card(csv, 3).answer, 'quotes – dashes');
      expect(_card(csv, 3).notes, 'Cuesta 5 €');
    });

    test('quoted fields keep ";", quotes and line breaks', () {
      final card = _card(_parseFixture('excel_es.csv'), 5);

      expect(card.question, 'año');
      expect(card.answer, 'year; también "curso"');
      expect(card.example, 'El año pasado\nfui a España.');
      expect(card.notes, 'Lleva ñ');
    });

    test('a line break typed as CRLF inside a cell becomes a plain one', () {
      final csv = _parse('question;answer\r\n"one\r\ntwo";uno\r\n');

      expect(_card(csv, 2).question, 'one\ntwo');
    });
  });

  group('cards', () {
    test('a row with an answer and no options is a simple card', () {
      final card = _card(_parseFixture('excel_es.csv'), 2);

      expect(card.type, CardType.simple);
      expect(card.question, 'to bring');
      expect(card.answer, 'traer (brought, brought)');
      expect(card.example, 'Can you bring me some water?');
      expect(card.notes, 'Verbo irregular');
      expect(card.validate(), isEmpty);
    });

    test('"correct = 2" makes a test card with one correct option', () {
      final card = _card(_parseFixture('excel_es.csv'), 3);

      expect(card.type, CardType.test);
      expect(card.allowMultiple, isFalse);
      expect(_options(card), [
        ('Sídney', false),
        ('Canberra', true),
        ('Melbourne', false),
      ]);
      expect(card.explanation, 'Canberra es la capital desde 1913.');
      expect(card.validate(), isEmpty);
    });

    test('"correct = 1|3" makes a test card with "allow multiple"', () {
      final card = _card(_parseFixture('excel_es.csv'), 4);

      expect(card.type, CardType.test);
      expect(card.allowMultiple, isTrue);
      expect(_options(card), [
        ('2', true),
        ('4', false),
        ('7', true),
        ('9', false),
      ]);
    });

    test('a test card ignores the answer column', () {
      final csv = _parse('$_header\n¿Sí?;ignored;Sí;No;;;;;1;;;\n');

      expect(_card(csv, 2).type, CardType.test);
      expect(_card(csv, 2).trimmedAnswer, isNull);
    });

    test('an option can be left empty: "correct" counts columns', () {
      final csv = _parse('$_header\n¿Uno?;;A;;C;;;;3;;;\n');

      expect(_options(_card(csv, 2)), [('A', false), ('C', true)]);
    });

    test('the "deck" column names the deck of each row', () {
      final csv = _parseFixture('google_sheets.csv');

      expect(
        [for (final card in csv.cards) card.deck],
        ['Verbos', 'Verbos', 'Adjetivos'],
      );
      expect(_parseFixture('excel_es.csv').cards.first.deck, isNull);
    });

    test('a file generated by an AI with the prompt has no errors', () {
      final csv = _parseFixture('ai_generated.csv');

      expect(csv.errors, isEmpty);
      expect(csv.cards, hasLength(10));
      expect(
        csv.cards.where((card) => card.input.type == CardType.test),
        hasLength(4),
      );
      expect([for (final card in csv.cards) ...card.input.validate()], isEmpty);
      expect(_card(csv, 8).explanation, 'Se dice "lent"; *lended* no existe.');
    });

    test('column names ignore case and surrounding spaces', () {
      final csv = _parse(' Question ;ANSWER\nto bring;traer\n');

      expect(_card(csv, 2).answer, 'traer');
    });
  });

  group('rows with errors', () {
    late CsvImport csv;

    setUp(() => csv = _parseFixture('with_errors.csv'));

    CsvRowError errorAt(int row) =>
        csv.errors.singleWhere((error) => error.row == row);

    test('are reported with their row number and skipped', () {
      expect([for (final card in csv.cards) card.row], [2, 10]);
      expect([for (final error in csv.errors) error.row], [3, 4, 5, 6, 7, 9]);
    });

    test('a row with no answer', () {
      expect(errorAt(3).problem, CsvRowProblem.answerMissing);
      expect(errorAt(3).question, 'to seek');
    });

    test('a row with no question', () {
      expect(errorAt(4).problem, CsvRowProblem.questionMissing);
      expect(errorAt(4).question, isNull);
    });

    test('a test row with no correct option', () {
      expect(errorAt(5).problem, CsvRowProblem.noCorrectOption);
    });

    test('"correct" pointing at an empty option or not a number', () {
      expect(errorAt(6).problem, CsvRowProblem.invalidCorrect);
      expect(errorAt(7).problem, CsvRowProblem.invalidCorrect);
    });

    test('a test row with a single option', () {
      expect(errorAt(9).problem, CsvRowProblem.tooFewOptions);
    });

    test('an empty row is skipped without an error', () {
      expect(csv.errors.map((e) => e.row), isNot(contains(8)));
    });
  });

  group('rejects the file', () {
    test('without a "question" column', () {
      expect(
        () => _parseFixture('missing_question_column.csv'),
        _failsWith(CsvError.missingQuestionColumn),
      );
    });

    test('with no rows at all', () {
      for (final text in ['', '﻿', '\r\n\r\n']) {
        expect(() => _parse(text), _failsWith(CsvError.empty));
      }
    });

    test('with the same column twice', () {
      expect(
        () => _parse('question;answer;Answer\nto bring;traer;traer\n'),
        throwsA(
          isA<CsvFormatException>()
              .having((e) => e.error, 'error', CsvError.duplicateColumn)
              .having((e) => e.column, 'column', 'answer'),
        ),
      );
    });

    test('over the size limit, before reading it', () {
      expect(
        () => parseCardsCsv(Uint8List(maxCsvFileBytes + 1)),
        _failsWith(CsvError.tooLarge),
      );
    });

    test('with more card rows than the limit', () {
      final rows = List.filled(maxCsvRows + 1, 'q;a').join('\n');

      expect(
        () => _parse('question;answer\n$rows'),
        _failsWith(CsvError.tooManyRows),
      );
      expect(
        _parse('question;answer\n${List.filled(maxCsvRows, 'q;a').join('\n')}')
            .cards,
        hasLength(maxCsvRows),
      );
    });
  });

  test('reads in a background isolate too', () async {
    final csv = await parseCardsCsvInBackground(_fixture('excel_es.csv'));

    expect(csv.cards, hasLength(5));
  });
}
