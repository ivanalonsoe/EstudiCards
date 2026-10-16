// P12: the statistics of a project (`docs/design/movil-claro/estadisticas.png`).
// On mobile it is the "Estadísticas" tab of the project; on desktop it is its
// own page, opened from "Ver estadísticas", and the project screen shows
// the chart and the most missed cards as a summary.
import 'package:estudicards/app/l10n/generated/app_localizations.dart';
import 'package:estudicards/app/router.dart';
import 'package:estudicards/app/theme/app_colors.dart';
import 'package:estudicards/app/theme/dimensions.dart';
import 'package:estudicards/app/theme/project_palette.dart';
import 'package:estudicards/core/providers.dart';
import 'package:estudicards/features/decks/domain/deck_summary.dart';
import 'package:estudicards/features/decks/presentation/deck_providers.dart';
import 'package:estudicards/features/stats/domain/project_statistics.dart';
import 'package:estudicards/features/stats/presentation/answers_chart.dart';
import 'package:estudicards/features/stats/presentation/stats_card.dart';
import 'package:estudicards/features/stats/presentation/stats_providers.dart';
import 'package:estudicards/features/stats/presentation/stats_texts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Sessions shown at first and added by each "Ver más".
const sessionsPage = 10;

/// Whether [projectId] has anything to show: answers, or sessions that
/// ended. Null while that is still loading.
bool? projectHasStatistics(WidgetRef ref, String projectId) {
  final decks = ref.watch(deckSummariesProvider(projectId)).value;
  final history = ref
      .watch(
        sessionHistoryProvider((projectId: projectId, limit: sessionsPage)),
      )
      .value;
  if (decks == null || history == null) return null;
  final answers = decks.fold(0, (sum, deck) => sum + deck.answers.total);
  return answers > 0 || history.sessions.isNotEmpty;
}

/// Every statistic of the project, one card under another, or in two
/// columns when [wide].
class ProjectStatisticsView extends ConsumerWidget {
  const new({required this.projectId, this.wide = false, super.key});

  final String projectId;
  final bool wide;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    switch (projectHasStatistics(ref, projectId)) {
      case null:
        return const SizedBox.shrink();
      case false:
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: AppSpacing.xxl),
          child: NoStatistics(key: Key('projectScreen.noStatistics')),
        );
      case true:
    }

    const gap = SizedBox(height: AppSpacing.lg);
    final l10n = AppLocalizations.of(context);
    final chart = ProjectChartCard(
      projectId: projectId,
      trailing: StatsCaption(l10n.cardsPerDay),
    );
    final decks = _DeckRatesCard(projectId: projectId);
    final missed = MostMissedCard(projectId: projectId, expandable: true);
    final sessions = _SessionsCard(projectId: projectId);

    if (!wide) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [chart, gap, decks, gap, missed, gap, sessions],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [chart, gap, decks],
          ),
        ),
        const SizedBox(width: AppSpacing.xl),
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [missed, gap, sessions],
          ),
        ),
      ],
    );
  }
}

/// "Últimos 30 días": the project's chart, with [trailing] on the right
/// of the heading ("tarjetas por día", or "Ver estadísticas" on the
/// desktop summary).
class ProjectChartCard extends ConsumerWidget {
  const new({required this.projectId, this.trailing, super.key});

  final String projectId;
  final Widget? trailing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final title = AppLocalizations.of(context).last30Days;
    final series = ref.watch(dailyAnswersProvider(projectId)).value;
    return StatsCard(
      title: title,
      trailing: trailing,
      child: series == null
          ? const SizedBox(height: 220)
          : AnswersChart(series: series, title: title),
    );
  }
}

/// "Aciertos por baraja": a % bar per deck, in the deck's colour.
class _DeckRatesCard extends ConsumerWidget {
  const new({required this.projectId});

  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaries =
        ref.watch(deckSummariesProvider(projectId)).value ??
        const <DeckSummary>[];
    final brightness = Theme.of(context).brightness;
    final text = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);
    return StatsCard(
      title: l10n.correctByDeck,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, summary) in summaries.indexed)
            Padding(
              key: Key('projectStats.deck.${summary.deck.id}'),
              padding: EdgeInsets.only(top: i == 0 ? 0 : AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          summary.deck.name,
                          style: text.titleSmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        rateText(l10n, summary.answers.rate),
                        style: text.titleSmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  ColoredRateBar(
                    rate: summary.answers.rate,
                    color: ProjectColor.fromKey(summary.deck.color)
                        .resolve(brightness),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// "Más falladas": the 3 cards with the most wrong answers. When
/// [expandable], "Ver 10" shows up to 10. Tapping a card opens it.
class MostMissedCard extends ConsumerStatefulWidget {
  const new({required this.projectId, this.expandable = false, super.key});

  final String projectId;
  final bool expandable;

  @override
  ConsumerState<MostMissedCard> createState() => _MostMissedCardState();
}

class _MostMissedCardState extends ConsumerState<MostMissedCard> {
  var _showAll = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final missed =
        ref.watch(mostMissedProvider(widget.projectId)).value ??
        const <MissedCard>[];
    final shown = _showAll ? missed : missed.take(3).toList();
    final canExpand = widget.expandable && !_showAll && missed.length > 3;
    return StatsCard(
      key: const Key('projectStats.missed'),
      title: l10n.mostMissed,
      trailing: canExpand
          ? TextButton(
              key: const Key('projectStats.missed.showAll'),
              onPressed: () => setState(() => _showAll = true),
              child: Text(l10n.seeTop10),
            )
          : null,
      child: missed.isEmpty
          ? Text(
              l10n.noMissedCards,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: colors.textMuted),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, card) in shown.indexed) ...[
                  if (i > 0) const Divider(height: 1),
                  _MissedRow(
                    projectId: widget.projectId,
                    card: card,
                    rank: widget.expandable ? i + 1 : null,
                  ),
                ],
              ],
            ),
    );
  }
}

class _MissedRow extends StatelessWidget {
  const new({required this.projectId, required this.card, this.rank});

  final String projectId;
  final MissedCard card;

  /// Shown on the left in the full list, not in the desktop summary.
  final int? rank;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    final rank = this.rank;
    return InkWell(
      key: Key('projectStats.missed.${card.cardId}'),
      onTap: () =>
          context.go(AppRoutes.editCard(projectId, card.deckId, card.cardId)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: minTouchTarget),
        child: Row(
          children: [
            if (rank != null)
              SizedBox(
                width: 32,
                child: Text(
                  '$rank',
                  style: text.titleSmall?.copyWith(color: colors.textMuted),
                ),
              ),
            Expanded(
              child: Text(
                card.question,
                style: text.titleSmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Icon(Icons.close_rounded, size: 16, color: colors.error),
            const SizedBox(width: AppSpacing.xs),
            Text(
              l10n.wrongAnswers(card.wrongCount),
              style: text.labelLarge?.copyWith(color: colors.error),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Sesiones": the latest sessions that ended, 10 at a time. Tapping one
/// opens its results.
class _SessionsCard extends ConsumerStatefulWidget {
  const new({required this.projectId});

  final String projectId;

  @override
  ConsumerState<_SessionsCard> createState() => _SessionsCardState();
}

class _SessionsCardState extends ConsumerState<_SessionsCard> {
  int _limit = sessionsPage;

  /// The last page read, shown while "Ver más" loads the next one.
  SessionHistory? _history;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    _history =
        ref
            .watch(
              sessionHistoryProvider((
                projectId: widget.projectId,
                limit: _limit,
              )),
            )
            .value ??
        _history;
    final history = _history;
    return StatsCard(
      key: const Key('projectStats.sessions'),
      title: l10n.sessionsTitle,
      child: history == null
          ? const SizedBox.shrink()
          : history.sessions.isEmpty
          ? Text(
              l10n.noSessions,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: AppColors.of(context).textMuted),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, session) in history.sessions.indexed) ...[
                  if (i > 0) const Divider(height: 1),
                  _SessionRow(session: session),
                ],
                if (history.hasMore) ...[
                  const SizedBox(height: AppSpacing.sm),
                  OutlinedButton(
                    key: const Key('projectStats.sessions.more'),
                    onPressed: () => setState(() => _limit += sessionsPage),
                    child: Text(l10n.seeMore),
                  ),
                ],
              ],
            ),
    );
  }
}

class _SessionRow extends ConsumerWidget {
  const new({required this.session});

  final SessionSummary session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    final clock = ref.watch(clockProvider);
    final day = clock.localDay(session.startedAt);
    return InkWell(
      key: Key('projectStats.session.${session.id}'),
      onTap: () => context.go(AppRoutes.results(session.id)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    joinNames(l10n, session.deckNames),
                    style: text.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    l10n.sessionDetails(
                      shortDate(context, day),
                      shortDuration(l10n, session.activeDuration),
                    ),
                    style: text.bodySmall?.copyWith(color: colors.textMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(rateText(l10n, session.answers.rate), style: text.titleSmall),
          ],
        ),
      ),
    );
  }
}
