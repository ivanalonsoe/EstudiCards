// What the results screen shows about a finished session (P11, US-20).
// Plain Dart: the repository reads the session, its attempts and its cards,
// and this class works out the numbers and lists.
import 'dart:math';

import 'package:estudicards/features/cards/domain/flashcard.dart';
import 'package:estudicards/features/study/domain/attempt_record.dart';
import 'package:estudicards/features/study/domain/card_selection.dart';
import 'package:estudicards/features/study/domain/session_config.dart';
import 'package:estudicards/features/study/domain/session_state.dart';

/// The subtle celebration appears from this % correct (SPEC §13.2,
/// assumption 4).
const celebrationPercent = 80;

/// The title of the results screen (decided with the owner).
enum ResultsHeadline {
  /// "¡Buen trabajo!": 80% correct or more.
  goodJob,

  /// "Sesión terminada": below 80%.
  finished,

  /// "¡Se acabó el tiempo!": the global timer ran out.
  timeUp,
}

class SessionResults {
  const new({
    required this.sessionId,
    required this.projectId,
    required this.projectName,
    required this.deckNames,
    required this.config,
    required this.status,
    required this.correctCount,
    required this.wrongCount,
    required this.unansweredCount,
    required this.activeDuration,
    required this.attempts,
    required this.cards,
  });

  final String sessionId;
  final String projectId;
  final String projectName;
  final List<String> deckNames;

  /// The configuration the session was started with.
  final SessionConfig config;

  /// Null while the session is still `in_progress` (the app closed midway).
  final SessionStatus? status;

  /// The session's saved totals (first attempts only). They stay even if
  /// cards or statistics are deleted later (R 7.4).
  final int correctCount;
  final int wrongCount;
  final int unansweredCount;

  /// Time spent studying, pauses excluded.
  final Duration activeDuration;

  /// Every attempt of the session, in the order they were saved.
  final List<AttemptRecord> attempts;

  /// The cards those attempts refer to that still exist, by ID.
  final Map<String, Flashcard> cards;

  /// The cards the session started with.
  int get totalCards => correctCount + wrongCount + unansweredCount;

  /// % correct, rounded to a whole number as it is shown; null with no
  /// answers ("—", R 7.6).
  int? get correctPercent {
    final answered = correctCount + wrongCount;
    if (answered == 0) return null;
    return (correctCount * 100 / answered).round();
  }

  /// Whether the subtle celebration appears. It uses the % as shown, so
  /// the screen never shows "80%" without it.
  bool get celebrates => (correctPercent ?? 0) >= celebrationPercent;

  ResultsHeadline get headline {
    if (status == SessionStatus.timeUp) return ResultsHeadline.timeUp;
    return celebrates ? ResultsHeadline.goodJob : ResultsHeadline.finished;
  }

  /// Mean response time of the answered first attempts; null if none.
  /// Repeats are left out, like in every other number on this screen.
  Duration? get averageResponseTime {
    final times = [
      for (final attempt in attempts)
        if (attempt.isFirstAttempt) ?attempt.responseTime,
    ];
    if (times.isEmpty) return null;
    final total = times.fold(Duration.zero, (sum, time) => sum + time);
    return total ~/ times.length;
  }

  /// The cards missed at their first attempt, in the order they were
  /// answered, each in the direction it was studied in.
  List<SelectedCard> get missed => _firstAttemptCards(AttemptResult.wrong);

  /// The original cards left unanswered.
  List<SelectedCard> get unanswered =>
      _firstAttemptCards(AttemptResult.unanswered);

  /// The configuration of "Repasar falladas ahora" (US-20 AC1): the same
  /// decks, direction, timer and "Repetir falladas al final", in normal
  /// mode, asking for exactly the missed cards.
  SessionConfig get reviewConfig => SessionConfig(
    deckIds: config.deckIds,
    direction: config.direction,
    requestedCount: missed.length,
    repeatFailed: config.repeatFailed,
    timerType: config.timerType,
    timerSeconds: config.timerSeconds,
  );

  /// The missed cards, shuffled, to review them now (R 7.2).
  List<SelectedCard> reviewQueue(Random random) => missed..shuffle(random);

  /// The cards whose first attempt had [result], skipping deleted cards.
  List<SelectedCard> _firstAttemptCards(AttemptResult result) => [
    for (final attempt in attempts)
      if (attempt.isFirstAttempt && attempt.result == result)
        if (cards[attempt.cardId] case final card?)
          SelectedCard(card: card, direction: attempt.direction),
  ];
}
