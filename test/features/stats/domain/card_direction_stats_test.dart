import 'package:estudicards/features/stats/domain/card_direction_stats.dart';
import 'package:estudicards/features/study/domain/attempt_record.dart';
import 'package:estudicards/features/study/domain/study_options.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final start = DateTime.utc(2026, 10, 15, 9);
  var minute = 0;

  /// An attempt at card `c1`, one minute after the previous one.
  AttemptRecord attempt(AttemptResult result, {bool isFirstAttempt = true}) =>
      AttemptRecord(
        cardId: 'c1',
        direction: StudyDirection.normal,
        result: result,
        source: result == AttemptResult.unanswered
            ? AttemptSource.sessionEnd
            : AttemptSource.selfEval,
        isFirstAttempt: isFirstAttempt,
        answeredAt: start.add(Duration(minutes: ++minute)),
      );

  /// The stats after [results], starting with no answers.
  CardDirectionStats after(List<AttemptResult> results) => results.fold(
    CardDirectionStats.empty,
    (stats, result) => stats.after(attempt(result)),
  );

  const correct = AttemptResult.correct;
  const wrong = AttemptResult.wrong;

  setUp(() => minute = 0);

  test('a wrong answer puts the card in errors', () {
    final stats = after([wrong]);

    expect(stats.inErrorList, isTrue);
    expect(stats.wrongCount, 1);
    expect(stats.correctCount, 0);
    expect(stats.consecutiveCorrect, 0);
    expect(stats.lastResult, wrong);
    expect(stats.lastAttemptAt, start.add(const Duration(minutes: 1)));
  });

  test('two correct answers in a row take it out of errors', () {
    expect(after([wrong, correct]).inErrorList, isTrue);

    final stats = after([wrong, correct, correct]);

    expect(stats.inErrorList, isFalse);
    expect(stats.consecutiveCorrect, 2);
    expect((stats.correctCount, stats.wrongCount), (2, 1));
    expect(stats.lastResult, correct);
  });

  test('correct, wrong, correct leaves it in errors', () {
    final stats = after([correct, wrong, correct]);

    expect(stats.inErrorList, isTrue);
    expect(stats.consecutiveCorrect, 1);
  });

  test('a miss resets the correct answers in a row', () {
    final stats = after([wrong, correct, wrong, correct]);

    expect(stats.inErrorList, isTrue);
    expect(stats.consecutiveCorrect, 1);
    expect((stats.correctCount, stats.wrongCount), (2, 2));
  });

  test('a card never missed never enters errors', () {
    final stats = after([correct, correct, correct]);

    expect(stats.inErrorList, isFalse);
    expect(stats.consecutiveCorrect, 3);
  });

  test('repeats change nothing', () {
    final missed = after([wrong]);

    expect(
      missed.after(attempt(correct, isFirstAttempt: false)),
      missed,
      reason: 'two correct repeats must not take it out of errors',
    );
    expect(missed.after(attempt(wrong, isFirstAttempt: false)), missed);
  });

  test('unanswered cards change nothing', () {
    final missed = after([wrong]);

    expect(missed.after(attempt(AttemptResult.unanswered)), missed);
    expect(
      CardDirectionStats.empty.after(attempt(AttemptResult.unanswered)),
      CardDirectionStats.empty,
    );
  });
}
