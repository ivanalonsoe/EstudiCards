// Imports cards from a file (SPEC §8.4): `preview` works out what will
// happen with `planImport`, and `commit` writes it in one transaction.
import 'package:drift/drift.dart';
import 'package:estudicards/core/clock.dart';
import 'package:estudicards/core/db/app_database.dart';
import 'package:estudicards/core/files/image_files.dart';
import 'package:estudicards/core/ids.dart';
import 'package:estudicards/features/cards/data/cards_repository.dart';
import 'package:estudicards/features/cards/domain/flashcard.dart';
import 'package:estudicards/features/import_export/data/import_dao.dart';
import 'package:estudicards/features/import_export/domain/exchange_document.dart';
import 'package:estudicards/features/import_export/domain/import_plan.dart';

/// What an import did, for the final summary (SPEC §8.4 rule 5).
class ImportResult {
  const new({
    required this.projectId,
    required this.deckIds,
    required this.added,
    required this.duplicates,
    required this.errors,
    this.imagesSkipped = 0,
  });

  final String projectId;

  /// The decks that received cards, in the plan's order.
  final List<String> deckIds;
  final int added;
  final int duplicates;
  final int errors;

  /// Images of the file that could not be stored; their cards were
  /// imported without them.
  final int imagesSkipped;
}

class ImportRepository {
  new(this._dao, this._clock, this._images);

  final ImportDao _dao;
  final Clock _clock;
  final ImageFiles _images;

  /// What importing [source] into [destination] will do (P07 step 3).
  /// Nothing is written.
  Future<ImportPlan> preview(
    ImportSource source,
    ImportDestination destination, {
    required String defaultDeckName,
  }) async {
    var deckCards = <Flashcard>[];
    var takenCardIds = <String>{};
    if (destination is ExistingDeckDestination) {
      final rows = await _dao.cardsOf(destination.deckId);
      final options = await _dao.optionsOf([for (final row in rows) row.id]);
      deckCards = [
        for (final row in rows)
          flashcardFromRows(row, [
            for (final option in options)
              if (option.cardId == row.id) option,
          ]),
      ];
      if (source case DeckFileSource(:final deck)) {
        takenCardIds = await _dao.existingCardIds([
          for (final card in deck.cards) card.id,
        ]);
      }
    }
    return planImport(
      source: source,
      destination: destination,
      defaultDeckName: defaultDeckName,
      deckCards: deckCards,
      takenCardIds: takenCardIds,
    );
  }

  /// Writes [plan]: everything or, if anything fails, nothing (rule 8).
  ///
  /// The images go first, to files with new names; they cannot be part of
  /// a database transaction, so if the transaction fails they are deleted
  /// again. A card whose image cannot be stored is imported without it.
  Future<ImportResult> commit(ImportPlan plan) async {
    final now = _clock.now();
    final storedImages = <String>[];
    var imagesSkipped = 0;
    Future<String?> store(ExchangeImage? image) async {
      if (image == null) return null;
      final path = await _images.saveImported(image.bytes);
      if (path == null) {
        imagesSkipped++;
      } else {
        storedImages.add(path);
      }
      return path;
    }

    try {
      final imagePaths = [
        for (final deck in plan.decks)
          [
            for (final card in deck.cards)
              (
                question: await store(card.questionImage),
                answer: await store(card.answerImage),
              ),
          ],
      ];
      final (projectId, deckIds) = await _dao.transaction(
        () => _write(plan, imagePaths, now),
      );
      return ImportResult(
        projectId: projectId,
        deckIds: deckIds,
        added: plan.newCards,
        duplicates: plan.duplicates.length,
        errors: plan.errors.length,
        imagesSkipped: imagesSkipped,
      );
    } catch (_) {
      await _images.delete(storedImages);
      rethrow;
    }
  }

  /// The database part of [commit]; it runs inside the transaction.
  /// Returns the project and the decks that received the cards.
  Future<(String, List<String>)> _write(
    ImportPlan plan,
    List<List<({String? question, String? answer})>> imagePaths,
    DateTime now,
  ) async {
    var projectId = plan.projectId;
    if (plan.project case final project?) {
      projectId = newId();
      await _dao.insertProject(
        ProjectsCompanion.insert(
          id: projectId,
          name: project.name.trim(),
          description: Value(_trimToNull(project.description)),
          color: project.color,
          icon: project.icon,
          lastUsedAt: Value(now),
          createdAt: now,
          updatedAt: now,
        ),
      );
    }

    final deckIds = <String>[];
    for (final (d, deck) in plan.decks.indexed) {
      var deckId = deck.existingId;
      if (deckId == null) {
        deckId = newId();
        await _dao.insertDeck(
          DecksCompanion.insert(
            id: deckId,
            projectId: projectId!,
            name: deck.name.trim(),
            description: Value(_trimToNull(deck.description)),
            color: Value(deck.color),
            type: Value(deck.settings.type.name),
            sourceLang: Value(deck.settings.sourceLang),
            targetLang: Value(deck.settings.targetLang),
            createdAt: now,
            updatedAt: now,
          ),
        );
      } else {
        projectId ??= (await _dao.deckById(deckId))!.projectId;
      }
      deckIds.add(deckId);

      for (final (c, card) in deck.cards.indexed) {
        final cardId = card.id ?? newId();
        final images = imagePaths[d][c];
        await _dao.insertCard(
          cardFields(card.input, now).copyWith(
            id: Value(cardId),
            deckId: Value(deckId),
            questionImage: Value(images.question),
            answerImage: Value(images.answer),
            createdAt: Value(now),
          ),
        );
        if (card.input.type == CardType.test) {
          for (final (position, option) in card.input.filledOptions.indexed) {
            await _dao.insertOption(
              CardOptionsCompanion.insert(
                id: newId(),
                cardId: cardId,
                optionText: option.text,
                isCorrect: option.isCorrect,
                position: position,
              ),
            );
          }
        }
      }
      // Adding cards counts as using the deck and its project (R 7.7).
      await _dao.markDeckAndProjectUsed(deckId, now);
    }
    return (projectId!, deckIds);
  }

  static String? _trimToNull(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
