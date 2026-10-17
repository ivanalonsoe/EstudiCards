import 'package:estudicards/features/stats/domain/metrics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('% correct (R 7.6)', () {
    test('is correct / (correct + wrong)', () {
      const counts = AnswerCounts(correct: 421, wrong: 114);

      expect(counts.total, 535);
      expect(counts.rate, closeTo(0.787, 0.001));
      expect(counts.percent, 79);
    });

    test('without answers there is no % (shown as "—")', () {
      const counts = AnswerCounts();

      expect(counts.total, 0);
      expect(counts.rate, isNull);
      expect(counts.percent, isNull);
    });

    test('all wrong is 0%, not "—"', () {
      expect(const AnswerCounts(wrong: 3).percent, 0);
    });
  });

  group('streak (US-23)', () {
    final today = DateTime.utc(2026, 10, 15);

    /// The days [daysAgo] before today.
    List<DateTime> days(List<int> daysAgo) => [
      for (final ago in daysAgo) DateTime.utc(2026, 10, 15 - ago),
    ];

    test('counts consecutive days up to today', () {
      final streak = streakFrom(days([0, 1, 2, 3]), today: today);

      expect(streak.current, 4);
    });

    test("with no activity yet today, yesterday's streak still stands", () {
      final streak = streakFrom(days([1, 2, 3]), today: today);

      expect(streak.current, 3);
    });

    test('a day with no activity breaks it', () {
      expect(streakFrom(days([0, 1, 3, 4, 5]), today: today).current, 2);
      expect(
        streakFrom(days([2, 3, 4]), today: today).current,
        0,
        reason: 'neither today nor yesterday had activity',
      );
    });

    test('with no activity at all it is 0', () {
      final streak = streakFrom(const [], today: today);

      expect((streak.current, streak.best), (0, 0));
    });

    test('the best streak is the longest run, past or current', () {
      expect(streakFrom(days([0, 1, 5, 6, 7, 8]), today: today).best, 4);
      expect(streakFrom(days([0, 1, 2, 9]), today: today).best, 3);
    });

    test('counts across months and years', () {
      final streak = streakFrom([
        DateTime.utc(2026, 12, 30),
        DateTime.utc(2026, 12, 31),
        DateTime.utc(2027),
      ], today: DateTime.utc(2027));

      expect(streak.current, 3);
    });

    test('repeated days and any order give the same streak', () {
      final streak = streakFrom(days([2, 0, 1, 0, 1]), today: today);

      expect((streak.current, streak.best), (3, 3));
    });
  });

  group('daily goal (US-23 AC2)', () {
    test("shows the day's progress towards the goal", () {
      final progress = dailyGoalProgress(goal: 20, answeredToday: 14)!;

      expect(progress.goal, 20);
      expect(progress.done, 14);
      expect(progress.remaining, 6);
      expect(progress.fraction, closeTo(0.7, 0.001));
      expect(progress.isReached, isFalse);
    });

    test('is reached at the goal and never goes past 100%', () {
      final reached = dailyGoalProgress(goal: 20, answeredToday: 20)!;
      final beyond = dailyGoalProgress(goal: 20, answeredToday: 26)!;

      expect(reached.isReached, isTrue);
      expect((beyond.remaining, beyond.fraction), (0, 1.0));
      expect(beyond.done, 26);
    });

    test('is off with no goal', () {
      expect(dailyGoalProgress(goal: null, answeredToday: 5), isNull);
      expect(dailyGoalProgress(goal: 0, answeredToday: 5), isNull);
    });
  });

  group('30-day series (P12, P13)', () {
    final today = DateTime.utc(2026, 10, 15);

    test('has 30 points, with zeros on days with no activity', () {
      final series = dailySeries({
        DateTime.utc(2026, 10, 15): const AnswerCounts(correct: 4, wrong: 1),
        DateTime.utc(2026, 9, 16): const AnswerCounts(correct: 2),
      }, today: today);

      expect(series.days, hasLength(30));
      expect(series.days.first.day, DateTime.utc(2026, 9, 16));
      expect(series.days.last.day, today);
      expect(series.days.first.answers.correct, 2);
      expect(
        (series.days.last.answers.correct, series.days.last.answers.wrong),
        (4, 1),
      );
      expect(series.days.where((day) => day.answers.total == 0), hasLength(28));
    });

    test('leaves out days before the 30', () {
      final series = dailySeries({
        DateTime.utc(2026, 9, 15): const AnswerCounts(correct: 9),
      }, today: today);

      expect(series.totals.total, 0);
    });

    test('adds up the totals of the legend', () {
      final series = dailySeries({
        DateTime.utc(2026, 10, 15): const AnswerCounts(correct: 4, wrong: 1),
        DateTime.utc(2026, 10, 2): const AnswerCounts(correct: 3, wrong: 2),
      }, today: today);

      expect((series.totals.correct, series.totals.wrong), (7, 3));
      expect(series.busiestDay, 5);
    });

    test('one point per calendar day across a summer time change', () {
      // Local days are midnight UTC (see `Clock.localDay`), so the 25-hour
      // day when clocks go back is still one point.
      final series = dailySeries(
        const <DateTime, AnswerCounts>{},
        today: DateTime.utc(2026, 11, 10),
      );

      expect(series.days.map((point) => point.day.day), [
        for (var day = 12; day <= 31; day++) day,
        for (var day = 1; day <= 10; day++) day,
      ]);
    });
  });
}
