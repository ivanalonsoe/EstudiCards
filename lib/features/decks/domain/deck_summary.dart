import 'package:estudicards/features/decks/domain/deck.dart';
import 'package:estudicards/features/stats/domain/metrics.dart';

/// A deck as the project screen lists it: the deck plus its number of
/// cards, its answers and its pending errors (P03).
class DeckSummary {
  const new({
    required this.deck,
    required this.cardCount,
    this.answers = const AnswerCounts(),
    this.errorCount = 0,
  });

  final Deck deck;
  final int cardCount;

  /// First attempts of its cards, both directions (R 7.6).
  final AnswerCounts answers;

  /// (card, direction) pairs in the error list (R 7.6).
  final int errorCount;
}
