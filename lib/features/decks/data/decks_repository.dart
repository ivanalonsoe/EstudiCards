// The entry point the app uses to read and save decks (see
// `ProjectsRepository` for what a repository does).
import 'package:drift/drift.dart';
import 'package:estudicards/core/clock.dart';
import 'package:estudicards/core/db/app_database.dart';
import 'package:estudicards/core/ids.dart';
import 'package:estudicards/features/decks/data/decks_dao.dart';
import 'package:estudicards/features/decks/domain/deck.dart';
import 'package:estudicards/features/decks/domain/deck_input.dart';
import 'package:estudicards/features/decks/domain/deck_summary.dart';
import 'package:estudicards/features/stats/domain/metrics.dart';

class DecksRepository {
  new(this._dao, this._clock);

  final DecksDao _dao;
  final Clock _clock;

  /// Throws [InvalidDeckException] if [input] is not valid.
  Future<Deck> create(String projectId, DeckInput input) async {
    _checkValid(input);
    final id = newId();
    final now = _clock.now();
    final isLanguage = input.type == DeckType.language;
    await _dao.insertDeck(
      DecksCompanion.insert(
        id: id,
        projectId: projectId,
        name: input.trimmedName,
        description: Value(input.trimmedDescription),
        color: Value(input.color),
        type: Value(input.type.name),
        sourceLang: Value(isLanguage ? input.sourceLang : null),
        targetLang: Value(isLanguage ? input.targetLang : null),
        createdAt: now,
        updatedAt: now,
      ),
    );
    // Read it back to get the project's colour if the deck inherits it.
    return (await getById(id))!;
  }

  /// Replaces the fields the user edits (P04). A null colour makes the deck
  /// inherit its project's colour again. Throws [InvalidDeckException] if
  /// [input] is not valid.
  ///
  /// A general deck keeps the languages already stored: switching from
  /// "Idioma" to "General" hides them but does not delete them (US-06 AC3).
  Future<Deck> update(String id, DeckInput input) async {
    _checkValid(input);
    final isLanguage = input.type == DeckType.language;
    await _dao.updateDeck(
      id,
      DecksCompanion(
        name: Value(input.trimmedName),
        description: Value(input.trimmedDescription),
        color: Value(input.color),
        type: Value(input.type.name),
        // `Value.absent()` leaves the column as it is.
        sourceLang: isLanguage ? Value(input.sourceLang) : const .absent(),
        targetLang: isLanguage ? Value(input.targetLang) : const .absent(),
        updatedAt: Value(_clock.now()),
      ),
    );
    final deck = await getById(id);
    if (deck == null) throw StateError('No deck with id $id');
    return deck;
  }

  Future<Deck?> getById(String id) async {
    final row = await _dao.findById(id);
    return row == null ? null : _toDeck(row);
  }

  /// A project's decks, not in the trash, with their number of cards;
  /// updated whenever they change.
  Stream<List<DeckSummary>> watchDecks(String projectId) => _dao
      .watchActiveByProject(projectId)
      .map(
        (rows) => [
          for (final row in rows)
            DeckSummary(
              deck: _toDeck(row.deck),
              cardCount: row.cardCount,
              answers: AnswerCounts(
                correct: row.correctCount,
                wrong: row.wrongCount,
              ),
              errorCount: row.errorCount,
            ),
        ],
      );

  /// Records that the deck was opened or studied (R 7.7).
  Future<void> markUsed(String id) =>
      _dao.updateDeck(id, DecksCompanion(lastUsedAt: Value(_clock.now())));

  static void _checkValid(DeckInput input) {
    final errors = input.validate();
    if (errors.isNotEmpty) throw InvalidDeckException(errors);
  }

  static Deck _toDeck(DeckWithProjectColor row) => Deck(
    id: row.deck.id,
    projectId: row.deck.projectId,
    name: row.deck.name,
    description: row.deck.description,
    color: row.deck.color ?? row.projectColor,
    inheritsColor: row.deck.color == null,
    type: DeckType.fromStored(row.deck.type),
    sourceLang: row.deck.sourceLang,
    targetLang: row.deck.targetLang,
    lastUsedAt: row.deck.lastUsedAt,
    createdAt: row.deck.createdAt,
    updatedAt: row.deck.updatedAt,
  );
}
