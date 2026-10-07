import 'package:estudicards/features/decks/domain/deck.dart';

/// A deck as the project screen lists it: the deck plus its number of
/// cards (P03).
class DeckSummary {
  const new({required this.deck, required this.cardCount});

  final Deck deck;
  final int cardCount;
}
