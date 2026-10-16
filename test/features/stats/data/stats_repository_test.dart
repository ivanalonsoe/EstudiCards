import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:estudicards/core/clock.dart';
import 'package:estudicards/core/db/app_database.dart';
import 'package:estudicards/core/random.dart';
import 'package:estudicards/features/cards/data/cards_dao.dart';
import 'package:estudicards/features/cards/data/cards_repository.dart';
import 'package:estudicards/features/cards/domain/card_input.dart';
import 'package:estudicards/features/cards/domain/flashcard.dart';
import 'package:estudicards/features/decks/data/decks_dao.dart';
import 'package:estudicards/features/decks/data/decks_repository.dart';
import 'package:estudicards/features/decks/domain/deck_input.dart';
import 'package:estudicards/features/projects/data/projects_dao.dart';
import 'package:estudicards/features/projects/data/projects_repository.dart';
import 'package:estudicards/features/projects/domain/project_input.dart';
import 'package:estudicards/features/stats/data/stats_dao.dart';
import 'package:estudicards/features/stats/data/stats_repository.dart';
import 'package:estudicards/features/study/data/study_dao.dart';
import 'package:estudicards/features/study/data/study_repository.dart';
import 'package:estudicards/features/study/domain/attempt_record.dart';
import 'package:estudicards/features/study/domain/card_selection.dart';
import 'package:estudicards/features/study/domain/session_config.dart';
import 'package:estudicards/features/study/domain/session_engine.dart';
import 'package:estudicards/features/study/domain/session_state.dart';
import 'package:estudicards/features/study/domain/study_options.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_image_files.dart';
import '../../../helpers/time_zones.dart';

void main() {
  late AppDatabase db;
  late FakeClock clock;
  late StatsRepository stats;
  late StudyRepository study;
  late String projectId;
  late String deckId;
  late Flashcard card;
  late String sessionId;
  late SessionState inProgress;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    // The user is in Madrid: local days follow its summer time.
    clock = FakeClock(DateTime.utc(2026, 10, 2), utcOffset: madridOffset);
    stats = StatsRepository(StatsDao(db), clock);
    study = StudyRepository(StudyDao(db), clock);
    projectId = (await ProjectsRepository(ProjectsDao(db), clock).create(
      const ProjectInput(name: 'Inglés B2', color: 'blue', icon: 'globe'),
    )).id;
    deckId = (await DecksRepository(
      DecksDao(db),
      clock,
    ).create(projectId, const DeckInput(name: 'Verbos'))).id;
    card = await CardsRepository(CardsDao(db), clock, FakeImageFiles()).create(
      deckId,
      const CardInput(type: CardType.simple, question: 'to bring', answer: 'x'),
    );
    final config = SessionConfig(deckIds: [deckId]);
    sessionId = await study.startSession(projectId, config);
    inProgress = SessionEngine(random: createRandom(seed: 1))
        .start(
          cards: [SelectedCard(card: card, direction: StudyDirection.normal)],
          settings: config.settings,
          at: clock.now(),
        )
        .state;
  });

  tearDown(() => db.close());

  /// Saves an answer given at the UTC instant [at], the way a study session
  /// does.
  Future<void> answerAt(
    DateTime at, {
    AttemptResult result = AttemptResult.correct,
    bool isFirstAttempt = true,
  }) => study.record(
    sessionId,
    SessionStep(inProgress, [
      AttemptRecord(
        cardId: card.id,
        direction: StudyDirection.normal,
        result: result,
        source: result == AttemptResult.unanswered
            ? AttemptSource.sessionEnd
            : AttemptSource.selfEval,
        isFirstAttempt: isFirstAttempt,
        answeredAt: at,
      ),
    ]),
  );

  test('saving an answer stores its local day', () async {
    // 22:30 UTC on 15 October is 00:30 on the 16th in Madrid.
    await answerAt(DateTime.utc(2026, 10, 15, 22, 30));

    final attempt = await db.select(db.attempts).getSingle();
    expect(attempt.localDay, '2026-10-16');
  });

  test('answers on both sides of local midnight are two days', () async {
    await answerAt(DateTime.utc(2026, 10, 14, 21, 50)); // 23:50 on the 14th
    await answerAt(DateTime.utc(2026, 10, 14, 22, 10)); // 00:10 on the 15th
    clock.set(DateTime.utc(2026, 10, 15, 8));

    expect((await stats.streak()).current, 2);
    expect(await stats.answeredToday(), 1);
  });

  test('a streak across the night clocks go back', () async {
    // 25 October has 25 hours. 23:30 on the 25th is 22:30 UTC (winter
    // time), which summer time would have put on the 26th.
    await answerAt(DateTime.utc(2026, 10, 24, 10)); // noon on the 24th
    await answerAt(DateTime.utc(2026, 10, 25, 22, 30)); // 23:30 on the 25th
    clock.set(DateTime.utc(2026, 10, 25, 23, 30)); // 00:30 on the 26th

    expect(await stats.answeredToday(), 0);
    expect(
      (await stats.streak()).current,
      2,
      reason: "nothing yet today, so yesterday's streak stands",
    );
  });

  test('a streak across the night clocks go forward', () async {
    // 29 March has 23 hours.
    await answerAt(DateTime.utc(2026, 3, 28, 22, 30)); // 23:30 on the 28th
    await answerAt(DateTime.utc(2026, 3, 29, 21, 30)); // 23:30 on the 29th
    await answerAt(DateTime.utc(2026, 3, 29, 22, 30)); // 00:30 on the 30th
    clock.set(DateTime.utc(2026, 3, 30, 8));

    expect((await stats.streak()).current, 3);
    expect(await stats.answeredToday(), 1);
  });

  test('a day with only unanswered cards does not count towards the '
      'streak', () async {
    await answerAt(DateTime.utc(2026, 10, 13, 10));
    await answerAt(
      DateTime.utc(2026, 10, 14, 10),
      result: AttemptResult.unanswered,
    );
    clock.set(DateTime.utc(2026, 10, 15, 8));

    final streak = await stats.streak();
    expect(streak.current, 0);
    expect(streak.best, 1);
  });

  test("today's answers count first attempts, right or wrong", () async {
    clock.set(DateTime.utc(2026, 10, 15, 8));
    await answerAt(clock.now());
    await answerAt(clock.now(), result: AttemptResult.wrong);
    await answerAt(clock.now(), isFirstAttempt: false);
    await answerAt(clock.now(), result: AttemptResult.unanswered);

    expect(await stats.answeredToday(), 2);
    expect((await stats.streak()).current, 1);
  });

  test('answers of decks or projects in the trash do not count '
      '(R 7.1)', () async {
    clock.set(DateTime.utc(2026, 10, 15, 8));
    await answerAt(clock.now());
    await (db.update(db.decks)..where((d) => d.id.equals(deckId))).write(
      DecksCompanion(deletedAt: Value(clock.now())),
    );

    expect(await stats.answeredToday(), 0);
    expect((await stats.streak()).current, 0);

    await (db.update(db.decks)..where((d) => d.id.equals(deckId))).write(
      const DecksCompanion(deletedAt: Value(null)),
    );
    await (db.update(db.projects)..where((p) => p.id.equals(projectId))).write(
      ProjectsCompanion(deletedAt: Value(clock.now())),
    );

    expect(await stats.answeredToday(), 0);
  });

  test('counts the cards answered in the last 7 days, today '
      'included', () async {
    await answerAt(DateTime.utc(2026, 10, 8, 10)); // 7 days ago: left out
    await answerAt(DateTime.utc(2026, 10, 9, 10)); // 6 days ago
    await answerAt(DateTime.utc(2026, 10, 15, 7), result: AttemptResult.wrong);
    await answerAt(
      DateTime.utc(2026, 10, 15, 7),
      result: AttemptResult.unanswered,
    );
    clock.set(DateTime.utc(2026, 10, 15, 8));

    expect(await stats.answeredInLastDays(7), 2);
    expect(await stats.answeredInLastDays(1), 1);
  });

  test('the overview gathers the streak and the last 7 days', () async {
    await answerAt(DateTime.utc(2026, 10, 14, 10));
    await answerAt(DateTime.utc(2026, 10, 15, 7));
    clock.set(DateTime.utc(2026, 10, 15, 8));

    final overview = await stats.watchOverview().first;

    expect((overview.streak.current, overview.streak.best), (2, 2));
    expect(overview.answeredToday, 1);
    expect(overview.answeredLast7Days, 2);
    expect(overview.dailyGoal, isNull);
  });

  group('daily goal', () {
    test('is off until the user sets one', () async {
      expect(await stats.dailyGoal(), isNull);
    });

    test("shows today's answers against the goal", () async {
      await db
          .into(db.settings)
          .insert(
            SettingsCompanion.insert(
              key: 'daily_goal',
              value: const Value('20'),
            ),
          );
      clock.set(DateTime.utc(2026, 10, 15, 8));
      await answerAt(clock.now());
      await answerAt(clock.now(), result: AttemptResult.wrong);

      final goal = (await stats.dailyGoal())!;
      expect((goal.done, goal.goal, goal.remaining), (2, 20, 18));
    });
  });
}
