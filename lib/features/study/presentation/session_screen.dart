import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:estudicards/app/l10n/generated/app_localizations.dart';
import 'package:estudicards/app/layout/breakpoints.dart';
import 'package:estudicards/app/router.dart';
import 'package:estudicards/app/theme/app_colors.dart';
import 'package:estudicards/app/theme/dimensions.dart';
import 'package:estudicards/app/theme/motion.dart';
import 'package:estudicards/core/providers.dart';
import 'package:estudicards/core/widgets/confirm_dialog.dart';
import 'package:estudicards/core/widgets/play_once.dart';
import 'package:estudicards/features/cards/domain/card_speech.dart';
import 'package:estudicards/features/cards/domain/flashcard.dart';
import 'package:estudicards/features/cards/presentation/speaker_button.dart';
import 'package:estudicards/features/cards/presentation/study_card.dart';
import 'package:estudicards/features/decks/domain/deck.dart';
import 'package:estudicards/features/decks/domain/deck_summary.dart';
import 'package:estudicards/features/decks/presentation/deck_providers.dart';
import 'package:estudicards/features/projects/presentation/project_labels.dart';
import 'package:estudicards/features/projects/presentation/project_providers.dart';
import 'package:estudicards/features/settings/presentation/settings_providers.dart';
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
/// (T3.5). It pauses with "Pausa" and when the app goes to the background
/// (US-19).
class _SessionView extends ConsumerStatefulWidget {
  const new({required this.sessionId, required this.launch});

  final String sessionId;
  final SessionLaunch launch;

  @override
  ConsumerState<_SessionView> createState() => _SessionViewState();
}

// `TickerProviderStateMixin` lets this state drive its own animations
// (`AnimationController`s): it gives them a "ticker", which calls them on
// every frame while the screen is visible.
class _SessionViewState extends ConsumerState<_SessionView>
    with TickerProviderStateMixin {
  late final SessionRunner _runner;

  /// Tells the screen when the app changes state, e.g. goes to the
  /// background (see [initState]).
  late final AppLifecycleListener _lifecycle;

  /// The saves, one after another, so the answers reach the database in
  /// the order they happened.
  Future<void> _saving = Future.value();
  bool _started = false;

  // The animations (brief §8) only draw what the engine already did: an
  // answer is recorded, and the next card is ready, before they start.

  /// The card on screen, to notice when the next one replaces it.
  CurrentCard? _shown;

  /// The result recorded for [_shown], if any.
  AttemptResult? _shownResult;

  /// How far the user dragged the card that was just graded, so it leaves
  /// from there.
  double _dragOffset = 0;

  /// The card leaving the screen while the next one comes in.
  _LeavingCard? _leaving;

  /// The answered card leaving and the next one coming in. It rests at its
  /// end (1) until a card is replaced.
  ///
  /// `preserve` keeps the duration with "reduce motion" on, which Flutter
  /// would otherwise cut 20 times, so the fade that replaces the movement
  /// can be seen.
  late final AnimationController _swap = AnimationController(
    vsync: this,
    duration: AppMotion.cardSwap,
    value: 1,
    animationBehavior: AnimationBehavior.preserve,
  )..addStatusListener(_onSwapStatus);

  /// The border flash of an answer recorded on a card that stays on
  /// screen: a checked test card, a revealed answer or a timeout.
  late final AnimationController _flash = AnimationController(
    vsync: this,
    duration: AppMotion.flash,
    value: 1,
    animationBehavior: AnimationBehavior.preserve,
  );
  AttemptResult? _flashResult;

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
    _shown = _currentOf(_runner.state);
    // Flutter reports the app's lifecycle: `resumed` (on screen and in
    // use), `inactive` (on screen but not in use, e.g. during a phone
    // call), `hidden` (not visible: in the background on a phone,
    // minimised on desktop), `paused` and `detached`. The session pauses
    // when the app is hidden (US-19 AC2), so the timers stop too (R 7.5).
    // `inactive` is not enough: on desktop it also comes whenever the
    // window loses focus. Coming back keeps the pause until "Continuar".
    _lifecycle = AppLifecycleListener(onHide: _pause);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _runner.dispose();
    _swap.dispose();
    _flash.dispose();
    super.dispose();
  }

  /// "Pausa" (US-19 AC1): hides the card and stops the timers.
  void _pause() {
    if (_runner.state is InProgress) _runner.send(const Pause());
  }

  void _onStep(SessionStep step) {
    final repository = ref.read(studyRepositoryProvider);
    _saving = _saving.then((_) => repository.record(widget.sessionId, step));
    if (step.state is Finished) {
      unawaited(_showResults());
    } else if (_started && mounted) {
      _animate(step);
      // A tick or a button changed the state: draw it again.
      setState(() {});
    }
  }

  /// Starts the animation that [step] calls for, once the engine has
  /// already moved on: the card leaving when the next one replaces it, or a
  /// flash when an answer is recorded on a card that stays.
  void _animate(SessionStep step) {
    final previous = _shown;
    final next = _currentOf(step.state);
    for (final attempt in step.attempts) {
      if (attempt.result != AttemptResult.unanswered) {
        _shownResult = attempt.result;
      }
    }
    _shown = next;
    if (previous == null || next == null) return;
    if (next.turn != previous.turn) {
      _leaving = _LeavingCard(
        card: previous,
        result: _shownResult,
        dragOffset: _dragOffset,
      );
      _shownResult = null;
      _dragOffset = 0;
      _flash.value = 1;
      _swap.forward(from: 0);
    } else if (step.attempts.isNotEmpty && _shownResult != null) {
      _flashResult = _shownResult;
      _flash.forward(from: 0);
    }
  }

  void _onSwapStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && mounted) {
      setState(() => _leaving = null);
    }
  }

  static CurrentCard? _currentOf(SessionState state) => switch (state) {
    InProgress(:final current) => current,
    Paused(:final session) => session.current,
    Finished() => null,
  };

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
  /// [dragOffset] is how far the card was dragged to answer, if it was.
  void _grade({
    required bool correct,
    required bool haptics,
    double dragOffset = 0,
  }) {
    if (haptics) unawaited(HapticFeedback.lightImpact());
    _dragOffset = dragOffset;
    _send((turn) => SelfGrade(turn: turn, correct: correct));
  }

  /// "Comprobar", with the same light vibration on phones.
  void _check({required bool haptics}) {
    if (haptics) unawaited(HapticFeedback.lightImpact());
    _send((turn) => Check(turn: turn));
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
    final (session, isPaused) = switch (_runner.state) {
      final InProgress session => (session, false),
      Paused(:final session) => (session, true),
      // Finished: the results open as soon as the end is saved.
      Finished() => (null, false),
    };
    if (session == null) return const Scaffold();
    final isDesktop =
        FormFactor.fromWidth(MediaQuery.sizeOf(context).width) ==
        FormFactor.desktop;
    final step = session.current.step;
    final isTest = session.current.card.type == CardType.test;
    final now = ref.read(clockProvider).now();

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
                session: session,
                projectId: widget.launch.projectId,
                isDesktop: isDesktop,
                now: now,
                onExit: () => unawaited(_confirmExit()),
                onPause: isPaused ? null : _pause,
              ),
              Expanded(
                child: isPaused
                    ? _PausePanel(
                        // The session clock is stopped while paused.
                        studied: session.clock.elapsedAt(now),
                        onResume: () => _runner.send(const Resume()),
                        onExit: () => unawaited(_confirmExit()),
                      )
                    : _CardAndActions(
                        isDesktop: isDesktop,
                        card: _AnimatedCards(
                          swap: _swap,
                          flash: _flash,
                          flashResult: _flashResult,
                          leaving: _leaving,
                          leavingCard: switch (_leaving) {
                            final leaving? => _SessionCard(
                              current: leaving.card,
                              projectId: widget.launch.projectId,
                              onFlip: () {},
                              onOptionTap: (_) {},
                            ),
                            null => null,
                          },
                          card: _SwipeToGrade(
                            // Swiping is for phones and tablets (US-15 AC2).
                            enabled: !isDesktop && step is Flipped,
                            onGrade: ({required correct, required offset}) =>
                                _grade(
                                  correct: correct,
                                  haptics: true,
                                  dragOffset: offset,
                                ),
                            child: _SessionCard(
                              current: session.current,
                              projectId: widget.launch.projectId,
                              onFlip: () => _send((turn) => Flip(turn: turn)),
                              onOptionTap: (id) => _send(
                                (turn) =>
                                    ToggleOption(turn: turn, optionId: id),
                              ),
                            ),
                          ),
                        ),
                        actions: _Actions(
                          step: step,
                          isTest: isTest,
                          onFlip: () => _send((turn) => Flip(turn: turn)),
                          onCheck: () => _check(haptics: !isDesktop),
                          onReveal: () =>
                              _send((turn) => RevealAnswer(turn: turn)),
                          onLeave: () =>
                              _send((turn) => LeaveForLater(turn: turn)),
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
    required this.onPause,
  });

  final InProgress session;
  final String projectId;
  final bool isDesktop;
  final DateTime now;
  final VoidCallback onExit;

  /// "Pausa"; null while paused, which hides the button.
  final VoidCallback? onPause;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    final repeats = session.pendingRepeats;
    final total = session.totalCards;
    final projectName = ref.watch(projectProvider(projectId)).value?.name;
    final timeLeft =
        session.questionTimeLeft(now) ?? session.sessionTimeLeft(now);
    // On a phone with a timer the row is full, so the counters go under
    // the bar, as in `docs/design/movil-oscuro/estudio-test-fallado.png`.
    final countersBelow = !isDesktop && timeLeft != null;
    final counters = [
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
    ];

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
              // Gives way on a narrow phone rather than pushing the
              // counters out.
              Flexible(
                child: Text(
                  l10n.pendingRepeats(repeats),
                  key: const Key('session.repeats'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.labelMedium?.copyWith(
                    color: colors.primaryStrong,
                  ),
                ),
              ),
            ],
            const Spacer(),
            if (!countersBelow) ...counters,
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
        if (countersBelow) ...[
          const SizedBox(height: AppSpacing.sm),
          Row(children: counters),
        ],
      ],
    );

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
    final onPause = this.onPause;
    final pause = switch ((onPause, isDesktop)) {
      // While paused there is no button; the space keeps the bar still.
      (null, _) => SizedBox(width: isDesktop ? 0 : minTouchTarget),
      (_, true) => OutlinedButton.icon(
        key: const Key('session.pause'),
        onPressed: onPause,
        icon: const Icon(Icons.pause_outlined),
        label: Text(l10n.pauseSession),
      ),
      (_, false) => IconButton(
        key: const Key('session.pause'),
        tooltip: l10n.pauseSession,
        onPressed: onPause,
        icon: const Icon(Icons.pause_outlined),
      ),
    };

    return DecoratedBox(
      key: const Key('session.topBar'),
      // On desktop a bar in the cards' colour across the window, as in
      // `escritorio-claro/sesion.png`; on a phone part of the page.
      decoration: BoxDecoration(
        color: isDesktop ? colors.surface : null,
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
            SizedBox(width: isDesktop ? AppSpacing.lg : AppSpacing.xs),
            pause,
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
    final time = _clockText(
      Duration(seconds: (timeLeft.inMilliseconds / 1000).ceil()),
    );
    final chip = Container(
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
          Icon(Icons.schedule_outlined, size: 16, color: color),
          const SizedBox(width: AppSpacing.xs),
          Text(
            time,
            key: const Key('session.timer'),
            style: Theme.of(context).textTheme.labelLarge
                ?.copyWith(color: color),
          ),
        ],
      ),
    );
    return Semantics(
      label: AppLocalizations.of(context).timeLeftLabel(time),
      excludeSemantics: true,
      child: warning ? _Pulse(beat: time, child: chip) : chip,
    );
  }
}

/// The gentle pulse of the timer in its last seconds (brief §8): the chip
/// grows a little and back, once per second, or only dims a little with
/// "reduce motion" on.
///
/// Each beat is its own short animation, started when the time shown
/// changes ([beat]), never a loop. So it never delays the timer (it only
/// draws what the timer says), and between beats nothing moves: tests that
/// wait for the screen to be still (`pumpAndSettle`) still finish.
class _Pulse extends StatelessWidget {
  const new({required this.beat, required this.child});

  final String beat;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final reduced = AppMotion.reduced(context);
    return PlayOnce(
      // Plays again, from the start, every time the second changes.
      replayKey: beat,
      duration: AppMotion.timerPulse,
      builder: (context, t, child) {
        // Up and back down: 0 at both ends, 1 in the middle.
        final strength = math.sin(math.pi * t);
        return Transform.scale(
          key: const Key('session.timerPulse'),
          scale: reduced ? 1 : 1 + 0.08 * strength,
          child: Opacity(
            opacity: reduced ? 1 - 0.4 * strength : 1,
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

/// "3:42": minutes and seconds.
String _clockText(Duration duration) {
  final seconds = duration.inSeconds;
  return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
}

/// P10, the pause (`docs/design/tarjetas/`, variant 10): a panel in place of
/// the card and its buttons, so the card cannot be seen (US-19 AC1), with
/// the time studied, "Continuar" and "Salir de la sesión".
class _PausePanel extends StatelessWidget {
  const new({
    required this.studied,
    required this.onResume,
    required this.onExit,
  });

  final Duration studied;
  final VoidCallback onResume;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Container(
            key: const Key('session.paused'),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl,
              vertical: AppSpacing.xxxl,
            ),
            decoration: BoxDecoration(
              color: colors.surfaceVariant,
              borderRadius: BorderRadius.circular(AppRadii.studyCard),
              border: Border.all(color: colors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: colors.primarySoft,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.pause_outlined,
                      size: 32,
                      color: colors.primary,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  l10n.sessionPaused,
                  textAlign: TextAlign.center,
                  style: text.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  l10n.sessionPausedBody(_clockText(studied)),
                  textAlign: TextAlign.center,
                  style: text.bodyMedium?.copyWith(color: colors.textMuted),
                ),
                const SizedBox(height: AppSpacing.xl),
                FilledButton.icon(
                  key: const Key('session.resume'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(
                      minTouchTarget + AppSpacing.sm,
                    ),
                  ),
                  onPressed: onResume,
                  icon: const Icon(Icons.play_arrow_outlined),
                  label: Text(l10n.resumeSession),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextButton(
                  key: const Key('session.pauseExit'),
                  style: TextButton.styleFrom(
                    foregroundColor: colors.primaryStrong,
                  ),
                  onPressed: onExit,
                  child: Text(l10n.exitFromPause),
                ),
              ],
            ),
          ),
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
      textScale: ref.watch(cardTextScaleProvider),
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

/// The card that was on screen, while it leaves (brief §8, "Next card").
class _LeavingCard {
  const new({
    required this.card,
    required this.result,
    required this.dragOffset,
  });

  final CurrentCard card;

  /// What was recorded for it: it leaves to the right if correct and to
  /// the left if wrong, with its ✓ or ✗. Null when it was left for later,
  /// and then it just fades away.
  final AttemptResult? result;

  /// How far it had been dragged to answer, so it leaves from there.
  final double dragOffset;
}

/// The card on screen and the animations around it: the card that is
/// leaving goes off over it towards the side of its answer, and the new
/// one grows into place (brief §8). An answer recorded on a card that stays
/// flashes its border. With "reduce motion" on, the cards only fade.
///
/// The leaving card is drawn on top but lets taps through, so the new card
/// can be used at once.
class _AnimatedCards extends StatelessWidget {
  const new({
    required this.swap,
    required this.flash,
    required this.flashResult,
    required this.leaving,
    required this.leavingCard,
    required this.card,
  });

  final Animation<double> swap;
  final Animation<double> flash;
  final AttemptResult? flashResult;
  final _LeavingCard? leaving;
  final Widget? leavingCard;
  final Widget card;

  @override
  Widget build(BuildContext context) {
    final reduced = AppMotion.reduced(context);
    // `AnimatedBuilder` builds again on every frame of the animations.
    return AnimatedBuilder(
      animation: Listenable.merge([swap, flash]),
      builder: (context, _) {
        final leaving = this.leaving;
        final leavingCard = this.leavingCard;
        final swapping =
            swap.status == AnimationStatus.forward &&
            leaving != null &&
            leavingCard != null;
        // How far the swap has gone, from 0 to 1 (1 when there is none).
        final t = swapping
            ? AppMotion.cardSwapCurve.transform(swap.value)
            : 1.0;
        final flashResult = this.flashResult;
        final flashing =
            flash.status == AnimationStatus.forward && flashResult != null;
        return Stack(
          children: [
            // The new card. Its wrappers are always there, so it keeps its
            // state when the animation ends.
            Opacity(
              opacity: reduced ? t : 0.3 + 0.7 * t,
              child: Transform.scale(
                scale: reduced ? 1 : 0.94 + 0.06 * t,
                child: card,
              ),
            ),
            if (flashing)
              Positioned.fill(
                child: Opacity(
                  opacity: 1 - flash.value,
                  child: _ResultFlash(result: flashResult, withIcon: false),
                ),
              ),
            if (swapping)
              Positioned.fill(
                child: IgnorePointer(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final result = leaving.result;
                      // Right for correct, left for wrong, nowhere when it
                      // was left for later.
                      final side = switch (result) {
                        AttemptResult.correct => 1,
                        AttemptResult.wrong => -1,
                        _ => 0,
                      };
                      Widget out = Stack(
                        fit: StackFit.expand,
                        children: [
                          leavingCard,
                          if (result != null)
                            _ResultFlash(result: result, withIcon: true),
                        ],
                      );
                      if (!reduced) {
                        final dx =
                            leaving.dragOffset +
                            side * constraints.maxWidth * 1.2 * t;
                        out = Transform.translate(
                          offset: Offset(dx, 0),
                          child: Transform.rotate(
                            angle: dx / 2000,
                            child: Transform.scale(
                              // Without a side, it shrinks a little instead.
                              scale: side == 0 ? 1 - 0.1 * t : 1,
                              child: out,
                            ),
                          ),
                        );
                      }
                      return Opacity(opacity: 1 - t, child: out);
                    },
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// A green or red border over the card, with a big ✓ or ✗ in the middle
/// when [withIcon]: colour is never the only sign (brief §9). Screen
/// readers already hear the result, so it is only decoration.
class _ResultFlash extends StatelessWidget {
  const new({required this.result, required this.withIcon});

  final AttemptResult result;
  final bool withIcon;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final correct = result == AttemptResult.correct;
    final color = correct ? colors.success : colors.error;
    return IgnorePointer(
      child: ExcludeSemantics(
        child: DecoratedBox(
          key: Key('session.flash.${correct ? 'correct' : 'wrong'}'),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppRadii.studyCard),
            border: Border.all(color: color, width: 3),
          ),
          child: withIcon
              ? Center(
                  child: Icon(
                    correct ? Icons.check_rounded : Icons.close_rounded,
                    size: 72,
                    color: color,
                  ),
                )
              : null,
        ),
      ),
    );
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

  /// Called with whether it was "Acerté" and how far the card was dragged.
  final void Function({required bool correct, required double offset}) onGrade;
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
              final offset = _offset;
              setState(() => _offset = 0);
              if (offset.abs() >= _threshold) {
                widget.onGrade(correct: offset > 0, offset: offset);
              }
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
