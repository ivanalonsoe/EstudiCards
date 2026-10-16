// Drift queries for decks (see `ProjectsDao` for what a DAO is).
import 'package:drift/drift.dart';
import 'package:estudicards/core/db/app_database.dart';

part 'decks_dao.g.dart';

/// A deck row together with its project's colour, which a deck without a
/// colour of its own inherits.
typedef DeckWithProjectColor = ({DeckRow deck, String projectColor});

/// A deck with its project's colour, its number of cards and the totals of
/// their statistics.
typedef DeckWithCardCount = ({
  DeckWithProjectColor deck,
  int cardCount,
  int correctCount,
  int wrongCount,
  int errorCount,
});

@DriftAccessor(tables: [Decks, Projects])
class DecksDao extends DatabaseAccessor<AppDatabase> with _$DecksDaoMixin {
  new(super.attachedDatabase);

  Future<void> insertDeck(DecksCompanion deck) => into(decks).insert(deck);

  /// Writes the given columns; returns how many rows changed (0 if there is
  /// no deck with that [id]).
  Future<int> updateDeck(String id, DecksCompanion changes) =>
      (update(decks)..where((d) => d.id.equals(id))).write(changes);

  Future<DeckWithProjectColor?> findById(String id) async {
    final query = _withProjectColor()..where(decks.id.equals(id));
    final row = await query.getSingleOrNull();
    return row == null ? null : _read(row);
  }

  /// A project's decks that are not in the trash, oldest first, each with
  /// its number of cards. Because the query joins `projects`, the stream
  /// also emits when the project's colour changes.
  Stream<List<DeckWithCardCount>> watchActiveByProject(String projectId) {
    final cards = attachedDatabase.cards;
    // A subquery counts each deck's cards (see `ProjectsDao.watchActive`).
    final cardCount = subqueryExpression<int>(
      selectOnly(cards)
        ..addColumns([countAll()])
        ..where(cards.deckId.equalsExp(decks.id)),
    );
    // The same over the `card_stats` rows of its cards (R 7.6).
    final stats = attachedDatabase.cardStats;
    Expression<T> overStats<T extends Object>(
      Expression<T> column, {
      Expression<bool>? filter,
    }) => subqueryExpression<T>(
      selectOnly(stats).join([
          innerJoin(cards, cards.id.equalsExp(stats.cardId), useColumns: false),
        ])
        ..addColumns([column])
        ..where(cards.deckId.equalsExp(decks.id))
        ..where(filter ?? const Constant(true)),
    );
    final correct = overStats(stats.correctCount.sum());
    final wrong = overStats(stats.wrongCount.sum());
    final errors = overStats(countAll(), filter: stats.inErrorList);

    final query = _withProjectColor()
      ..addColumns([cardCount, correct, wrong, errors])
      ..where(decks.projectId.equals(projectId) & decks.deletedAt.isNull())
      ..orderBy([
        OrderingTerm.asc(decks.createdAt),
        OrderingTerm.asc(decks.name),
      ]);
    return query.watch().map(
      (rows) => [
        for (final row in rows)
          (
            deck: _read(row),
            cardCount: row.read(cardCount)!,
            // `sum` is null when there are no statistics yet.
            correctCount: row.read(correct) ?? 0,
            wrongCount: row.read(wrong) ?? 0,
            errorCount: row.read(errors)!,
          ),
      ],
    );
  }

  /// A join reads two tables in one query: every deck row comes with the
  /// `color` column of the project it belongs to.
  JoinedSelectStatement<HasResultSet, dynamic> _withProjectColor() =>
      select(decks).join([
        innerJoin(
          projects,
          projects.id.equalsExp(decks.projectId),
          useColumns: false,
        ),
      ])..addColumns([projects.color]);

  DeckWithProjectColor _read(TypedResult row) =>
      (deck: row.readTable(decks), projectColor: row.read(projects.color)!);
}
