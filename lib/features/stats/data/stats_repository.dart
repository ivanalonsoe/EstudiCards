// The entry point the app uses to read statistics (see `ProjectsRepository`
// for what a repository does). The DAO counts in SQL; the rules in
// `domain/metrics.dart` turn the counts into streaks and progress.
import 'package:estudicards/core/clock.dart';
import 'package:estudicards/features/stats/data/stats_dao.dart';
import 'package:estudicards/features/stats/domain/metrics.dart';

class StatsRepository {
  new(this._dao, this._clock);

  final StatsDao _dao;
  final Clock _clock;

  /// Today, in the user's local time.
  DateTime get _today => _clock.localDay(_clock.now());

  /// The current and best streak (R 7.6).
  Future<Streak> streak() async => streakFrom([
    for (final day in await _dao.activeDays()) parseDayKey(day),
  ], today: _today);

  /// Cards answered today: first attempts, correct or wrong.
  Future<int> answeredToday() => answeredInLastDays(1);

  /// Cards answered in the last [days] local days, today included (e.g. 7
  /// = today and the 6 days before).
  Future<int> answeredInLastDays(int days) {
    final today = _today;
    final first = today.subtract(Duration(days: days - 1));
    return _dao.answeredBetween(dayKey(first), dayKey(today));
  }

  /// Today's progress towards the daily goal, or null while there is none
  /// (`daily_goal` in `settings`, set from Settings in T6.2).
  Future<DailyGoalProgress?> dailyGoal() async {
    final goal = int.tryParse(await _dao.readSetting(_dailyGoalKey) ?? '');
    if (goal == null) return null;
    return dailyGoalProgress(goal: goal, answeredToday: await answeredToday());
  }

  /// What the dashboard header shows, read again whenever an answer is
  /// saved or a deck or project goes to or leaves the trash.
  ///
  /// `async*` makes a stream: each `yield` emits one value. The first is
  /// emitted at once, the next ones after each change.
  Stream<StatsOverview> watchOverview() async* {
    yield await _overview();
    await for (final _ in _dao.watchChanges()) {
      yield await _overview();
    }
  }

  Future<StatsOverview> _overview() async => StatsOverview(
    streak: await streak(),
    answeredToday: await answeredToday(),
    answeredLast7Days: await answeredInLastDays(7),
    dailyGoal: await dailyGoal(),
  );

  static const _dailyGoalKey = 'daily_goal';
}
