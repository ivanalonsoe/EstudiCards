import 'package:estudicards/app/l10n/generated/app_localizations.dart';
import 'package:estudicards/app/router.dart';
import 'package:estudicards/app/shell/brand_logo.dart';
import 'package:estudicards/app/shell/nav_destinations.dart';
import 'package:estudicards/app/theme/app_colors.dart';
import 'package:estudicards/app/theme/dimensions.dart';
import 'package:estudicards/features/projects/domain/project_summary.dart';
import 'package:estudicards/features/projects/presentation/open_project.dart';
import 'package:estudicards/features/projects/presentation/project_form.dart';
import 'package:estudicards/features/projects/presentation/project_icon.dart';
import 'package:estudicards/features/projects/presentation/project_providers.dart';
import 'package:estudicards/features/projects/presentation/project_search_field.dart';
import 'package:estudicards/features/stats/presentation/goal_ring.dart';
import 'package:estudicards/features/stats/presentation/stats_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The fixed left sidebar on desktop (`docs/design/escritorio-claro/`):
/// logo, project search, "Inicio", the projects (favourites on top), the
/// daily goal card when there is a goal, and the menu at the bottom. Each
/// project shows its pending errors.
class AppSidebar extends ConsumerWidget {
  const new({required this.location, super.key});

  static const double width = 280;

  /// The current path, to highlight the matching menu entry or project.
  final String location;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final summaries =
        ref.watch(visibleProjectsProvider).value ?? const <ProjectSummary>[];
    final favorites = [
      for (final s in summaries)
        if (s.project.isFavorite) s,
    ];
    final others = [
      for (final s in summaries)
        if (!s.project.isFavorite) s,
    ];

    return Material(
      key: const Key('shell.sidebar'),
      color: colors.surface,
      child: Container(
        width: width,
        decoration: BoxDecoration(
          border: Border(right: BorderSide(color: colors.border)),
        ),
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const BrandLogo(),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  l10n.appTitle,
                  style: text.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            const ProjectSearchField(key: Key('sidebar.search'), dense: true),
            const SizedBox(height: AppSpacing.md),
            NavTile(
              destination: homeDestination,
              selected: location == homeDestination.path,
            ),
            Expanded(
              child: ListView(
                children: [
                  if (favorites.isNotEmpty) ...[
                    _SidebarHeading(l10n.favorites),
                    for (final summary in favorites)
                      _SidebarProjectTile(summary: summary, location: location),
                  ],
                  _SidebarHeading(
                    l10n.projects,
                    trailing: IconButton(
                      key: const Key('sidebar.newProject'),
                      tooltip: l10n.newProject,
                      onPressed: () => showProjectForm(context, ref),
                      icon: const Icon(Icons.add_rounded),
                      iconSize: 18,
                      color: colors.primaryStrong,
                      style: IconButton.styleFrom(
                        backgroundColor: colors.primarySoft,
                      ),
                    ),
                  ),
                  for (final summary in others)
                    _SidebarProjectTile(summary: summary, location: location),
                ],
              ),
            ),
            const _SidebarGoal(),
            for (final destination in menuDestinations)
              NavTile(
                destination: destination,
                selected: location == destination.path,
              ),
          ],
        ),
      ),
    );
  }
}

/// "14 de 20 hoy" and the streak, with the goal ring, above the menu; only
/// when a daily goal is set (US-23 AC2).
class _SidebarGoal extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overview = ref.watch(statsOverviewProvider).value;
    final goal = overview?.dailyGoal;
    if (overview == null || goal == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    return Container(
      key: const Key('sidebar.goal'),
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(AppRadii.control),
      ),
      child: Row(
        children: [
          GoalRing(progress: goal, size: 44, showGoal: false),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.goalToday(goal.done, goal.goal),
                  style: text.titleSmall,
                ),
                Row(
                  children: [
                    Icon(
                      Icons.local_fire_department_outlined,
                      size: 14,
                      color: colors.primary,
                    ),
                    const SizedBox(width: 2),
                    Flexible(
                      child: Text(
                        l10n.streakOfDays(overview.streak.current),
                        style: text.labelMedium?.copyWith(
                          color: colors.primaryStrong,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarHeading extends StatelessWidget {
  const new(this.title, {this.trailing});

  final String title;

  /// E.g. the "+" button next to "PROYECTOS".
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.lg,
      AppSpacing.lg,
      AppSpacing.xs,
      AppSpacing.sm,
    ),
    child: Row(
      children: [
        Expanded(
          child: Text(
            title.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.of(context).textMuted,
              letterSpacing: 1.2,
            ),
          ),
        ),
        ?trailing,
      ],
    ),
  );
}

/// A project in the sidebar, with a red badge for its pending errors;
/// highlighted while its screen (or one of its decks) is open.
class _SidebarProjectTile extends ConsumerWidget {
  const new({required this.summary, required this.location});

  final ProjectSummary summary;
  final String location;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final project = summary.project;
    final path = AppRoutes.project(project.id);
    final errors = summary.errorCount;
    return ListTile(
      key: Key('sidebar.project.${project.id}'),
      selected: location == path || location.startsWith('$path/'),
      visualDensity: VisualDensity.compact,
      leading: ProjectIconTile(
        icon: project.icon,
        color: project.color,
        size: 28,
      ),
      title: Text(project.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: errors == 0
          ? null
          : Semantics(
              label: AppLocalizations.of(context).pendingErrors(errors),
              excludeSemantics: true,
              child: Container(
                key: Key('sidebar.project.${project.id}.errors'),
                constraints: const BoxConstraints(minWidth: 22),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xs + 2,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: colors.error.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadii.chip),
                ),
                child: Text(
                  '$errors',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colors.error,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
      textColor: colors.text,
      selectedColor: colors.primaryStrong,
      selectedTileColor: colors.primarySoft,
      titleTextStyle: Theme.of(context).textTheme.titleSmall,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.control),
      ),
      onTap: () => openProject(context, ref, project.id),
    );
  }
}
