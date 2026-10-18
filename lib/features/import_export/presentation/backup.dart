// "Exportar todo" (US-24): a full backup, as JSON, shared on mobile or
// saved with "Save as…" on desktop (SPEC §8.1).
import 'dart:typed_data';

import 'package:estudicards/app/l10n/generated/app_localizations.dart';
import 'package:estudicards/core/providers.dart';
import 'package:estudicards/features/import_export/domain/exchange_document.dart';
import 'package:estudicards/features/import_export/domain/exchange_json.dart';
import 'package:estudicards/features/import_export/domain/export_names.dart';
import 'package:estudicards/features/import_export/presentation/import_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Saves or shares `estudicards-backup-<today>.json` with everything in the
/// database. The JSON is written in a background isolate: with images it
/// can be tens of megabytes.
Future<void> exportAll(BuildContext context, WidgetRef ref) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final box = context.findRenderObject() as RenderBox?;
  final origin = box == null ? null : box.localToGlobal(Offset.zero) & box.size;
  try {
    final clock = ref.read(clockProvider);
    final backup = await ref.read(exchangeRepositoryProvider).exportBackup();
    final bytes = await _encode(ref.read(backgroundRunnerProvider), backup);
    final saved = await ref
        .read(fileExporterProvider)
        .export(
          name: backupFileName(clock.localDay(clock.now())),
          bytes: bytes,
          mimeType: 'application/json',
          origin: origin,
        );
    if (saved != null) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.savedTo(saved))));
    }
  } on Object {
    messenger.showSnackBar(SnackBar(content: Text(l10n.shareFailed)));
  }
}

/// Top-level, so the work sent to the isolate holds only the backup.
Future<Uint8List> _encode(BackgroundRunner run, BackupDocument backup) =>
    run(() => encodeExchange(backup));
