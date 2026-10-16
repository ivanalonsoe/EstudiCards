import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:estudicards/core/clock.dart';
import 'package:estudicards/core/db/app_database.dart';
import 'package:estudicards/features/decks/data/decks_dao.dart';
import 'package:estudicards/features/decks/data/decks_repository.dart';
import 'package:estudicards/features/decks/domain/deck_input.dart';
import 'package:estudicards/features/projects/data/projects_dao.dart';
import 'package:estudicards/features/projects/data/projects_repository.dart';
import 'package:estudicards/features/projects/domain/project_input.dart';
import 'package:estudicards/features/stats/data/stats_dao.dart';
import 'package:estudicards/features/stats/data/stats_repository.dart';
import 'package:estudicards/features/study/domain/session_state.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/test_data.dart';

/// The statistics of one project (P12) and the 30-day chart of every
/// project (P13), counted in SQL.
void main() {
  late AppDatabase db;
  late FakeClock clock;
  late StatsRepository stats;
  late ProjectsRepository projects;
  late DecksRepository decks;
  late String projectId;
  late String deckId;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    clock = FakeClock(DateTime.utc(2026, 10, 15, 12));
    stats = StatsRepository(StatsDao(db), clock);
    projects = ProjectsRepository(ProjectsDao(db), clock);
    decks = DecksRepository(DecksDao(db), clock);
    projectId = (await projects.create(
      const ProjectInput(name: 'Inglés B2', color: 'blue', icon: 'globe'),
    )).id;
    deckId = (await decks.create(
      projectId,
      const DeckInput(name: 'Verbos'),
    )).id;
  });

  tearDown(() => db.close());

  Future<String> newProject(String name) async => (await projects.create(
    ProjectInput(name: name, color: 'green', icon: 'flask'),
  )).id;

  Future<void> trashDeck(String id) =>
      (db.update(db.decks)..where((d) => d.id.equals(id))).write(
        DecksCompanion(deletedAt: Value(clock.now())),
      );

  group('answers per day', () {
    test('counts first attempts per local day, with zeros '
        'in between', () async {
      final card = await addTestCard(db, deckId);
      await addTestAnswers(
        db,
        projectId: projectId,
        cardId: card,
        results: ['correct', 'wrong', 'correct'],
        at: DateTime.utc(2026, 10, 15, 9),
      );
      await addTestAnswers(
        db,
        projectId: projectId,
        cardId: card,
        results: ['wrong'],
        at: DateTime.utc(2026, 10, 1, 9),
      );

      final series = await stats.dailyAnswers(projectId: projectId);

      expect(series.days, hasLength(30));
      expect(series.days.last.day, DateTime.utc(2026, 10, 15));
      expect(
        (series.days.last.answers.correct, series.days.last.answers.wrong),
        (2, 1),
      );
      expect(series.days[series.days.length - 15].answers.wrong, 1);
      expect((series.totals.correct, series.totals.wrong), (2, 2));
    });

    test('leaves out repeats, unanswered cards and answers older than '
        '30 days', () async {
      final card = await addTestCard(db, deckId);
      await addTestAnswers(
        db,
        projectId: projectId,
        cardId: card,
        results: ['correct', 'unanswered'],
        at: DateTime.utc(2026, 10, 15, 9),
      );
      await addTestAnswers(
        db,
        projectId: projectId,
        cardId: card,
        results: ['correct'],
        at: DateTime.utc(2026, 9, 15, 9), // 31 days ago
      );
      await (db.update(db.attempts)
            ..where((a) => a.answeredAt.equals(DateTime.utc(2026, 10, 15, 9))))
          .write(const AttemptsCompanion(isFirstAttempt: Value(false)));

      final series = await stats.dailyAnswers(projectId: projectId);

      expect(series.totals.total, 0);
    });

    test("a project's series leaves out other projects; without a project, "
        'every project counts, archived ones too', () async {
      final card = await addTestCard(db, deckId);
      final otherProject = await newProject('Biología');
      final otherDeck = (await decks.create(
        otherProject,
        const DeckInput(name: 'Células'),
      )).id;
      final otherCard = await addTestCard(db, otherDeck);
      await addTestAnswers(
        db,
        projectId: projectId,
        cardId: card,
        results: ['correct'],
        at: DateTime.utc(2026, 10, 14, 9),
      );
      await addTestAnswers(
        db,
        projectId: otherProject,
        cardId: otherCard,
        results: ['wrong', 'wrong'],
        at: DateTime.utc(2026, 10, 14, 9),
      );
      await projects.setArchived(otherProject, isArchived: true);

      expect((await stats.dailyAnswers(projectId: projectId)).totals.total, 1);
      final all = await stats.dailyAnswers();
      expect((all.totals.correct, all.totals.wrong), (1, 2));
    });

    test('leaves out decks in the trash (R 7.1)', () async {
      final card = await addTestCard(db, deckId);
      await addTestAnswers(
        db,
        projectId: projectId,
        cardId: card,
        results: ['correct'],
        at: DateTime.utc(2026, 10, 14, 9),
      );
      await trashDeck(deckId);

      expect((await stats.dailyAnswers(projectId: projectId)).totals.total, 0);
      expect((await stats.dailyAnswers()).totals.total, 0);
    });
  });

  group('most missed cards', () {
    test('the top 10 by wrong answers, both directions added up', () async {
      final cards = [
        for (var i = 0; i < 12; i++) await addTestCard(db, deckId),
      ];
      // Card i has i wrong answers in the normal direction.
      for (final (i, card) in cards.indexed) {
        await addTestStats(db, card, wrong: i);
      }
      // The first card is also missed 20 times in reverse.
      await addTestStats(db, cards.first, direction: 'reverse', wrong: 20);

      final missed = await stats.mostMissed(projectId);

      expect(missed, hasLength(10));
      expect(missed.first.cardId, cards.first);
      expect(missed.first.wrongCount, 20);
      expect(missed.first.deckId, deckId);
      expect(missed.first.question, 'to bring');
      expect(missed[1].wrongCount, 11);
      expect(missed.last.wrongCount, 3);
    });

    test('leaves out cards never missed, decks in the trash and other '
        'projects', () async {
      final neverMissed = await addTestCard(db, deckId);
      await addTestStats(db, neverMissed, correct: 5);
      final trashedDeck = (await decks.create(
        projectId,
        const DeckInput(name: 'Viejo'),
      )).id;
      final trashedCard = await addTestCard(db, trashedDeck);
      await addTestStats(db, trashedCard, wrong: 4);
      await trashDeck(trashedDeck);
      final otherProject = await newProject('Biología');
      final otherDeck = (await decks.create(
        otherProject,
        const DeckInput(name: 'Células'),
      )).id;
      await addTestStats(db, await addTestCard(db, otherDeck), wrong: 2);

      expect(await stats.mostMissed(projectId), isEmpty);
    });
  });

  group('session history', () {
    test('the latest sessions first, with their decks, totals and '
        'duration', () async {
      final otherDeck = (await decks.create(
        projectId,
        const DeckInput(name: 'Phrasal verbs'),
      )).id;
      await addTestSession(
        db,
        projectId: projectId,
        deckIds: [deckId],
        startedAt: DateTime.utc(2026, 10, 13, 18),
        correct: 3,
      );
      await addTestSession(
        db,
        projectId: projectId,
        deckIds: [deckId, otherDeck],
        startedAt: DateTime.utc(2026, 10, 14, 18),
        status: 'time_up',
        correct: 12,
        wrong: 3,
        unanswered: 2,
        activeDuration: const Duration(minutes: 9),
      );

      final history = await stats.sessionHistory(projectId, limit: 10);

      expect(history.hasMore, isFalse);
      expect(history.sessions, hasLength(2));
      final latest = history.sessions.first;
      expect(latest.startedAt, DateTime.utc(2026, 10, 14, 18));
      expect(latest.status, SessionStatus.timeUp);
      expect(latest.deckNames, unorderedEquals(['Verbos', 'Phrasal verbs']));
      expect((latest.answers.correct, latest.answers.wrong), (12, 3));
      expect(latest.unanswered, 2);
      expect(latest.activeDuration, const Duration(minutes: 9));
    });

    test('pages with a limit, and leaves out sessions in progress and '
        'other projects', () async {
      for (var day = 1; day <= 12; day++) {
        await addTestSession(
          db,
          projectId: projectId,
          deckIds: [deckId],
          startedAt: DateTime.utc(2026, 10, day, 18),
        );
      }
      await addTestSession(
        db,
        projectId: projectId,
        deckIds: [deckId],
        startedAt: DateTime.utc(2026, 10, 15, 11),
        status: 'in_progress',
      );
      final otherProject = await newProject('Biología');
      await addTestSession(
        db,
        projectId: otherProject,
        deckIds: const [],
        startedAt: DateTime.utc(2026, 10, 15, 10),
      );

      final first = await stats.sessionHistory(projectId, limit: 10);
      expect(first.sessions, hasLength(10));
      expect(first.hasMore, isTrue);
      expect(first.sessions.first.startedAt, DateTime.utc(2026, 10, 12, 18));

      final all = await stats.sessionHistory(projectId, limit: 20);
      expect(all.sessions, hasLength(12));
      expect(all.hasMore, isFalse);
    });
  });

  test('the watched statistics are read again after an answer', () async {
    final card = await addTestCard(db, deckId);
    final totals = stats
        .watchDailyAnswers(projectId: projectId)
        .map((series) => series.totals.total);

    final emitted = expectLater(totals, emitsInOrder([0, 1]));
    await Future<void>.delayed(Duration.zero);
    await addTestAnswers(
      db,
      projectId: projectId,
      cardId: card,
      results: ['correct'],
      at: DateTime.utc(2026, 10, 15, 9),
    );
    await emitted;
  });
}
