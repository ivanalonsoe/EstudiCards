import 'package:estudicards/app/l10n/generated/app_localizations.dart';
import 'package:estudicards/app/layout/breakpoints.dart';
import 'package:estudicards/app/shell/app_menu_drawer.dart';
import 'package:estudicards/app/shell/brand_logo.dart';
import 'package:estudicards/app/theme/app_colors.dart';
import 'package:estudicards/app/theme/dimensions.dart';
import 'package:estudicards/core/providers.dart';
import 'package:estudicards/core/widgets/dashed_border.dart';
import 'package:estudicards/features/projects/domain/greeting.dart';
import 'package:estudicards/features/projects/domain/project_summary.dart';
import 'package:estudicards/features/projects/presentation/project_card.dart';
import 'package:estudicards/features/projects/presentation/project_providers.dart';
import 'package:estudicards/features/projects/presentation/project_search_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// P01: the project list, the first screen of the app
/// (`docs/design/movil-claro/dashboard.png`, `escritorio-claro/dashboard.png`).
///
/// The streak stays at 0 and the daily goal is hidden until the statistics
/// of phase 4 exist.
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

/// Opens the form to create a project; wired up by the project form (T1.3).
void _newProject() {}

/// Mobile and tablet: greeting, search and the list in two sections.
class _MobileDashboard extends ConsumerWidget {
  const new({required this.projects});

  final List<ProjectSummary> projects;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
            const _GreetingText(),
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
class _DesktopDashboard extends StatelessWidget {
  const new({required this.projects});

  final List<ProjectSummary> projects;

  static const double _gap = AppSpacing.lg;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final text = Theme.of(context).textTheme;

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
                  const Expanded(child: _GreetingText(large: true)),
                  FilledButton.icon(
                    key: const Key('dashboard.newProject'),
                    onPressed: _newProject,
                    icon: const Icon(Icons.add_rounded),
                    label: Text(l10n.newProject),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              SizedBox(width: tileWidth, child: const _StreakCard()),
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

/// "Buenos días", "Buenas tardes" or "Buenas noches", by local time.
class _GreetingText extends ConsumerWidget {
  const new({this.large = false});

  final bool large;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final now = ref.watch(clockProvider).now().toLocal();
    return Text(switch (Greeting.at(now)) {
      Greeting.morning => l10n.greetingMorning,
      Greeting.afternoon => l10n.greetingAfternoon,
      Greeting.evening => l10n.greetingEvening,
    }, style: large ? text.displaySmall : text.headlineSmall);
  }
}

/// The streak in the mobile app bar: a flame and "0 días".
class _StreakChip extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
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
            // The real streak arrives with the statistics (phase 4).
            AppLocalizations.of(context).streakDays(0),
            style: Theme.of(context).textTheme.labelLarge
                ?.copyWith(color: colors.primaryStrong),
          ),
        ],
      ),
    );
  }
}

/// The streak card on the desktop dashboard.
class _StreakCard extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    return Card(
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
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // The real streak arrives with the statistics (phase 4).
                Text(l10n.streakDays(0), style: text.titleLarge),
                Text(
                  l10n.currentStreak,
                  style: text.labelMedium?.copyWith(
                    color: colors.primaryStrong,
                  ),
                ),
              ],
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
class _EmptyDashboard extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
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
                  onPressed: _newProject,
                  icon: const Icon(Icons.add_rounded),
                  label: Text(l10n.newProject),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NewProjectFab extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return FloatingActionButton.extended(
      key: const Key('dashboard.newProject'),
      onPressed: _newProject,
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
      icon: const Icon(Icons.add_rounded),
      label: Text(AppLocalizations.of(context).newProject),
    );
  }
}

/// The dashed "Nuevo proyecto" tile at the end of the desktop grid.
class _NewProjectTile extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return DashedBorder(
      color: colors.border,
      radius: AppRadii.listCard,
      child: InkWell(
        key: const Key('dashboard.newProjectTile'),
        onTap: _newProject,
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
