import 'package:estudicards/app/l10n/generated/app_localizations.dart';
import 'package:estudicards/app/router.dart';
import 'package:estudicards/app/shell/brand_logo.dart';
import 'package:estudicards/app/shell/nav_destinations.dart';
import 'package:estudicards/app/theme/app_colors.dart';
import 'package:estudicards/app/theme/dimensions.dart';
import 'package:estudicards/features/projects/domain/project.dart';
import 'package:estudicards/features/projects/domain/project_summary.dart';
import 'package:estudicards/features/projects/presentation/open_project.dart';
import 'package:estudicards/features/projects/presentation/project_form.dart';
import 'package:estudicards/features/projects/presentation/project_icon.dart';
import 'package:estudicards/features/projects/presentation/project_providers.dart';
import 'package:estudicards/features/projects/presentation/project_search_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The fixed left sidebar on desktop (`docs/design/escritorio-claro/`):
/// logo, project search, "Inicio", the projects (favourites on top) and the
/// menu at the bottom. The daily goal card arrives with phase 4.
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
    final summaries = ref.watch(visibleProjectsProvider).value;
    final projects = <Project>[
      for (final summary in summaries ?? const <ProjectSummary>[])
        summary.project,
    ];
    final favorites = [
      for (final p in projects)
        if (p.isFavorite) p,
    ];
    final others = [
      for (final p in projects)
        if (!p.isFavorite) p,
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
                    for (final project in favorites)
                      _SidebarProjectTile(project: project, location: location),
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
                  for (final project in others)
                    _SidebarProjectTile(project: project, location: location),
                ],
              ),
            ),
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

/// A project in the sidebar; highlighted while its screen (or one of its
/// decks) is open.
class _SidebarProjectTile extends ConsumerWidget {
  const new({required this.project, required this.location});

  final Project project;
  final String location;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final path = AppRoutes.project(project.id);
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
