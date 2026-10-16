import 'package:estudicards/app/l10n/generated/app_localizations.dart';
import 'package:estudicards/app/layout/breakpoints.dart';
import 'package:estudicards/app/router.dart';
import 'package:estudicards/app/theme/app_colors.dart';
import 'package:estudicards/app/theme/dimensions.dart';
import 'package:estudicards/features/projects/domain/project.dart';
import 'package:estudicards/features/projects/presentation/project_providers.dart';
import 'package:estudicards/features/stats/presentation/project_statistics_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// P12 on desktop: the statistics of a project on their own page, opened
/// from "Ver estadísticas" (decided with the owner). On mobile they are a
/// tab of the project; if the window narrows here, they show in one column.
class ProjectStatisticsScreen extends ConsumerWidget {
  const new({required this.projectId, super.key});

  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final project = ref.watch(projectProvider(projectId)).value;
    final isDesktop =
        FormFactor.fromWidth(MediaQuery.sizeOf(context).width) ==
        FormFactor.desktop;
    if (!isDesktop) {
      return Scaffold(
        appBar: AppBar(title: Text(project?.name ?? l10n.statistics)),
        body: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [ProjectStatisticsView(projectId: projectId)],
        ),
      );
    }
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: 40,
          vertical: AppSpacing.xl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (project != null) _Breadcrumb(project: project),
            const SizedBox(height: AppSpacing.xl),
            Text(
              l10n.statistics,
              style: Theme.of(context).textTheme.displaySmall,
            ),
            const SizedBox(height: AppSpacing.xl),
            ProjectStatisticsView(projectId: projectId, wide: true),
          ],
        ),
      ),
    );
  }
}

/// "Inicio › Inglés B2 › Estadísticas" above the title.
class _Breadcrumb extends StatelessWidget {
  const new({required this.project});

  final Project project;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final style = Theme.of(context).textTheme.labelLarge;
    Widget link(String label, String location, String key) => InkWell(
      key: Key(key),
      onTap: () => context.go(location),
      borderRadius: BorderRadius.circular(AppSpacing.xs),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xs),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: style?.copyWith(color: colors.textMuted),
        ),
      ),
    );
    final separator = Icon(
      Icons.chevron_right_rounded,
      size: 18,
      color: colors.textMuted,
    );
    return Row(
      children: [
        link(l10n.home, AppRoutes.home, 'projectStatistics.breadcrumbHome'),
        separator,
        Flexible(
          child: link(
            project.name,
            AppRoutes.project(project.id),
            'projectStatistics.breadcrumbProject',
          ),
        ),
        separator,
        const SizedBox(width: AppSpacing.xs),
        Text(l10n.statistics, style: style),
      ],
    );
  }
}
