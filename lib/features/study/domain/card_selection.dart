// Which cards enter a study session and in what order (R 7.2). Pure Dart:
// the repository reads the candidates from the database and these
// functions only decide. All randomness comes from the `Random` passed in,
// so a test with a seeded one always gets the same result.
import 'dart:math';

import 'package:estudicards/features/cards/domain/flashcard.dart';
import 'package:estudicards/features/study/domain/study_options.dart';

/// What selection needs from a card's `card_stats` row in one direction.
class DirectionStats {
  const new({this.inErrorList = false, this.studied = false});

  final bool inErrorList;

  /// True once the card has a correct or wrong first attempt in this
  /// direction. Unanswered attempts do not count (SPEC §13.2, assumption 3).
  final bool studied;
}

/// A card that could enter a session, with what the rules need to know
/// about its deck and its results.
class StudyCandidate {
  const new({
    required this.card,
    required this.isLanguageDeck,
    this.isDeckInTrash = false,
    this.normalStats = const DirectionStats(),
    this.reverseStats = const DirectionStats(),
  });

  final Flashcard card;
  final bool isLanguageDeck;
  final bool isDeckInTrash;
  final DirectionStats normalStats;
  final DirectionStats reverseStats;
}

/// A card chosen for the session, with the direction it is studied in.
class SelectedCard {
  const new({required this.card, required this.direction});

  final Flashcard card;
  final StudyDirection direction;
}

/// The direction [candidate] is studied and recorded in, in a session going
/// in [sessionDirection]. Reverse only applies to simple cards of language
/// decks; every other card goes in the normal direction (R 7.3).
StudyDirection directionFor(
  StudyCandidate candidate,
  StudyDirection sessionDirection,
) {
  final canGoInReverse =
      candidate.isLanguageDeck && candidate.card.type == CardType.simple;
  return canGoInReverse ? sessionDirection : StudyDirection.normal;
}

/// The cards a session can use (R 7.2, steps 1 and 2): no card twice, none
/// from a deck in the trash and, in "Solo errores", only the cards in errors
/// in the direction each one is studied in. P08 shows how many there are.
List<StudyCandidate> availableCards(
  Iterable<StudyCandidate> candidates, {
  required StudyMode mode,
  required StudyDirection direction,
}) {
  final seenIds = <String>{};
  final available = <StudyCandidate>[];
  for (final candidate in candidates) {
    if (candidate.isDeckInTrash) continue;
    if (mode == StudyMode.errors &&
        !_statsFor(candidate, direction).inErrorList) {
      continue;
    }
    // `add` returns false when the ID was already in the set.
    if (!seenIds.add(candidate.card.id)) continue;
    available.add(candidate);
  }
  return available;
}

/// The session's queue (R 7.2, steps 3 and 4): [count] cards (all of them
/// when null or when fewer are available), chosen at random and shuffled.
///
/// With [prioritizeFailed], a card in errors is 3 times as likely to be
/// chosen as one already studied, and a card never studied twice as likely.
List<SelectedCard> selectCards(
  Iterable<StudyCandidate> candidates, {
  required StudyMode mode,
  required StudyDirection direction,
  required Random random,
  int? count,
  bool prioritizeFailed = false,
}) {
  final available = availableCards(
    candidates,
    mode: mode,
    direction: direction,
  );
  final wanted = min(count ?? available.length, available.length);

  final chosen = prioritizeFailed
      ? _weightedSample(available, wanted, direction, random)
      : _uniformSample(available, wanted, random);

  // The weighted draw tends to pick the heaviest cards first, so the queue is
  // always shuffled at the end: missed cards are not all at the start.
  // `shuffle` is the Fisher–Yates algorithm.
  final queue = chosen..shuffle(random);
  return [
    for (final candidate in queue)
      SelectedCard(
        card: candidate.card,
        direction: directionFor(candidate, direction),
      ),
  ];
}

/// [options] in a new random order (R 7.2, step 5). The card keeps its own
/// list in editing order; the session shuffles a copy each time it shows
/// the card.
List<CardOption> shuffleOptions(List<CardOption> options, Random random) =>
    options.toList()..shuffle(random);

/// The stats of [candidate] in the direction it is studied in.
DirectionStats _statsFor(
  StudyCandidate candidate,
  StudyDirection sessionDirection,
) => switch (directionFor(candidate, sessionDirection)) {
  StudyDirection.normal => candidate.normalStats,
  StudyDirection.reverse => candidate.reverseStats,
};

/// "Priorizar las más falladas" (R 7.2): 3 if in errors, 2 if never studied
/// in that direction, 1 otherwise.
int _weight(StudyCandidate candidate, StudyDirection sessionDirection) {
  final stats = _statsFor(candidate, sessionDirection);
  if (stats.inErrorList) return 3;
  if (!stats.studied) return 2;
  return 1;
}

/// [count] cards from [pool], each one as likely as any other.
List<StudyCandidate> _uniformSample(
  List<StudyCandidate> pool,
  int count,
  Random random,
) => (pool.toList()..shuffle(random)).take(count).toList();

/// Draws [count] cards from [pool] without replacement, each draw with a
/// chance proportional to the card's weight: like a raffle where a card in
/// errors holds 3 tickets. A drawn card leaves the raffle with its tickets.
List<StudyCandidate> _weightedSample(
  List<StudyCandidate> pool,
  int count,
  StudyDirection sessionDirection,
  Random random,
) {
  final remaining = pool.toList();
  final weights = [
    for (final candidate in remaining) _weight(candidate, sessionDirection),
  ];
  var totalWeight = weights.fold(0, (sum, weight) => sum + weight);
  final chosen = <StudyCandidate>[];

  while (chosen.length < count) {
    // Pick a ticket, then walk the cards until reaching its owner.
    var ticket = random.nextInt(totalWeight);
    var index = 0;
    while (ticket >= weights[index]) {
      ticket -= weights[index];
      index++;
    }
    chosen.add(remaining.removeAt(index));
    totalWeight -= weights.removeAt(index);
  }
  return chosen;
}
