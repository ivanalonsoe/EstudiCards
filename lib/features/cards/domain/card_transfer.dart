// What changes for some cards when they are moved or copied to a deck of
// another type or with other languages (US-07 AC4). The card itself does
// not change: the type and the languages belong to the deck, so the app
// only warns before doing it.
import 'package:estudicards/features/cards/domain/flashcard.dart';
import 'package:estudicards/features/decks/domain/deck.dart';

/// Why moving or copying cards deserves a warning. `sealed` means these
/// three classes are the only kinds, so a `switch` must handle each one.
sealed class TransferWarning {
  const new();
}

/// To a general deck: example and notes are hidden (not deleted), and the
/// cards have no voice or reverse mode.
final class ToGeneralDeck extends TransferWarning {
  const new({required this.cardsWithLanguageFields});

  /// How many of the cards have an example or notes.
  final int cardsWithLanguageFields;
}

/// To a language deck: the cards get voice and reverse mode with its
/// languages.
final class ToLanguageDeck extends TransferWarning {
  const new({required this.sourceLang, required this.targetLang});

  final String? sourceLang;
  final String? targetLang;
}

/// Between language decks with other languages: the voice reads the cards
/// in the new ones.
final class LanguagesChange extends TransferWarning {
  const new({
    required this.fromSourceLang,
    required this.fromTargetLang,
    required this.toSourceLang,
    required this.toTargetLang,
  });

  final String? fromSourceLang;
  final String? fromTargetLang;
  final String? toSourceLang;
  final String? toTargetLang;
}

/// The warning for moving or copying [cards] [from] one deck [to] another,
/// or null when both decks have the same type (and the same languages).
TransferWarning? transferWarning({
  required Deck from,
  required Deck to,
  required Iterable<Flashcard> cards,
}) {
  switch ((from.isLanguage, to.isLanguage)) {
    case (true, false):
      return ToGeneralDeck(
        cardsWithLanguageFields: cards
            .where((card) => card.example != null || card.notes != null)
            .length,
      );
    case (false, true):
      return ToLanguageDeck(
        sourceLang: to.sourceLang,
        targetLang: to.targetLang,
      );
    case (true, true)
        when from.sourceLang != to.sourceLang ||
            from.targetLang != to.targetLang:
      return LanguagesChange(
        fromSourceLang: from.sourceLang,
        fromTargetLang: from.targetLang,
        toSourceLang: to.sourceLang,
        toTargetLang: to.targetLang,
      );
    default:
      return null;
  }
}
