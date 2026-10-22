import 'dart:async';

import 'package:estudicards/app/l10n/generated/app_localizations.dart';
import 'package:estudicards/app/layout/breakpoints.dart';
import 'package:estudicards/app/router.dart';
import 'package:estudicards/app/theme/app_colors.dart';
import 'package:estudicards/app/theme/button_styles.dart';
import 'package:estudicards/app/theme/dimensions.dart';
import 'package:estudicards/core/widgets/breadcrumb.dart';
import 'package:estudicards/core/widgets/dashed_border.dart';
import 'package:estudicards/core/widgets/empty_state.dart';
import 'package:estudicards/features/decks/domain/deck_summary.dart';
import 'package:estudicards/features/decks/presentation/deck_form.dart';
import 'package:estudicards/features/decks/presentation/deck_providers.dart';
import 'package:estudicards/features/decks/presentation/deck_tile.dart';
import 'package:estudicards/features/import_export/presentation/share.dart';
import 'package:estudicards/features/projects/domain/project.dart';
import 'package:estudicards/features/projects/presentation/archive_project.dart';
import 'package:estudicards/features/projects/presentation/project_form.dart';
import 'package:estudicards/features/projects/presentation/project_icon.dart';
import 'package:estudicards/features/projects/presentation/project_providers.dart';
import 'package:estudicards/features/stats/domain/metrics.dart';
import 'package:estudicards/features/stats/presentation/project_statistics_view.dart';
import 'package:estudicards/features/stats/presentation/stats_card.dart';
import 'package:estudicards/features/stats/presentation/stats_texts.dart';
import 'package:estudicards/features/study/presentation/review_errors_button.dart';
import 'package:estudicards/features/trash/presentation/move_to_trash.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:go_router/go_router.dart';

/// P03: a project with its decks (`docs/design/movil-claro/proyecto.png`,
/// `escritorio-claro/proyecto.png`).
///
/// The statistics (P12) are a tab on mobile; on desktop a summary sits next
/// to the decks. "Compartir" and "Importar" arrive in phase 5.
class ProjectScreen extends ConsumerWidget {
  const new({required this.projectId, super.key});

  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDesktop =
        FormFactor.fromWidth(MediaQuery.sizeOf(context).width) ==
        FormFactor.desktop;
    return ref
        .watch(projectProvider(projectId))
        .when(
          loading: () => const Scaffold(),
          error: (error, stackTrace) => Scaffold(
            appBar: AppBar(),
            body: LoadErrorState(
              onRetry: () => ref.invalidate(projectProvider(projectId)),
            ),
          ),
          data: (project) {
            if (project == null) return const _ProjectNotFound();
            return isDesktop
                ? _DesktopProject(project: project)
                : _MobileProject(project: project);
          },
        );
  }
}

/// Mobile and tablet: header, metrics and the Barajas / Estadísticas tabs.
class _MobileProject extends StatefulWidget {
  const new({required this.project});

  final Project project;

  @override
  State<_MobileProject> createState() => _MobileProjectState();
}

// `SingleTickerProviderStateMixin` gives the TabController the ticker it
// needs to animate the tab indicator.
class _MobileProjectState extends State<_MobileProject>
    with SingleTickerProviderStateMixin {
  late final _tabs = TabController(length: 2, vsync: this)
    ..addListener(() => setState(() {}));

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final project = widget.project;
    return Scaffold(
      appBar: AppBar(
        actions: [
          _ShareButton(project: project),
          _ProjectMenu(project: project),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
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
            children: [
              _ProjectHeader(project: project),
              const SizedBox(height: AppSpacing.xl),
              _Metrics(projectId: project.id),
              const SizedBox(height: AppSpacing.lg),
              _StudyButton(project: project, expanded: true),
              _ReviewErrors(project: project, expanded: true),
              const SizedBox(height: AppSpacing.xl),
              TabBar(
                controller: _tabs,
                tabs: [
                  Tab(
                    key: const Key('projectScreen.tab.decks'),
                    text: l10n.decks,
                  ),
                  Tab(
                    key: const Key('projectScreen.tab.statistics'),
                    text: l10n.statistics,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              if (_tabs.index == 0) ...[
                _DeckList(project: project, isMobile: true),
              ] else
                ProjectStatisticsView(projectId: project.id),
            ],
          ),
        ),
      ),
    );
  }
}

/// Desktop: breadcrumb, header, and the decks next to the summary.
class _DesktopProject extends StatelessWidget {
  const new({required this.project});

  final Project project;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: 40,
          vertical: AppSpacing.xl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Breadcrumb(project: project),
            const SizedBox(height: AppSpacing.xl),
            Row(
              children: [
                // The header and the actions share the width 3:2 (see the
                // deck screen).
                Expanded(
                  flex: 3,
                  child: _ProjectHeader(project: project, large: true),
                ),
                const SizedBox(width: AppSpacing.lg),
                // Share and import are icons next to the ⋮ menu, as in the
                // design, together with "Repasar errores" at the right, next
                // to "Estudiar". Any width they do not use is left before
                // them.
                Flexible(
                  flex: 2,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _ShareButton(project: project),
                        const SizedBox(width: AppSpacing.sm),
                        IconButton(
                          key: const Key('projectScreen.importDeck'),
                          tooltip: l10n.importDeck,
                          style: boxedIconButtonStyle(context),
                          onPressed: () => context.go(
                            AppRoutes.importCards(projectId: project.id),
                          ),
                          icon: const Icon(Icons.file_upload_outlined),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        _ProjectMenu(project: project),
                        const SizedBox(width: AppSpacing.sm),
                        _ReviewErrors(project: project, expanded: false),
                      ],
                    ),
                  ),
                ),
                _StudyButton(project: project, expanded: false),
              ],
            ),
            const SizedBox(height: AppSpacing.xxl),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(l10n.decks, style: text.titleLarge),
                          ),
                          OutlinedButton.icon(
                            key: const Key('projectScreen.newDeck'),
                            onPressed: () =>
                                showDeckForm(context, project: project),
                            icon: const Icon(Icons.add_rounded),
                            label: Text(l10n.newDeck),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      _DeckList(project: project),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.xl),
                Expanded(flex: 2, child: _Summary(projectId: project.id)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// "Inicio › Inglés B2" above the desktop header.
class _Breadcrumb extends StatelessWidget {
  const new({required this.project});

  final Project project;

  @override
  Widget build(BuildContext context) => Breadcrumb([
    (
      label: AppLocalizations.of(context).home,
      location: AppRoutes.home,
      key: const Key('projectScreen.breadcrumbHome'),
    ),
    (label: project.name, location: null, key: null),
  ]);
}

/// Icon, name and description. On desktop the details also hold the counts,
/// since there are no metric boxes. The languages belong to each deck and
/// show in its row (T2.10).
class _ProjectHeader extends ConsumerWidget {
  const new({required this.project, this.large = false});

  final Project project;
  final bool large;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final totals = large ? ref.watch(_totalsProvider(project.id)) : null;
    final details = [
      ?project.description,
      if (totals != null) ...[
        l10n.cardCount(totals.cards),
        l10n.correctRate(rateText(l10n, totals.answers.rate)),
      ],
    ].join(l10n.detailsSeparator);

    return Row(
      children: [
        ProjectIconTile(
          icon: project.icon,
          color: project.color,
          size: large ? 64 : 56,
        ),
        const SizedBox(width: AppSpacing.lg),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(project.name, style: text.displaySmall),
              if (details.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  details,
                  style: text.titleSmall?.copyWith(
                    color: AppColors.of(context).textMuted,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// "Estudiar": opens the session setup (P08) with the project's last
/// configuration. Full width on mobile.
class _StudyButton extends StatelessWidget {
  const new({required this.project, required this.expanded});

  final Project project;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      key: const Key('projectScreen.study'),
      style: expanded
          ? FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(
                minTouchTarget + AppSpacing.sm,
              ),
            )
          : null,
      onPressed: () => context.go(AppRoutes.sessionSetup(project.id)),
      icon: const Icon(Icons.play_arrow_outlined),
      label: Text(AppLocalizations.of(context).study),
    );
  }
}

/// "Repasar errores (N)", only when the project has pending errors (US-21):
/// under "Estudiar" on mobile, before it on desktop.
class _ReviewErrors extends ConsumerWidget {
  const new({required this.project, required this.expanded});

  final Project project;
  final bool expanded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final errors = ref.watch(_totalsProvider(project.id)).errors;
    if (errors == 0) return const SizedBox.shrink();
    final button = ReviewErrorsButton(
      key: const Key('projectScreen.reviewErrors'),
      projectId: project.id,
      count: errors,
      expanded: expanded,
    );
    return expanded
        ? Padding(
            padding: const EdgeInsets.only(top: AppSpacing.md),
            child: button,
          )
        // A `Flexible` can be returned here because this widget sits
        // directly in a `Row` of the header.
        : Flexible(
            child: Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: button,
            ),
          );
  }
}

/// The totals of a project: its decks' cards, answers and pending errors
/// added up (each deck's were counted in SQL). Zero while loading.
typedef _Totals = ({int cards, AnswerCounts answers, int errors});

final ProviderFamily<_Totals, String> _totalsProvider = Provider.family((
  ref,
  projectId,
) {
  var cards = 0;
  var correct = 0;
  var wrong = 0;
  var errors = 0;
  for (final summary
      in ref.watch(deckSummariesProvider(projectId)).value ??
          const <DeckSummary>[]) {
    cards += summary.cardCount;
    correct += summary.answers.correct;
    wrong += summary.answers.wrong;
    errors += summary.errorCount;
  }
  return (
    cards: cards,
    answers: AnswerCounts(correct: correct, wrong: wrong),
    errors: errors,
  );
});

/// The three boxes under the mobile header: cards, % correct and errors.
class _Metrics extends ConsumerWidget {
  const new({required this.projectId});

  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final totals = ref.watch(_totalsProvider(projectId));
    final cards = totals.cards;
    final errors = totals.errors;
    return Row(
      children: [
        Expanded(
          child: _Metric(
            key: const Key('projectScreen.metric.cards'),
            value: '$cards',
            label: l10n.metricCards(cards),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: _Metric(
            key: const Key('projectScreen.metric.correct'),
            value: rateText(l10n, totals.answers.rate),
            label: l10n.metricCorrect,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: _Metric(
            key: const Key('projectScreen.metric.errors'),
            value: '$errors',
            label: l10n.metricErrors(errors),
            // Red when there are errors to review, as in the design.
            valueColor: errors > 0 ? AppColors.of(context).error : null,
          ),
        ),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const new({
    required this.value,
    required this.label,
    this.valueColor,
    super.key,
  });

  final String value;
  final String label;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: text.headlineSmall?.copyWith(color: valueColor)),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.labelLarge?.copyWith(
                color: AppColors.of(context).textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The project's decks, or the empty state when it has none. On mobile
/// the dashed "Nueva baraja" button follows the decks; with no decks, the
/// empty state's own button takes its place.
class _DeckList extends ConsumerWidget {
  const new({required this.project, this.isMobile = false});

  final Project project;
  final bool isMobile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaries = ref.watch(deckSummariesProvider(project.id)).value;
    if (summaries == null) return const SizedBox.shrink();
    if (summaries.isEmpty) {
      return _EmptyDecks(project: project, isMobile: isMobile);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final summary in summaries) ...[
          DeckTile(summary: summary, project: project),
          const SizedBox(height: AppSpacing.md),
        ],
        if (isMobile) _NewDeckButton(project: project),
      ],
    );
  }
}

/// The dashed "Nueva baraja" button under the mobile deck list.
class _NewDeckButton extends StatelessWidget {
  const new({required this.project});

  final Project project;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return DashedBorder(
      color: colors.border,
      radius: AppRadii.listCard,
      child: InkWell(
        key: const Key('projectScreen.newDeck'),
        onTap: () => showDeckForm(context, project: project),
        borderRadius: BorderRadius.circular(AppRadii.listCard),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_rounded, color: colors.primaryStrong),
              const SizedBox(width: AppSpacing.sm),
              Flexible(
                child: Text(
                  AppLocalizations.of(context).newDeck,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(color: colors.primaryStrong),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A project with no decks yet (SPEC §5.3). On mobile it has "Nueva
/// baraja", in place of the dashed button; on desktop that button is
/// already next to the "Barajas" heading.
class _EmptyDecks extends StatelessWidget {
  const new({required this.project, required this.isMobile});

  final Project project;
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return EmptyState(
      key: const Key('projectScreen.empty'),
      icon: Icons.layers_outlined,
      title: l10n.emptyDecks,
      actions: [
        if (isMobile)
          FilledButton.icon(
            key: const Key('projectScreen.newDeck'),
            onPressed: () => showDeckForm(context, project: project),
            icon: const Icon(Icons.add_rounded),
            label: Text(l10n.newDeck),
          ),
      ],
    );
  }
}

/// The desktop summary next to the decks: the 30-day chart with "Ver
/// estadísticas", and the 3 most missed cards. With nothing studied yet,
/// the empty state.
class _Summary extends ConsumerWidget {
  const new({required this.projectId});

  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final hasStatistics = projectHasStatistics(ref, projectId);
    if (hasStatistics == null) return const SizedBox.shrink();
    if (!hasStatistics) {
      return StatsCard(
        key: const Key('projectScreen.summary'),
        title: l10n.last30Days,
        child: const Padding(
          padding: EdgeInsets.only(bottom: AppSpacing.lg),
          child: NoStatistics(key: Key('projectScreen.noStatistics')),
        ),
      );
    }
    final colors = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ProjectChartCard(
          key: const Key('projectScreen.summary'),
          projectId: projectId,
          trailing: TextButton(
            key: const Key('projectScreen.seeStatistics'),
            style: TextButton.styleFrom(
              foregroundColor: colors.primaryStrong,
              textStyle: Theme.of(context).textTheme.labelLarge
                  ?.copyWith(decoration: TextDecoration.underline),
            ),
            onPressed: () => context.go(AppRoutes.projectStatistics(projectId)),
            child: Text(l10n.seeStatistics),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        MostMissedCard(projectId: projectId),
      ],
    );
  }
}

/// "Compartir" the project (US-26): an icon in the header, as in the
/// design.
class _ShareButton extends ConsumerWidget {
  const new({required this.project});

  final Project project;

  @override
  Widget build(BuildContext context, WidgetRef ref) => IconButton(
    key: const Key('projectScreen.share'),
    tooltip: AppLocalizations.of(context).shareProject,
    // In a box on desktop, as in the design; plain in the mobile top bar.
    style: _isDesktop(context) ? boxedIconButtonStyle(context) : null,
    onPressed: () => unawaited(shareProject(context, ref, project)),
    icon: const Icon(Icons.ios_share_outlined),
  );
}

bool _isDesktop(BuildContext context) =>
    FormFactor.fromWidth(MediaQuery.sizeOf(context).width) ==
    FormFactor.desktop;

/// The ⋮ menu of the project. On mobile it also has "Importar baraja",
/// which desktop shows as an icon.
class _ProjectMenu extends ConsumerWidget {
  const new({required this.project});

  final Project project;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final isDesktop =
        FormFactor.fromWidth(MediaQuery.sizeOf(context).width) ==
        FormFactor.desktop;
    return PopupMenuButton<VoidCallback>(
      key: const Key('projectScreen.menu'),
      tooltip: l10n.projectOptions,
      style: isDesktop ? boxedIconButtonStyle(context) : null,
      icon: const Icon(Icons.more_vert_rounded),
      // Each item's value is the action to run when it is chosen.
      onSelected: (action) => action(),
      itemBuilder: (menuContext) => [
        PopupMenuItem(
          value: () =>
              unawaited(showProjectForm(context, ref, project: project)),
          child: Text(l10n.editProject),
        ),
        if (!isDesktop)
          PopupMenuItem(
            key: const Key('projectScreen.importDeck'),
            value: () =>
                context.go(AppRoutes.importCards(projectId: project.id)),
            child: Text(l10n.importDeck),
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
          value: () => unawaited(
            archiveProject(
              context,
              ref,
              project: project,
              // Archived projects are not on the dashboard path any more.
              afterArchive: () {
                if (context.mounted) context.go(AppRoutes.home);
              },
            ),
          ),
          child: Text(l10n.archive),
        ),
        PopupMenuItem(
          value: () => unawaited(
            confirmMoveProjectToTrash(
              context,
              ref,
              project: project,
              deckCount:
                  ref.read(deckSummariesProvider(project.id)).value?.length ??
                  0,
              cardCount: ref.read(_totalsProvider(project.id)).cards,
              // The project is gone: back to the dashboard, where
              // "Deshacer" is shown (decided with the owner).
              afterMove: () {
                if (context.mounted) context.go(AppRoutes.home);
              },
            ),
          ),
          child: Text(l10n.deleteProject),
        ),
      ],
    );
  }
}

/// The ID does not match any project, e.g. an old link.
class _ProjectNotFound extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        key: const Key('projectScreen.notFound'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.projectNotFound,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              onPressed: () => context.go(AppRoutes.home),
              child: Text(l10n.backToHome),
            ),
          ],
        ),
      ),
    );
  }
}
