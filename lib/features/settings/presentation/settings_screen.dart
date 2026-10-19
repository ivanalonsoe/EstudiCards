// P16: settings (`docs/design/movil-claro/ajustes.png`): theme, card text
// size, daily goal, voice status, backups and the footer. They are saved
// in the `settings` table as soon as they change, so they are kept after
// restarting and travel with "Exportar todo".
import 'dart:async';

import 'package:estudicards/app/l10n/generated/app_localizations.dart';
import 'package:estudicards/app/theme/app_colors.dart';
import 'package:estudicards/app/theme/dimensions.dart';
import 'package:estudicards/core/app_version.dart';
import 'package:estudicards/core/providers.dart';
import 'package:estudicards/core/text_search.dart';
import 'package:estudicards/features/cards/presentation/speaker_button.dart';
import 'package:estudicards/features/import_export/data/auto_backup_files.dart';
import 'package:estudicards/features/import_export/presentation/backup.dart';
import 'package:estudicards/features/import_export/presentation/import_providers.dart';
import 'package:estudicards/features/projects/presentation/project_labels.dart';
import 'package:estudicards/features/settings/domain/app_settings.dart';
import 'package:estudicards/features/settings/presentation/settings_providers.dart';
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
    final settings =
        ref.watch(appSettingsProvider).value ?? const AppSettings();
    final repository = ref.watch(settingsRepositoryProvider);
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
              SettingsSectionLabel(l10n.settingsAppearance),
              SettingsPanel(
                children: [
                  _ThemeTile(
                    selected: settings.themeMode,
                    onChanged: (mode) =>
                        unawaited(repository.setThemeMode(mode)),
                  ),
                  _CardTextScaleTile(
                    stored: settings.cardTextScale,
                    onChanged: (scale) =>
                        unawaited(repository.setCardTextScale(scale)),
                  ),
                ],
              ),
              SettingsSectionLabel(l10n.settingsStudy),
              SettingsPanel(
                children: [
                  _DailyGoalTile(
                    goal: settings.dailyGoal,
                    onChanged: (goal) =>
                        unawaited(repository.setDailyGoal(goal)),
                  ),
                ],
              ),
              SettingsSectionLabel(l10n.settingsVoices),
              const _VoicesPanel(),
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

/// "Tema": Sistema, Claro or Oscuro, in a grey track with the chosen one in
/// white, as in the design.
class _ThemeTile extends StatelessWidget {
  const new({required this.selected, required this.onChanged});

  final AppThemeMode selected;
  final ValueChanged<AppThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.settingsTheme, style: text.titleMedium),
          const SizedBox(height: AppSpacing.md),
          SegmentedButton<AppThemeMode>(
            segments: [
              for (final (mode, label) in [
                (AppThemeMode.system, l10n.themeSystem),
                (AppThemeMode.light, l10n.themeLight),
                (AppThemeMode.dark, l10n.themeDark),
              ])
                ButtonSegment(
                  value: mode,
                  label: Text(label, key: Key('settings.theme.${mode.name}')),
                ),
            ],
            selected: {selected},
            showSelectedIcon: false,
            // As wide as the panel.
            expandedInsets: EdgeInsets.zero,
            style: SegmentedButton.styleFrom(
              backgroundColor: colors.surfaceVariant,
              foregroundColor: colors.textMuted,
              selectedBackgroundColor: colors.surface,
              selectedForegroundColor: colors.text,
              side: BorderSide(color: colors.border),
              textStyle: text.labelLarge,
            ),
            onSelectionChanged: (selection) => onChanged(selection.single),
          ),
        ],
      ),
    );
  }
}

/// "Texto de las tarjetas": a slider from 80% to 160% in steps of 10%,
/// between a small and a big "A". It only changes the study card.
class _CardTextScaleTile extends StatefulWidget {
  const new({required this.stored, required this.onChanged});

  /// The size saved in the settings.
  final double stored;

  /// Saves a new size, once the user lets go of the slider.
  final ValueChanged<double> onChanged;

  @override
  State<_CardTextScaleTile> createState() => _CardTextScaleTileState();
}

class _CardTextScaleTileState extends State<_CardTextScaleTile> {
  /// The size being chosen: while dragging, and after letting go until the
  /// saved value catches up.
  double? _chosen;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    if (_chosen == widget.stored) _chosen = null;
    final scale = _chosen ?? widget.stored;
    final percent = l10n.percent((scale * 100).round());
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(l10n.cardTextSize, style: text.titleMedium)),
              Text(percent, style: text.titleMedium),
            ],
          ),
          Row(
            children: [
              ExcludeSemantics(
                child: Text(
                  'A',
                  style: text.labelLarge?.copyWith(color: colors.textMuted),
                ),
              ),
              Expanded(
                // Without the marks of each step, as in the design.
                child: SliderTheme(
                  data: SliderTheme.of(context)
                      .copyWith(tickMarkShape: SliderTickMarkShape.noTickMark),
                  child: Slider(
                    key: const Key('settings.cardTextScale'),
                    value: scale,
                    min: minCardTextScale,
                    max: maxCardTextScale,
                    divisions: ((maxCardTextScale - minCardTextScale) * 10)
                        .round(),
                    semanticFormatterCallback: (value) =>
                        l10n.percent((value * 100).round()),
                    onChanged: (value) =>
                        setState(() => _chosen = roundCardTextScale(value)),
                    onChangeEnd: (value) =>
                        widget.onChanged(roundCardTextScale(value)),
                  ),
                ),
              ),
              ExcludeSemantics(
                child: Text(
                  'A',
                  style: text.headlineSmall?.copyWith(
                    color: colors.textMuted,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// "Objetivo diario" with its switch and, when on, "Tarjetas al día" with
/// "−" and "+" (US-23 AC2). Each change is saved at once.
class _DailyGoalTile extends StatelessWidget {
  const new({required this.goal, required this.onChanged});

  /// Null when the goal is off.
  final int? goal;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    final goal = this.goal;
    final stepStyle = IconButton.styleFrom(
      backgroundColor: colors.surfaceVariant,
      foregroundColor: colors.text,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.control),
      ),
    );
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: Text(l10n.dailyGoal, style: text.titleMedium)),
              // The switch carries the title for screen readers.
              Semantics(
                label: l10n.dailyGoal,
                child: Switch(
                  key: const Key('settings.dailyGoal'),
                  value: goal != null,
                  onChanged: (on) => onChanged(on ? defaultDailyGoal : null),
                ),
              ),
            ],
          ),
          if (goal != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.cardsPerDay,
                    style: text.bodyLarge?.copyWith(color: colors.textMuted),
                  ),
                ),
                IconButton(
                  key: const Key('settings.dailyGoal.decrease'),
                  tooltip: l10n.fewerCards,
                  style: stepStyle,
                  onPressed: goal > minDailyGoal
                      ? () => onChanged(previousDailyGoal(goal))
                      : null,
                  icon: const Icon(Icons.remove_rounded),
                ),
                ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 56),
                  child: Text(
                    '$goal',
                    key: const Key('settings.dailyGoal.value'),
                    textAlign: TextAlign.center,
                    style: text.titleMedium,
                  ),
                ),
                IconButton(
                  key: const Key('settings.dailyGoal.increase'),
                  tooltip: l10n.moreCards,
                  style: stepStyle,
                  onPressed: goal < maxDailyGoal
                      ? () => onChanged(nextDailyGoal(goal))
                      : null,
                  icon: const Icon(Icons.add_rounded),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// "Voces": for each language of the user's language decks, whether the
/// system has a voice to read it (US-13), with the steps to install a
/// missing one.
class _VoicesPanel extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final languages = ref.watch(deckLanguagesProvider).value;
    if (languages == null) return const SizedBox.shrink();
    if (languages.isEmpty) {
      return SettingsPanel(
        children: [
          Padding(
            key: const Key('settings.voices.none'),
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Text(
              l10n.noLanguageDecks,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: colors.textMuted),
            ),
          ),
        ],
      );
    }
    // By name, as the user reads them, ignoring accents.
    final sorted = [...languages]
      ..sort(
        (a, b) =>
            normalizeForSearch(languageName(l10n, a))
                .compareTo(normalizeForSearch(languageName(l10n, b))),
      );
    return SettingsPanel(
      children: [for (final code in sorted) _VoiceTile(language: code)],
    );
  }
}

/// One language: its name and "Instalada" or "No instalada", always with an
/// icon as well as the colour, and "Cómo instalarla" when it is missing.
class _VoiceTile extends ConsumerWidget {
  const new({required this.language});

  final String language;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    // Null while the system answers.
    final available = ref.watch(voiceAvailableProvider(language)).value;
    final (color, icon, label) = available ?? true
        ? (colors.success, Icons.check_rounded, l10n.voiceInstalled)
        : (colors.warning, Icons.error_outline_rounded, l10n.voiceNotInstalled);
    return Padding(
      key: Key('settings.voice.$language'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(languageName(l10n, language), style: text.titleMedium),
                if (available == false)
                  TextButton(
                    key: Key('settings.voice.$language.howTo'),
                    style: TextButton.styleFrom(
                      foregroundColor: colors.primaryStrong,
                      padding: EdgeInsets.zero,
                      textStyle: text.labelLarge?.copyWith(
                        decoration: TextDecoration.underline,
                      ),
                    ),
                    onPressed: () =>
                        unawaited(showVoiceMissingDialog(context, language)),
                    child: Text(l10n.voiceHowToInstall),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          if (available != null)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xs + 2,
              ),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(AppRadii.chip),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 16, color: color),
                  const SizedBox(width: AppSpacing.xs),
                  Text(label, style: text.labelLarge?.copyWith(color: color)),
                ],
              ),
            ),
        ],
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
