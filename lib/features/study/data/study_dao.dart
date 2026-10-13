// Drift queries for study sessions and their attempts (see `ProjectsDao`
// for what a DAO is).
import 'package:drift/drift.dart';
import 'package:estudicards/core/db/app_database.dart';

part 'study_dao.g.dart';

@DriftAccessor(
  tables: [
    StudySessions,
    SessionDecks,
    Attempts,
    Decks,
    Projects,
    Cards,
    CardOptions,
  ],
)
class StudyDao extends DatabaseAccessor<AppDatabase> with _$StudyDaoMixin {
  new(super.attachedDatabase);

  Future<void> insertSession(StudySessionsCompanion session) =>
      into(studySessions).insert(session);

  Future<void> insertSessionDeck(SessionDecksCompanion sessionDeck) =>
      into(sessionDecks).insert(sessionDeck);

  Future<void> insertAttempt(AttemptsCompanion attempt) =>
      into(attempts).insert(attempt);

  Future<void> updateSession(String id, StudySessionsCompanion changes) =>
      (update(studySessions)..where((s) => s.id.equals(id))).write(changes);

  Future<StudySessionRow?> findSession(String id) =>
      (select(studySessions)..where((s) => s.id.equals(id))).getSingleOrNull();

  /// A session's attempts in the order they were saved. SQLite numbers the
  /// rows it inserts (`rowid`), so sorting by it keeps that order even for
  /// attempts saved at the same time.
  Future<List<AttemptRow>> attemptsOf(String sessionId) =>
      (select(attempts)
            ..where((a) => a.sessionId.equals(sessionId))
            ..orderBy([(a) => OrderingTerm.asc(a.rowId)]))
          .get();

  Future<ProjectRow?> findProject(String id) =>
      (select(projects)..where((p) => p.id.equals(id))).getSingleOrNull();

  /// The decks of a session in the order P03 lists them: oldest first,
  /// then by name.
  Future<List<DeckRow>> decksOf(String sessionId) {
    final query =
        select(decks).join([
            innerJoin(sessionDecks, sessionDecks.deckId.equalsExp(decks.id)),
          ])
          ..where(sessionDecks.sessionId.equals(sessionId))
          ..orderBy([
            OrderingTerm.asc(decks.createdAt),
            OrderingTerm.asc(decks.name),
          ]);
    return query.map((row) => row.readTable(decks)).get();
  }

  Future<List<CardRow>> cardsByIds(Iterable<String> ids) =>
      (select(cards)..where((c) => c.id.isIn(ids))).get();

  /// The options of these cards, in their editing order.
  Future<List<CardOptionRow>> optionsOf(Iterable<String> cardIds) =>
      (select(cardOptions)
            ..where((o) => o.cardId.isIn(cardIds))
            ..orderBy([(o) => OrderingTerm.asc(o.position)]))
          .get();

  /// Records that the project and these decks were studied now (R 7.7).
  Future<void> markUsed(
    String projectId,
    Iterable<String> deckIds,
    DateTime now,
  ) async {
    await (update(projects)..where((p) => p.id.equals(projectId))).write(
      ProjectsCompanion(lastUsedAt: Value(now)),
    );
    await (update(decks)..where((d) => d.id.isIn(deckIds))).write(
      DecksCompanion(lastUsedAt: Value(now)),
    );
  }
}
