// The state of a study session (R 7.3). Every class here is immutable: the
// engine never changes a state, it builds the next one. `sealed` means the
// subclasses listed in this file are the only ones, so a `switch` over a
// state must handle each of them.
import 'package:estudicards/features/cards/domain/flashcard.dart';
import 'package:estudicards/features/study/domain/active_time.dart';
import 'package:estudicards/features/study/domain/attempt_record.dart';
import 'package:estudicards/features/study/domain/card_selection.dart';

/// `none` | `per_card` | `global` (R 7.5). Only one timer at a time.
enum TimerType {
  none('none'),
  perCard('per_card'),
  global('global');

  new(this.stored);

  /// The value saved in `study_sessions.timer_type`.
  final String stored;
}

/// The session choices the engine applies.
class SessionSettings {
  const new({
    this.repeatFailed = false,
    this.timerType = TimerType.none,
    this.timerLimit = Duration.zero,
  });

  /// "Repetir falladas al final": a missed card comes back at the end of
  /// the queue until it is answered correctly.
  final bool repeatFailed;
  final TimerType timerType;

  /// The time of the timer: per question (5–120 s) or for the whole
  /// session (1–120 min). P08 only offers values in those ranges.
  final Duration timerLimit;
}

/// The per-question timer shows a warning in its last 5 seconds, and the
/// global timer in its last minute (R 7.5).
const questionWarningTime = Duration(seconds: 5);
const sessionWarningTime = Duration(minutes: 1);

/// How a session ended (SPEC §4.2 `study_sessions.status`). A session
/// still running is stored as `in_progress`, which has no case here: the
/// engine knows it as [InProgress] or [Paused].
enum SessionStatus {
  completed('completed'),
  abandoned('abandoned'),
  timeUp('time_up');

  new(this.stored);

  /// The value saved in `study_sessions.status`.
  final String stored;
}

/// A card waiting in the queue.
class QueueEntry {
  const new({required this.selected, this.isRepeat = false});

  final SelectedCard selected;

  /// A repeat of a missed card ("Repetir falladas al final").
  final bool isRepeat;

  Flashcard get card => selected.card;
}

/// Where the card on screen is (R 7.3, buttons per state).
sealed class CardStep {
  const new();
}

/// Not answered yet: "Girar" or "Comprobar", "Ver respuesta" and "Dejar
/// para el final".
final class Answering extends CardStep {
  const new({this.selectedOptionIds = const {}});

  /// The ticked options of a test card.
  final Set<String> selectedOptionIds;
}

/// A simple card turned over, waiting for "Acerté" or "Fallé".
final class Flipped extends CardStep {
  const new();
}

/// The answer is recorded and the solution is on screen, waiting for
/// "Siguiente".
final class Resolved extends CardStep {
  const new({required this.attempt});

  final AttemptRecord attempt;
}

/// The card on screen.
class CurrentCard {
  const new({
    required this.entry,
    required this.turn,
    required this.options,
    required this.clock,
    this.step = const Answering(),
    this.thinkingTime,
  });

  final QueueEntry entry;

  /// Goes up by one every time a card is shown, also when the same card
  /// comes back. Card events carry the turn of the card they were meant
  /// for, so a late double tap never acts on the next card.
  final int turn;

  /// A test card's options, shuffled each time the card is shown.
  final List<CardOption> options;

  /// Time since the card was shown, pauses excluded.
  final ActiveTime clock;
  final CardStep step;

  /// The time the per-question timer stopped at: when the card was flipped,
  /// checked, revealed or timed out. Null while it runs (R 7.5).
  final Duration? thinkingTime;

  Flashcard get card => entry.card;

  CurrentCard copyWith({
    ActiveTime? clock,
    CardStep? step,
    Duration? thinkingTime,
  }) => CurrentCard(
    entry: entry,
    turn: turn,
    options: options,
    clock: clock ?? this.clock,
    step: step ?? this.step,
    thinkingTime: thinkingTime ?? this.thinkingTime,
  );
}

sealed class SessionState {
  const new();
}

final class InProgress extends SessionState {
  const new({
    required this.settings,
    required this.current,
    required this.queue,
    required this.totalCards,
    required this.clock,
    this.correctCount = 0,
    this.wrongCount = 0,
  });

  final SessionSettings settings;
  final CurrentCard current;

  /// The cards still to come, in order; the current card is not included.
  final List<QueueEntry> queue;

  /// How many cards the session started with.
  final int totalCards;

  /// First attempts only (the ✓ and ✗ counters).
  final int correctCount;
  final int wrongCount;

  /// The session's active time, pauses excluded.
  final ActiveTime clock;

  /// The "n" of "n / total": original cards already answered. Each original
  /// card gets exactly one first attempt, so these are the counters.
  int get answeredCount => correctCount + wrongCount;

  /// The "+N repasos": repeats still to answer, counting the one on screen
  /// until it is answered.
  int get pendingRepeats {
    final waiting = queue.where((entry) => entry.isRepeat).length;
    final onScreen = current.entry.isRepeat && current.step is! Resolved;
    return waiting + (onScreen ? 1 : 0);
  }

  /// What the per-question timer shows at [at]; null without that timer.
  /// It stays still once the card is flipped, checked or revealed.
  Duration? questionTimeLeft(DateTime at) {
    if (settings.timerType != TimerType.perCard) return null;
    final used = current.thinkingTime ?? current.clock.elapsedAt(at);
    return _timeLeft(used);
  }

  /// What the global timer shows at [at]; null without that timer.
  Duration? sessionTimeLeft(DateTime at) {
    if (settings.timerType != TimerType.global) return null;
    return _timeLeft(clock.elapsedAt(at));
  }

  /// Whether the timer shows its warning at [at] (R 7.5).
  bool isTimeRunningOut(DateTime at) => switch (settings.timerType) {
    TimerType.none => false,
    TimerType.perCard => questionTimeLeft(at)! <= questionWarningTime,
    TimerType.global => sessionTimeLeft(at)! <= sessionWarningTime,
  };

  /// The timer's limit minus [used], never below zero.
  Duration _timeLeft(Duration used) {
    final limit = settings.timerLimit;
    return used >= limit ? Duration.zero : limit - used;
  }

  InProgress copyWith({
    CurrentCard? current,
    List<QueueEntry>? queue,
    int? correctCount,
    int? wrongCount,
    ActiveTime? clock,
  }) => InProgress(
    settings: settings,
    current: current ?? this.current,
    queue: queue ?? this.queue,
    totalCards: totalCards,
    correctCount: correctCount ?? this.correctCount,
    wrongCount: wrongCount ?? this.wrongCount,
    clock: clock ?? this.clock,
  );
}

/// The pause overlay (P10). Resuming goes back to [session] exactly as it
/// was, with its stopwatches stopped in the meantime.
final class Paused extends SessionState {
  const new({required this.session});

  final InProgress session;
}

final class Finished extends SessionState {
  const new({
    required this.status,
    required this.activeDuration,
    required this.correctCount,
    required this.wrongCount,
    required this.unansweredCount,
  });

  final SessionStatus status;

  /// Time spent studying, pauses excluded.
  final Duration activeDuration;

  /// First attempts only.
  final int correctCount;
  final int wrongCount;
  final int unansweredCount;
}
