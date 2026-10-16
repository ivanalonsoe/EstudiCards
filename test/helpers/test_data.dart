import 'package:drift/drift.dart';
import 'package:estudicards/core/db/app_database.dart';
import 'package:estudicards/core/ids.dart';

final _now = DateTime.utc(2026, 10, 6);

/// Inserts a simple card into [deckId] and returns its ID. The cards
/// repository arrives in phase 2; until then tests that need cards insert
/// them by hand.
Future<String> addTestCard(
  AppDatabase db,
  String deckId, {
  String? questionImage,
  String? answerImage,
}) async {
  final id = newId();
  await db
      .into(db.cards)
      .insert(
        CardsCompanion.insert(
          id: id,
          deckId: deckId,
          type: 'simple',
          question: 'to bring',
          answer: const Value('traer'),
          questionImage: Value(questionImage),
          answerImage: Value(answerImage),
          createdAt: _now,
          updatedAt: _now,
        ),
      );
  return id;
}

/// Inserts the statistics of [cardId] in one [direction]. They are written
/// by the study session in phases 3 and 4.
Future<void> addTestStats(
  AppDatabase db,
  String cardId, {
  String direction = 'normal',
  int correct = 0,
  int wrong = 0,
  DateTime? lastAttemptAt,
}) => db
    .into(db.cardStats)
    .insert(
      CardStatsCompanion.insert(
        cardId: cardId,
        direction: direction,
        correctCount: Value(correct),
        wrongCount: Value(wrong),
        inErrorList: Value(wrong > 0),
        lastAttemptAt: Value(lastAttemptAt),
      ),
    );

/// Saves first-attempt answers to [cardId] in [direction], one per result
/// (`correct` or `wrong`), one minute apart from [at], in a finished session
/// of [projectId]. Then rebuilds `card_stats` from the attempts, so the
/// statistics are what studying would leave (R 7.4). Local days are UTC
/// days, like a `FakeClock` without a time zone.
Future<void> addTestAnswers(
  AppDatabase db, {
  required String projectId,
  required String cardId,
  required List<String> results,
  String direction = 'normal',
  DateTime? at,
}) async {
  final start = at ?? _now;
  final sessionId = newId();
  await db
      .into(db.studySessions)
      .insert(
        StudySessionsCompanion.insert(
          id: sessionId,
          projectId: projectId,
          mode: 'normal',
          direction: direction,
          prioritizeFailed: false,
          repeatFailed: false,
          timerType: 'none',
          status: 'completed',
          startedAt: start,
        ),
      );
  for (final (i, result) in results.indexed) {
    final answeredAt = start.add(Duration(minutes: i));
    await db
        .into(db.attempts)
        .insert(
          AttemptsCompanion.insert(
            id: newId(),
            sessionId: sessionId,
            cardId: cardId,
            direction: direction,
            result: result,
            source: 'self_eval',
            isFirstAttempt: true,
            answeredAt: answeredAt,
            localDay: Value(answeredAt.toIso8601String().substring(0, 10)),
          ),
        );
  }
  await db.recomputeCardStats();
}

/// Inserts a study session of [projectId] over [deckIds] with these totals,
/// as the study screen leaves it when it ends ([status] `in_progress` while
/// it is still open). No attempts are saved.
Future<String> addTestSession(
  AppDatabase db, {
  required String projectId,
  required List<String> deckIds,
  required DateTime startedAt,
  String status = 'completed',
  int correct = 0,
  int wrong = 0,
  int unanswered = 0,
  Duration activeDuration = const Duration(minutes: 5),
}) async {
  final sessionId = newId();
  await db
      .into(db.studySessions)
      .insert(
        StudySessionsCompanion.insert(
          id: sessionId,
          projectId: projectId,
          mode: 'normal',
          direction: 'normal',
          prioritizeFailed: false,
          repeatFailed: false,
          timerType: 'none',
          status: status,
          startedAt: startedAt,
          endedAt: Value(
            status == 'in_progress' ? null : startedAt.add(activeDuration),
          ),
          activeDurationMs: Value(activeDuration.inMilliseconds),
          correctTotal: Value(correct),
          wrongTotal: Value(wrong),
          unansweredTotal: Value(unanswered),
        ),
      );
  for (final deckId in deckIds) {
    await db
        .into(db.sessionDecks)
        .insert(
          SessionDecksCompanion.insert(sessionId: sessionId, deckId: deckId),
        );
  }
  return sessionId;
}

/// Inserts a finished study session of [projectId] with one correct answer
/// to [cardId]. Sessions arrive in phase 3.
Future<void> addTestAttempt(
  AppDatabase db, {
  required String projectId,
  required String cardId,
}) async {
  final sessionId = newId();
  await db
      .into(db.studySessions)
      .insert(
        StudySessionsCompanion.insert(
          id: sessionId,
          projectId: projectId,
          mode: 'normal',
          direction: 'normal',
          prioritizeFailed: false,
          repeatFailed: false,
          timerType: 'none',
          status: 'completed',
          startedAt: _now,
        ),
      );
  await db
      .into(db.attempts)
      .insert(
        AttemptsCompanion.insert(
          id: newId(),
          sessionId: sessionId,
          cardId: cardId,
          direction: 'normal',
          result: 'correct',
          source: 'self_eval',
          isFirstAttempt: true,
          answeredAt: _now,
        ),
      );
}
