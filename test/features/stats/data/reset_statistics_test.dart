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
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/test_data.dart';

/// "Reiniciar estadísticas" of a card, deck or project (R 7.4, US-11 AC1):
/// its attempts and `card_stats` rows go; past sessions keep their totals.
void main() {
  late AppDatabase db;
  late FakeClock clock;
  late StatsRepository stats;
  late ProjectsRepository projects;
  late DecksRepository decks;
  late String projectId;
  late String verbsId;
  late String phrasalId;
  late String verbCard;
  late String phrasalCard;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    clock = FakeClock(DateTime.utc(2026, 10, 6, 12));
    stats = StatsRepository(StatsDao(db), clock);
    projects = ProjectsRepository(ProjectsDao(db), clock);
    decks = DecksRepository(DecksDao(db), clock);
    projectId = (await projects.create(
      const ProjectInput(name: 'Inglés B2', color: 'blue', icon: 'globe'),
    )).id;
    verbsId = (await decks.create(
      projectId,
      const DeckInput(name: 'Verbos'),
    )).id;
    phrasalId = (await decks.create(
      projectId,
      const DeckInput(name: 'Phrasal verbs'),
    )).id;
    verbCard = await addTestCard(db, verbsId);
    phrasalCard = await addTestCard(db, phrasalId);
    for (final card in [verbCard, phrasalCard]) {
      for (final direction in ['normal', 'reverse']) {
        await addTestAnswers(
          db,
          projectId: projectId,
          cardId: card,
          results: ['correct', 'wrong'],
          direction: direction,
        );
      }
    }
    // The totals the sessions saved when they ended.
    await db
        .update(db.studySessions)
        .write(
          const StudySessionsCompanion(
            correctTotal: Value(1),
            wrongTotal: Value(1),
          ),
        );
  });

  tearDown(() => db.close());

  Future<int> attemptsOf(String cardId) async => (await (db.select(
    db.attempts,
  )..where((a) => a.cardId.equals(cardId))).get()).length;

  Future<int> statsOf(String cardId) async => (await (db.select(
    db.cardStats,
  )..where((s) => s.cardId.equals(cardId))).get()).length;

  /// Every session still exists with the totals it saved.
  Future<void> expectSessionsKept() async {
    final sessions = await db.select(db.studySessions).get();
    expect(sessions, hasLength(4));
    for (final session in sessions) {
      expect((session.correctTotal, session.wrongTotal), (1, 1));
    }
  }

  test('resetting a deck deletes its attempts and statistics but not those '
      'of other decks; past session totals are kept', () async {
    await stats.resetDeck(verbsId);

    expect(await attemptsOf(verbCard), 0);
    expect(await statsOf(verbCard), 0);
    expect(await attemptsOf(phrasalCard), 4);
    expect(await statsOf(phrasalCard), 2);
    await expectSessionsKept();
  });

  test('resetting a card leaves the other cards of its deck', () async {
    final otherVerb = await addTestCard(db, verbsId);
    await addTestAnswers(
      db,
      projectId: projectId,
      cardId: otherVerb,
      results: ['wrong'],
    );

    await stats.resetCard(verbCard);

    expect(await attemptsOf(verbCard), 0);
    expect(await statsOf(verbCard), 0);
    expect(await attemptsOf(otherVerb), 1);
    expect(await statsOf(otherVerb), 1);
    expect(await attemptsOf(phrasalCard), 4);
  });

  test('resetting a project deletes every deck of it, in the trash too, '
      'and leaves other projects', () async {
    await (db.update(db.decks)..where((d) => d.id.equals(phrasalId))).write(
      DecksCompanion(deletedAt: Value(clock.now())),
    );
    final otherProject = (await projects.create(
      const ProjectInput(name: 'Biología', color: 'green', icon: 'flask'),
    )).id;
    final otherDeck = (await decks.create(
      otherProject,
      const DeckInput(name: 'Células'),
    )).id;
    final otherCard = await addTestCard(db, otherDeck);
    await addTestAnswers(
      db,
      projectId: otherProject,
      cardId: otherCard,
      results: ['correct'],
    );

    await stats.resetProject(projectId);

    expect(await attemptsOf(verbCard), 0);
    expect(await attemptsOf(phrasalCard), 0);
    expect(await statsOf(phrasalCard), 0);
    expect(await attemptsOf(otherCard), 1);
    expect(await statsOf(otherCard), 1);
  });

  test('after a reset the statistics count from zero', () async {
    await stats.resetDeck(verbsId);
    await addTestAnswers(
      db,
      projectId: projectId,
      cardId: verbCard,
      results: ['correct'],
    );

    final row = await (db.select(
      db.cardStats,
    )..where((s) => s.cardId.equals(verbCard))).getSingle();
    expect((row.correctCount, row.wrongCount, row.inErrorList), (1, 0, false));
  });
}
