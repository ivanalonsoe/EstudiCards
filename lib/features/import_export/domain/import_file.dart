// Reads the file picked in P07 step 1 with the reader of its type.
import 'dart:typed_data';

import 'package:estudicards/features/import_export/domain/cards_csv.dart';
import 'package:estudicards/features/import_export/domain/exchange_document.dart';
import 'package:estudicards/features/import_export/domain/exchange_json.dart';
import 'package:estudicards/features/import_export/domain/import_limits.dart';
import 'package:estudicards/features/import_export/domain/import_plan.dart';

/// The files P07 can import, by extension.
enum ImportFileType {
  csv,
  json;

  /// The type of a file called [name], or null if it is neither.
  static ImportFileType? fromName(String name) {
    final dot = name.lastIndexOf('.');
    if (dot <= 0) return null;
    return values.asNameMap()[name.substring(dot + 1).toLowerCase()];
  }

  /// The biggest file of this type that is read (§8.4 rule 1).
  int get maxBytes => switch (this) {
    csv => maxCsvFileBytes,
    json => maxJsonFileBytes,
  };
}

/// Why a picked file cannot be imported, apart from what the readers
/// report (`ExchangeError`, `CsvError`).
enum ImportFileError {
  /// Neither `.csv` nor `.json`.
  unsupportedType,

  /// Over [ImportFileType.maxBytes].
  tooLarge,

  /// A full backup: it is restored from the settings (US-25), not imported.
  backup,
}

class ImportFileException implements Exception {
  const new(this.error);

  final ImportFileError error;

  @override
  String toString() => 'ImportFileException($error)';
}

/// Reads the file the user picked (P07 step 1). Throws
/// [ImportFileException], or the reader's own `ExchangeFormatException` or
/// `CsvFormatException`. It can take a while for a big file, so the screen
/// runs it in a background isolate.
ImportSource readImportFile(String name, Uint8List bytes) {
  final type = ImportFileType.fromName(name);
  if (type == null) {
    throw const ImportFileException(.unsupportedType);
  }
  if (bytes.length > type.maxBytes) {
    throw const ImportFileException(.tooLarge);
  }
  return switch (type) {
    .csv => CsvSource(parseCardsCsv(bytes)),
    .json => switch (decodeExchange(bytes)) {
      DeckDocument(:final deck) => DeckFileSource(deck),
      ProjectDocument(:final project) => ProjectFileSource(project),
      BackupDocument() => throw const ImportFileException(.backup),
    },
  };
}
