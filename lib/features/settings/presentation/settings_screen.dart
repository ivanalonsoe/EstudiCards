// P16: settings (`docs/design/movil-claro/ajustes.png`).
//
// For now only the "Datos" section, with the backup actions of phase 5, and
// the footer. Theme, card text size, daily goal and voices arrive with
// T6.2 (decided with the owner).
import 'dart:async';

import 'package:estudicards/app/l10n/generated/app_localizations.dart';
import 'package:estudicards/app/theme/app_colors.dart';
import 'package:estudicards/app/theme/dimensions.dart';
import 'package:estudicards/core/app_version.dart';
import 'package:estudicards/features/import_export/data/auto_backup_files.dart';
import 'package:estudicards/features/import_export/presentation/backup.dart';
import 'package:estudicards/features/import_export/presentation/import_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// P16: settings.
class SettingsScreen extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    final autoBackups = ref.watch(autoBackupsProvider).value ?? const [];
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.xxl,
            ),
            children: [
              SettingsSectionLabel(l10n.settingsData),
              SettingsPanel(
                children: [
                  SettingsActionTile(
                    key: const Key('settings.exportAll'),
                    icon: Icons.download_rounded,
                    title: l10n.exportAll,
                    subtitle: l10n.exportAllHint,
                    onTap: () => unawaited(exportAll(context, ref)),
                  ),
                  SettingsActionTile(
                    key: const Key('settings.restore'),
                    icon: Icons.upload_rounded,
                    title: l10n.restoreBackup,
                    onTap: () => unawaited(restoreBackupFile(context, ref)),
                  ),
                ],
              ),
              // Shown only when there are any (decided with the owner).
              if (autoBackups.isNotEmpty) ...[
                SettingsSectionLabel(l10n.autoBackups),
                SettingsPanel(
                  children: [
                    for (final backup in autoBackups)
                      _AutoBackupTile(backup: backup),
                  ],
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              Text(
                l10n.appVersionLabel(appVersion),
                textAlign: TextAlign.center,
                style: text.bodyMedium?.copyWith(color: colors.textMuted),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                l10n.privacyNote,
                textAlign: TextAlign.center,
                style: text.bodyMedium?.copyWith(color: colors.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// An automatic backup: when it was made, "Restaurar" and a bin to delete
/// it after asking.
class _AutoBackupTile extends ConsumerWidget {
  const new({required this.backup});

  final AutoBackup backup;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    return ListTile(
      key: Key('autoBackup.${backup.name}'),
      contentPadding: const EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.sm,
      ),
      leading: Icon(Icons.history_rounded, color: colors.text),
      title: Text(autoBackupLabel(context, backup), style: text.titleSmall),
      subtitle: Text(
        l10n.autoBackupHint,
        style: text.bodySmall?.copyWith(color: colors.textMuted),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextButton(
            key: Key('autoBackup.${backup.name}.restore'),
            onPressed: () => unawaited(restoreAutoBackup(context, ref, backup)),
            child: Text(l10n.restoreAction),
          ),
          IconButton(
            key: Key('autoBackup.${backup.name}.delete'),
            tooltip: l10n.deleteAutoBackup,
            onPressed: () => unawaited(deleteAutoBackup(context, ref, backup)),
            icon: Icon(Icons.delete_outline_rounded, color: colors.error),
          ),
        ],
      ),
    );
  }
}

/// "DATOS": the grey capital heading above a group of settings.
class SettingsSectionLabel extends StatelessWidget {
  const new(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(0, AppSpacing.lg, 0, AppSpacing.sm),
    child: Text(
      label.toUpperCase(),
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
        color: AppColors.of(context).textMuted,
        letterSpacing: 1.2,
      ),
    ),
  );
}

/// A white card with rows separated by lines, as in the design.
class SettingsPanel extends StatelessWidget {
  const new({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    // A `Material` rather than a decorated box, so the rows' tap ripple is
    // painted on it and stays visible.
    return Material(
      color: colors.surface,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: colors.border),
        borderRadius: BorderRadius.circular(AppRadii.listCard),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (final (i, child) in children.indexed) ...[
            if (i > 0)
              Divider(
                height: 1,
                indent: AppSpacing.lg,
                endIndent: AppSpacing.lg,
                color: colors.border,
              ),
            child,
          ],
        ],
      ),
    );
  }
}

/// A row that runs an action: icon, title, optional subtitle and a chevron.
class SettingsActionTile extends StatelessWidget {
  const new({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xs,
      ),
      leading: Icon(icon, color: colors.text),
      title: Text(title, style: text.titleMedium),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle!,
              style: text.bodyMedium?.copyWith(color: colors.textMuted),
            ),
      trailing: Icon(Icons.chevron_right_rounded, color: colors.textMuted),
    );
  }
}
