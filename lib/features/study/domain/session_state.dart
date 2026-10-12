// The state of a study session (R 7.3). Every class here is immutable: the
// engine never changes a state, it builds the next one. `sealed` means the
// subclasses listed in this file are the only ones, so a `switch` over a
// state must handle each of them.
import 'package:estudicards/features/cards/domain/flashcard.dart';
import 'package:estudicards/features/study/domain/active_time.dart';
import 'package:estudicards/features/study/domain/attempt_record.dart';
import 'package:estudicards/features/study/domain/card_selection.dart';

/// The session choices the engine applies.
class SessionSettings {
  const new({this.repeatFailed = false});

  /// "Repetir falladas al final": a missed card comes back at the end of
  /// the queue until it is answered correctly.
  final bool repeatFailed;
}

/// How a session ended (SPEC §4.2 `study_sessions.status`).
enum SessionStatus { completed, abandoned, timeUp }

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

  Flashcard get card => entry.card;

  CurrentCard copyWith({ActiveTime? clock, CardStep? step}) => CurrentCard(
    entry: entry,
    turn: turn,
    options: options,
    clock: clock ?? this.clock,
    step: step ?? this.step,
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
