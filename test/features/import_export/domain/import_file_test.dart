import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:estudicards/features/import_export/domain/exchange_document.dart';
import 'package:estudicards/features/import_export/domain/exchange_json.dart';
import 'package:estudicards/features/import_export/domain/import_file.dart';
import 'package:estudicards/features/import_export/domain/import_limits.dart';
import 'package:estudicards/features/import_export/domain/import_plan.dart';
import 'package:flutter_test/flutter_test.dart';

Uint8List _json(ExchangeDocument document) => encodeExchange(document);

final _at = DateTime.utc(2026, 10, 17);

Matcher _failsWith(ImportFileError error) =>
    throwsA(isA<ImportFileException>().having((e) => e.error, 'error', error));

void main() {
  test('the type comes from the extension, in any case', () {
    expect(ImportFileType.fromName('verbos.csv'), ImportFileType.csv);
    expect(ImportFileType.fromName('Copia.JSON'), ImportFileType.json);
    expect(ImportFileType.fromName('notas.txt'), isNull);
    expect(ImportFileType.fromName('csv'), isNull);
    expect(ImportFileType.csv.maxBytes, maxCsvFileBytes);
    expect(ImportFileType.json.maxBytes, maxJsonFileBytes);
  });

  test('a CSV file is read as cards', () {
    final source = readImportFile(
      'excel_es.csv',
      File('test/fixtures/excel_es.csv').readAsBytesSync(),
    );

    expect((source as CsvSource).csv.cards, hasLength(5));
  });

  test('a shared deck or project is read from JSON', () {
    final deck = readImportFile(
      'd.json',
      _json(
        DeckDocument(
          exportedAt: _at,
          appVersion: '1.0.0',
          deck: const ExchangeDeck(id: 'd', name: 'Verbos'),
        ),
      ),
    );
    final project = readImportFile(
      'p.json',
      _json(
        ProjectDocument(
          exportedAt: _at,
          appVersion: '1.0.0',
          project: const ExchangeProject(
            id: 'p',
            name: 'Inglés',
            color: 'orange',
            icon: 'book',
          ),
        ),
      ),
    );

    expect((deck as DeckFileSource).deck.name, 'Verbos');
    expect((project as ProjectFileSource).project.name, 'Inglés');
  });

  test('a backup is refused: it is restored from the settings', () {
    expect(
      () => readImportFile(
        'copia.json',
        _json(BackupDocument(exportedAt: _at, appVersion: '1.0.0')),
      ),
      _failsWith(ImportFileError.backup),
    );
  });

  test('another type of file is refused', () {
    expect(
      () => readImportFile('notas.txt', utf8.encode('question\nq')),
      _failsWith(ImportFileError.unsupportedType),
    );
  });

  test('a file over the limit of its type is refused', () {
    expect(
      () => readImportFile('big.csv', Uint8List(maxCsvFileBytes + 1)),
      _failsWith(ImportFileError.tooLarge),
    );
  });

  test('the readers report their own errors', () {
    expect(
      () => readImportFile('x.json', utf8.encode('nope')),
      throwsA(isA<ExchangeFormatException>()),
    );
  });
}
