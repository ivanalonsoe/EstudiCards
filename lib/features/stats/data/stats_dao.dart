// Drift queries for statistics (see `ProjectsDao` for what a DAO is). The
// numbers are counted by SQLite, so no attempt is loaded into Dart.
import 'package:drift/drift.dart';
import 'package:estudicards/core/db/app_database.dart';

part 'stats_dao.g.dart';

@DriftAccessor(tables: [Attempts, Cards, Decks, Projects, Settings])
class StatsDao extends DatabaseAccessor<AppDatabase> with _$StatsDaoMixin {
  new(super.attachedDatabase);

  /// The local days (`YYYY-MM-DD`) with at least one counted answer, in no
  /// particular order.
  Future<List<String>> activeDays() {
    final query = selectOnly(attempts, distinct: true)
      ..addColumns([attempts.localDay])
      ..join(_cardDeckProject)
      ..where(_counted & attempts.localDay.isNotNull());
    return query.map((row) => row.read(attempts.localDay)!).get();
  }

  /// How many counted answers were given on the local day [day]
  /// (`YYYY-MM-DD`).
  Future<int> answeredOn(String day) {
    final count = attempts.id.count();
    final query = selectOnly(attempts)
      ..addColumns([count])
      ..join(_cardDeckProject)
      ..where(_counted & attempts.localDay.equals(day));
    return query.map((row) => row.read(count)!).getSingle();
  }

  Future<String?> readSetting(String key) async {
    final row = await (select(
      settings,
    )..where((s) => s.key.equals(key))).getSingleOrNull();
    return row?.value;
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
