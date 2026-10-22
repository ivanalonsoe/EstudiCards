// Drift queries for statistics (see `ProjectsDao` for what a DAO is). The
// numbers are counted by SQLite, so no attempt is loaded into Dart.
import 'package:drift/drift.dart';
import 'package:estudicards/core/db/app_database.dart';

part 'stats_dao.g.dart';

@DriftAccessor(
  tables: [
    Attempts,
    Cards,
    CardStats,
    Decks,
    Projects,
    SessionDecks,
    Settings,
    StudySessions,
  ],
)
class StatsDao extends DatabaseAccessor<AppDatabase> with _$StatsDaoMixin {
  new(super.attachedDatabase);

  /// Correct and wrong answers per local day from [from] to [to] (both
  /// included), of [projectId] or of every project when null. Days without
  /// answers are missing. SQLite groups and counts the attempts.
  Future<List<({String day, int correct, int wrong})>> answersPerDay(
    String from,
    String to, {
    String? projectId,
  }) {
    final correct = attempts.id.count(
      filter: attempts.result.equals('correct'),
    );
    final wrong = attempts.id.count(filter: attempts.result.equals('wrong'));
    final query = selectOnly(attempts)
      ..addColumns([attempts.localDay, correct, wrong])
      ..join(_cardDeckProject)
      ..where(_counted & attempts.localDay.isBetweenValues(from, to))
      ..groupBy([attempts.localDay]);
    if (projectId != null) query.where(projects.id.equals(projectId));
    return query
        .map(
          (row) => (
            day: row.read(attempts.localDay)!,
            correct: row.read(correct)!,
            wrong: row.read(wrong)!,
          ),
        )
        .get();
  }

  /// The [limit] cards of [projectId] with the most wrong answers, both
  /// directions added up from `card_stats`; ties by question. Cards never
  /// missed and decks in the trash are left out.
  Future<List<({String cardId, String deckId, String question, int wrong})>>
  mostMissed(String projectId, {required int limit}) {
    final wrong = cardStats.wrongCount.sum();
    final query =
        selectOnly(cardStats).join([
            innerJoin(
              cards,
              cards.id.equalsExp(cardStats.cardId),
              useColumns: false,
            ),
            innerJoin(
              decks,
              decks.id.equalsExp(cards.deckId),
              useColumns: false,
            ),
          ])
          ..addColumns([cards.id, cards.deckId, cards.question, wrong])
          ..where(decks.projectId.equals(projectId) & decks.deletedAt.isNull())
          ..groupBy([cards.id], having: wrong.isBiggerThanValue(0))
          ..orderBy([
            OrderingTerm.desc(wrong),
            OrderingTerm.asc(cards.question),
          ])
          ..limit(limit);
    return query
        .map(
          (row) => (
            cardId: row.read(cards.id)!,
            deckId: row.read(cards.deckId)!,
            question: row.read(cards.question)!,
            wrong: row.read(wrong)!,
          ),
        )
        .get();
  }

  /// The [limit] latest sessions of [projectId] that have ended, newest
  /// first.
  Future<List<StudySessionRow>> endedSessions(
    String projectId, {
    required int limit,
  }) =>
      (select(studySessions)
            ..where(
              (s) =>
                  s.projectId.equals(projectId) &
                  s.status.equals('in_progress').not(),
            )
            ..orderBy([(s) => OrderingTerm.desc(s.startedAt)])
            ..limit(limit))
          .get();

  /// The decks studied in each of [sessionIds], as (session ID, deck name).
  Future<List<({String sessionId, String deckName})>> deckNamesOf(
    Iterable<String> sessionIds,
  ) {
    final query =
        select(sessionDecks)
            .join([innerJoin(decks, decks.id.equalsExp(sessionDecks.deckId))])
          ..where(sessionDecks.sessionId.isIn(sessionIds))
          ..orderBy([OrderingTerm.asc(decks.createdAt)]);
    return query
        .map(
          (row) => (
            sessionId: row.readTable(sessionDecks).sessionId,
            deckName: row.readTable(decks).name,
          ),
        )
        .get();
  }

  /// The local days (`YYYY-MM-DD`) with at least one counted answer, in no
  /// particular order.
  Future<List<String>> activeDays() {
    final query = selectOnly(attempts, distinct: true)
      ..addColumns([attempts.localDay])
      ..join(_cardDeckProject)
      ..where(_counted & attempts.localDay.isNotNull());
    return query.map((row) => row.read(attempts.localDay)!).get();
  }

  /// How many counted answers were given from the local day [from] to
  /// [to], both included (`YYYY-MM-DD`; this text sorts like the dates).
  Future<int> answeredBetween(String from, String to) {
    final count = attempts.id.count();
    final query = selectOnly(attempts)
      ..addColumns([count])
      ..join(_cardDeckProject)
      ..where(_counted & attempts.localDay.isBetweenValues(from, to));
    return query.map((row) => row.read(count)!).getSingle();
  }

  /// Deletes the attempts and `card_stats` rows of the cards that match
  /// [where] (R 7.4, "Reiniciar estadísticas"), in one transaction. The
  /// cards are picked in SQL: a subquery of their IDs, joined to their deck
  /// so a project can choose them. Sessions are not touched, so they keep
  /// their totals.
  Future<void> deleteStatistics(Expression<bool> where) {
    final cardIds =
        selectOnly(cards).join([
            innerJoin(
              decks,
              decks.id.equalsExp(cards.deckId),
              useColumns: false,
            ),
          ])
          ..addColumns([cards.id])
          ..where(where);
    return transaction(() async {
      await (delete(attempts)..where((a) => a.cardId.isInQuery(cardIds))).go();
      await (delete(cardStats)..where((s) => s.cardId.isInQuery(cardIds))).go();
    });
  }

  /// Emits every time something the statistics count changes: an answer is
  /// saved, a session ends, cards are edited or deleted, or a deck or
  /// project goes to or leaves the trash.
  Stream<void> watchChanges() => attachedDatabase.tableUpdates(
    TableUpdateQuery.onAllTables([
      attempts,
      cardStats,
      cards,
      decks,
      projects,
      studySessions,
      // The daily goal, set in Settings.
      settings,
    ]),
  );

  /// The setting stored under [key], as key → value; empty if it was never
  /// stored (a key stored with no value is not the same, see
  /// `dailyGoalFromStored`).
  Future<Map<String, String?>> readSetting(String key) async {
    final row = await (select(
      settings,
    )..where((s) => s.key.equals(key))).getSingleOrNull();
    return {if (row != null) row.key: row.value};
  }

  /// Joins each attempt to its card, deck and project, to leave out those
  /// in the trash. `useColumns: false` because only the filter is needed.
  List<Join<HasResultSet, dynamic>> get _cardDeckProject => [
    innerJoin(cards, cards.id.equalsExp(attempts.cardId), useColumns: false),
    innerJoin(decks, decks.id.equalsExp(cards.deckId), useColumns: false),
    innerJoin(
      projects,
      projects.id.equalsExp(decks.projectId),
      useColumns: false,
    ),
  ];

  /// The answers statistics count: first attempts, correct or wrong (R 7.6,
  /// assumption 3), of decks and projects not in the trash (R 7.1).
  Expression<bool> get _counted =>
      attempts.isFirstAttempt.equals(true) &
      attempts.result.isIn(['correct', 'wrong']) &
      decks.deletedAt.isNull() &
      projects.deletedAt.isNull();
}
