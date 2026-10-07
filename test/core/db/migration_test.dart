import 'package:drift/native.dart';
import 'package:estudicards/core/db/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

/// The `projects` table as schema version 1 created it (T0.4), copied from
/// `sqlite_master`. Never change it: it is what installed apps have.
const _projectsV1 =
    'CREATE TABLE "projects" ("id" TEXT NOT NULL, "name" TEXT NOT NULL, '
    '"description" TEXT NULL, "color" TEXT NOT NULL, "icon" TEXT NOT NULL, '
    '"type" TEXT NOT NULL, "source_lang" TEXT NULL, "target_lang" TEXT NULL, '
    '"is_favorite" INTEGER NOT NULL DEFAULT 0 CHECK ("is_favorite" IN (0, 1)), '
    '"is_archived" INTEGER NOT NULL DEFAULT 0 CHECK ("is_archived" IN (0, 1)), '
    '"deleted_at" TEXT NULL, "last_used_at" TEXT NULL, '
    '"created_at" TEXT NOT NULL, "updated_at" TEXT NOT NULL, '
    'PRIMARY KEY ("id"))';

void main() {
  test('upgrading from version 1 adds archived_at', () async {
    // `setup` runs on the raw SQLite database before Drift opens it: here
    // it builds a version 1 database with one archived project.
    final db = AppDatabase(
      NativeDatabase.memory(
        setup: (raw) {
          raw
            ..execute(_projectsV1)
            ..execute(
              'INSERT INTO projects (id, name, color, icon, type, is_archived, '
              "created_at, updated_at) VALUES ('p1', 'Alemán A1', 'amber', "
              "'globe', 'language', 1, '2026-09-02T10:00:00.000Z', "
              "'2026-09-02T10:00:00.000Z')",
            )
            ..userVersion = 1;
        },
      ),
    );
    addTearDown(db.close);

    final project = await db.select(db.projects).getSingle();

    expect(db.schemaVersion, 2);
    expect(project.name, 'Alemán A1');
    expect(project.isArchived, isTrue);
    // Projects archived before the upgrade have no date.
    expect(project.archivedAt, isNull);
  });
}
