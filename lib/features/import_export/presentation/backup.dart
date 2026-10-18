// "Exportar todo" (US-24) and "Restaurar copia" (US-25): a full backup as
// JSON, shared on mobile or saved with "Save as…" on desktop (SPEC §8.1),
// and restoring one, with the automatic backups of Settings.
import 'dart:async';
import 'dart:typed_data';

import 'package:estudicards/app/l10n/generated/app_localizations.dart';
import 'package:estudicards/app/theme/app_colors.dart';
import 'package:estudicards/app/theme/dimensions.dart';
import 'package:estudicards/core/providers.dart';
import 'package:estudicards/core/widgets/choice_tile.dart';
import 'package:estudicards/core/widgets/confirm_dialog.dart';
import 'package:estudicards/features/import_export/data/auto_backup_files.dart';
import 'package:estudicards/features/import_export/data/backup_repository.dart';
import 'package:estudicards/features/import_export/domain/exchange_document.dart';
import 'package:estudicards/features/import_export/domain/exchange_json.dart';
import 'package:estudicards/features/import_export/domain/export_names.dart';
import 'package:estudicards/features/import_export/domain/import_limits.dart';
import 'package:estudicards/features/import_export/presentation/import_messages.dart';
import 'package:estudicards/features/import_export/presentation/import_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

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

/// "Restaurar copia" (US-25): picks a backup file and restores it.
Future<void> restoreBackupFile(BuildContext context, WidgetRef ref) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final file = await ref.read(documentPickerProvider).pick(const ['json']);
  if (file == null || !context.mounted) return;
  final size = file.size;
  if (size != null && size > maxJsonFileBytes) {
    // Refused before reading it, as in the import wizard.
    messenger.showSnackBar(
      SnackBar(
        content: Text(l10n.importErrorTooLarge(megabytes(maxJsonFileBytes))),
      ),
    );
    return;
  }
  await _restore(context, ref, name: file.name, read: file.read);
}

/// Restores an automatic backup from Settings.
Future<void> restoreAutoBackup(
  BuildContext context,
  WidgetRef ref,
  AutoBackup backup,
) => _restore(
  context,
  ref,
  name: autoBackupLabel(context, backup),
  read: () => ref.read(autoBackupFilesProvider).read(backup),
);

/// Deletes an automatic backup after asking (decided with the owner).
Future<void> deleteAutoBackup(
  BuildContext context,
  WidgetRef ref,
  AutoBackup backup,
) async {
  final l10n = AppLocalizations.of(context);
  final confirmed = await showConfirmDialog(
    context,
    title: l10n.deleteAutoBackupTitle,
    body: l10n.deleteAutoBackupBody(autoBackupLabel(context, backup)),
    confirmLabel: l10n.delete,
  );
  if (!confirmed) return;
  await ref.read(autoBackupFilesProvider).delete(backup);
  ref.invalidate(autoBackupsProvider);
}

/// "18 oct 2026, 9:30": when [backup] was made, in local time.
String autoBackupLabel(BuildContext context, AutoBackup backup) => DateFormat(
  'd MMM y, H:mm',
  Localizations.localeOf(context).toString(),
).format(backup.time.toLocal());

/// Reads the backup, asks how to restore it when there is data, and
/// restores it in one transaction (SPEC §8.4 rule 7).
Future<void> _restore(
  BuildContext context,
  WidgetRef ref, {
  required String name,
  required Future<Uint8List> Function() read,
}) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  void say(String message) =>
      messenger.showSnackBar(SnackBar(content: Text(message)));

  final BackupDocument backup;
  try {
    final document = await _decode(
      ref.read(backgroundRunnerProvider),
      await read(),
    );
    if (document is! BackupDocument) {
      say(l10n.notABackup);
      return;
    }
    backup = document;
  } on Object catch (error) {
    say(importErrorMessage(l10n, error, name));
    return;
  }

  final repository = ref.read(backupRepositoryProvider);
  // With nothing to lose, it is restored as it is, without asking.
  var mode = RestoreMode.replaceAll;
  if (!await repository.isEmpty()) {
    if (!context.mounted) return;
    final chosen = await showDialog<RestoreMode>(
      context: context,
      builder: (context) => _RestoreDialog(name: name),
    );
    if (chosen == null || !context.mounted) return;
    if (chosen == RestoreMode.replaceAll &&
        !await showConfirmDialog(
          context,
          title: l10n.replaceAllTitle,
          body: l10n.replaceAllBody,
          confirmLabel: l10n.restoreReplace,
        )) {
      return;
    }
    mode = chosen;
  }
  if (!context.mounted) return;

  // A dialog that cannot be closed while the data changes.
  final navigator = Navigator.of(context, rootNavigator: true);
  unawaited(
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: AlertDialog(
          key: const Key('restoreProgress'),
          content: Row(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: AppSpacing.xl),
              Expanded(child: Text(l10n.restoring)),
            ],
          ),
        ),
      ),
    ),
  );
  try {
    final result = await repository.restore(backup, mode);
    navigator.pop();
    ref.invalidate(autoBackupsProvider);
    say(
      result.autoBackup == null ? l10n.restored : l10n.restoredWithAutoBackup,
    );
  } on Object {
    navigator.pop();
    say(l10n.restoreFailed);
  }
}

/// Reads a backup in a background isolate: it can be tens of megabytes.
Future<ExchangeDocument> _decode(BackgroundRunner run, Uint8List bytes) =>
    run(() => decodeExchange(bytes));

/// The dialog "Ya tienes datos aquí" of `docs/design/movil-claro/dialogos.png`:
/// merge (chosen by default) or replace everything.
class _RestoreDialog extends StatefulWidget {
  const new({required this.name});

  final String name;

  @override
  State<_RestoreDialog> createState() => _RestoreDialogState();
}

class _RestoreDialogState extends State<_RestoreDialog> {
  RestoreMode _mode = RestoreMode.merge;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    return AlertDialog(
      key: const Key('restoreDialog'),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: colors.primarySoft,
              borderRadius: BorderRadius.circular(AppRadii.control),
            ),
            child: Icon(Icons.upload_rounded, color: colors.primaryStrong),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(l10n.restoreDialogTitle, style: text.titleLarge),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.restoreDialogBody(widget.name),
            style: text.bodyMedium?.copyWith(color: colors.textMuted),
          ),
          const SizedBox(height: AppSpacing.lg),
          ChoiceTile(
            key: const Key('restoreDialog.merge'),
            icon: Icons.layers_outlined,
            title: l10n.restoreMerge,
            hint: l10n.restoreMergeHint,
            selected: _mode == RestoreMode.merge,
            onTap: () => setState(() => _mode = RestoreMode.merge),
          ),
          const SizedBox(height: AppSpacing.sm),
          ChoiceTile(
            key: const Key('restoreDialog.replace'),
            icon: Icons.delete_outline_rounded,
            title: l10n.restoreReplace,
            hint: l10n.restoreReplaceHint,
            selected: _mode == RestoreMode.replaceAll,
            destructive: true,
            onTap: () => setState(() => _mode = RestoreMode.replaceAll),
          ),
        ],
      ),
      actions: [
        TextButton(
          key: const Key('restoreDialog.cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          key: const Key('restoreDialog.continue'),
          onPressed: () => Navigator.of(context).pop(_mode),
          child: Text(l10n.restoreContinue),
        ),
      ],
    );
  }
}
