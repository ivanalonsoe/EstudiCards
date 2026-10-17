// The Spanish texts for what the import readers and engine report. The
// domain only gives codes (`ExchangeError`, `CsvError`, `ImportProblem`…);
// the words live in the ARB file.
import 'package:estudicards/app/l10n/generated/app_localizations.dart';
import 'package:estudicards/features/import_export/domain/cards_csv.dart';
import 'package:estudicards/features/import_export/domain/exchange_json.dart';
import 'package:estudicards/features/import_export/domain/import_file.dart';
import 'package:estudicards/features/import_export/domain/import_limits.dart';
import 'package:estudicards/features/import_export/domain/import_plan.dart';

/// A size limit as the user reads it, e.g. "5 MB".
String megabytes(int bytes) => '${bytes ~/ (1024 * 1024)} MB';

/// Why the file called [fileName] cannot be imported, for step 1.
String importErrorMessage(
  AppLocalizations l10n,
  Object error,
  String fileName,
) => switch (error) {
  ImportFileException(error: .unsupportedType) => l10n.importErrorUnsupported,
  ImportFileException(error: .tooLarge) => l10n.importErrorTooLarge(
    megabytes(ImportFileType.fromName(fileName)?.maxBytes ?? maxCsvFileBytes),
  ),
  ImportFileException(error: .backup) => l10n.importErrorBackup,
  ExchangeFormatException(error: .tooLarge) => l10n.importErrorTooLarge(
    megabytes(maxJsonFileBytes),
  ),
  ExchangeFormatException(error: .notJson) => l10n.importErrorNotJson,
  ExchangeFormatException(error: .notEstudiCards || .unknownKind) =>
    l10n.importErrorNotEstudiCards,
  ExchangeFormatException(error: .unsupportedVersion) =>
    l10n.importErrorVersion,
  ExchangeFormatException(error: .invalidData, :final path) =>
    l10n.importErrorInvalidData(path ?? ''),
  ExchangeFormatException(error: .invalidImage, :final path) =>
    l10n.importErrorInvalidImage(path ?? ''),
  ExchangeFormatException(error: .imageTooLarge) =>
    l10n.importErrorImageTooLarge(megabytes(maxImageBytes)),
  CsvFormatException(error: .tooLarge) => l10n.importErrorTooLarge(
    megabytes(maxCsvFileBytes),
  ),
  CsvFormatException(error: .empty) => l10n.importErrorCsvEmpty,
  CsvFormatException(error: .missingQuestionColumn) =>
    l10n.importErrorCsvNoQuestion,
  CsvFormatException(error: .duplicateColumn, :final column) =>
    l10n.importErrorCsvDuplicateColumn(column ?? ''),
  CsvFormatException(error: .tooManyRows) => l10n.importErrorCsvTooManyRows(
    '$maxCsvRows',
  ),
  // The system could not read the file (moved, no permission…).
  _ => l10n.importErrorRead,
};

/// Why a card is not imported, e.g. "falta la respuesta".
String importProblemText(AppLocalizations l10n, ImportProblem problem) =>
    switch (problem) {
      .questionMissing => l10n.problemQuestionMissing,
      .answerMissing => l10n.problemAnswerMissing,
      .tooFewOptions => l10n.problemTooFewOptions,
      .tooManyOptions => l10n.problemTooManyOptions,
      .noCorrectOption => l10n.problemNoCorrectOption,
      .tooManyCorrectOptions => l10n.problemTooManyCorrectOptions,
      .invalidCorrect => l10n.problemInvalidCorrect,
    };
