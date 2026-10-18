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
import 'package:estudicards/features/import_export/presentation/backup.dart';
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
                ],
              ),
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
