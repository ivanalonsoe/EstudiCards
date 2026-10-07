import 'dart:async';

import 'package:estudicards/app/l10n/generated/app_localizations.dart';
import 'package:estudicards/app/theme/app_colors.dart';
import 'package:estudicards/app/theme/dimensions.dart';
import 'package:estudicards/core/widgets/adaptive_actions_row.dart';
import 'package:estudicards/features/projects/domain/project_summary.dart';
import 'package:estudicards/features/projects/presentation/project_icon.dart';
import 'package:estudicards/features/projects/presentation/project_providers.dart';
import 'package:estudicards/features/trash/presentation/move_to_trash.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

/// P14: the archived projects, with "Desarchivar" and "Eliminar"
/// (`docs/design/movil-claro/archivados.png`).
class ArchivedScreen extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final archived = ref.watch(archivedProjectsProvider).value;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.archived)),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: switch (archived) {
            null => const SizedBox.shrink(),
            [] => const _EmptyArchived(),
            _ => ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                Text(
                  l10n.archivedInfo,
                  style: Theme.of(context).textTheme.bodyLarge
                      ?.copyWith(color: AppColors.of(context).textMuted),
                ),
                const SizedBox(height: AppSpacing.lg),
                for (final summary in archived) ...[
                  _ArchivedCard(summary: summary),
                  const SizedBox(height: AppSpacing.md),
                ],
              ],
            ),
          },
        ),
      ),
    );
  }
}

class _ArchivedCard extends ConsumerWidget {
  const new({required this.summary});

  final ProjectSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    final project = summary.project;
    final archivedAt = project.archivedAt;

    return Card(
      key: Key('archivedItem.${project.id}'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ProjectIconTile(icon: project.icon, color: project.color),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        project.name,
                        style: text.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        l10n.projectContents(
                          l10n.deckCount(summary.deckCount),
                          l10n.cardCount(summary.cardCount),
                        ),
                        style: text.bodyMedium?.copyWith(
                          color: colors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            AdaptiveActionsRow(
              // Projects archived before the date was recorded show none.
              leading: archivedAt == null
                  ? const SizedBox.shrink()
                  : Text(
                      l10n.archivedOn(_shortDate(context, archivedAt)),
                      style: text.labelLarge?.copyWith(color: colors.textMuted),
                    ),
              actions: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    key: Key('archivedItem.${project.id}.delete'),
                    tooltip: l10n.delete,
                    color: colors.error,
                    onPressed: () => unawaited(
                      confirmMoveProjectToTrash(
                        context,
                        ref,
                        project: project,
                        deckCount: summary.deckCount,
                        cardCount: summary.cardCount,
                      ),
                    ),
                    icon: const Icon(Icons.delete_outline_rounded),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  FilledButton.icon(
                    key: Key('archivedItem.${project.id}.unarchive'),
                    style: FilledButton.styleFrom(
                      backgroundColor: colors.primarySoft,
                      foregroundColor: colors.primaryStrong,
                    ),
                    onPressed: () => unawaited(
                      ref
                          .read(projectsRepositoryProvider)
                          .setArchived(project.id, isArchived: false),
                    ),
                    icon: const Icon(Icons.unarchive_outlined),
                    label: Text(l10n.unarchive),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// "2 sep": day and short month, in local time and the app's language.
  static String _shortDate(BuildContext context, DateTime date) =>
      DateFormat.MMMd(Localizations.localeOf(context).toString())
          .format(date.toLocal());
}

/// No archived projects (SPEC §5.3).
class _EmptyArchived extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    return Center(
      key: const Key('archived.empty'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.archive_outlined, size: 48, color: colors.textMuted),
            const SizedBox(height: AppSpacing.lg),
            Text(
              l10n.archivedEmptyTitle,
              textAlign: TextAlign.center,
              style: text.titleMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              l10n.archivedEmptyBody,
              textAlign: TextAlign.center,
              style: text.bodyMedium?.copyWith(color: colors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}
