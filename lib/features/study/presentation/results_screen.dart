import 'package:estudicards/app/l10n/generated/app_localizations.dart';
import 'package:estudicards/app/layout/breakpoints.dart';
import 'package:estudicards/app/router.dart';
import 'package:estudicards/app/theme/app_colors.dart';
import 'package:estudicards/app/theme/dimensions.dart';
import 'package:estudicards/features/cards/domain/flashcard.dart';
import 'package:estudicards/features/cards/presentation/formatted_text.dart';
import 'package:estudicards/features/study/domain/card_selection.dart';
import 'package:estudicards/features/study/domain/session_results.dart';
import 'package:estudicards/features/study/domain/study_options.dart';
import 'package:estudicards/features/study/presentation/session_launch.dart';
import 'package:estudicards/features/study/presentation/study_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// P11: the results of a study session (`docs/design/movil-claro/
/// resultados.png`, `escritorio-claro/resultados.png`).
///
/// "Repetir sesión" arrives with the session setup (T3.6), as decided with
/// the owner.
class ResultsScreen extends ConsumerWidget {
  const new({required this.sessionId, super.key});

  final String sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDesktop =
        FormFactor.fromWidth(MediaQuery.sizeOf(context).width) ==
        FormFactor.desktop;
    return ref
        .watch(sessionResultsProvider(sessionId))
        .when(
          loading: () => const Scaffold(),
          error: (error, stackTrace) => Scaffold(
            appBar: AppBar(),
            body: Center(child: Text(AppLocalizations.of(context).loadError)),
          ),
          data: (results) {
            if (results == null) return const _SessionNotFound();
            return isDesktop
                ? _DesktopResults(results: results)
                : _MobileResults(results: results);
          },
        );
  }
}

/// Mobile and tablet: one column, as in `movil-claro/resultados.png`.
class _MobileResults extends StatelessWidget {
  const new({required this.results});

  final SessionResults results;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    final average = results.averageResponseTime;
    final summary = [
      results.projectName,
      l10n.cardCount(results.totalCards),
      l10n.resultsTotalTime(_formatClock(results.activeDuration)),
      if (average != null)
        l10n.resultsAverageTime(_formatShortTime(l10n, average)),
    ].join(' · ');

    return Scaffold(
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                AppSpacing.xxl,
              ),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    key: const Key('results.close'),
                    tooltip: l10n.close,
                    onPressed: () => _backToProject(context, results),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ),
                Center(child: _ScoreRing(results: results, size: 136)),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  _headline(l10n, results.headline),
                  textAlign: TextAlign.center,
                  style: text.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  summary,
                  textAlign: TextAlign.center,
                  style: text.labelMedium?.copyWith(color: colors.textMuted),
                ),
                const SizedBox(height: AppSpacing.xl),
                _CountTiles(results: results),
                const SizedBox(height: AppSpacing.lg),
                if (results.missed.isNotEmpty || results.unanswered.isNotEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.sm,
                      ),
                      child: Column(
                        children: [
                          if (results.missed.isNotEmpty)
                            _CardList.missed(
                              cards: results.missed,
                              collapsible: true,
                            ),
                          if (results.missed.isNotEmpty &&
                              results.unanswered.isNotEmpty)
                            const Divider(
                              indent: AppSpacing.lg,
                              endIndent: AppSpacing.lg,
                            ),
                          if (results.unanswered.isNotEmpty)
                            _CardList.unanswered(
                              cards: results.unanswered,
                              collapsible: true,
                            ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: AppSpacing.xl),
                if (results.missed.isNotEmpty) ...[
                  _ReviewMissedButton(results: results, expanded: true),
                  const SizedBox(height: AppSpacing.md),
                ],
                TextButton(
                  key: const Key('results.back'),
                  style: TextButton.styleFrom(
                    minimumSize: const Size.fromHeight(minTouchTarget),
                  ),
                  onPressed: () => _backToProject(context, results),
                  child: Text(l10n.back),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Desktop: the ring next to the title and tiles, and both lists side by
/// side, as in `escritorio-claro/resultados.png`.
class _DesktopResults extends StatelessWidget {
  const new({required this.results});

  final SessionResults results;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    final subtitle = [
      results.projectName,
      if (results.deckNames.isNotEmpty) _joinNames(l10n, results.deckNames),
      l10n.cardCount(results.totalCards),
    ].join(' · ');

    return Scaffold(
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            children: [
              Row(
                children: [
                  _ScoreRing(results: results, size: 170),
                  const SizedBox(width: AppSpacing.xxxl),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _headline(l10n, results.headline),
                          style: text.headlineLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          subtitle,
                          style: text.bodyLarge?.copyWith(
                            color: colors.textMuted,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        _CountTiles(results: results, withTime: true),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (results.missed.isNotEmpty)
                    Expanded(
                      child: Card(
                        child: _CardList.missed(cards: results.missed),
                      ),
                    ),
                  if (results.missed.isNotEmpty &&
                      results.unanswered.isNotEmpty)
                    const SizedBox(width: AppSpacing.lg),
                  if (results.unanswered.isNotEmpty)
                    Expanded(
                      child: Card(
                        child: _CardList.unanswered(cards: results.unanswered),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.md,
                children: [
                  TextButton(
                    key: const Key('results.backToProject'),
                    onPressed: () => _backToProject(context, results),
                    child: Text(l10n.backToProject),
                  ),
                  if (results.missed.isNotEmpty)
                    _ReviewMissedButton(results: results, expanded: false),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The % correct in an orange ring, with the subtle celebration around it
/// from 80% (SPEC §13.2, assumption 4).
class _ScoreRing extends StatelessWidget {
  const new({required this.results, required this.size});

  final SessionResults results;
  final double size;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    final percent = results.correctPercent;
    final ring = SizedBox.square(
      dimension: size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CircularProgressIndicator(
            value: (percent ?? 0) / 100,
            strokeWidth: size / 10,
            strokeCap: StrokeCap.round,
            backgroundColor: colors.surfaceVariant,
            color: colors.primary,
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  percent == null ? '—' : l10n.percent(percent),
                  style: text.headlineLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: size / 4,
                  ),
                ),
                Text(
                  l10n.resultsCorrectRateLabel,
                  style: text.titleMedium?.copyWith(color: colors.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    if (!results.celebrates) return ring;

    // The celebration: a few small shapes around the ring. They are only
    // decoration, so screen readers skip them.
    final pieces = [
      (const Alignment(-0.95, -0.85), colors.primaryStrong, true),
      (const Alignment(0.95, -1), colors.primary, false),
      (const Alignment(-1.25, 0.05), colors.primary, true),
      (const Alignment(1.25, 0), colors.warning, true),
      (const Alignment(-1.05, 0.75), colors.primary, false),
      (const Alignment(0.95, 0.95), colors.primaryStrong, true),
    ];
    return SizedBox.square(
      key: const Key('results.celebration'),
      dimension: size * 1.4,
      child: Stack(
        children: [
          Center(child: ring),
          for (final (alignment, color, square) in pieces)
            Align(
              alignment: alignment,
              child: ExcludeSemantics(
                child: Transform.rotate(
                  angle: square ? 0.4 : 0,
                  child: Container(
                    width: size / 14,
                    height: size / 14,
                    decoration: BoxDecoration(
                      color: color,
                      shape: square ? BoxShape.rectangle : BoxShape.circle,
                      borderRadius: square ? BorderRadius.circular(2) : null,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// "15 acertadas", "4 falladas", "1 sin responder" and, on desktop, the
/// time.
class _CountTiles extends StatelessWidget {
  const new({required this.results, this.withTime = false});

  final SessionResults results;
  final bool withTime;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final average = results.averageResponseTime;
    final tiles = [
      _CountTile(
        key: const Key('results.correct'),
        value: '${results.correctCount}',
        label: l10n.resultsCorrect,
        color: colors.success,
      ),
      _CountTile(
        key: const Key('results.wrong'),
        value: '${results.wrongCount}',
        label: l10n.resultsWrong,
        color: colors.error,
      ),
      _CountTile(
        key: const Key('results.unanswered'),
        value: '${results.unansweredCount}',
        label: l10n.resultsUnanswered,
        color: colors.text,
      ),
      if (withTime)
        _CountTile(
          key: const Key('results.time'),
          value: _formatClock(results.activeDuration),
          label: l10n.resultsTimeTile(
            average == null ? '—' : _formatShortTime(l10n, average),
          ),
          color: colors.text,
        ),
    ];
    if (withTime) {
      return Wrap(
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.md,
        children: [for (final tile in tiles) SizedBox(width: 120, child: tile)],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (index, tile) in tiles.indexed) ...[
          if (index > 0) const SizedBox(width: AppSpacing.md),
          Expanded(child: tile),
        ],
      ],
    );
  }
}

class _CountTile extends StatelessWidget {
  const new({
    required this.value,
    required this.label,
    required this.color,
    super.key,
  });

  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: text.headlineSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
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

/// "Falladas (4)" or "No respondidas (1)", with each card's question and
/// correct answer. On mobile the heading opens and closes the list; the
/// missed cards start open.
class _CardList extends StatefulWidget {
  const new missed({required this.cards, this.collapsible = false})
    : isMissed = true;

  const new unanswered({required this.cards, this.collapsible = false})
    : isMissed = false;

  final List<SelectedCard> cards;
  final bool isMissed;
  final bool collapsible;

  @override
  State<_CardList> createState() => _CardListState();
}

class _CardListState extends State<_CardList> {
  late bool _open = !widget.collapsible || widget.isMissed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    final count = widget.cards.length;
    final title = widget.isMissed
        ? l10n.resultsMissedList(count)
        : l10n.resultsUnansweredList(count);
    final heading = Row(
      children: [
        Icon(
          widget.isMissed ? Icons.close_rounded : Icons.low_priority_rounded,
          color: widget.isMissed ? colors.error : colors.textMuted,
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(child: Text(title, style: text.titleMedium)),
        if (widget.collapsible)
          Icon(
            _open
                ? Icons.keyboard_arrow_up_rounded
                : Icons.keyboard_arrow_down_rounded,
          ),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.collapsible)
          InkWell(
            key: Key(
              widget.isMissed
                  ? 'results.missedHeading'
                  : 'results.unansweredHeading',
            ),
            onTap: () => setState(() => _open = !_open),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: heading,
            ),
          )
        else
          Padding(padding: const EdgeInsets.all(AppSpacing.lg), child: heading),
        if (_open)
          for (final (index, selected) in widget.cards.indexed) ...[
            if (index > 0)
              const Divider(
                height: 1,
                indent: AppSpacing.lg,
                endIndent: AppSpacing.lg,
              ),
            _CardRow(selected: selected),
          ],
        if (_open) const SizedBox(height: AppSpacing.sm),
      ],
    );
  }
}

/// One card of a list: what was asked, in grey, and the correct answer.
class _CardRow extends StatelessWidget {
  const new({required this.selected});

  final SelectedCard selected;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    final (prompt, answer) = _promptAndAnswer(selected);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: FormattedText(
              prompt,
              style: text.bodyLarge?.copyWith(
                color: colors.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: FormattedText(
              answer,
              textAlign: TextAlign.end,
              style: text.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Repasar falladas ahora" (US-20 AC1). It starts the new session once,
/// even if tapped twice.
class _ReviewMissedButton extends ConsumerStatefulWidget {
  const new({required this.results, required this.expanded});

  final SessionResults results;

  /// Full width, as on mobile.
  final bool expanded;

  @override
  ConsumerState<_ReviewMissedButton> createState() =>
      _ReviewMissedButtonState();
}

class _ReviewMissedButtonState extends ConsumerState<_ReviewMissedButton> {
  bool _starting = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return FilledButton.icon(
      key: const Key('results.reviewMissed'),
      style: widget.expanded
          ? FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(
                minTouchTarget + AppSpacing.sm,
              ),
            )
          : null,
      onPressed: _starting ? null : _start,
      icon: Icon(
        widget.expanded ? Icons.refresh_rounded : Icons.play_arrow_rounded,
      ),
      label: Text(l10n.reviewMissedNow),
    );
  }

  Future<void> _start() async {
    setState(() => _starting = true);
    final sessionId = await startReviewOfMissed(ref, widget.results);
    if (mounted) context.go(AppRoutes.session(sessionId));
  }
}

class _SessionNotFound extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.sessionNotFound),
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

void _backToProject(BuildContext context, SessionResults results) =>
    context.go(AppRoutes.project(results.projectId));

String _headline(AppLocalizations l10n, ResultsHeadline headline) =>
    switch (headline) {
      ResultsHeadline.goodJob => l10n.resultsGoodJob,
      ResultsHeadline.finished => l10n.resultsFinished,
      ResultsHeadline.timeUp => l10n.resultsTimeUp,
    };

/// What was asked and the correct answer, as the card was studied: in
/// reverse the answer was shown and the question was the one to guess. A
/// test card's answer is its correct options.
(String, String) _promptAndAnswer(SelectedCard selected) {
  final card = selected.card;
  if (card.type == CardType.test) {
    return (
      card.question,
      card.options.where((o) => o.isCorrect).map((o) => o.text).join(', '),
    );
  }
  final answer = card.answer ?? '';
  return selected.direction == StudyDirection.reverse
      ? (answer, card.question)
      : (card.question, answer);
}

/// "Verbos irregulares y Phrasal verbs".
String _joinNames(AppLocalizations l10n, List<String> names) {
  if (names.length == 1) return names.single;
  return l10n.listAnd(
    names.sublist(0, names.length - 1).join(', '),
    names.last,
  );
}

/// "6:12", or "1:02:03" past an hour.
String _formatClock(Duration duration) {
  String twoDigits(int value) => value.toString().padLeft(2, '0');
  final seconds = twoDigits(duration.inSeconds % 60);
  if (duration.inHours > 0) {
    final minutes = twoDigits(duration.inMinutes % 60);
    return '${duration.inHours}:$minutes:$seconds';
  }
  return '${duration.inMinutes}:$seconds';
}

/// "18 s" under a minute, "1:05" from a minute.
String _formatShortTime(AppLocalizations l10n, Duration duration) {
  final seconds = (duration.inMilliseconds / 1000).round();
  return seconds < 60
      ? l10n.secondsShort(seconds)
      : _formatClock(Duration(seconds: seconds));
}
