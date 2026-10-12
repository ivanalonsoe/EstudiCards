import 'package:estudicards/core/random.dart';
import 'package:estudicards/features/cards/domain/flashcard.dart';
import 'package:estudicards/features/study/domain/card_selection.dart';
import 'package:estudicards/features/study/domain/study_options.dart';
import 'package:flutter_test/flutter_test.dart';

final _start = DateTime.utc(2026, 10, 12);

/// Card number [n] was created [n] minutes after [_start], so a list built
/// with increasing numbers is in creation order.
Flashcard card(int n, {CardType type = CardType.simple}) => Flashcard(
  id: 'card-$n',
  deckId: 'deck',
  type: type,
  question: 'Question $n',
  answer: type == CardType.simple ? 'Answer $n' : null,
  allowMultiple: false,
  options: type == CardType.test ? options(4) : const [],
  createdAt: _start.add(Duration(minutes: n)),
  updatedAt: _start.add(Duration(minutes: n)),
);

List<CardOption> options(int count) => [
  for (var i = 0; i < count; i++)
    CardOption(
      id: 'option-$i',
      text: 'Option $i',
      isCorrect: i == 0,
      position: i,
    ),
];

StudyCandidate candidate(
  int n, {
  CardType type = CardType.simple,
  bool isLanguageDeck = false,
  bool isDeckInTrash = false,
  DirectionStats normalStats = const DirectionStats(),
  DirectionStats reverseStats = const DirectionStats(),
}) => StudyCandidate(
  card: card(n, type: type),
  isLanguageDeck: isLanguageDeck,
  isDeckInTrash: isDeckInTrash,
  normalStats: normalStats,
  reverseStats: reverseStats,
);

/// [count] general-deck cards, in creation order.
List<StudyCandidate> candidates(int count) => [
  for (var n = 1; n <= count; n++) candidate(n),
];

const inErrors = DirectionStats(inErrorList: true, studied: true);
const studied = DirectionStats(studied: true);

List<String> ids(List<SelectedCard> selection) => [
  for (final selected in selection) selected.card.id,
];

void main() {
  test('with a fixed seed, the result is always the same', () {
    List<String> select() => ids(
      selectCards(
        candidates(30),
        mode: StudyMode.normal,
        direction: StudyDirection.normal,
        count: 10,
        random: createRandom(seed: 7),
      ),
    );

    expect(select(), select());
  });

  test('never returns duplicates or cards from deleted decks', () {
    final selection = selectCards(
      [
        ...candidates(5),
        candidate(3), // the same card again
        candidate(6, isDeckInTrash: true),
      ],
      mode: StudyMode.normal,
      direction: StudyDirection.normal,
      random: createRandom(seed: 1),
    );

    expect(
      ids(selection),
      unorderedEquals(['card-1', 'card-2', 'card-3', 'card-4', 'card-5']),
    );
  });

  test('returns as many cards as requested when there are enough', () {
    final selection = selectCards(
      candidates(30),
      mode: StudyMode.normal,
      direction: StudyDirection.normal,
      count: 10,
      random: createRandom(seed: 1),
    );

    expect(selection, hasLength(10));
    expect(ids(selection).toSet(), hasLength(10));
  });

  test('if more cards are requested than exist, it returns all of them', () {
    final selection = selectCards(
      candidates(5),
      mode: StudyMode.normal,
      direction: StudyDirection.normal,
      count: 20,
      random: createRandom(seed: 1),
    );

    expect(selection, hasLength(5));
  });

  group('"errors only"', () {
    // A language deck with a simple and a test card, and a general deck with
    // a simple card. Each card is in errors in one direction only.
    final pool = [
      candidate(1, isLanguageDeck: true, normalStats: inErrors),
      candidate(2, isLanguageDeck: true, reverseStats: inErrors),
      candidate(
        3,
        type: CardType.test,
        isLanguageDeck: true,
        normalStats: inErrors,
      ),
      candidate(
        4,
        type: CardType.test,
        isLanguageDeck: true,
        reverseStats: inErrors,
      ),
      candidate(5, normalStats: inErrors),
      candidate(6, reverseStats: inErrors),
      candidate(7, isLanguageDeck: true),
    ];

    test('in the normal direction, returns the cards in errors in the normal '
        'direction', () {
      final selection = selectCards(
        pool,
        mode: StudyMode.errors,
        direction: StudyDirection.normal,
        random: createRandom(seed: 1),
      );

      expect(ids(selection), unorderedEquals(['card-1', 'card-3', 'card-5']));
    });

    test('in reverse, uses the reverse errors only for simple cards of '
        'language decks; the rest go in the normal direction', () {
      final selection = selectCards(
        pool,
        mode: StudyMode.errors,
        direction: StudyDirection.reverse,
        random: createRandom(seed: 1),
      );

      expect(ids(selection), unorderedEquals(['card-2', 'card-3', 'card-5']));
    });

    test('with no cards in errors, there is nothing to study', () {
      expect(
        availableCards(
          candidates(5),
          mode: StudyMode.errors,
          direction: StudyDirection.normal,
        ),
        isEmpty,
      );
    });
  });

  test('each card carries the direction it is studied in', () {
    final selection = selectCards(
      [
        candidate(1, isLanguageDeck: true),
        candidate(2, type: CardType.test, isLanguageDeck: true),
        candidate(3),
      ],
      mode: StudyMode.normal,
      direction: StudyDirection.reverse,
      random: createRandom(seed: 1),
    );

    expect(
      {for (final selected in selection) selected.card.id: selected.direction},
      {
        'card-1': StudyDirection.reverse,
        'card-2': StudyDirection.normal,
        'card-3': StudyDirection.normal,
      },
    );
  });

  group('how often each card comes up', () {
    // Weight 3: in errors. Weight 2: never studied. Weight 1: studied, not in
    // errors (R 7.2).
    final pool = [
      candidate(1, normalStats: inErrors),
      candidate(2),
      candidate(3, normalStats: studied),
    ];

    Map<String, int> countPicks({required bool prioritizeFailed}) {
      final random = createRandom(seed: 3);
      final picks = {'card-1': 0, 'card-2': 0, 'card-3': 0};
      for (var i = 0; i < 10000; i++) {
        final selection = selectCards(
          pool,
          mode: StudyMode.normal,
          direction: StudyDirection.normal,
          count: 1,
          prioritizeFailed: prioritizeFailed,
          random: random,
        );
        picks.update(selection.single.card.id, (n) => n + 1);
      }
      return picks;
    }

    test('with "prioritise", over 10,000 selections, weight-3 cards come up '
        'about 3 times as often as weight-1 cards', () {
      final picks = countPicks(prioritizeFailed: true);

      expect(picks['card-1']! / picks['card-3']!, closeTo(3, 0.3));
      expect(picks['card-2']! / picks['card-3']!, closeTo(2, 0.2));
    });

    test('without "prioritise", every card comes up about as often', () {
      final picks = countPicks(prioritizeFailed: false);

      expect(picks['card-1']! / picks['card-3']!, closeTo(1, 0.1));
      expect(picks['card-2']! / picks['card-3']!, closeTo(1, 0.1));
    });
  });

  test('the output order does not match the creation order', () {
    final inCreationOrder = [for (var n = 1; n <= 20; n++) 'card-$n'];

    for (final prioritizeFailed in [false, true]) {
      for (var seed = 1; seed <= 5; seed++) {
        final selection = selectCards(
          candidates(20),
          mode: StudyMode.normal,
          direction: StudyDirection.normal,
          prioritizeFailed: prioritizeFailed,
          random: createRandom(seed: seed),
        );

        expect(ids(selection), hasLength(20));
        expect(ids(selection), isNot(inCreationOrder));
      }
    }
  });

  test('test options are shuffled', () {
    final original = options(6);
    final random = createRandom(seed: 5);
    final firstOptions = <String>{};

    for (var i = 0; i < 100; i++) {
      final shuffled = shuffleOptions(original, random);

      expect(
        shuffled.map((o) => o.id),
        unorderedEquals(original.map((o) => o.id)),
      );
      firstOptions.add(shuffled.first.id);
    }
    // Every option is shown first at some point, and the card's own list
    // keeps its editing order.
    expect(firstOptions, hasLength(6));
    expect(original.map((o) => o.position), [0, 1, 2, 3, 4, 5]);
  });
}
