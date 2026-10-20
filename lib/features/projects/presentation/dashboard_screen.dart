import 'package:estudicards/app/l10n/generated/app_localizations.dart';
import 'package:estudicards/app/layout/breakpoints.dart';
import 'package:estudicards/app/router.dart';
import 'package:estudicards/app/shell/app_menu_drawer.dart';
import 'package:estudicards/app/shell/brand_logo.dart';
import 'package:estudicards/app/theme/app_colors.dart';
import 'package:estudicards/app/theme/dimensions.dart';
import 'package:estudicards/core/providers.dart';
import 'package:estudicards/core/widgets/dashed_border.dart';
import 'package:estudicards/features/projects/domain/greeting.dart';
import 'package:estudicards/features/projects/domain/project_summary.dart';
import 'package:estudicards/features/projects/presentation/project_card.dart';
import 'package:estudicards/features/projects/presentation/project_form.dart';
import 'package:estudicards/features/projects/presentation/project_providers.dart';
import 'package:estudicards/features/projects/presentation/project_search_field.dart';
import 'package:estudicards/features/stats/domain/metrics.dart';
import 'package:estudicards/features/stats/presentation/goal_ring.dart';
import 'package:estudicards/features/stats/presentation/stats_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// P01: the project list, the first screen of the app
/// (`docs/design/movil-claro/dashboard.png`, `escritorio-claro/dashboard.png`).
///
/// The daily goal appears once it is turned on in Settings (T6.2).
class DashboardScreen extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDesktop =
        FormFactor.fromWidth(MediaQuery.sizeOf(context).width) ==
        FormFactor.desktop;
    // `AsyncValue` is either loading, an error or the data; `when` builds
    // the widget for each case.
    final content = ref
        .watch(projectSummariesProvider)
        .when(
          loading: () => const SizedBox.shrink(),
          error: (error, stackTrace) =>
              Center(child: Text(AppLocalizations.of(context).loadError)),
          data: (all) {
            if (all.isEmpty) return const _EmptyDashboard();
            final visible = ref.watch(visibleProjectsProvider).value ?? all;
            return isDesktop
                ? _DesktopDashboard(projects: visible)
                : _MobileDashboard(projects: visible);
          },
        );
    final hasProjects =
        ref.watch(projectSummariesProvider).value?.isNotEmpty ?? false;

    if (isDesktop) return Scaffold(body: content);
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const BrandLogo(),
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              child: Text(
                AppLocalizations.of(context).appTitle,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          if (hasProjects) const _StreakChip(),
          const SizedBox(width: AppSpacing.lg),
        ],
      ),
      drawer: const AppMenuDrawer(),
      floatingActionButton: hasProjects ? const _NewProjectFab() : null,
      body: content,
    );
  }
}

/// Mobile and tablet: greeting, search and the list in two sections.
class _MobileDashboard extends StatelessWidget {
  const new({required this.projects});

  final List<ProjectSummary> projects;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final favorites = [
      for (final s in projects)
        if (s.project.isFavorite) s,
    ];
    final others = [
      for (final s in projects)
        if (!s.project.isFavorite) s,
    ];

    List<Widget> section(String title, List<ProjectSummary> items) => [
      _SectionHeading(title),
      for (final summary in items) ...[
        ProjectCard(summary: summary),
        const SizedBox(height: AppSpacing.md),
      ],
    ];

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        // On tablets the list keeps a comfortable reading width.
        constraints: const BoxConstraints(maxWidth: 640),
        child: ListView(
          // Bottom padding so the floating button never hides the last card.
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.xxxl * 2,
          ),
          children: [
            const _MobileGreeting(),
            const SizedBox(height: AppSpacing.lg),
            const ProjectSearchField(key: Key('dashboard.search')),
            const SizedBox(height: AppSpacing.sm),
            if (projects.isEmpty) const _NoResults(),
            if (favorites.isNotEmpty) ...section(l10n.favorites, favorites),
            if (others.isNotEmpty) ...section(l10n.recent, others),
          ],
        ),
      ),
    );
  }
}

/// Desktop: greeting with the "Nuevo proyecto" button, the streak, and the
/// projects in a grid. The search is in the sidebar.
class _DesktopDashboard extends ConsumerWidget {
  const new({required this.projects});

  final List<ProjectSummary> projects;

  static const double _gap = AppSpacing.lg;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    final goal = ref.watch(statsOverviewProvider).value?.dailyGoal;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: 40,
        vertical: AppSpacing.xxl,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Three columns on a wide window, two on a narrower one.
          final columns = constraints.maxWidth >= 900 ? 3 : 2;
          final tileWidth =
              (constraints.maxWidth - _gap * (columns - 1)) / columns;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _GreetingText(large: true),
                        _DesktopSubtitle(),
                      ],
                    ),
                  ),
                  OutlinedButton.icon(
                    key: const Key('dashboard.import'),
                    onPressed: () => context.go(AppRoutes.importCards()),
                    icon: const Icon(Icons.upload_rounded),
                    label: Text(l10n.importButton),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  FilledButton.icon(
                    key: const Key('dashboard.newProject'),
                    onPressed: () => showProjectForm(context, ref),
                    icon: const Icon(Icons.add_rounded),
                    label: Text(l10n.newProject),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              // `IntrinsicHeight` gives the cards the height of the
              // tallest one. With a daily goal, its card goes first and the
              // three share the width, as in the design.
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: goal == null
                      ? [
                          SizedBox(
                            width: tileWidth,
                            child: const _StreakCard(),
                          ),
                          const SizedBox(width: _gap),
                          SizedBox(
                            width: tileWidth,
                            child: const _LastWeekCard(),
                          ),
                        ]
                      : [
                          Expanded(child: _GoalCard(progress: goal)),
                          const SizedBox(width: _gap),
                          const Expanded(child: _StreakCard()),
                          const SizedBox(width: _gap),
                          const Expanded(child: _LastWeekCard()),
                        ],
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              Row(
                children: [
                  Text(l10n.yourProjects, style: text.titleLarge),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(
                    child: Text(
                      l10n.projectsOrder,
                      textAlign: TextAlign.end,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.labelMedium?.copyWith(
                        color: colors.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              if (projects.isEmpty) const _NoResults(),
              Wrap(
                spacing: _gap,
                runSpacing: _gap,
                children: [
                  for (final summary in projects)
                    SizedBox(
                      width: tileWidth,
                      child: ProjectCard(summary: summary),
                    ),
                  SizedBox(width: tileWidth, child: const _NewProjectTile()),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

/// "Buenos días", "Buenas tardes" or "Buenas noches", by local time:
/// [large] on desktop, [compact] inside the mobile goal card.
class _GreetingText extends ConsumerWidget {
  const new({this.large = false, this.compact = false});

  final bool large;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final now = ref.watch(clockProvider).now().toLocal();
    return Text(
      switch (Greeting.at(now)) {
        Greeting.morning => l10n.greetingMorning,
        Greeting.afternoon => l10n.greetingAfternoon,
        Greeting.evening => l10n.greetingEvening,
      },
      style: large
          ? text.displaySmall
          : compact
          ? text.titleLarge
          : text.headlineSmall,
    );
  }
}

/// "Te quedan 6 tarjetas para tu objetivo de hoy", or that it is reached;
/// null without a daily goal.
String? _goalText(
  AppLocalizations l10n,
  DailyGoalProgress? goal, {
  bool sentence = false,
}) => switch (goal) {
  null => null,
  DailyGoalProgress(isReached: true) => l10n.goalReached,
  DailyGoalProgress(:final remaining) =>
    sentence
        ? l10n.goalRemainingSentence(remaining)
        : l10n.goalRemaining(remaining),
};

/// Mobile and tablet: the greeting alone, or, with a daily goal, a card
/// with the goal ring, the greeting and the cards left (US-23 AC2).
class _MobileGreeting extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goal = ref.watch(statsOverviewProvider).value?.dailyGoal;
    if (goal == null) return const _GreetingText();
    final colors = AppColors.of(context);
    return Card(
      key: const Key('dashboard.goal'),
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: colors.border),
        borderRadius: BorderRadius.circular(AppRadii.listCard),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            GoalRing(progress: goal, size: 64),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _GreetingText(compact: true),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    _goalText(AppLocalizations.of(context), goal)!,
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(color: colors.textMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Under the desktop greeting: "Te quedan 6 tarjetas para tu objetivo de
/// hoy." with a daily goal, then "Tienes 13 errores pendientes en 2
/// proyectos." when there are any; nothing without either. The errors
/// count the projects on the dashboard, so archived projects are left out
/// (assumption 2).
class _DesktopSubtitle extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final summaries =
        ref.watch(projectSummariesProvider).value ?? const <ProjectSummary>[];
    final goal = ref.watch(statsOverviewProvider).value?.dailyGoal;
    var errors = 0;
    var projects = 0;
    for (final summary in summaries) {
      if (summary.errorCount == 0) continue;
      errors += summary.errorCount;
      projects++;
    }
    final parts = [
      ?_goalText(l10n, goal, sentence: true),
      if (errors > 0) l10n.pendingErrorsInProjects(errors, projects),
    ];
    if (parts.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Text(
        parts.join(' '),
        style: Theme.of(context).textTheme.bodyLarge
            ?.copyWith(color: AppColors.of(context).textMuted),
      ),
    );
  }
}

/// The daily goal card on the desktop dashboard: the ring, "Objetivo
/// diario" and "70% completado".
class _GoalCard extends StatelessWidget {
  const new({required this.progress});

  final DailyGoalProgress progress;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    return Card(
      key: const Key('dashboard.goal'),
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.listCard),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Row(
          children: [
            GoalRing(progress: progress, size: 64),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.dailyGoal, style: text.titleMedium),
                  Text(
                    l10n.goalDonePercent((progress.fraction * 100).floor()),
                    style: text.labelMedium?.copyWith(color: colors.textMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The current streak; 0 while it loads.
int _currentStreak(WidgetRef ref) =>
    ref.watch(statsOverviewProvider).value?.streak.current ?? 0;

/// The streak in the mobile app bar: a flame and "12 días".
class _StreakChip extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs + 2,
      ),
      decoration: BoxDecoration(
        color: colors.primarySoft,
        borderRadius: BorderRadius.circular(AppRadii.chip),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.local_fire_department_outlined,
            color: colors.primary,
            size: 18,
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            AppLocalizations.of(context).streakDays(_currentStreak(ref)),
            style: Theme.of(context).textTheme.labelLarge
                ?.copyWith(color: colors.primaryStrong),
          ),
        ],
      ),
    );
  }
}

/// The streak card on the desktop dashboard: "12 días" and "Racha actual ·
/// récord 21".
class _StreakCard extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    final best = ref.watch(statsOverviewProvider).value?.streak.best ?? 0;
    return Card(
      key: const Key('dashboard.streak'),
      margin: EdgeInsets.zero,
      color: colors.primarySoft,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.listCard),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Row(
          children: [
            Icon(
              Icons.local_fire_department_outlined,
              color: colors.primary,
              size: 28,
            ),
            const SizedBox(width: AppSpacing.lg),
            // `Expanded` lets long texts wrap instead of overflowing.
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.streakDays(_currentStreak(ref)),
                    style: text.titleLarge,
                  ),
                  Text(
                    l10n.currentStreakWithRecord(best),
                    style: text.labelMedium?.copyWith(
                      color: colors.primaryStrong,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The cards answered in the last 7 days, today included (decided with the
/// owner: the design's "esta semana" reads "en 7 días").
class _LastWeekCard extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    final count =
        ref.watch(statsOverviewProvider).value?.answeredLast7Days ?? 0;
    return Card(
      key: const Key('dashboard.lastWeek'),
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.listCard),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: colors.success.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadii.control),
              ),
              child: Icon(Icons.check_rounded, color: colors.success),
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$count', style: text.titleLarge),
                  Text(
                    AppLocalizations.of(context).cardsLast7Days(count),
                    style: text.labelMedium?.copyWith(color: colors.textMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const new(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: AppSpacing.lg, bottom: AppSpacing.md),
    child: Text(
      title.toUpperCase(),
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
        color: AppColors.of(context).textMuted,
        letterSpacing: 1.2,
      ),
    ),
  );
}

/// The search found nothing (SPEC §5.3).
class _NoResults extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) => Padding(
    key: const Key('dashboard.noResults'),
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
    child: Text(
      AppLocalizations.of(context)
          .noSearchResults(ref.watch(projectSearchQueryProvider).trim()),
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.bodyLarge
          ?.copyWith(color: AppColors.of(context).textMuted),
    ),
  );
}

/// No projects yet: the logo, an explanation and the button to create the
/// first one (SPEC §5.3, `docs/design/movil-claro/dashboard-vacio.png`).
class _EmptyDashboard extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    return Center(
      key: const Key('dashboard.empty'),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            children: [
              Container(
                width: 112,
                height: 112,
                decoration: BoxDecoration(
                  color: colors.primarySoft,
                  borderRadius: BorderRadius.circular(AppSpacing.xxl),
                ),
                alignment: Alignment.center,
                child: const BrandLogo(size: 72),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                l10n.emptyProjectsTitle,
                style: text.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                l10n.emptyProjectsBody,
                style: text.bodyLarge?.copyWith(color: colors.textMuted),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xxl),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: const Key('dashboard.newProject'),
                  onPressed: () => showProjectForm(context, ref),
                  icon: const Icon(Icons.add_rounded),
                  label: Text(l10n.newProject),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  key: const Key('dashboard.importEmpty'),
                  onPressed: () => context.go(AppRoutes.importCards()),
                  icon: const Icon(Icons.upload_rounded),
                  label: Text(l10n.importProject),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NewProjectFab extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return FloatingActionButton.extended(
      key: const Key('dashboard.newProject'),
      onPressed: () => showProjectForm(context, ref),
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
      icon: const Icon(Icons.add_rounded),
      label: Text(AppLocalizations.of(context).newProject),
    );
  }
}

/// The dashed "Nuevo proyecto" tile at the end of the desktop grid.
class _NewProjectTile extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    return DashedBorder(
      color: colors.border,
      radius: AppRadii.listCard,
      child: InkWell(
        key: const Key('dashboard.newProjectTile'),
        onTap: () => showProjectForm(context, ref),
        borderRadius: BorderRadius.circular(AppRadii.listCard),
        child: SizedBox(
          height: 160,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: colors.primarySoft,
                  borderRadius: BorderRadius.circular(AppRadii.control),
                ),
                child: Icon(Icons.add_rounded, color: colors.primaryStrong),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                AppLocalizations.of(context).newProject,
                style: Theme.of(context).textTheme.labelLarge
                    ?.copyWith(color: colors.primaryStrong),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
