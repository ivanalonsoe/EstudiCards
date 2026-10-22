import 'package:estudicards/app/l10n/generated/app_localizations.dart';
import 'package:estudicards/app/layout/breakpoints.dart';
import 'package:estudicards/app/router.dart';
import 'package:estudicards/app/theme/app_colors.dart';
import 'package:estudicards/app/theme/dimensions.dart';
import 'package:estudicards/app/theme/motion.dart';
import 'package:estudicards/core/widgets/empty_state.dart';
import 'package:estudicards/core/widgets/play_once.dart';
import 'package:estudicards/features/cards/domain/flashcard.dart';
import 'package:estudicards/features/cards/presentation/formatted_text.dart';
import 'package:estudicards/features/stats/presentation/stats_texts.dart';
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
            body: LoadErrorState(
              onRetry: () => ref.invalidate(sessionResultsProvider(sessionId)),
            ),
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
                // "Repetir sesión" and "Volver" share a row, as in the
                // design.
                Row(
                  children: [
                    Expanded(
                      child: _RepeatSessionButton(
                        results: results,
                        expanded: true,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: TextButton(
                        key: const Key('results.back'),
                        style: TextButton.styleFrom(
                          minimumSize: const Size.fromHeight(
                            minTouchTarget + AppSpacing.sm,
                          ),
                        ),
                        onPressed: () => _backToProject(context, results),
                        child: Text(l10n.back),
                      ),
                    ),
                  ],
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
      if (results.deckNames.isNotEmpty) joinNames(l10n, results.deckNames),
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
                  _RepeatSessionButton(results: results, expanded: false),
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
///
/// The ring fills up and the confetti bursts out from behind it once
/// (brief §8). With "reduce motion" on, both just fade in where they end.
class _ScoreRing extends StatelessWidget {
  const new({required this.results, required this.size});

  final SessionResults results;
  final double size;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    final reduced = AppMotion.reduced(context);
    final percent = results.correctPercent;
    final value = (percent ?? 0) / 100;
    final ring = SizedBox.square(
      key: const Key('results.ring'),
      dimension: size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // From 0 to the result, or straight to it with reduced motion.
          PlayOnce(
            duration: AppMotion.ringFill,
            builder: (context, t, _) => CircularProgressIndicator(
              value: reduced
                  ? value
                  : value * AppMotion.ringFillCurve.transform(t),
              strokeWidth: size / 10,
              strokeCap: StrokeCap.round,
              backgroundColor: colors.surfaceVariant,
              color: colors.primary,
            ),
          ),
          // With large system text the % shrinks to fit inside the ring.
          Padding(
            padding: EdgeInsets.all(size / 7),
            child: FittedBox(
              fit: BoxFit.scaleDown,
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
      child: PlayOnce(
        duration: reduced ? AppMotion.fade : AppMotion.confetti,
        builder: (context, t, ring) {
          // The pieces fly out from the middle; the curve overshoots a
          // little, as if they bounced into place.
          final flight = reduced ? 1.0 : AppMotion.confettiCurve.transform(t);
          return Stack(
            children: [
              Center(child: ring),
              Positioned.fill(
                child: Opacity(
                  key: const Key('results.celebrationFade'),
                  // Fully visible in the first third of the flight.
                  opacity: reduced ? t : (t * 3).clamp(0.0, 1.0),
                  child: Stack(
                    children: [
                      for (final (i, (alignment, color, square))
                          in pieces.indexed)
                        Align(
                          alignment: Alignment.lerp(
                            Alignment.center,
                            alignment,
                            flight,
                          )!,
                          child: ExcludeSemantics(
                            child: Transform.rotate(
                              angle: (square ? 0.4 : 0) + (1 - flight) * 2,
                              child: Container(
                                key: Key('results.confetti.$i'),
                                width: size / 14,
                                height: size / 14,
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: square
                                      ? BoxShape.rectangle
                                      : BoxShape.circle,
                                  borderRadius: square
                                      ? BorderRadius.circular(2)
                                      : null,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
        child: ring,
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
    // `IntrinsicHeight` gives every tile the height of the tallest one, as
    // in the design, also when a label takes two lines ("sin responder").
    if (withTime) {
      const tileWidth = 120.0;
      const rowWidth =
          tileWidth * 4 + AppSpacing.md * 3; // The four tiles in one row.
      return LayoutBuilder(
        builder: (context, constraints) => constraints.maxWidth >= rowWidth
            ? IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final (index, tile) in tiles.indexed) ...[
                      if (index > 0) const SizedBox(width: AppSpacing.md),
                      SizedBox(width: tileWidth, child: tile),
                    ],
                  ],
                ),
              )
            // A narrow window: they wrap onto more lines.
            : Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.md,
                children: [
                  for (final tile in tiles)
                    SizedBox(width: tileWidth, child: tile),
                ],
              ),
      );
    }
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (index, tile) in tiles.indexed) ...[
            if (index > 0) const SizedBox(width: AppSpacing.md),
            Expanded(child: tile),
          ],
        ],
      ),
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

/// "Repasar falladas ahora" (US-20 AC1), the main button.
class _ReviewMissedButton extends StatelessWidget {
  const new({required this.results, required this.expanded});

  final SessionResults results;

  /// Full width, as on mobile.
  final bool expanded;

  @override
  Widget build(BuildContext context) => _StartSessionButton(
    key: const Key('results.reviewMissed'),
    label: AppLocalizations.of(context).reviewMissedNow,
    icon: expanded ? Icons.refresh_rounded : Icons.play_arrow_outlined,
    filled: true,
    expanded: expanded,
    start: (ref) => startReviewOfMissed(ref, results),
  );
}

/// "Repetir sesión" (US-20 AC2): the same configuration, with a new random
/// selection of cards.
class _RepeatSessionButton extends StatelessWidget {
  const new({required this.results, required this.expanded});

  final SessionResults results;
  final bool expanded;

  @override
  Widget build(BuildContext context) => _StartSessionButton(
    key: const Key('results.repeatSession'),
    label: AppLocalizations.of(context).repeatSession,
    icon: Icons.replay_rounded,
    filled: false,
    expanded: expanded,
    start: (ref) => launchSession(ref, results.projectId, results.config),
  );
}

/// A button that starts a new session with [start] and opens it. It starts
/// the session once, even if tapped twice.
class _StartSessionButton extends ConsumerStatefulWidget {
  const new({
    required this.label,
    required this.icon,
    required this.filled,
    required this.expanded,
    required this.start,
    super.key,
  });

  final String label;
  final IconData icon;
  final bool filled;
  final bool expanded;

  /// Starts the session and returns its ID.
  final Future<String> Function(WidgetRef ref) start;

  @override
  ConsumerState<_StartSessionButton> createState() =>
      _StartSessionButtonState();
}

class _StartSessionButtonState extends ConsumerState<_StartSessionButton> {
  bool _starting = false;

  @override
  Widget build(BuildContext context) {
    final size = widget.expanded
        ? const Size.fromHeight(minTouchTarget + AppSpacing.sm)
        : null;
    final onPressed = _starting ? null : _start;
    final icon = Icon(widget.icon);
    final label = Text(widget.label);
    return widget.filled
        ? FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: size),
            onPressed: onPressed,
            icon: icon,
            label: label,
          )
        : OutlinedButton.icon(
            style: OutlinedButton.styleFrom(minimumSize: size),
            onPressed: onPressed,
            icon: icon,
            label: label,
          );
  }

  Future<void> _start() async {
    setState(() => _starting = true);
    final sessionId = await widget.start(ref);
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
