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
