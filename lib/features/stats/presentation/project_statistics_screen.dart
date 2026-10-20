import 'package:estudicards/app/l10n/generated/app_localizations.dart';
import 'package:estudicards/app/layout/breakpoints.dart';
import 'package:estudicards/app/router.dart';
import 'package:estudicards/app/theme/dimensions.dart';
import 'package:estudicards/core/widgets/breadcrumb.dart';
import 'package:estudicards/features/projects/domain/project.dart';
import 'package:estudicards/features/projects/presentation/project_providers.dart';
import 'package:estudicards/features/stats/presentation/project_statistics_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    return Breadcrumb([
      (
        label: l10n.home,
        location: AppRoutes.home,
        key: const Key('projectStatistics.breadcrumbHome'),
      ),
      (
        label: project.name,
        location: AppRoutes.project(project.id),
        key: const Key('projectStatistics.breadcrumbProject'),
      ),
      (label: l10n.statistics, location: null, key: null),
    ]);
  }
}
