import 'package:drift/drift.dart' show Variable;
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

  test('the current version is 3', () {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    expect(db.schemaVersion, 3);
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

    test('keeps cards and statistics', () async {
      final db = await migrate(await versionTwoWithData());

      final card = await db.select(db.cards).getSingle();
      final stats = await db.select(db.cardStats).getSingle();
      expect(card.question, 'to bring');
      expect(stats.correctCount, 3);
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
}
