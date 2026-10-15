// The numbers the statistics show (R 7.6, US-23): % correct, streak and
// daily goal. Pure Dart: the repository reads the counts from the database
// and these rules turn them into what the screens show.

/// Correct and wrong first attempts of a card, deck, project or period.
class AnswerCounts {
  const new({this.correct = 0, this.wrong = 0});

  final int correct;
  final int wrong;

  int get total => correct + wrong;

  /// correct / (correct + wrong), as a fraction (R 7.6). Null with no
  /// answers, which the screens show as "—".
  double? get rate => total == 0 ? null : correct / total;

  /// [rate] as a whole percentage (e.g. 79); null with no answers.
  int? get percent => switch (rate) {
    final rate? => (rate * 100).round(),
    null => null,
  };
}

/// The current and the best streak, in days (R 7.6).
class Streak {
  const new({required this.current, required this.best});

  /// Consecutive days up to today with at least one answer. If there is no
  /// activity yet today, the streak up to yesterday still stands.
  final int current;

  /// The longest run of consecutive days ever ("Récord").
  final int best;
}

/// The streak from the local days with at least one correct or wrong
/// answer ([activeDays], in any order) on [today]. Days are midnight UTC of
/// each local date (see `Clock.localDay`), so one day is always 24 hours.
Streak streakFrom(Iterable<DateTime> activeDays, {required DateTime today}) {
  final days = activeDays.toSet().toList()..sort();
  const oneDay = Duration(days: 1);

  // The runs of consecutive days, oldest first, each kept as its length.
  var best = 0;
  var run = 0;
  DateTime? previous;
  for (final day in days) {
    run = previous != null && day.difference(previous) == oneDay ? run + 1 : 1;
    if (run > best) best = run;
    previous = day;
  }

  // `run` is the last run: it is current if it reaches today or yesterday.
  final yesterday = today.subtract(oneDay);
  final isCurrent = previous == today || previous == yesterday;
  return Streak(current: isCurrent ? run : 0, best: best);
}

/// How far today's answers are from the daily goal (US-23 AC2).
class DailyGoalProgress {
  const new({required this.goal, required this.done});

  /// Cards to answer each day.
  final int goal;

  /// Cards answered today (first attempts, correct or wrong).
  final int done;

  int get remaining => done >= goal ? 0 : goal - done;

  /// From 0 to 1, for the ring; it never goes past 1.
  double get fraction => done >= goal ? 1 : done / goal;

  bool get isReached => done >= goal;
}

/// The progress towards [goal], or null when there is no goal (it is
/// optional and off by default, SPEC §4.2).
DailyGoalProgress? dailyGoalProgress({
  required int? goal,
  required int answeredToday,
}) => goal == null || goal <= 0
    ? null
    : DailyGoalProgress(goal: goal, done: answeredToday);
