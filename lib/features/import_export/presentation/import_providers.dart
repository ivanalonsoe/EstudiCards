import 'dart:typed_data';

import 'package:estudicards/core/providers.dart';
import 'package:estudicards/features/import_export/data/auto_backup_files.dart';
import 'package:estudicards/features/import_export/data/backup_dao.dart';
import 'package:estudicards/features/import_export/data/backup_repository.dart';
import 'package:estudicards/features/import_export/data/exchange_dao.dart';
import 'package:estudicards/features/import_export/data/exchange_repository.dart';
import 'package:estudicards/features/import_export/data/import_dao.dart';
import 'package:estudicards/features/import_export/data/import_repository.dart';
import 'package:estudicards/features/import_export/domain/exchange_document.dart';
import 'package:estudicards/features/import_export/domain/exchange_json.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Builds the files to share and back up (see `ExchangeRepository`).
final exchangeRepositoryProvider = Provider<ExchangeRepository>(
  (ref) => ExchangeRepository(
    ExchangeDao(ref.watch(databaseProvider)),
    ref.watch(clockProvider),
    ref.watch(imageFilesProvider),
  ),
);

/// The automatic backups (see `AutoBackupFiles`).
final autoBackupFilesProvider = Provider<AutoBackupFiles>(
  (ref) => AutoBackupFiles(() => ref.read(backupsFolderProvider.future)),
);

/// Restores full backups (see `BackupRepository`).
final backupRepositoryProvider = Provider<BackupRepository>((ref) {
  final run = ref.watch(backgroundRunnerProvider);
  return BackupRepository(
    BackupDao(ref.watch(databaseProvider)),
    ref.watch(clockProvider),
    ref.watch(imageFilesProvider),
    ref.watch(exchangeRepositoryProvider),
    ref.watch(autoBackupFilesProvider),
    encode: (backup) => _encodeInBackground(run, backup),
  );
});

/// The automatic backups, newest first, for Settings. Read again whenever
/// one is saved or deleted (`ref.invalidate`).
final FutureProvider<List<AutoBackup>> autoBackupsProvider =
    FutureProvider.autoDispose<List<AutoBackup>>(
      (ref) => ref.watch(autoBackupFilesProvider).list(),
    );

/// Top-level, so the work sent to the isolate holds only the backup.
Future<Uint8List> _encodeInBackground(
  BackgroundRunner run,
  BackupDocument backup,
) => run(() => encodeExchange(backup));

/// Previews and writes imports (see `ImportRepository`).
final importRepositoryProvider = Provider<ImportRepository>(
  (ref) => ImportRepository(
    ImportDao(ref.watch(databaseProvider)),
    ref.watch(clockProvider),
    ref.watch(imageFilesProvider),
  ),
);
