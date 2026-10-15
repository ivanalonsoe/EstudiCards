import 'dart:async';
import 'dart:io';

import 'package:estudicards/app/l10n/generated/app_localizations.dart';
import 'package:estudicards/app/layout/breakpoints.dart';
import 'package:estudicards/app/router.dart';
import 'package:estudicards/app/theme/app_colors.dart';
import 'package:estudicards/app/theme/dimensions.dart';
import 'package:estudicards/core/providers.dart';
import 'package:estudicards/core/widgets/confirm_dialog.dart';
import 'package:estudicards/features/cards/domain/card_speech.dart';
import 'package:estudicards/features/cards/domain/flashcard.dart';
import 'package:estudicards/features/cards/presentation/speaker_button.dart';
import 'package:estudicards/features/cards/presentation/study_card.dart';
import 'package:estudicards/features/decks/domain/deck.dart';
import 'package:estudicards/features/decks/domain/deck_summary.dart';
import 'package:estudicards/features/decks/presentation/deck_providers.dart';
import 'package:estudicards/features/projects/presentation/project_labels.dart';
import 'package:estudicards/features/projects/presentation/project_providers.dart';
import 'package:estudicards/features/study/domain/attempt_record.dart';
import 'package:estudicards/features/study/domain/session_engine.dart';
import 'package:estudicards/features/study/domain/session_event.dart';
import 'package:estudicards/features/study/domain/session_runner.dart';
import 'package:estudicards/features/study/domain/session_state.dart';
import 'package:estudicards/features/study/domain/study_options.dart';
import 'package:estudicards/features/study/presentation/session_launch.dart';
import 'package:estudicards/features/study/presentation/study_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// P09: the study session (`docs/design/movil-claro/estudio.png`,
/// `escritorio-claro/sesion.png`, US-15 to US-17). It covers the whole
/// window, also on desktop.
///
/// The session's cards wait in `launchedSessionsProvider` (see
/// `launchSession`). A session that is not there, e.g. after the app was
/// restarted, cannot go on: its answers so far are already saved.
class SessionScreen extends ConsumerWidget {
  const new({required this.sessionId, super.key});

  final String sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final launch = ref.watch(launchedSessionsProvider)[sessionId];
    if (launch == null) return const _SessionNotFound();
    return _SessionView(sessionId: sessionId, launch: launch);
  }
}

/// Runs the session with a [SessionRunner] and saves every step at once
/// (T3.5). "Pausa" and the pause when the app goes to the background arrive
/// with T3.8.
class _SessionView extends ConsumerStatefulWidget {
  const new({required this.sessionId, required this.launch});

  final String sessionId;
  final SessionLaunch launch;

  @override
  ConsumerState<_SessionView> createState() => _SessionViewState();
}

class _SessionViewState extends ConsumerState<_SessionView> {
  late final SessionRunner _runner;

  /// The saves, one after another, so the answers reach the database in
  /// the order they happened.
  Future<void> _saving = Future.value();
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _runner = SessionRunner(
      engine: SessionEngine(random: ref.read(randomProvider)),
      clock: ref.read(clockProvider),
      cards: widget.launch.cards,
      settings: widget.launch.settings,
      onStep: _onStep,
    );
    _started = true;
  }

  @override
  void dispose() {
    _runner.dispose();
    super.dispose();
  }

  void _onStep(SessionStep step) {
    final repository = ref.read(studyRepositoryProvider);
    _saving = _saving.then((_) => repository.record(widget.sessionId, step));
    if (step.state is Finished) {
      unawaited(_showResults());
    } else if (_started && mounted) {
      // A tick or a button changed the state: draw it again.
      setState(() {});
    }
  }

  /// Once the end is saved, the results replace the session.
  Future<void> _showResults() async {
    final launches = ref.read(launchedSessionsProvider.notifier);
    await _saving;
    if (!mounted) return;
    context.go(AppRoutes.results(widget.sessionId));
    launches.remove(widget.sessionId);
  }

  /// Sends the event built for the card on screen.
  void _send(CardEvent Function(int turn) event) {
    final state = _runner.state;
    if (state is InProgress) _runner.send(event(state.current.turn));
  }

  /// "Acerté" or "Fallé", with a light vibration on phones (brief §8).
  void _grade({required bool correct, required bool haptics}) {
    if (haptics) unawaited(HapticFeedback.lightImpact());
    _send((turn) => SelfGrade(turn: turn, correct: correct));
  }

  /// "Salir" (US-19 AC3): after confirming, the session ends and what was
  /// answered is kept; the rest is recorded as unanswered.
  Future<void> _confirmExit() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.exitSessionTitle,
      body: l10n.exitSessionBody,
      confirmLabel: l10n.exitSession,
      icon: Icons.logout_rounded,
      destructive: false,
    );
    if (confirmed && mounted) _runner.send(const Exit());
  }

  @override
  Widget build(BuildContext context) {
    final state = _runner.state;
    // Finished: the results open as soon as the end is saved.
    if (state is! InProgress) return const Scaffold();
    final isDesktop =
        FormFactor.fromWidth(MediaQuery.sizeOf(context).width) ==
        FormFactor.desktop;
    final step = state.current.step;
    final isTest = state.current.card.type == CardType.test;

    // The system back button asks before leaving, like "Salir".
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) unawaited(_confirmExit());
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              _TopBar(
                session: state,
                projectId: widget.launch.projectId,
                isDesktop: isDesktop,
                now: ref.read(clockProvider).now(),
                onExit: () => unawaited(_confirmExit()),
              ),
              Expanded(
                child: _CardAndActions(
                  isDesktop: isDesktop,
                  card: _SwipeToGrade(
                    // Swiping is for phones and tablets (US-15 AC2).
                    enabled: !isDesktop && step is Flipped,
                    onGrade: (correct) =>
                        _grade(correct: correct, haptics: true),
                    child: _SessionCard(
                      current: state.current,
                      projectId: widget.launch.projectId,
                      onFlip: () => _send((turn) => Flip(turn: turn)),
                      onOptionTap: (id) => _send(
                        (turn) => ToggleOption(turn: turn, optionId: id),
                      ),
                    ),
                  ),
                  actions: _Actions(
                    step: step,
                    isTest: isTest,
                    onFlip: () => _send((turn) => Flip(turn: turn)),
                    onCheck: () => _send((turn) => Check(turn: turn)),
                    onReveal: () => _send((turn) => RevealAnswer(turn: turn)),
                    onLeave: () => _send((turn) => LeaveForLater(turn: turn)),
                    onGrade: (correct) =>
                        _grade(correct: correct, haptics: !isDesktop),
                    onNext: () => _send((turn) => Next(turn: turn)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Lays out the card and its buttons, at most 720 px wide (brief §6.9). On
/// a phone the card is centred and the buttons sit at the bottom, within
/// reach of the thumb; on desktop the buttons go right under the card and
/// both are centred.
class _CardAndActions extends StatelessWidget {
  const new({
    required this.isDesktop,
    required this.card,
    required this.actions,
  });

  final bool isDesktop;
  final Widget card;
  final Widget actions;

  /// The tallest a card gets, so it keeps the proportions of the design.
  static const _maxCardHeight = 560.0;

  @override
  Widget build(BuildContext context) {
    const padding = EdgeInsets.all(AppSpacing.lg);
    if (isDesktop) {
      return LayoutBuilder(
        builder: (context, constraints) {
          // Room for the buttons (about 100 px) under the card.
          final cardHeight = (constraints.maxHeight - 100 - padding.vertical)
              .clamp(200.0, 520.0);
          return Center(
            child: SingleChildScrollView(
              padding: padding,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(height: cardHeight, child: card),
                    const SizedBox(height: AppSpacing.lg),
                    actions,
                  ],
                ),
              ),
            ),
          );
        },
      );
    }
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Padding(
          padding: padding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxHeight: _maxCardHeight,
                    ),
                    child: card,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              actions,
            ],
          ),
        ),
      ),
    );
  }
}

/// ✕ or "Salir", the progress with its bar, "+N repasos", the ✓ and ✗
/// counters and the timer. On desktop the project name goes before the
/// progress.
class _TopBar extends ConsumerWidget {
  const new({
    required this.session,
    required this.projectId,
    required this.isDesktop,
    required this.now,
    required this.onExit,
  });

  final InProgress session;
  final String projectId;
  final bool isDesktop;
  final DateTime now;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    final repeats = session.pendingRepeats;
    final total = session.totalCards;
    final projectName = ref.watch(projectProvider(projectId)).value?.name;

    final progress = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            if (isDesktop && projectName != null)
              Flexible(
                child: Text(
                  '$projectName${l10n.detailsSeparator}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.titleSmall,
                ),
              ),
            Text(
              l10n.sessionProgress(session.answeredCount, total),
              key: const Key('session.progress'),
              style: text.titleSmall,
            ),
            if (repeats > 0) ...[
              const SizedBox(width: AppSpacing.sm),
              Text(
                l10n.pendingRepeats(repeats),
                key: const Key('session.repeats'),
                style: text.labelMedium?.copyWith(color: colors.primaryStrong),
              ),
            ],
            const Spacer(),
            _Counter(
              countKey: const Key('session.correctCount'),
              count: session.correctCount,
              icon: Icons.check_rounded,
              color: colors.success,
              label: l10n.correctCountLabel(session.correctCount),
            ),
            const SizedBox(width: AppSpacing.md),
            _Counter(
              countKey: const Key('session.wrongCount'),
              count: session.wrongCount,
              icon: Icons.close_rounded,
              color: colors.error,
              label: l10n.wrongCountLabel(session.wrongCount),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadii.chip),
          child: LinearProgressIndicator(
            value: total == 0 ? 0 : session.answeredCount / total,
            minHeight: 8,
            color: colors.primary,
            backgroundColor: colors.surfaceVariant,
          ),
        ),
      ],
    );

    final timeLeft =
        session.questionTimeLeft(now) ?? session.sessionTimeLeft(now);
    final exit = isDesktop
        ? TextButton.icon(
            key: const Key('session.exit'),
            style: TextButton.styleFrom(foregroundColor: colors.primaryStrong),
            onPressed: onExit,
            icon: const Icon(Icons.close_rounded),
            label: Text(l10n.exitSession),
          )
        : IconButton(
            key: const Key('session.exit'),
            tooltip: l10n.exitSession,
            onPressed: onExit,
            icon: const Icon(Icons.close_rounded),
          );

    return DecoratedBox(
      decoration: BoxDecoration(
        border: isDesktop
            ? Border(bottom: BorderSide(color: colors.border))
            : null,
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: isDesktop ? AppSpacing.xl : AppSpacing.sm,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            exit,
            SizedBox(width: isDesktop ? AppSpacing.xxxl : AppSpacing.sm),
            Expanded(
              child: isDesktop
                  ? Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 720),
                        child: progress,
                      ),
                    )
                  : progress,
            ),
            if (timeLeft != null) ...[
              SizedBox(width: isDesktop ? AppSpacing.xxxl : AppSpacing.md),
              _TimerChip(
                timeLeft: timeLeft,
                warning: session.isTimeRunningOut(now),
              ),
            ],
            const SizedBox(width: AppSpacing.md),
          ],
        ),
      ),
    );
  }
}

/// "✓ 5": a counter with its icon, as colour alone is not enough.
class _Counter extends StatelessWidget {
  const new({
    required this.countKey,
    required this.count,
    required this.icon,
    required this.color,
    required this.label,
  });

  final Key countKey;
  final int count;
  final IconData icon;
  final Color color;

  /// What screen readers say, e.g. "5 aciertos".
  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 2),
          Text(
            '$count',
            key: countKey,
            style: Theme.of(context).textTheme.titleSmall
                ?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

/// The time left, "0:18", in `warning` in its last seconds (R 7.5).
class _TimerChip extends StatelessWidget {
  const new({required this.timeLeft, required this.warning});

  final Duration timeLeft;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final color = warning ? colors.warning : colors.textMuted;
    // Whole seconds, rounded up: "0:01" until the time is really over.
    final seconds = (timeLeft.inMilliseconds / 1000).ceil();
    final time =
        '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
    return Semantics(
      label: AppLocalizations.of(context).timeLeftLabel(time),
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: warning
              ? colors.warning.withValues(alpha: 0.15)
              : colors.surfaceVariant,
          borderRadius: BorderRadius.circular(AppRadii.chip),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.schedule_rounded, size: 16, color: color),
            const SizedBox(width: AppSpacing.xs),
            Text(
              time,
              key: const Key('session.timer'),
              style: Theme.of(context).textTheme.labelLarge
                  ?.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}

/// The card on screen as a [StudyCard], in the state the engine says.
class _SessionCard extends ConsumerWidget {
  const new({
    required this.current,
    required this.projectId,
    required this.onFlip,
    required this.onOptionTap,
  });

  final CurrentCard current;
  final String projectId;
  final VoidCallback onFlip;
  final ValueChanged<String> onOptionTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final card = current.card;
    final project = ref.watch(projectProvider(projectId)).value;
    final deck = [
      for (final summary
          in ref.watch(deckSummariesProvider(projectId)).value ??
              const <DeckSummary>[])
        if (summary.deck.id == card.deckId) summary.deck,
    ].firstOrNull;
    final reversed = current.entry.selected.direction == StudyDirection.reverse;
    final step = current.step;
    final isTest = card.type == CardType.test;
    final attempt = step is Resolved ? step.attempt : null;
    final face = !isTest && (step is Flipped || step is Resolved)
        ? CardFace.back
        : CardFace.front;

    return StudyCard(
      // A new turn is a new card, even when the same card comes back: it
      // starts on its front, without turning.
      key: ValueKey(current.turn),
      card: card,
      label: project == null || deck == null
          ? ''
          : l10n.cardLabel(project.name, deck.name),
      color: deck?.color ?? project?.color ?? 'blue',
      face: face,
      languagePair: _languagePair(l10n, deck, reversed: reversed),
      options: current.options,
      selectedOptionIds: switch (step) {
        Answering(:final selectedOptionIds) => selectedOptionIds,
        Resolved(:final attempt) => attempt.selectedOptionIds ?? const {},
        Flipped() => const {},
      },
      checked: isTest && attempt != null,
      answeredCorrectly: attempt == null
          ? null
          : attempt.result == AttemptResult.correct,
      reversed: reversed,
      showFlipHint: !isTest && step is Answering,
      onTap: !isTest && step is Answering ? onFlip : null,
      onOptionTap: isTest && step is Answering ? onOptionTap : null,
      questionImage: _imageFor(ref, card.questionImage),
      answerImage: _imageFor(ref, card.answerImage),
      speechLanguages: deck == null ? null : speechLanguagesOf(deck),
      speaker: (speech) => SpeakerButton(speech: speech),
    );
  }

  /// "Inglés → Español" for a language deck, the other way round in
  /// reverse; null for a general deck.
  static String? _languagePair(
    AppLocalizations l10n,
    Deck? deck, {
    required bool reversed,
  }) {
    final source = deck?.sourceLang;
    final target = deck?.targetLang;
    if (deck == null || !deck.isLanguage || source == null || target == null) {
      return null;
    }
    final (from, to) = reversed ? (target, source) : (source, target);
    return l10n.languagePair(languageName(l10n, from), languageName(l10n, to));
  }

  /// A card image from the images folder; null while the folder is not
  /// known yet.
  static ImageProvider? _imageFor(WidgetRef ref, String? path) {
    final folder = ref.watch(imagesFolderProvider).value;
    if (path == null || folder == null) return null;
    return FileImage(File('${folder.path}/$path'));
  }
}

/// Lets a flipped card be dragged to answer on phones (US-15 AC2): to the
/// right is "Acerté" and to the left "Fallé". While dragging, the card is
/// tinted green with ✓ or red with ✗ (brief §6.9).
class _SwipeToGrade extends StatefulWidget {
  const new({
    required this.enabled,
    required this.onGrade,
    required this.child,
  });

  final bool enabled;
  final ValueChanged<bool> onGrade;
  final Widget child;

  @override
  State<_SwipeToGrade> createState() => _SwipeToGradeState();
}

class _SwipeToGradeState extends State<_SwipeToGrade> {
  /// How far the card must be dragged to count as an answer.
  static const _threshold = 100.0;

  double _offset = 0;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final progress = (_offset.abs() / _threshold).clamp(0.0, 1.0);
    final correct = _offset > 0;
    final tint = correct ? colors.success : colors.error;
    return GestureDetector(
      onHorizontalDragUpdate: widget.enabled
          ? (details) => setState(() => _offset += details.delta.dx)
          : null,
      onHorizontalDragEnd: widget.enabled
          ? (_) {
              // Read the offset now: the drag may end before a rebuild.
              final answered = _offset.abs() >= _threshold;
              final toTheRight = _offset > 0;
              setState(() => _offset = 0);
              if (answered) widget.onGrade(toTheRight);
            }
          : null,
      child: Transform.translate(
        offset: Offset(_offset, 0),
        child: Transform.rotate(
          // A slight tilt, as when a card is pushed aside.
          angle: _offset / 2000,
          child: Stack(
            children: [
              widget.child,
              if (_offset != 0)
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: tint.withValues(alpha: 0.18 * progress),
                        borderRadius: BorderRadius.circular(AppRadii.studyCard),
                        border: Border.all(
                          color: tint.withValues(alpha: progress),
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: Opacity(
                          opacity: progress,
                          child: Icon(
                            correct ? Icons.check_rounded : Icons.close_rounded,
                            size: 72,
                            color: tint,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The buttons under the card, depending on its state (R 7.3).
class _Actions extends StatelessWidget {
  const new({
    required this.step,
    required this.isTest,
    required this.onFlip,
    required this.onCheck,
    required this.onReveal,
    required this.onLeave,
    required this.onGrade,
    required this.onNext,
  });

  final CardStep step;
  final bool isTest;
  final VoidCallback onFlip;
  final VoidCallback onCheck;
  final VoidCallback onReveal;
  final VoidCallback onLeave;
  final ValueChanged<bool> onGrade;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    const tall = Size.fromHeight(minTouchTarget + AppSpacing.sm);
    // Less side padding, so "Dejar para el final" fits in half a phone.
    final secondary = OutlinedButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
    );
    return switch (step) {
      Answering(:final selectedOptionIds) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isTest)
            FilledButton(
              key: const Key('session.check'),
              style: FilledButton.styleFrom(minimumSize: tall),
              // Enabled once something is ticked (R 7.3).
              onPressed: selectedOptionIds.isEmpty ? null : onCheck,
              child: Text(l10n.checkAnswer),
            )
          else
            FilledButton.icon(
              key: const Key('session.flip'),
              style: FilledButton.styleFrom(minimumSize: tall),
              onPressed: onFlip,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(l10n.flipCard),
            ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  key: const Key('session.reveal'),
                  style: secondary,
                  onPressed: onReveal,
                  icon: const Icon(Icons.visibility_outlined),
                  label: Text(l10n.revealAnswer),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: OutlinedButton.icon(
                  key: const Key('session.leave'),
                  style: secondary,
                  onPressed: onLeave,
                  icon: const Icon(Icons.low_priority_rounded),
                  label: Text(l10n.leaveForLater),
                ),
              ),
            ],
          ),
        ],
      ),
      Flipped() => Row(
        children: [
          Expanded(
            child: FilledButton.icon(
              key: const Key('session.wrong'),
              style: FilledButton.styleFrom(
                minimumSize: tall,
                backgroundColor: colors.error,
                foregroundColor: colors.onError,
              ),
              onPressed: () => onGrade(false),
              icon: const Icon(Icons.close_rounded),
              label: Text(l10n.gotItWrong),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: FilledButton.icon(
              key: const Key('session.correct'),
              style: FilledButton.styleFrom(
                minimumSize: tall,
                backgroundColor: colors.success,
                foregroundColor: colors.onSuccess,
              ),
              onPressed: () => onGrade(true),
              icon: const Icon(Icons.check_rounded),
              label: Text(l10n.gotItRight),
            ),
          ),
        ],
      ),
      Resolved() => FilledButton(
        key: const Key('session.next'),
        style: FilledButton.styleFrom(minimumSize: tall),
        onPressed: onNext,
        child: Text(l10n.nextCard),
      ),
    };
  }
}

/// The session is not in memory: an old link, or the app was restarted.
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
