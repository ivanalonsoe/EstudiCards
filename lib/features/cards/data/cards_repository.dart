// The entry point the app uses to read and save cards (see
// `ProjectsRepository` for what a repository does).
import 'package:drift/drift.dart';
import 'package:estudicards/core/clock.dart';
import 'package:estudicards/core/db/app_database.dart';
import 'package:estudicards/core/files/image_files.dart';
import 'package:estudicards/core/ids.dart';
import 'package:estudicards/features/cards/data/cards_dao.dart';
import 'package:estudicards/features/cards/domain/card_input.dart';
import 'package:estudicards/features/cards/domain/card_list.dart';
import 'package:estudicards/features/cards/domain/flashcard.dart';

class CardsRepository {
  new(this._dao, this._clock, this._images);

  final CardsDao _dao;
  final Clock _clock;
  final ImageFiles _images;

  /// Saves a new card in [deckId] with its options, and marks the deck and
  /// its project as used (R 7.7). Throws [InvalidCardException] if [input]
  /// is not valid.
  Future<Flashcard> create(String deckId, CardInput input) async {
    _checkValid(input);
    final id = newId();
    final now = _clock.now();
    // A transaction groups several writes: either all of them are saved or,
    // if one fails, none is. A card is never left without its options.
    await _dao.transaction(() async {
      await _dao.insertCard(
        _fields(
          input,
          now,
        ).copyWith(id: Value(id), deckId: Value(deckId), createdAt: Value(now)),
      );
      await _saveOptions(id, input);
      await _dao.markDeckAndProjectUsed(deckId, now);
    });
    return (await getById(id))!;
  }

  /// Replaces what the user edits (P06). The statistics and attempts stay
  /// (US-11 AC1). Options keep their ID when the input gives it, so past
  /// attempts still point at them. Throws [InvalidCardException] if [input]
  /// is not valid.
  Future<Flashcard> update(String id, CardInput input) async {
    _checkValid(input);
    await _dao.transaction(() async {
      final changed = await _dao.updateCard(id, _fields(input, _clock.now()));
      if (changed == 0) throw StateError('No card with id $id');
      await _saveOptions(id, input);
    });
    return (await getById(id))!;
  }

  Future<Flashcard?> getById(String id) async {
    final row = await _dao.findById(id);
    if (row == null) return null;
    return _toFlashcard(row, await _dao.optionsOf([id]));
  }

  /// Deletes the card for good, with its options, statistics and attempts,
  /// and then its images (US-11 AC2). Cards do not go to the trash.
  Future<void> delete(String id) async {
    final images = await _dao.transaction(() async {
      final row = await _dao.findById(id);
      await _dao.deleteCard(id);
      return [?row?.questionImage, ?row?.answerImage];
    });
    // After the transaction, as in the trash: if the database write fails,
    // no image is lost.
    await _images.delete(images);
  }

  /// A deck's cards with their results, filtered by [query] and sorted by
  /// [sort] (P05, US-12), read again whenever cards change.
  ///
  /// `async*` makes a stream function: each `yield` emits one value.
  Stream<List<CardSummary>> watchCards(
    String deckId, {
    String query = '',
    CardSort sort = CardSort.newest,
  }) async* {
    yield await _readCards(deckId, query, sort);
    await for (final _ in _dao.watchChanges()) {
      yield await _readCards(deckId, query, sort);
    }
  }

  Future<List<CardSummary>> _readCards(
    String deckId,
    String query,
    CardSort sort,
  ) async {
    final rows = await _dao.cardsWithResults(deckId);
    final options = await _dao.optionsOf([for (final row in rows) row.card.id]);
    final summaries = [
      for (final row in rows)
        CardSummary(
          card: _toFlashcard(row.card, [
            for (final option in options)
              if (option.cardId == row.card.id) option,
          ]),
          correctCount: row.correctCount,
          wrongCount: row.wrongCount,
        ),
    ];
    return sortCards(
      summaries.where((s) => matchesCardSearch(s.card, query)),
      sort,
    );
  }

  /// The columns the user edits. Each type stores only its own fields: a
  /// simple card has no explanation or "allow multiple", and a test card
  /// has no answer. Example and notes are kept for both (SPEC §4.2).
  static CardsCompanion _fields(CardInput input, DateTime now) {
    final isTest = input.type == CardType.test;
    return CardsCompanion(
      type: Value(input.type.name),
      question: Value(input.trimmedQuestion),
      questionImage: Value(input.questionImage),
      answer: Value(isTest ? null : input.trimmedAnswer),
      answerImage: Value(input.answerImage),
      explanation: Value(isTest ? input.trimmedExplanation : null),
      allowMultiple: Value(isTest && input.allowMultiple),
      example: Value(input.trimmedExample),
      notes: Value(input.trimmedNotes),
      updatedAt: Value(now),
    );
  }

  /// Saves the options of a test card in the order given, keeping the IDs
  /// it brings, and deletes the stored options that are no longer there. A
  /// simple card ends up with no options.
  Future<void> _saveOptions(String cardId, CardInput input) async {
    final options = input.type == CardType.test
        ? input.filledOptions
        : const <CardOptionInput>[];
    final stored = {
      for (final o in await _dao.optionsOf([cardId])) o.id,
    };
    final keptIds = <String>[];
    for (final (position, option) in options.indexed) {
      // An ID that is not one of this card's options is treated as new.
      final id = stored.contains(option.id) ? option.id! : newId();
      keptIds.add(id);
      await _dao.saveOption(
        CardOptionsCompanion.insert(
          id: id,
          cardId: cardId,
          optionText: option.text,
          isCorrect: option.isCorrect,
          position: position,
        ),
      );
    }
    await _dao.deleteOtherOptions(cardId, keptIds);
  }

  static void _checkValid(CardInput input) {
    final errors = input.validate();
    if (errors.isNotEmpty) throw InvalidCardException(errors);
  }

  static Flashcard _toFlashcard(CardRow row, List<CardOptionRow> options) =>
      Flashcard(
        id: row.id,
        deckId: row.deckId,
        type: CardType.fromStored(row.type),
        question: row.question,
        questionImage: row.questionImage,
        answer: row.answer,
        answerImage: row.answerImage,
        explanation: row.explanation,
        allowMultiple: row.allowMultiple,
        example: row.example,
        notes: row.notes,
        options: [
          for (final option in options)
            CardOption(
              id: option.id,
              text: option.optionText,
              isCorrect: option.isCorrect,
              position: option.position,
            ),
        ],
        createdAt: row.createdAt,
        updatedAt: row.updatedAt,
      );
}
