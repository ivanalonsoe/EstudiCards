import 'dart:io';

import 'package:drift/drift.dart' show OrderingTerm, Variable;
import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:estudicards/core/db/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

import 'schema_files.dart';

// How these tests work, with Drift's `SchemaVerifier`:
//   1. `schemaAt(n)` creates an in-memory database exactly as schema version n
//      left it (from drift_schemas/, see `SchemaFiles`).
//   2. The test inserts rows with plain SQL, since the app's Dart tables only
//      describe the current version.
//   3. `migrateAndValidate(db, n)` opens the app's database on it, which runs
//      the migration, and then checks that the result has the same tables,
//      columns and indexes as a fresh install of version n.
//   4. The test reads the rows back to check that the data survived.

const _now = "'2026-09-02T10:00:00.000Z'";

void main() {
  late SchemaVerifier verifier;

  setUpAll(() => verifier = SchemaVerifier(SchemaFiles()));

  /// Opens the app's database on [schema], migrates it to the current
  /// version and checks the result against a fresh install.
  Future<AppDatabase> migrate(InitializedSchema schema) async {
    final db = AppDatabase(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, db.schemaVersion);
    return db;
  }

  test('the current version is 4', () {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    expect(db.schemaVersion, 4);
  });

  group('from version 1', () {
    test('adds archived_at', () async {
      final schema = await verifier.schemaAt(1);
      schema.rawDatabase.execute(
        'INSERT INTO projects (id, name, color, icon, type, is_archived, '
        "created_at, updated_at) VALUES ('p1', 'Alemán A1', 'amber', "
        "'globe', 'language', 1, $_now, $_now)",
      );

      final db = await migrate(schema);
      final project = await db.select(db.projects).getSingle();

      expect(project.name, 'Alemán A1');
      expect(project.isArchived, isTrue);
      // Projects archived before the upgrade have no date.
      expect(project.archivedAt, isNull);
    });

    test(
      'an upgrade cut short (column added, version not saved) still opens',
      () async {
        // Drift saves the new version after the whole opening finishes. If
        // the app is closed in between, the column exists but the version is
        // still 1, and the next start runs the step again.
        final schema = await verifier.schemaAt(1);
        schema.rawDatabase.execute(
          'ALTER TABLE projects ADD COLUMN archived_at TEXT NULL',
        );

        final db = await migrate(schema);

        expect(await db.select(db.projects).get(), isEmpty);
      },
    );
  });

  group('from version 2', () {
    /// A version 2 database with three projects:
    ///  - p1, a language project (English → Spanish) with two decks;
    ///  - p2, a general project with one deck;
    ///  - p3, a general project that was a language project and kept its
    ///    languages hidden (US-02 AC2 before T2.10), with one deck.
    /// The first deck has a card with statistics.
    Future<InitializedSchema> versionTwoWithData() async {
      final schema = await verifier.schemaAt(2);
      final raw = schema.rawDatabase
        ..execute(
          'INSERT INTO projects (id, name, color, icon, type, source_lang, '
          'target_lang, created_at, updated_at) VALUES '
          "('p1', 'Inglés B2', 'blue', 'globe', 'language', 'en-GB', "
          "'es-ES', $_now, $_now), "
          "('p2', 'Biología', 'green', 'flask', 'general', NULL, NULL, "
          '$_now, $_now), '
          "('p3', 'Alemán A1', 'amber', 'globe', 'general', 'de-DE', "
          "'es-ES', $_now, $_now)",
        )
        ..execute(
          'INSERT INTO decks (id, project_id, name, created_at, updated_at) '
          "VALUES ('d1', 'p1', 'Verbos irregulares', $_now, $_now), "
          "('d2', 'p1', 'Phrasal verbs', $_now, $_now), "
          "('d3', 'p2', 'Célula', $_now, $_now), "
          "('d4', 'p3', 'Saludos', $_now, $_now)",
        )
        ..execute(
          'INSERT INTO cards (id, deck_id, type, question, answer, '
          "created_at, updated_at) VALUES ('c1', 'd1', 'simple', "
          "'to bring', 'traer', $_now, $_now)",
        )
        ..execute(
          'INSERT INTO card_stats (card_id, direction, correct_count, '
          "wrong_count) VALUES ('c1', 'normal', 3, 1)",
        );
      expect(raw.userVersion, 2);
      return schema;
    }

    Future<Map<String, (String, String?, String?)>> decksOf(
      AppDatabase db,
    ) async => {
      for (final deck in await db.select(db.decks).get())
        deck.id: (deck.type, deck.sourceLang, deck.targetLang),
    };

    Future<List<String>> projectColumns(AppDatabase db) async => [
      for (final row
          in await db
              .customSelect(
                'SELECT name FROM pragma_table_info(?)',
                variables: [const Variable('projects')],
              )
              .get())
        row.read<String>('name'),
    ];

    test('gives each deck the type and languages of its project', () async {
      final db = await migrate(await versionTwoWithData());

      expect(await decksOf(db), {
        'd1': ('language', 'en-GB', 'es-ES'),
        'd2': ('language', 'en-GB', 'es-ES'),
        'd3': ('general', null, null),
        // A general deck keeps the languages its project had hidden.
        'd4': ('general', 'de-DE', 'es-ES'),
      });
    });

    test('removes the type and languages from projects', () async {
      final db = await migrate(await versionTwoWithData());

      expect(
        await projectColumns(db),
        isNot(
          anyOf(
            contains('type'),
            contains('source_lang'),
            contains('target_lang'),
          ),
        ),
      );
      expect(await db.select(db.projects).get(), hasLength(3));
    });

    test('keeps cards, and statistics come from the attempts', () async {
      // Since version 4, `card_stats` is recalculated from `attempts` on
      // upgrade: the row inserted above has no attempts behind it.
      final schema = await versionTwoWithData();
      schema.rawDatabase
        ..execute(_sessionInsert('s1', 'p1'))
        ..execute(
          _attemptInsert('a1', 's1', 'c1', 'normal', 'correct', minute: 1),
        );

      final db = await migrate(schema);

      final card = await db.select(db.cards).getSingle();
      final stats = await db.select(db.cardStats).getSingle();
      expect(card.question, 'to bring');
      expect((stats.correctCount, stats.wrongCount), (1, 0));
    });

    test('an upgrade cut short halfway still opens', () async {
      // The deck columns were added and filled, and projects lost `type`,
      // but the app closed before dropping the languages and saving the
      // version. The next start must finish the job.
      final schema = await versionTwoWithData();
      schema.rawDatabase
        ..execute(
          "ALTER TABLE decks ADD COLUMN type TEXT NOT NULL DEFAULT 'general'",
        )
        ..execute('ALTER TABLE decks ADD COLUMN source_lang TEXT NULL')
        ..execute('ALTER TABLE decks ADD COLUMN target_lang TEXT NULL')
        ..execute(
          "UPDATE decks SET type = 'language', source_lang = 'en-GB', "
          "target_lang = 'es-ES' WHERE project_id = 'p1'",
        )
        ..execute('ALTER TABLE projects DROP COLUMN type');

      final db = await migrate(schema);

      expect((await decksOf(db))['d1'], ('language', 'en-GB', 'es-ES'));
      expect(await projectColumns(db), isNot(contains('source_lang')));
    });
  });

  group('from version 3', () {
    /// A version 3 database with the attempts of phase 3 and no
    /// `card_stats`, as phase 3 left them (T3.5 did not fill them).
    Future<InitializedSchema> versionThreeWithAttempts() async {
      final schema = await verifier.schemaAt(3);
      schema.rawDatabase
        ..execute(
          'INSERT INTO projects (id, name, color, icon, created_at, '
          "updated_at) VALUES ('p1', 'Inglés B2', 'blue', 'globe', $_now, "
          '$_now)',
        )
        ..execute(
          'INSERT INTO decks (id, project_id, name, created_at, updated_at) '
          "VALUES ('d1', 'p1', 'Verbos', $_now, $_now)",
        )
        ..execute(
          'INSERT INTO cards (id, deck_id, type, question, answer, '
          "created_at, updated_at) VALUES ('c1', 'd1', 'simple', 'to bring', "
          "'traer', $_now, $_now), ('c2', 'd1', 'simple', 'to seek', "
          "'buscar', $_now, $_now)",
        )
        ..execute(_sessionInsert('s1', 'p1'))
        ..execute(
          _attemptInsert('a1', 's1', 'c1', 'normal', 'wrong', minute: 1),
        )
        // A repeat of "Repetir falladas al final" does not count.
        ..execute(
          _attemptInsert(
            'a2',
            's1',
            'c1',
            'normal',
            'correct',
            minute: 2,
            isFirstAttempt: false,
          ),
        )
        ..execute(
          _attemptInsert('a3', 's1', 'c1', 'normal', 'correct', minute: 3),
        )
        ..execute(
          _attemptInsert('a4', 's1', 'c1', 'reverse', 'correct', minute: 4),
        )
        // An unanswered card gets no statistics.
        ..execute(
          _attemptInsert('a5', 's1', 'c2', 'normal', 'unanswered', minute: 5),
        );
      return schema;
    }

    test('fills card_stats from the attempts', () async {
      final db = await migrate(await versionThreeWithAttempts());

      final stats = await (db.select(
        db.cardStats,
      )..orderBy([(s) => OrderingTerm.asc(s.direction)])).get();
      expect(
        stats.map(
          (s) => (
            s.cardId,
            s.direction,
            s.correctCount,
            s.wrongCount,
            s.consecutiveCorrect,
            s.inErrorList,
            s.lastResult,
          ),
        ),
        [
          ('c1', 'normal', 1, 1, 1, true, 'correct'),
          ('c1', 'reverse', 1, 0, 1, false, 'correct'),
        ],
      );
      expect(
        stats.first.lastAttemptAt,
        DateTime.utc(2026, 9, 2, 10, 3),
        reason: 'the repeat at minute 2 does not count',
      );
    });

    test('gives each attempt its local day, in the device time '
        'zone', () async {
      final db = await migrate(await versionThreeWithAttempts());

      final local = DateTime.utc(2026, 9, 2, 10, 1).toLocal();
      final expected =
          '${local.year}-${local.month.toString().padLeft(2, '0')}-'
          '${local.day.toString().padLeft(2, '0')}';
      final attempts = await db.select(db.attempts).get();
      expect(attempts.map((a) => a.localDay).toSet(), {expected});
    });
  });

  group('from the 1.0.0 release (version 4)', () {
    // A database file made by the 1.0.0 app, with rows in every table. It
    // is never regenerated: every later version must open it as it is.
    const releasedFile = 'drift_schemas/estudicards_1.0.0.sqlite';

    /// Opens a copy of [releasedFile] with the app's database, migrated to
    /// the current version and checked against a fresh install.
    Future<AppDatabase> openReleased() async {
      final folder = Directory.systemTemp.createTempSync('released_db');
      addTearDown(() => folder.deleteSync(recursive: true));
      final copy = File(releasedFile).copySync('${folder.path}/copy.sqlite');
      final db = AppDatabase(NativeDatabase(copy));
      addTearDown(db.close);
      await verifier.migrateAndValidate(db, db.schemaVersion);
      return db;
    }

    test('has the schema saved in drift_schema_v4.json', () async {
      final schema = await verifier.schemaAt(4);
      final raw = schema.rawDatabase
        ..execute("ATTACH DATABASE '$releasedFile' AS released");
      List<String> objects(String database) => [
        for (final row in raw.select(
          'SELECT type, name, sql FROM $database.sqlite_master '
          "WHERE name NOT LIKE 'sqlite_%' ORDER BY type, name",
        ))
          '${row['type']} ${row['name']}: ${row['sql']}',
      ];

      expect(objects('released'), objects('main'));
    });

    test('opens with every row', () async {
      final db = await openReleased();

      final project = await db.select(db.projects).getSingle();
      final decks = await (db.select(
        db.decks,
      )..orderBy([(d) => OrderingTerm.asc(d.name)])).get();
      final cards = await (db.select(
        db.cards,
      )..orderBy([(c) => OrderingTerm.asc(c.id)])).get();
      expect((project.name, project.isFavorite), ('Inglés B2', true));
      expect(decks.map((d) => (d.name, d.type, d.sourceLang, d.targetLang)), [
        ('Repaso general', 'general', null, null),
        ('Verbos irregulares', 'language', 'en-GB', 'es-ES'),
      ]);
      expect(cards.map((c) => (c.type, c.question, c.questionImage)), [
        ('simple', 'to bring', 'c1-question.jpg'),
        ('test', '¿Qué verbos son irregulares?', null),
      ]);
      expect(await db.select(db.cardOptions).get(), hasLength(3));
      expect(await db.select(db.studySessions).get(), hasLength(1));
      expect(await db.select(db.sessionDecks).get(), hasLength(2));
      expect(await db.select(db.attempts).get(), hasLength(3));
      expect(
        {
          for (final setting in await db.select(db.settings).get())
            setting.key: setting.value,
        },
        {'theme_mode': 'dark', 'card_text_scale': '1.2', 'daily_goal': null},
      );
    });

    test('keeps card_stats as the attempts give them', () async {
      final db = await openReleased();
      Future<List<CardStatsRow>> stats() =>
          (db.select(db.cardStats)..orderBy([
                (s) => OrderingTerm.asc(s.cardId),
                (s) => OrderingTerm.asc(s.direction),
              ]))
              .get();

      final stored = await stats();
      await db.recomputeCardStats();

      expect(stored, hasLength(2));
      expect(await stats(), stored);
    });
  });
}

/// SQL that inserts a finished session [id] of [projectId].
String _sessionInsert(String id, String projectId) =>
    'INSERT INTO study_sessions (id, project_id, mode, direction, '
    'prioritize_failed, repeat_failed, timer_type, status, started_at) '
    "VALUES ('$id', '$projectId', 'normal', 'normal', 0, 0, 'none', "
    "'completed', $_now)";

/// SQL that inserts an attempt answered [minute] minutes after 10:00 UTC on
/// 2 September 2026.
String _attemptInsert(
  String id,
  String sessionId,
  String cardId,
  String direction,
  String result, {
  required int minute,
  bool isFirstAttempt = true,
}) {
  final at = DateTime.utc(2026, 9, 2, 10, minute).toIso8601String();
  final source = result == 'unanswered' ? 'session_end' : 'self_eval';
  return 'INSERT INTO attempts (id, session_id, card_id, direction, result, '
      'source, is_first_attempt, answered_at) VALUES '
      "('$id', '$sessionId', '$cardId', '$direction', '$result', '$source', "
      "${isFirstAttempt ? 1 : 0}, '$at')";
}
