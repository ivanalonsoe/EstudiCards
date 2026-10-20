// Drift queries for the settings (see `ProjectsDao` for what a DAO is).
import 'package:drift/drift.dart';
import 'package:estudicards/core/db/app_database.dart';

part 'settings_dao.g.dart';

@DriftAccessor(tables: [Decks, Projects, Settings])
class SettingsDao extends DatabaseAccessor<AppDatabase>
    with _$SettingsDaoMixin {
  new(super.attachedDatabase);

  /// Every stored setting, as key → value; read again after each change.
  Stream<Map<String, String?>> watchAll() =>
      select(settings)
          .watch()
          .map((rows) => {for (final row in rows) row.key: row.value});

  Future<Map<String, String?>> readAll() async => {
    for (final row in await select(settings).get()) row.key: row.value,
  };

  /// Saves [value] under [key], replacing what was there; null leaves the
  /// key with no value.
  Future<void> write(String key, String? value) => into(settings)
      .insertOnConflictUpdate(
        SettingsCompanion.insert(key: key, value: Value(value)),
      );

  /// The languages of the language decks that are not in the trash, nor in
  /// a project in the trash. Archived projects count: they are still the
  /// user's decks.
  Future<List<({String? source, String? target})>> languageDecks() {
    final query =
        select(decks)
            .join([innerJoin(projects, projects.id.equalsExp(decks.projectId))])
          ..where(
            decks.type.equals('language') &
                decks.deletedAt.isNull() &
                projects.deletedAt.isNull(),
          )
          ..orderBy([OrderingTerm.asc(decks.createdAt)]);
    return query
        .map(
          (row) => (
            source: row.readTable(decks).sourceLang,
            target: row.readTable(decks).targetLang,
          ),
        )
        .get();
  }
}
