import 'dart:async';

import 'package:estudicards/app/l10n/generated/app_localizations.dart';
import 'package:estudicards/app/layout/breakpoints.dart';
import 'package:estudicards/app/router.dart';
import 'package:estudicards/app/theme/app_colors.dart';
import 'package:estudicards/app/theme/dimensions.dart';
import 'package:estudicards/core/widgets/dashed_border.dart';
import 'package:estudicards/features/decks/presentation/deck_form.dart';
import 'package:estudicards/features/decks/presentation/deck_providers.dart';
import 'package:estudicards/features/decks/presentation/deck_tile.dart';
import 'package:estudicards/features/projects/domain/project.dart';
import 'package:estudicards/features/projects/presentation/archive_project.dart';
import 'package:estudicards/features/projects/presentation/project_form.dart';
import 'package:estudicards/features/projects/presentation/project_icon.dart';
import 'package:estudicards/features/projects/presentation/project_labels.dart';
import 'package:estudicards/features/projects/presentation/project_providers.dart';
import 'package:estudicards/features/trash/presentation/move_to_trash.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:go_router/go_router.dart';

/// P03: a project with its decks (`docs/design/movil-claro/proyecto.png`,
/// `escritorio-claro/proyecto.png`).
///
/// Until the statistics of phase 4, % correct shows "—", errors 0, and the
/// statistics tab and the desktop summary show an empty state. "Estudiar",
/// "Repasar errores", "Compartir" and "Importar" arrive with their phases.
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
            body: Center(child: Text(AppLocalizations.of(context).loadError)),
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
                _DeckList(project: project),
                _NewDeckButton(project: project),
              ] else
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.xxl),
                  child: _NoStatistics(),
                ),
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
                Expanded(child: _ProjectHeader(project: project, large: true)),
                const SizedBox(width: AppSpacing.lg),
                _ProjectMenu(project: project),
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
                const Expanded(flex: 2, child: _SummaryCard()),
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
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final style = Theme.of(context).textTheme.labelLarge;
    return Row(
      children: [
        InkWell(
          key: const Key('projectScreen.breadcrumbHome'),
          onTap: () => context.go(AppRoutes.home),
          borderRadius: BorderRadius.circular(AppSpacing.xs),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xs),
            child: Text(
              AppLocalizations.of(context).home,
              style: style?.copyWith(color: colors.textMuted),
            ),
          ),
        ),
        Icon(Icons.chevron_right_rounded, size: 18, color: colors.textMuted),
        const SizedBox(width: AppSpacing.xs),
        Flexible(
          child: Text(
            project.name,
            style: style,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// Icon, name and details. On desktop the details also hold the counts,
/// since there are no metric boxes.
class _ProjectHeader extends ConsumerWidget {
  const new({required this.project, this.large = false});

  final Project project;
  final bool large;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final cardCount = large ? ref.watch(_cardCountProvider(project.id)) : null;
    final details = [
      ?_languages(l10n),
      ?project.description,
      if (cardCount != null) ...[
        l10n.cardCount(cardCount),
        l10n.correctRate('—'),
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

  /// "Inglés → Español", only for a language project with both languages.
  String? _languages(AppLocalizations l10n) {
    final source = project.sourceLang;
    final target = project.targetLang;
    if (project.type != ProjectType.language ||
        source == null ||
        target == null) {
      return null;
    }
    return l10n.languagePair(
      languageName(l10n, source),
      languageName(l10n, target),
    );
  }
}

/// The total number of cards in a project's decks; 0 while loading.
final ProviderFamily<int, String> _cardCountProvider = Provider.family(
  (ref, projectId) =>
      ref
          .watch(deckSummariesProvider(projectId))
          .value
          ?.fold<int>(0, (total, s) => total + s.cardCount) ??
      0,
);

/// The three boxes under the mobile header: cards, % correct and errors.
class _Metrics extends ConsumerWidget {
  const new({required this.projectId});

  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final cards = ref.watch(_cardCountProvider(projectId));
    // % correct and errors arrive with the statistics (phase 4).
    const errors = 0;
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
            value: '—',
            label: l10n.metricCorrect,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: _Metric(
            key: const Key('projectScreen.metric.errors'),
            value: '$errors',
            label: l10n.metricErrors(errors),
          ),
        ),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const new({required this.value, required this.label, super.key});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: text.headlineSmall),
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

/// The project's decks, or the empty state when it has none.
class _DeckList extends ConsumerWidget {
  const new({required this.project});

  final Project project;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaries = ref.watch(deckSummariesProvider(project.id)).value;
    if (summaries == null) return const SizedBox.shrink();
    if (summaries.isEmpty) return const _EmptyDecks();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final summary in summaries) ...[
          DeckTile(summary: summary, project: project),
          const SizedBox(height: AppSpacing.md),
        ],
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
              Text(
                AppLocalizations.of(context).newDeck,
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(color: colors.primaryStrong),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A project with no decks yet (SPEC §5.3).
class _EmptyDecks extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
      key: const Key('projectScreen.empty'),
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
      child: Column(
        children: [
          Icon(Icons.layers_outlined, size: 40, color: colors.textMuted),
          const SizedBox(height: AppSpacing.md),
          Text(
            AppLocalizations.of(context).emptyDecks,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge
                ?.copyWith(color: colors.textMuted),
          ),
        ],
      ),
    );
  }
}

/// The desktop summary next to the decks. The 30-day chart and the most
/// missed cards arrive with the statistics (phase 4).
class _SummaryCard extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    return Card(
      key: const Key('projectScreen.summary'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              AppLocalizations.of(context).last30Days,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.xl),
            const _NoStatistics(),
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }
}

/// Nothing studied yet (SPEC §5.3, "statistics with no data").
class _NoStatistics extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    return Column(
      key: const Key('projectScreen.noStatistics'),
      children: [
        Icon(Icons.bar_chart_rounded, size: 40, color: colors.textMuted),
        const SizedBox(height: AppSpacing.md),
        Text(
          l10n.noStatisticsTitle,
          textAlign: TextAlign.center,
          style: text.titleMedium,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          l10n.noStatisticsBody,
          textAlign: TextAlign.center,
          style: text.bodyMedium?.copyWith(color: colors.textMuted),
        ),
      ],
    );
  }
}

/// The ⋮ menu of the project. "Compartir" arrives in phase 5.
class _ProjectMenu extends ConsumerWidget {
  const new({required this.project});

  final Project project;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return PopupMenuButton<VoidCallback>(
      key: const Key('projectScreen.menu'),
      tooltip: l10n.projectOptions,
      icon: const Icon(Icons.more_vert_rounded),
      // Each item's value is the action to run when it is chosen.
      onSelected: (action) => action(),
      itemBuilder: (menuContext) => [
        PopupMenuItem(
          value: () =>
              unawaited(showProjectForm(context, ref, project: project)),
          child: Text(l10n.editProject),
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
              cardCount: ref.read(_cardCountProvider(project.id)),
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
