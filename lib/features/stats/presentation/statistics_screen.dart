import 'package:estudicards/app/l10n/generated/app_localizations.dart';
import 'package:estudicards/app/layout/breakpoints.dart';
import 'package:estudicards/app/router.dart';
import 'package:estudicards/app/theme/app_colors.dart';
import 'package:estudicards/app/theme/dimensions.dart';
import 'package:estudicards/app/theme/project_palette.dart';
import 'package:estudicards/core/providers.dart';
import 'package:estudicards/features/projects/domain/project_summary.dart';
import 'package:estudicards/features/projects/presentation/project_icon.dart';
import 'package:estudicards/features/projects/presentation/project_providers.dart';
import 'package:estudicards/features/stats/domain/metrics.dart';
import 'package:estudicards/features/stats/presentation/answers_chart.dart';
import 'package:estudicards/features/stats/presentation/stats_card.dart';
import 'package:estudicards/features/stats/presentation/stats_providers.dart';
import 'package:estudicards/features/stats/presentation/stats_texts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// P13: the global statistics (`docs/design/movil-claro/
/// estadisticas-globales.png`, `escritorio-claro/estadisticas.png`).
///
/// Every project not in the trash counts, archived ones too. There is no
/// error review here: errors are always reviewed within one project
/// (US-21).
class StatisticsScreen extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final isDesktop =
        FormFactor.fromWidth(MediaQuery.sizeOf(context).width) ==
        FormFactor.desktop;
    final overview = ref.watch(statsOverviewProvider).value;
    final series = ref.watch(dailyAnswersProvider(null)).value;
    final projects = ref.watch(statisticsProjectsProvider).value;

    final Widget content;
    if (overview == null || series == null || projects == null) {
      content = const SizedBox.shrink();
    } else if (overview.streak.best == 0) {
      // No day has ever had an answer.
      content = Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
        child: NoStatistics(
          key: const Key('statistics.empty'),
          body: l10n.noGlobalStatisticsBody,
        ),
      );
    } else {
      final data = _Data(overview, series, projects);
      content = isDesktop ? _DesktopContent(data) : _MobileContent(data);
    }

    if (isDesktop) {
      return Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: 40,
            vertical: AppSpacing.xl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.statistics,
                style: Theme.of(context).textTheme.displaySmall,
              ),
              const SizedBox(height: AppSpacing.xl),
              content,
            ],
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(l10n.statistics)),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          // On tablets the content keeps a comfortable reading width.
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.xxxl,
            ),
            children: [content],
          ),
        ),
      ),
    );
  }
}

/// What the screen shows, once loaded.
class _Data {
  const new(this.overview, this.series, this.projects);

  final StatsOverview overview;
  final DailySeries series;
  final List<ProjectSummary> projects;
}

/// Mobile and tablet: the streak and record side by side, the three
/// counts, the chart and the projects.
class _MobileContent extends StatelessWidget {
  const new(this.data);

  final _Data data;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final overview = data.overview;
    const gap = SizedBox(width: AppSpacing.md);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // `IntrinsicHeight` gives the cards of a row the same height.
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _StreakCard(
                  days: overview.streak.current,
                  vertical: true,
                ),
              ),
              gap,
              Expanded(
                child: _NumberCard(
                  key: const Key('statistics.best'),
                  icon: Icons.star_outline_rounded,
                  value: l10n.streakDays(overview.streak.best),
                  label: l10n.statsBestStreak,
                  large: true,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _NumberCard(
                  key: const Key('statistics.today'),
                  value: '${overview.answeredToday}',
                  label: l10n.statsToday,
                ),
              ),
              gap,
              Expanded(
                child: _NumberCard(
                  key: const Key('statistics.last7Days'),
                  value: '${overview.answeredLast7Days}',
                  label: l10n.statsLast7Days,
                ),
              ),
              gap,
              Expanded(
                child: _NumberCard(
                  key: const Key('statistics.last30Days'),
                  value: '${data.series.totals.total}',
                  label: l10n.statsLast30Days,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        StatsCard(
          title: l10n.allProjectsChart,
          child: AnswersChart(
            series: data.series,
            title: l10n.allProjectsChart,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        _ProjectsCard(projects: data.projects, wide: false),
      ],
    );
  }
}

/// Desktop: five cards in a row, then the chart next to the projects.
class _DesktopContent extends StatelessWidget {
  const new(this.data);

  final _Data data;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final overview = data.overview;
    const gap = SizedBox(width: AppSpacing.lg);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _StreakCard(
                  days: overview.streak.current,
                  vertical: false,
                ),
              ),
              gap,
              Expanded(
                child: _NumberCard(
                  key: const Key('statistics.best'),
                  value: l10n.streakDays(overview.streak.best),
                  label: l10n.statsBestStreakLong,
                ),
              ),
              gap,
              Expanded(
                child: _NumberCard(
                  key: const Key('statistics.today'),
                  value: '${overview.answeredToday}',
                  label: l10n.statsTodayLong,
                ),
              ),
              gap,
              Expanded(
                child: _NumberCard(
                  key: const Key('statistics.last7Days'),
                  value: '${overview.answeredLast7Days}',
                  label: l10n.statsLast7Days,
                ),
              ),
              gap,
              Expanded(
                child: _NumberCard(
                  key: const Key('statistics.last30Days'),
                  value: '${data.series.totals.total}',
                  label: l10n.statsLast30Days,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: StatsCard(
                title: l10n.allProjectsChartLong,
                trailing: StatsCaption(l10n.cardsPerDay),
                child: AnswersChart(
                  series: data.series,
                  title: l10n.allProjectsChartLong,
                  height: 280,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.xl),
            Expanded(
              flex: 2,
              child: _ProjectsCard(projects: data.projects, wide: true),
            ),
          ],
        ),
      ],
    );
  }
}

/// "12 días · Racha actual" on the brand's soft colour, with the fire icon
/// above (mobile, [vertical]) or on the left (desktop).
class _StreakCard extends StatelessWidget {
  const new({required this.days, required this.vertical});

  final int days;
  final bool vertical;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    final icon = Icon(
      Icons.local_fire_department_outlined,
      color: colors.primary,
      size: 28,
    );
    final texts = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          l10n.streakDays(days),
          style: vertical ? _bigNumber(context) : text.titleLarge,
        ),
        Text(
          l10n.currentStreak,
          style: text.labelLarge?.copyWith(color: colors.primaryStrong),
        ),
      ],
    );
    return Card(
      key: const Key('statistics.streak'),
      margin: EdgeInsets.zero,
      color: colors.primarySoft,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: vertical
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  icon,
                  const SizedBox(height: AppSpacing.md),
                  texts,
                ],
              )
            : Row(
                children: [
                  icon,
                  const SizedBox(width: AppSpacing.md),
                  Expanded(child: texts),
                ],
              ),
      ),
    );
  }
}

/// A number and what it counts ("108 · últimos 7 días"), with an optional
/// [icon] above.
class _NumberCard extends StatelessWidget {
  const new({
    required this.value,
    required this.label,
    this.icon,
    this.large = false,
    super.key,
  });

  final String value;
  final String label;
  final IconData? icon;

  /// The record on mobile has the streak's size.
  final bool large;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    final icon = this.icon;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: EdgeInsets.all(large ? AppSpacing.xl : AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (icon != null) ...[
              Icon(icon, color: colors.textMuted, size: 28),
              const SizedBox(height: AppSpacing.md),
            ],
            Text(value, style: large ? _bigNumber(context) : text.titleLarge),
            Text(
              label,
              style: text.labelLarge?.copyWith(color: colors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Por proyecto": each project's % correct; on desktop also its cards,
/// errors and a bar, on mobile when it was last studied. Tapping a project
/// opens it. No "Repasar errores" here (P13).
class _ProjectsCard extends StatelessWidget {
  const new({required this.projects, required this.wide});

  final List<ProjectSummary> projects;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return StatsCard(
      title: l10n.byProject,
      trailing: StatsCaption(l10n.percentCorrectCaption),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, summary) in projects.indexed) ...[
            if (i > 0) const Divider(height: 1),
            _ProjectRow(summary: summary, wide: wide),
          ],
        ],
      ),
    );
  }
}

class _ProjectRow extends ConsumerWidget {
  const new({required this.summary, required this.wide});

  final ProjectSummary summary;
  final bool wide;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    final project = summary.project;
    final rate = summary.answers.rate;
    final details = wide
        ? [
            l10n.cardCount(summary.cardCount),
            if (summary.errorCount > 0) l10n.errorsChip(summary.errorCount),
          ].join(l10n.detailsSeparator)
        : reviewedText(
            l10n,
            summary.lastStudiedAt,
            ref.watch(clockProvider).now(),
          );
    return InkWell(
      key: Key('statistics.project.${project.id}'),
      onTap: () => context.go(AppRoutes.project(project.id)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Row(
          children: [
            ProjectIconTile(icon: project.icon, color: project.color, size: 44),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    project.name,
                    style: text.titleMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    details,
                    style: text.bodyMedium?.copyWith(color: colors.textMuted),
                  ),
                ],
              ),
            ),
            if (wide) ...[
              const SizedBox(width: AppSpacing.md),
              Expanded(
                flex: 2,
                child: ColoredRateBar(
                  rate: rate,
                  color: ProjectColor.fromKey(project.color)
                      .resolve(Theme.of(context).brightness),
                ),
              ),
            ],
            const SizedBox(width: AppSpacing.md),
            Text(rateText(l10n, rate), style: text.titleSmall),
          ],
        ),
      ),
    );
  }
}

/// The streak and the record on mobile: as large and bold as the design.
TextStyle? _bigNumber(BuildContext context) =>
    Theme.of(context).textTheme.headlineMedium
        ?.copyWith(fontWeight: FontWeight.w800);
