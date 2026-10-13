// The study session engine (R 7.3): it starts a session and applies each
// event to the current state. It is a state machine written as plain
// functions: `apply` takes a state and an event and returns the next state,
// plus the answers to save. It never reads the clock or the database;
// whoever uses it passes the current time and saves the answers.
import 'dart:math';

import 'package:estudicards/features/cards/domain/flashcard.dart';
import 'package:estudicards/features/study/domain/active_time.dart';
import 'package:estudicards/features/study/domain/attempt_record.dart';
import 'package:estudicards/features/study/domain/card_selection.dart';
import 'package:estudicards/features/study/domain/session_event.dart';
import 'package:estudicards/features/study/domain/session_state.dart';
import 'package:estudicards/features/study/domain/test_grading.dart';

/// The result of a transition: the new state and the answers it recorded,
/// to be saved at once.
class SessionStep {
  const new(this.state, [this.attempts = const []]);

  final SessionState state;
  final List<AttemptRecord> attempts;
}

class SessionEngine {
  /// [random] shuffles the options of test cards each time they are shown.
  new({required this.random});

  final Random random;

  /// A session over [cards], in the order given (selection already
  /// shuffled them), starting at [at].
  SessionStep start({
    required List<SelectedCard> cards,
    required SessionSettings settings,
    required DateTime at,
  }) {
    if (cards.isEmpty) {
      return const SessionStep(
        Finished(
          status: SessionStatus.completed,
          activeDuration: Duration.zero,
          correctCount: 0,
          wrongCount: 0,
          unansweredCount: 0,
        ),
      );
    }
    final queue = [for (final card in cards) QueueEntry(selected: card)];
    return SessionStep(
      InProgress(
        settings: settings,
        current: _show(queue.first, turn: 1, at: at),
        queue: queue.sublist(1),
        totalCards: cards.length,
        clock: ActiveTime(runningSince: at),
      ),
    );
  }

  /// The state after [event] happens at [at]. An event that does not apply
  /// to [state] changes nothing: buttons the user should not see, double
  /// taps and events meant for a card no longer on screen are ignored.
  SessionStep apply(
    SessionState state,
    SessionEvent event, {
    required DateTime at,
  }) => switch ((state, event)) {
    (final InProgress session, Pause()) => SessionStep(
      Paused(session: _stopClocks(session, at)),
    ),
    (final Paused paused, Resume()) => SessionStep(
      _startClocks(paused.session, at),
    ),
    (final InProgress session, Exit()) => _finish(
      session,
      at,
      SessionStatus.abandoned,
    ),
    (final Paused paused, Exit()) => _finish(
      paused.session,
      at,
      SessionStatus.abandoned,
    ),
    (final InProgress session, Tick()) => _checkTimers(session, at),
    (final InProgress session, final CardEvent cardEvent)
        when cardEvent.turn == session.current.turn =>
      _applyToCard(session, cardEvent, at),
    _ => SessionStep(state),
  };

  /// The buttons of the card on screen (R 7.3).
  SessionStep _applyToCard(InProgress session, CardEvent event, DateTime at) {
    final current = session.current;
    final isTest = current.card.type == CardType.test;

    return switch ((current.step, event)) {
      // Flipping stops the per-question timer (R 7.5), but not the response
      // time, which runs until "Acerté" or "Fallé".
      (Answering(), Flip()) when !isTest => SessionStep(
        session.copyWith(
          current: current.copyWith(
            step: const Flipped(),
            thinkingTime: current.clock.elapsedAt(at),
          ),
        ),
      ),
      (final Answering answering, ToggleOption(:final optionId)) when isTest =>
        SessionStep(
          _withStep(
            session,
            Answering(
              selectedOptionIds: _toggle(
                answering.selectedOptionIds,
                optionId,
                allowMultiple: current.card.allowMultiple,
              ),
            ),
          ),
        ),
      (Answering(:final selectedOptionIds), Check())
          when isTest && selectedOptionIds.isNotEmpty =>
        _resolve(
          session,
          at,
          isTestAnswerCorrect(current.card, selectedOptionIds)
              ? AttemptResult.correct
              : AttemptResult.wrong,
          AttemptSource.testCheck,
        ),
      (Answering(), RevealAnswer()) => _resolve(
        session,
        at,
        AttemptResult.wrong,
        AttemptSource.revealed,
      ),
      (Answering(), LeaveForLater()) => _showNext(
        session.copyWith(queue: [...session.queue, current.entry]),
        at,
      ),
      // "Acerté" and "Fallé" record the answer and go straight to the next
      // card, with no "Siguiente".
      (Flipped(), SelfGrade(:final correct)) => _then(
        _resolve(
          session,
          at,
          correct ? AttemptResult.correct : AttemptResult.wrong,
          AttemptSource.selfEval,
        ),
        (resolved) => _showNext(resolved, at),
      ),
      (Resolved(), Next()) => _showNext(session, at),
      _ => SessionStep(session),
    };
  }

  /// Records the answer to the card on screen and leaves it [Resolved].
  /// A first attempt updates the counters; a missed card comes back at the
  /// end of the queue with "Repetir falladas al final".
  SessionStep _resolve(
    InProgress session,
    DateTime at,
    AttemptResult result,
    AttemptSource source,
  ) {
    final current = session.current;
    final step = current.step;
    final isFirstAttempt = !current.entry.isRepeat;
    final missed = result == AttemptResult.wrong;
    final attempt = AttemptRecord(
      cardId: current.card.id,
      direction: current.entry.selected.direction,
      result: result,
      source: source,
      isFirstAttempt: isFirstAttempt,
      selectedOptionIds: current.card.type == CardType.test
          ? (step is Answering ? step.selectedOptionIds : const {})
          : null,
      responseTime: current.clock.elapsedAt(at),
      answeredAt: at,
    );

    return SessionStep(
      session.copyWith(
        // The per-question timer stops here unless flipping stopped it.
        current: current.copyWith(
          step: Resolved(attempt: attempt),
          thinkingTime: current.thinkingTime ?? current.clock.elapsedAt(at),
        ),
        correctCount:
            session.correctCount + (isFirstAttempt && !missed ? 1 : 0),
        wrongCount: session.wrongCount + (isFirstAttempt && missed ? 1 : 0),
        queue: missed && session.settings.repeatFailed
            ? [
                ...session.queue,
                QueueEntry(selected: current.entry.selected, isRepeat: true),
              ]
            : null,
      ),
      [attempt],
    );
  }

  /// What a [Tick] does (R 7.5). The answer or the end is recorded at the
  /// moment the time ran out, not at the tick that noticed it.
  SessionStep _checkTimers(InProgress session, DateTime at) {
    final limit = session.settings.timerLimit;
    switch (session.settings.timerType) {
      case TimerType.global:
        final used = session.clock.elapsedAt(at);
        if (used >= limit) {
          return _finish(
            session,
            at.subtract(used - limit),
            SessionStatus.timeUp,
          );
        }
      case TimerType.perCard:
        final current = session.current;
        final used = current.clock.elapsedAt(at);
        if (current.step is Answering && used >= limit) {
          return _resolve(
            session,
            at.subtract(used - limit),
            AttemptResult.wrong,
            AttemptSource.timeout,
          );
        }
      case TimerType.none:
        break;
    }
    return SessionStep(session);
  }

  /// [session] with the card on screen moved to [step].
  InProgress _withStep(InProgress session, CardStep step) =>
      session.copyWith(current: session.current.copyWith(step: step));

  /// Shows the next card of the queue, or ends the session when there is
  /// none left.
  SessionStep _showNext(InProgress session, DateTime at) {
    if (session.queue.isEmpty) {
      return _finish(session, at, SessionStatus.completed);
    }
    return SessionStep(
      session.copyWith(
        current: _show(
          session.queue.first,
          turn: session.current.turn + 1,
          at: at,
        ),
        queue: session.queue.sublist(1),
      ),
    );
  }

  /// [entry] on screen from [at], with its options shuffled (R 7.2) and its
  /// stopwatch from zero.
  CurrentCard _show(
    QueueEntry entry, {
    required int turn,
    required DateTime at,
  }) => CurrentCard(
    entry: entry,
    turn: turn,
    options: entry.card.type == CardType.test
        ? shuffleOptions(entry.card.options, random)
        : const [],
    clock: ActiveTime(runningSince: at),
  );

  /// Ends the session. The original cards still unresolved, on screen or in
  /// the queue, are recorded as unanswered; pending repeats are not (R 7.3).
  SessionStep _finish(InProgress session, DateTime at, SessionStatus status) {
    final current = session.current;
    final unanswered = [
      if (!current.entry.isRepeat && current.step is! Resolved)
        _unanswered(current.entry, at),
      for (final entry in session.queue)
        if (!entry.isRepeat) _unanswered(entry, at),
    ];
    return SessionStep(
      Finished(
        status: status,
        activeDuration: session.clock.elapsedAt(at),
        correctCount: session.correctCount,
        wrongCount: session.wrongCount,
        unansweredCount: unanswered.length,
      ),
      unanswered,
    );
  }

  AttemptRecord _unanswered(QueueEntry entry, DateTime at) => AttemptRecord(
    cardId: entry.card.id,
    direction: entry.selected.direction,
    result: AttemptResult.unanswered,
    source: AttemptSource.sessionEnd,
    isFirstAttempt: true,
    answeredAt: at,
  );

  /// Pausing stops both stopwatches: the session's and the card's.
  InProgress _stopClocks(InProgress session, DateTime at) => session.copyWith(
    clock: session.clock.pausedAt(at),
    current: session.current.copyWith(
      clock: session.current.clock.pausedAt(at),
    ),
  );

  InProgress _startClocks(InProgress session, DateTime at) => session.copyWith(
    clock: session.clock.resumedAt(at),
    current: session.current.copyWith(
      clock: session.current.clock.resumedAt(at),
    ),
  );
}

/// The ticked options after tapping [optionId]. With a single correct
/// answer the tapped option replaces the ticked one; with several, each tap
/// ticks or unticks it.
Set<String> _toggle(
  Set<String> selected,
  String optionId, {
  required bool allowMultiple,
}) {
  if (!allowMultiple) return {optionId};
  return selected.contains(optionId)
      ? selected.difference({optionId})
      : {...selected, optionId};
}

/// Runs [next] on the state [first] left, keeping the answers of both
/// steps in order.
SessionStep _then(SessionStep first, SessionStep Function(InProgress) next) {
  final second = next(first.state as InProgress);
  return SessionStep(second.state, [...first.attempts, ...second.attempts]);
}
