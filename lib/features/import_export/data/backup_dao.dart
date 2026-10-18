// Drift queries for restoring a backup (see `ProjectsDao` for what a DAO
// is).
import 'package:drift/drift.dart';
import 'package:estudicards/core/db/app_database.dart';

part 'backup_dao.g.dart';

@DriftAccessor(
  tables: [
    Projects,
    Decks,
    Cards,
    CardOptions,
    CardStats,
    StudySessions,
    SessionDecks,
    Attempts,
    Settings,
  ],
)
class BackupDao extends DatabaseAccessor<AppDatabase> with _$BackupDaoMixin {
  new(super.attachedDatabase);

  /// Whether there is nothing to lose: no projects (not even in the trash)
  /// and no sessions.
  Future<bool> isEmpty() async {
    final project = await (select(projects)..limit(1)).getSingleOrNull();
    final session = await (select(studySessions)..limit(1)).getSingleOrNull();
    return project == null && session == null;
  }

  /// When each stored project, deck and card was last updated, by ID.
  Future<Map<String, DateTime>> projectUpdates() async => {
    for (final row in await select(projects).get()) row.id: row.updatedAt,
  };

  Future<Map<String, DateTime>> deckUpdates() async => {
    for (final row in await select(decks).get()) row.id: row.updatedAt,
  };

  Future<List<CardRow>> allCards() => select(cards).get();

  /// Deletes everything. The foreign keys cascade from the projects to
  /// their decks, cards, options, statistics, sessions and attempts.
  Future<void> deleteAll() async {
    await delete(projects).go();
    await delete(settings).go();
  }

  Future<void> upsertProject(ProjectsCompanion row) =>
      into(projects).insertOnConflictUpdate(row);

  Future<void> upsertDeck(DecksCompanion row) =>
      into(decks).insertOnConflictUpdate(row);

  Future<void> upsertCard(CardsCompanion row) =>
      into(cards).insertOnConflictUpdate(row);

  /// Replaces the options of [cardId] with [options].
  Future<void> replaceOptions(
    String cardId,
    List<CardOptionsCompanion> options,
  ) async {
    await (delete(cardOptions)..where((o) => o.cardId.equals(cardId))).go();
    for (final option in options) {
      await into(cardOptions).insertOnConflictUpdate(option);
    }
  }

  /// Inserts the row unless one with its key already exists.
  Future<void> addSession(StudySessionsCompanion row) =>
      into(studySessions).insert(row, mode: InsertMode.insertOrIgnore);

  Future<void> addSessionDeck(SessionDecksCompanion row) =>
      into(sessionDecks).insert(row, mode: InsertMode.insertOrIgnore);

  Future<void> addAttempt(AttemptsCompanion row) =>
      into(attempts).insert(row, mode: InsertMode.insertOrIgnore);

  Future<void> addCardStats(CardStatsCompanion row) =>
      into(cardStats).insert(row, mode: InsertMode.insertOrIgnore);

  Future<void> addSetting(SettingsCompanion row) =>
      into(settings).insert(row, mode: InsertMode.insertOrIgnore);
}
