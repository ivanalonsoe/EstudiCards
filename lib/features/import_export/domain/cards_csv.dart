// Reads cards from a CSV file (SPEC §8.3): the app's template, a file saved
// by Excel or Google Sheets, or one written by an AI with the prompt of
// SPEC §8.5.
//
// The `csv` package splits the text into rows and cells following RFC 4180
// (cells in double quotes can hold the separator, quotes written twice and
// line breaks). This file adds what is specific to EstudiCards: the text
// encoding, which separator the file uses, the header row and turning each
// row into a card or an error for the preview.
import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:estudicards/features/cards/domain/card_input.dart';
import 'package:estudicards/features/cards/domain/flashcard.dart';
import 'package:estudicards/features/import_export/domain/import_limits.dart';

/// Why a CSV file cannot be imported at all.
enum CsvError {
  /// Bigger than [maxCsvFileBytes].
  tooLarge,

  /// No header row.
  empty,

  /// The header row has no `question` column.
  missingQuestionColumn,

  /// The header row names a column twice.
  duplicateColumn,

  /// More than [maxCsvRows] card rows.
  tooManyRows,
}

/// Thrown when a CSV file cannot be imported. Nothing has been written.
class CsvFormatException implements Exception {
  const new(this.error, [this.column]);

  final CsvError error;

  /// The column a [CsvError.duplicateColumn] is about.
  final String? column;

  @override
  String toString() => 'CsvFormatException($error, $column)';
}

/// Why one row cannot become a card. The row is skipped.
enum CsvRowProblem {
  questionMissing,
  answerMissing,
  tooFewOptions,
  noCorrectOption,

  /// `correct` is not made of option numbers (1–6) whose option has text.
  invalidCorrect,
}

class CsvRowError {
  const new({required this.row, required this.problem, this.question});

  /// The row number as a spreadsheet shows it: the header is row 1.
  final int row;
  final CsvRowProblem problem;

  /// The question of the row, if it has one, to name it in the preview.
  final String? question;
}

/// A row that can become a card.
class CsvCard {
  const new({required this.row, required this.input, this.deck});

  final int row;
  final CardInput input;

  /// The `deck` column: the deck it goes to when importing as a new
  /// project. Null when empty or absent.
  final String? deck;
}

/// What a CSV file holds.
class CsvImport {
  const new({
    required this.separator,
    required this.cards,
    required this.errors,
  });

  /// `;` or `,`, as detected.
  final String separator;

  /// In the order of the file.
  final List<CsvCard> cards;
  final List<CsvRowError> errors;
}

/// The columns of the template (SPEC §8.3), in its order. Their names are
/// part of the file format and are never translated.
const csvColumns = [
  'question',
  'answer',
  'option1',
  'option2',
  'option3',
  'option4',
  'option5',
  'option6',
  'correct',
  'explanation',
  'example',
  'notes',
];

/// Only when importing as a new project: the deck of each row.
const csvDeckColumn = 'deck';

/// Reads the cards of a CSV file. Throws [CsvFormatException] if the whole
/// file is unusable; a row that is not a valid card goes to
/// [CsvImport.errors] and the rest are still read.
CsvImport parseCardsCsv(Uint8List bytes) {
  // The size is checked first, before reading anything.
  if (bytes.length > maxCsvFileBytes) {
    throw const CsvFormatException(.tooLarge);
  }
  final text = _decodeText(bytes);
  final separator = _detectSeparator(text);
  // Blank lines are kept as rows so that row numbers match the spreadsheet;
  // they are skipped below.
  final rows = Csv(
    fieldDelimiter: separator,
    autoDetect: false,
    skipEmptyLines: false,
  ).decode(text);

  final headerIndex = rows.indexWhere((row) => !_isBlank(row));
  if (headerIndex < 0) throw const CsvFormatException(.empty);
  final columns = _readHeader(rows[headerIndex]);

  final cards = <CsvCard>[];
  final errors = <CsvRowError>[];
  for (var i = headerIndex + 1; i < rows.length; i++) {
    final row = rows[i];
    if (_isBlank(row)) continue;
    if (cards.length + errors.length == maxCsvRows) {
      throw const CsvFormatException(.tooManyRows);
    }
    final cells = _Row(row, columns);
    final (:card, :problem) = _readRow(cells);
    final deck = cells[csvDeckColumn].trim();
    final question = cells['question'].trim();
    if (card != null) {
      cards.add(
        CsvCard(row: i + 1, input: card, deck: deck.isEmpty ? null : deck),
      );
    } else {
      errors.add(
        CsvRowError(
          row: i + 1,
          problem: problem!,
          question: question.isEmpty ? null : question,
        ),
      );
    }
  }
  return CsvImport(separator: separator, cards: cards, errors: errors);
}

/// [parseCardsCsv] in a background isolate, so a large file does not
/// freeze the screen (see `encodeExchangeInBackground`).
Future<CsvImport> parseCardsCsvInBackground(Uint8List bytes) =>
    Isolate.run(() => parseCardsCsv(bytes));

/// The text of the file. It should be UTF-8 (SPEC §8.3), with or without
/// a BOM; if it is not valid UTF-8 it is read as Windows-1252, the encoding
/// of Excel's plain "CSV (delimitado por comas)" in Spanish.
String _decodeText(Uint8List bytes) {
  final hasBom =
      bytes.length >= 3 &&
      bytes[0] == 0xEF &&
      bytes[1] == 0xBB &&
      bytes[2] == 0xBF;
  final body = Uint8List.sublistView(bytes, hasBom ? 3 : 0);
  try {
    return utf8.decode(body);
  } on FormatException {
    return String.fromCharCodes(body.map(_fromWindows1252));
  }
}

/// The character of [byte] in Windows-1252.
int _fromWindows1252(int byte) =>
    byte >= 0x80 && byte < 0xA0 ? _windows1252[byte - 0x80] : byte;

/// Windows-1252 is Latin-1 (where each byte is its own character) except
/// for bytes 0x80–0x9F, which hold €, typographic quotes, dashes… The five
/// unused bytes keep their own value.
const _windows1252 = [
  0x20AC, 0x81, 0x201A, 0x0192, 0x201E, 0x2026, 0x2020, 0x2021, //
  0x02C6, 0x2030, 0x0160, 0x2039, 0x0152, 0x8D, 0x017D, 0x8F, //
  0x90, 0x2018, 0x2019, 0x201C, 0x201D, 0x2022, 0x2013, 0x2014, //
  0x02DC, 0x2122, 0x0161, 0x203A, 0x0153, 0x9D, 0x017E, 0x0178, //
];

/// `;` or `,`, whichever appears more in the first line (the header). The
/// column names never contain either, so the header tells for sure.
String _detectSeparator(String text) {
  final end = text.indexOf(RegExp('[\r\n]'));
  final header = end < 0 ? text : text.substring(0, end);
  final semicolons = ';'.allMatches(header).length;
  final commas = ','.allMatches(header).length;
  return semicolons > commas ? ';' : ',';
}

/// The position of each column, by its name without surrounding spaces and
/// in lower case. Unknown columns are ignored.
Map<String, int> _readHeader(List<dynamic> header) {
  final columns = <String, int>{};
  for (final (index, cell) in header.indexed) {
    final name = '$cell'.trim().toLowerCase();
    if (name.isEmpty) continue;
    if (columns.containsKey(name)) {
      throw CsvFormatException(.duplicateColumn, name);
    }
    columns[name] = index;
  }
  if (!columns.containsKey('question')) {
    throw const CsvFormatException(.missingQuestionColumn);
  }
  return columns;
}

bool _isBlank(List<dynamic> row) => row.every((cell) => '$cell'.trim() == '');

/// A data row, read by column name.
class _Row {
  const new(this._cells, this._columns);

  final List<dynamic> _cells;
  final Map<String, int> _columns;

  /// The cell of [column]; empty if the file has no such column or the row
  /// is shorter. A line break saved as CRLF becomes a plain one.
  String operator [](String column) {
    final index = _columns[column];
    if (index == null || index >= _cells.length) return '';
    return '${_cells[index]}'.replaceAll('\r\n', '\n');
  }
}

/// The card of a row, or else why it cannot be one.
///
/// A row with text in any option column is a test card: its answer is
/// ignored, and `correct` holds the numbers of the correct option columns,
/// separated by `|` (SPEC §8.3). More than one makes "Permitir varias
/// correctas". Any other row is a simple card. The card rules are the
/// editor's (`CardInput.validate`).
({CardInput? card, CsvRowProblem? problem}) _readRow(_Row row) {
  final question = row['question'];
  if (question.trim().isEmpty) {
    return (card: null, problem: CsvRowProblem.questionMissing);
  }

  final options = [for (var n = 1; n <= 6; n++) row['option$n']];
  final isTest = options.any((option) => option.trim().isNotEmpty);
  final correct = <int>{};
  if (isTest) {
    for (final part in row['correct'].split('|')) {
      if (part.trim().isEmpty) continue;
      final number = int.tryParse(part.trim());
      if (number == null ||
          number < 1 ||
          number > options.length ||
          options[number - 1].trim().isEmpty) {
        return (card: null, problem: CsvRowProblem.invalidCorrect);
      }
      correct.add(number);
    }
  }

  final input = CardInput(
    type: isTest ? CardType.test : CardType.simple,
    question: question,
    answer: isTest ? null : row['answer'],
    explanation: isTest ? row['explanation'] : null,
    allowMultiple: correct.length > 1,
    example: row['example'],
    notes: row['notes'],
    options: [
      for (final (i, option) in options.indexed)
        if (option.trim().isNotEmpty)
          CardOptionInput(text: option, isCorrect: correct.contains(i + 1)),
    ],
  );
  final errors = input.validate();
  if (errors.isEmpty) return (card: input, problem: null);
  final problem = switch (errors.first) {
    .questionMissing => CsvRowProblem.questionMissing,
    .answerMissing => CsvRowProblem.answerMissing,
    .noCorrectOption => CsvRowProblem.noCorrectOption,
    // Six columns cannot hold too many options, and two or more correct
    // options turn "allow multiple" on, so only too few is possible.
    .tooFewOptions ||
    .tooManyOptions ||
    .tooManyCorrectOptions => CsvRowProblem.tooFewOptions,
  };
  return (card: null, problem: problem);
}
