import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:estudicards/core/db/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  final now = DateTime.utc(2026, 10, 4, 12);

  setUp(() {
    // A fresh in-memory database for every test: nothing is written to disk.
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  Future<void> insertProjectDeckAndCard() async {
    await db
        .into(db.projects)
        .insert(
          ProjectsCompanion.insert(
            id: 'project-1',
            name: 'Inglés B2',
            color: 'orange',
            icon: '🇬🇧',
            createdAt: now,
            updatedAt: now,
          ),
        );
    await db
        .into(db.decks)
        .insert(
          DecksCompanion.insert(
            id: 'deck-1',
            projectId: 'project-1',
            name: 'Verbos irregulares',
            type: const Value('language'),
            sourceLang: const Value('en-GB'),
            targetLang: const Value('es-ES'),
            createdAt: now,
            updatedAt: now,
          ),
        );
    await db
        .into(db.cards)
        .insert(
          CardsCompanion.insert(
            id: 'card-1',
            deckId: 'deck-1',
            type: 'simple',
            question: 'to bring',
            answer: const Value('traer'),
            createdAt: now,
            updatedAt: now,
          ),
        );
  }

  test('opens in memory with schema version 4 and every table empty', () async {
    expect(db.schemaVersion, 4);
    expect(
      db.allTables.map((t) => t.actualTableName),
      unorderedEquals([
        'projects',
        'decks',
        'cards',
        'card_options',
        'card_stats',
        'study_sessions',
        'session_decks',
        'attempts',
        'settings',
      ]),
    );

    for (final table in db.allTables) {
      final count = await table.count().getSingle();
      expect(count, 0, reason: '${table.actualTableName} should be empty');
    }
  });

  test('creates the recommended indexes', () async {
    final rows = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'index' "
          "AND name NOT LIKE 'sqlite_%'",
        )
        .get();

    expect(
      rows.map((r) => r.read<String>('name')),
      unorderedEquals([
        'decks_project_deleted',
        'cards_deck',
        'attempts_card_direction_answered',
        'attempts_session',
        'attempts_local_day',
        'card_stats_in_error_list',
      ]),
    );
  });

  test('inserts a project, a deck and a card and reads them back', () async {
    await insertProjectDeckAndCard();

    final project = await db.select(db.projects).getSingle();
    expect(project.id, 'project-1');
    expect(project.name, 'Inglés B2');
    expect(project.isFavorite, isFalse);
    expect(project.isArchived, isFalse);
    expect(project.deletedAt, isNull);
    expect(project.createdAt, now);

    final deck = await db.select(db.decks).getSingle();
    expect(deck.projectId, 'project-1');
    expect(deck.name, 'Verbos irregulares');
    expect(deck.color, isNull);
    expect(deck.type, 'language');
    expect(deck.sourceLang, 'en-GB');
    expect(deck.targetLang, 'es-ES');

    final card = await db.select(db.cards).getSingle();
    expect(card.deckId, 'deck-1');
    expect(card.question, 'to bring');
    expect(card.answer, 'traer');
    expect(card.allowMultiple, isFalse);
  });

  test('keeps dates in UTC with millisecond precision', () async {
    await insertProjectDeckAndCard();
    final usedAt = DateTime.utc(2026, 10, 4, 12, 30, 15, 123);

    await (db.update(db.projects)..where((p) => p.id.equals('project-1')))
        .write(ProjectsCompanion(lastUsedAt: Value(usedAt)));

    final project = await db.select(db.projects).getSingle();
    expect(project.lastUsedAt, usedAt);
    expect(project.lastUsedAt!.isUtc, isTrue);
  });

  test('deleting a card cascades to its options, stats and attempts', () async {
    await insertProjectDeckAndCard();
    await db
        .into(db.cardOptions)
        .insert(
          CardOptionsCompanion.insert(
            id: 'option-1',
            cardId: 'card-1',
            optionText: 'traer',
            isCorrect: true,
            position: 0,
          ),
        );
    await db
        .into(db.cardStats)
        .insert(
          CardStatsCompanion.insert(cardId: 'card-1', direction: 'normal'),
        );
    await db
        .into(db.studySessions)
        .insert(
          StudySessionsCompanion.insert(
            id: 'session-1',
            projectId: 'project-1',
            mode: 'normal',
            direction: 'normal',
            prioritizeFailed: false,
            repeatFailed: false,
            timerType: 'none',
            status: 'completed',
            startedAt: now,
          ),
        );
    await db
        .into(db.attempts)
        .insert(
          AttemptsCompanion.insert(
            id: 'attempt-1',
            sessionId: 'session-1',
            cardId: 'card-1',
            direction: 'normal',
            result: 'correct',
            source: 'self_eval',
            isFirstAttempt: true,
            answeredAt: now,
          ),
        );

    await (db.delete(db.cards)..where((c) => c.id.equals('card-1'))).go();

    expect(await db.cardOptions.count().getSingle(), 0);
    expect(await db.cardStats.count().getSingle(), 0);
    expect(await db.attempts.count().getSingle(), 0);
    // The session itself is kept: it belongs to the project, not the card.
    expect(await db.studySessions.count().getSingle(), 1);
  });

  test(
    'deleting a project cascades to its decks, cards and sessions',
    () async {
      await insertProjectDeckAndCard();
      await db
          .into(db.studySessions)
          .insert(
            StudySessionsCompanion.insert(
              id: 'session-1',
              projectId: 'project-1',
              mode: 'normal',
              direction: 'normal',
              prioritizeFailed: false,
              repeatFailed: false,
              timerType: 'none',
              status: 'completed',
              startedAt: now,
            ),
          );
      await db
          .into(db.sessionDecks)
          .insert(
            SessionDecksCompanion.insert(
              sessionId: 'session-1',
              deckId: 'deck-1',
            ),
          );

      await (db.delete(
        db.projects,
      )..where((p) => p.id.equals('project-1'))).go();

      for (final table in db.allTables) {
        final count = await table.count().getSingle();
        expect(count, 0, reason: '${table.actualTableName} should be empty');
      }
    },
  );

  test('rejects a deck whose project does not exist', () async {
    expect(
      () => db
          .into(db.decks)
          .insert(
            DecksCompanion.insert(
              id: 'deck-1',
              projectId: 'missing',
              name: 'Orphan',
              createdAt: now,
              updatedAt: now,
            ),
          ),
      throwsA(isA<SqliteException>()),
    );
  });
}
