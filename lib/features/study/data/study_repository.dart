// The entry point the app uses to save study sessions and their answers
// (see `ProjectsRepository` for what a repository does).
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:estudicards/core/clock.dart';
import 'package:estudicards/core/db/app_database.dart';
import 'package:estudicards/core/ids.dart';
import 'package:estudicards/features/cards/data/cards_repository.dart';
import 'package:estudicards/features/study/data/study_dao.dart';
import 'package:estudicards/features/study/domain/attempt_record.dart';
import 'package:estudicards/features/study/domain/session_config.dart';
import 'package:estudicards/features/study/domain/session_engine.dart';
import 'package:estudicards/features/study/domain/session_results.dart';
import 'package:estudicards/features/study/domain/session_state.dart';
import 'package:estudicards/features/study/domain/study_options.dart';

class StudyRepository {
  new(this._dao, this._clock);

  final StudyDao _dao;
  final Clock _clock;

  /// Saves a new session of [projectId] as `in_progress`, with its decks,
  /// and returns its ID. The project and the decks are marked as used
  /// (R 7.7).
  Future<String> startSession(String projectId, SessionConfig config) async {
    final id = newId();
    final now = _clock.now();
    await _dao.transaction(() async {
      await _dao.insertSession(
        StudySessionsCompanion.insert(
          id: id,
          projectId: projectId,
          mode: config.mode.name,
          direction: config.direction.name,
          requestedCount: Value(config.requestedCount),
          prioritizeFailed: config.prioritizeFailed,
          repeatFailed: config.repeatFailed,
          timerType: config.timerType.stored,
          timerSeconds: Value(config.timerSeconds),
          status: 'in_progress',
          startedAt: now,
        ),
      );
      for (final deckId in config.deckIds) {
        await _dao.insertSessionDeck(
          SessionDecksCompanion.insert(sessionId: id, deckId: deckId),
        );
      }
      await _dao.markUsed(projectId, config.deckIds, now);
    });
    return id;
  }

  /// Saves what one engine [step] recorded in session [sessionId], at once
  /// and in one transaction: its answers and, when the session finished,
  /// its end. If the app closes later, what was answered is already saved.
  Future<void> record(String sessionId, SessionStep step) async {
    final state = step.state;
    // Most steps (flipping, ticking an option, ticks…) record nothing.
    if (step.attempts.isEmpty && state is! Finished) return;
    await _dao.transaction(() async {
      for (final attempt in step.attempts) {
        await _dao.insertAttempt(_attemptRow(sessionId, attempt));
      }
      if (state is Finished) await _finish(sessionId, state);
    });
  }

  /// What the results screen shows about session [sessionId] (P11); null
  /// if there is no such session.
  Future<SessionResults?> results(String sessionId) async {
    final session = await _dao.findSession(sessionId);
    if (session == null) return null;
    final project = await _dao.findProject(session.projectId);
    final decks = await _dao.decksOf(sessionId);
    final attemptRows = await _dao.attemptsOf(sessionId);
    final cardIds = {for (final row in attemptRows) row.cardId};
    final cardRows = await _dao.cardsByIds(cardIds);
    final options = await _dao.optionsOf(cardIds);

    return SessionResults(
      sessionId: session.id,
      projectId: session.projectId,
      projectName: project?.name ?? '',
      deckNames: [for (final deck in decks) deck.name],
      config: SessionConfig(
        deckIds: [for (final deck in decks) deck.id],
        mode: StudyMode.fromStored(session.mode),
        direction: StudyDirection.fromStored(session.direction),
        requestedCount: session.requestedCount,
        prioritizeFailed: session.prioritizeFailed,
        repeatFailed: session.repeatFailed,
        timerType: TimerType.fromStored(session.timerType),
        timerSeconds: session.timerSeconds,
      ),
      status: SessionStatus.fromStored(session.status),
      correctCount: session.correctTotal,
      wrongCount: session.wrongTotal,
      unansweredCount: session.unansweredTotal,
      activeDuration: Duration(milliseconds: session.activeDurationMs),
      attempts: [for (final row in attemptRows) _attemptRecord(row)],
      cards: {
        for (final row in cardRows)
          row.id: flashcardFromRows(row, [
            for (final option in options)
              if (option.cardId == row.id) option,
          ]),
      },
    );
  }

  /// Saves how the session ended. The totals are counted from the saved
  /// attempts, first attempts only (SPEC §4.2), so repeats never count.
  Future<void> _finish(String sessionId, Finished finished) async {
    final firstAttempts = [
      for (final row in await _dao.attemptsOf(sessionId))
        if (row.isFirstAttempt) AttemptResult.fromStored(row.result),
    ];
    int total(AttemptResult result) =>
        firstAttempts.where((r) => r == result).length;

    await _dao.updateSession(
      sessionId,
      StudySessionsCompanion(
        status: Value(finished.status.stored),
        endedAt: Value(_clock.now()),
        activeDurationMs: Value(finished.activeDuration.inMilliseconds),
        correctTotal: Value(total(AttemptResult.correct)),
        wrongTotal: Value(total(AttemptResult.wrong)),
        unansweredTotal: Value(total(AttemptResult.unanswered)),
      ),
    );
  }

  static AttemptRecord _attemptRecord(AttemptRow row) {
    final selected = row.selectedOptionIds;
    final responseTime = row.responseTimeMs;
    return AttemptRecord(
      cardId: row.cardId,
      direction: StudyDirection.fromStored(row.direction),
      result: AttemptResult.fromStored(row.result),
      source: AttemptSource.fromStored(row.source),
      isFirstAttempt: row.isFirstAttempt,
      selectedOptionIds: selected == null
          ? null
          : {for (final id in jsonDecode(selected) as List<dynamic>) '$id'},
      responseTime: responseTime == null
          ? null
          : Duration(milliseconds: responseTime),
      answeredAt: row.answeredAt,
    );
  }

  static AttemptsCompanion _attemptRow(
    String sessionId,
    AttemptRecord attempt,
  ) {
    final selected = attempt.selectedOptionIds;
    return AttemptsCompanion.insert(
      id: newId(),
      sessionId: sessionId,
      cardId: attempt.cardId,
      direction: attempt.direction.name,
      result: attempt.result.name,
      source: attempt.source.stored,
      isFirstAttempt: attempt.isFirstAttempt,
      // A JSON list, sorted so the same choice is always stored the same.
      selectedOptionIds: Value(
        selected == null ? null : jsonEncode(selected.toList()..sort()),
      ),
      responseTimeMs: Value(attempt.responseTime?.inMilliseconds),
      answeredAt: attempt.answeredAt,
    );
  }
}
