// Builds the EstudiCards files (SPEC §8.2) from the database. Turning a
// file into rows is the import engine's job (T5.3).
import 'package:estudicards/core/app_version.dart';
import 'package:estudicards/core/clock.dart';
import 'package:estudicards/core/db/app_database.dart';
import 'package:estudicards/core/files/image_files.dart';
import 'package:estudicards/features/cards/domain/flashcard.dart';
import 'package:estudicards/features/decks/domain/deck.dart';
import 'package:estudicards/features/import_export/data/exchange_dao.dart';
import 'package:estudicards/features/import_export/domain/exchange_document.dart';

class ExchangeRepository {
  new(this._dao, this._clock, this._images);

  final ExchangeDao _dao;
  final Clock _clock;
  final ImageFiles _images;

  /// A deck with its cards, as shared (US-26): no statistics and no dates.
  /// Its images go inside the file. Throws [StateError] if there is no
  /// deck with [deckId].
  Future<DeckDocument> exportDeck(String deckId) async {
    final row = await _dao.deckById(deckId);
    if (row == null) throw StateError('No deck with id $deckId');
    return DeckDocument(
      exportedAt: _clock.now(),
      appVersion: appVersion,
      deck: await _deck(row),
    );
  }

  /// A project with its decks and cards, as shared (US-26): no statistics,
  /// no dates and no favourite or archived state. Decks in the trash are
  /// left out. Throws [StateError] if there is no project with
  /// [projectId].
  Future<ProjectDocument> exportProject(String projectId) async {
    final row = await _dao.projectById(projectId);
    if (row == null) throw StateError('No project with id $projectId');
    return ProjectDocument(
      exportedAt: _clock.now(),
      appVersion: appVersion,
      project: ExchangeProject(
        id: row.id,
        name: row.name,
        description: row.description,
        color: row.color,
        icon: row.icon,
        decks: [
          for (final deck in await _dao.activeDecksOf(projectId))
            await _deck(deck),
        ],
      ),
    );
  }

  Future<ExchangeDeck> _deck(DeckRow row) async {
    final cards = await _dao.cardsOf([row.id]);
    final options = await _dao.optionsOf([for (final card in cards) card.id]);
    return ExchangeDeck(
      id: row.id,
      name: row.name,
      description: row.description,
      color: row.color,
      type: DeckType.fromStored(row.type),
      sourceLang: row.sourceLang,
      targetLang: row.targetLang,
      cards: [
        for (final card in cards)
          await _card(card, [
            for (final option in options)
              if (option.cardId == card.id) option,
          ]),
      ],
    );
  }

  Future<ExchangeCard> _card(CardRow row, List<CardOptionRow> options) async =>
      ExchangeCard(
        id: row.id,
        type: CardType.fromStored(row.type),
        question: row.question,
        answer: row.answer,
        explanation: row.explanation,
        allowMultiple: row.allowMultiple,
        example: row.example,
        notes: row.notes,
        questionImage: await _image(row.questionImage),
        answerImage: await _image(row.answerImage),
        options: [
          for (final option in options)
            ExchangeOption(
              id: option.id,
              text: option.optionText,
              isCorrect: option.isCorrect,
            ),
        ],
      );

  /// The stored image, or null if the card has none or its file is gone.
  Future<ExchangeImage?> _image(String? relativePath) async {
    if (relativePath == null) return null;
    final bytes = await _images.read(relativePath);
    return bytes == null ? null : ExchangeImage(bytes);
  }
}
