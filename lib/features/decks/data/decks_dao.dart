// Drift queries for decks (see `ProjectsDao` for what a DAO is).
import 'package:drift/drift.dart';
import 'package:estudicards/core/db/app_database.dart';

part 'decks_dao.g.dart';

/// A deck row together with its project's colour, which a deck without a
/// colour of its own inherits.
typedef DeckWithProjectColor = ({DeckRow deck, String projectColor});

/// A deck with its project's colour and its number of cards.
typedef DeckWithCardCount = ({DeckWithProjectColor deck, int cardCount});

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
    final query = _withProjectColor()
      ..addColumns([cardCount])
      ..where(decks.projectId.equals(projectId) & decks.deletedAt.isNull())
      ..orderBy([
        OrderingTerm.asc(decks.createdAt),
        OrderingTerm.asc(decks.name),
      ]);
    return query.watch().map(
      (rows) => [
        for (final row in rows)
          (deck: _read(row), cardCount: row.read(cardCount)!),
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
