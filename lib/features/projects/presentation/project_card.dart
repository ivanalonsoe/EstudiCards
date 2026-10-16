import 'dart:async';

import 'package:estudicards/app/l10n/generated/app_localizations.dart';
import 'package:estudicards/app/theme/app_colors.dart';
import 'package:estudicards/app/theme/dimensions.dart';
import 'package:estudicards/app/theme/project_palette.dart';
import 'package:estudicards/core/providers.dart';
import 'package:estudicards/features/projects/domain/project_summary.dart';
import 'package:estudicards/features/projects/presentation/archive_project.dart';
import 'package:estudicards/features/projects/presentation/open_project.dart';
import 'package:estudicards/features/projects/presentation/project_form.dart';
import 'package:estudicards/features/projects/presentation/project_icon.dart';
import 'package:estudicards/features/projects/presentation/project_providers.dart';
import 'package:estudicards/features/stats/presentation/stats_texts.dart';
import 'package:estudicards/features/study/presentation/review_errors_button.dart';
import 'package:estudicards/features/trash/presentation/move_to_trash.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A project on the dashboard (DESIGN_BRIEF.md §6.1): icon, name, counts,
/// % correct, "Repasar errores (N)" or "Sin errores pendientes", and when it
/// was last studied. Tapping it opens the project.
class ProjectCard extends ConsumerWidget {
  const new({required this.summary, super.key});

  final ProjectSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final project = summary.project;
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    final projectColor = ProjectColor.fromKey(project.color)
        .resolve(Theme.of(context).brightness);

    return Card(
      key: Key('projectCard.${project.id}'),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => openProject(context, ref, project.id),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  ProjectIconTile(icon: project.icon, color: project.color),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                project.name,
                                style: text.titleMedium,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (project.isFavorite) ...[
                              const SizedBox(width: AppSpacing.xs),
                              Icon(
                                Icons.star_rounded,
                                color: colors.primary,
                                size: 20,
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xs),
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
                  _ProjectMenu(summary: summary),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadii.chip),
                      child: LinearProgressIndicator(
                        // Empty with no answers yet.
                        value: summary.answers.rate ?? 0,
                        minHeight: 6,
                        color: projectColor,
                        backgroundColor: colors.surfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  Text(
                    l10n.correctRate(rateText(l10n, summary.answers.rate)),
                    style: text.titleSmall,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              // At least as tall as the button, so cards with and without
              // errors line up in the desktop grid.
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: minTouchTarget),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // `Flexible`: on a narrow card the button or the text
                    // shrinks (and ends in "…") so the date still fits.
                    Flexible(
                      child: summary.errorCount > 0
                          ? ReviewErrorsButton(
                              key: Key(
                                'projectCard.${project.id}.reviewErrors',
                              ),
                              projectId: project.id,
                              count: summary.errorCount,
                            )
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.check_rounded,
                                  color: colors.success,
                                  size: 18,
                                ),
                                const SizedBox(width: AppSpacing.xs),
                                Flexible(
                                  child: Text(
                                    l10n.noPendingErrors,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: text.labelMedium?.copyWith(
                                      color: colors.textMuted,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                    ),
                    // When it was last studied: "Hoy", "Ayer", "Hace 2 días".
                    if (summary.lastStudiedAt case final studied?) ...[
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        reviewedText(
                          l10n,
                          studied,
                          ref.watch(clockProvider).now(),
                        ),
                        style: text.labelMedium?.copyWith(
                          color: colors.textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The ⋮ menu of a project card. "Compartir" arrives in phase 5.
class _ProjectMenu extends ConsumerWidget {
  const new({required this.summary});

  final ProjectSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final project = summary.project;
    return PopupMenuButton<VoidCallback>(
      key: Key('projectCard.${project.id}.menu'),
      tooltip: l10n.projectOptions,
      icon: const Icon(Icons.more_vert_rounded),
      // Each item's value is the action to run when it is chosen.
      onSelected: (action) => action(),
      itemBuilder: (menuContext) => [
        PopupMenuItem(
          // `context` is the card's, which stays open after the menu closes.
          value: () =>
              unawaited(showProjectForm(context, ref, project: project)),
          child: Text(l10n.edit),
        ),
        PopupMenuItem(
          value: () => unawaited(
            ref
                .read(projectsRepositoryProvider)
                .setFavorite(project.id, isFavorite: !project.isFavorite),
          ),
          child: Text(
            project.isFavorite ? l10n.unmarkFavorite : l10n.markFavorite,
          ),
        ),
        PopupMenuItem(
          value: () =>
              unawaited(archiveProject(context, ref, project: project)),
          child: Text(l10n.archive),
        ),
        PopupMenuItem(
          value: () => unawaited(
            confirmMoveProjectToTrash(
              context,
              ref,
              project: project,
              deckCount: summary.deckCount,
              cardCount: summary.cardCount,
            ),
          ),
          child: Text(l10n.delete),
        ),
      ],
    );
  }
}
