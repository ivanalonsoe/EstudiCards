// The entry point the app uses to read statistics (see `ProjectsRepository`
// for what a repository does). The DAO counts in SQL; the rules in
// `domain/metrics.dart` turn the counts into streaks and progress.
import 'package:estudicards/core/clock.dart';
import 'package:estudicards/features/stats/data/stats_dao.dart';
import 'package:estudicards/features/stats/domain/metrics.dart';
import 'package:estudicards/features/stats/domain/project_statistics.dart';
import 'package:estudicards/features/study/domain/session_state.dart';

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
  Stream<StatsOverview> watchOverview() => _watch(_overview);

  /// Correct and wrong answers per day over the last 30 days, today
  /// included: of [projectId] (P12) or of every project (P13), archived
  /// ones too.
  Future<DailySeries> dailyAnswers({String? projectId}) async {
    final today = _today;
    final rows = await _dao.answersPerDay(
      dayKey(today.subtract(const Duration(days: chartDays - 1))),
      dayKey(today),
      projectId: projectId,
    );
    return dailySeries({
      for (final row in rows)
        parseDayKey(row.day): AnswerCounts(
          correct: row.correct,
          wrong: row.wrong,
        ),
    }, today: today);
  }

  /// The [limit] cards of [projectId] with the most wrong answers
  /// ("Más falladas").
  Future<List<MissedCard>> mostMissed(
    String projectId, {
    int limit = 10,
  }) async => [
    for (final row in await _dao.mostMissed(projectId, limit: limit))
      MissedCard(
        cardId: row.cardId,
        deckId: row.deckId,
        question: row.question,
        wrongCount: row.wrong,
      ),
  ];

  /// The [limit] latest sessions of [projectId] that have ended, with the
  /// names of their decks.
  Future<SessionHistory> sessionHistory(
    String projectId, {
    required int limit,
  }) async {
    // One more than asked, to know whether "Ver más" has anything to show.
    final rows = await _dao.endedSessions(projectId, limit: limit + 1);
    final shown = rows.take(limit).toList();
    final deckNames = await _dao.deckNamesOf([for (final row in shown) row.id]);
    return SessionHistory(
      hasMore: rows.length > limit,
      sessions: [
        for (final row in shown)
          SessionSummary(
            id: row.id,
            startedAt: row.startedAt,
            status: SessionStatus.fromStored(row.status),
            deckNames: [
              for (final deck in deckNames)
                if (deck.sessionId == row.id) deck.deckName,
            ],
            answers: AnswerCounts(
              correct: row.correctTotal,
              wrong: row.wrongTotal,
            ),
            unanswered: row.unansweredTotal,
            activeDuration: Duration(milliseconds: row.activeDurationMs),
          ),
      ],
    );
  }

  /// "Reiniciar estadísticas" (R 7.4): deletes the attempts and statistics
  /// of one card, every card of a deck, or every card of a project (its
  /// decks in the trash too). Past sessions keep their totals.
  Future<void> resetCard(String cardId) =>
      _dao.deleteStatistics(_dao.cards.id.equals(cardId));

  Future<void> resetDeck(String deckId) =>
      _dao.deleteStatistics(_dao.cards.deckId.equals(deckId));

  Future<void> resetProject(String projectId) =>
      _dao.deleteStatistics(_dao.decks.projectId.equals(projectId));

  /// [dailyAnswers], read again after every change.
  Stream<DailySeries> watchDailyAnswers({String? projectId}) =>
      _watch(() => dailyAnswers(projectId: projectId));

  /// [mostMissed], read again after every change.
  Stream<List<MissedCard>> watchMostMissed(String projectId) =>
      _watch(() => mostMissed(projectId));

  /// [sessionHistory], read again after every change.
  Stream<SessionHistory> watchSessionHistory(
    String projectId, {
    required int limit,
  }) => _watch(() => sessionHistory(projectId, limit: limit));

  /// Emits what [read] returns now and again after every change to the
  /// tables the statistics count.
  ///
  /// `async*` makes a stream: each `yield` emits one value. The first is
  /// emitted at once, the next ones after each change.
  Stream<T> _watch<T>(Future<T> Function() read) async* {
    yield await read();
    await for (final _ in _dao.watchChanges()) {
      yield await read();
    }
  }

  /// The days of the charts.
  static const chartDays = 30;

  Future<StatsOverview> _overview() async => StatsOverview(
    streak: await streak(),
    answeredToday: await answeredToday(),
    answeredLast7Days: await answeredInLastDays(7),
    dailyGoal: await dailyGoal(),
  );

  static const _dailyGoalKey = 'daily_goal';
}
