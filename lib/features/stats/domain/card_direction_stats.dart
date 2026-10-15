// The statistics of one card in one direction, and how each answer changes
// them (R 7.4). They are stored in `card_stats`, one row per card and
// direction (SPEC §4.2).
import 'package:estudicards/features/study/domain/attempt_record.dart';

/// Correct answers in a row that take a card out of the error list. Fixed
/// in v1 (R 7.4).
const errorListExitStreak = 2;

class CardDirectionStats {
  const new({
    this.correctCount = 0,
    this.wrongCount = 0,
    this.consecutiveCorrect = 0,
    this.inErrorList = false,
    this.lastResult,
    this.lastAttemptAt,
  });

  /// A card never answered in this direction.
  static const empty = CardDirectionStats();

  /// First attempts only.
  final int correctCount;
  final int wrongCount;

  /// Correct answers in a row since the last miss.
  final int consecutiveCorrect;
  final bool inErrorList;

  /// [AttemptResult.correct] or [AttemptResult.wrong]; null if never
  /// answered.
  final AttemptResult? lastResult;
  final DateTime? lastAttemptAt;

  /// The statistics once [attempt] is applied. Repeats and unanswered
  /// cards change nothing (R 7.3, R 7.4).
  CardDirectionStats after(AttemptRecord attempt) {
    if (!attempt.isFirstAttempt) return this;
    return switch (attempt.result) {
      AttemptResult.unanswered => this,
      AttemptResult.wrong => CardDirectionStats(
        correctCount: correctCount,
        wrongCount: wrongCount + 1,
        inErrorList: true,
        lastResult: AttemptResult.wrong,
        lastAttemptAt: attempt.answeredAt,
      ),
      AttemptResult.correct => CardDirectionStats(
        correctCount: correctCount + 1,
        wrongCount: wrongCount,
        consecutiveCorrect: consecutiveCorrect + 1,
        inErrorList:
            inErrorList && consecutiveCorrect + 1 < errorListExitStreak,
        lastResult: AttemptResult.correct,
        lastAttemptAt: attempt.answeredAt,
      ),
    };
  }
}
