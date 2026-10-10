import 'package:estudicards/features/cards/domain/card_list.dart';
import 'package:estudicards/features/cards/domain/flashcard.dart';
import 'package:flutter_test/flutter_test.dart';

final _start = DateTime.utc(2026, 10, 6);

/// A card created [day] days after 6 October 2026.
Flashcard card(
  String question, {
  String? answer,
  List<String> options = const [],
  int day = 0,
}) => Flashcard(
  id: question,
  deckId: 'deck',
  type: options.isEmpty ? CardType.simple : CardType.test,
  question: question,
  answer: answer,
  allowMultiple: false,
  options: [
    for (final (i, text) in options.indexed)
      CardOption(
        id: '$question-$i',
        text: text,
        isCorrect: i == 0,
        position: i,
      ),
  ],
  createdAt: _start.add(Duration(days: day)),
  updatedAt: _start.add(Duration(days: day)),
);

CardSummary summary(
  String question, {
  int day = 0,
  int correct = 0,
  int wrong = 0,
}) => CardSummary(
  card: card(question, day: day),
  correctCount: correct,
  wrongCount: wrong,
);

List<String> questions(List<CardSummary> cards) => [
  for (final s in cards) s.card.question,
];

void main() {
  group('daysSinceReview', () {
    // Noon in local time, so the tests do not depend on the time zone.
    final now = DateTime(2026, 10, 10, 12).toUtc();

    test('is null for a card never reviewed', () {
      expect(daysSinceReview(null, now), isNull);
    });

    test('counts calendar days in local time', () {
      expect(daysSinceReview(DateTime(2026, 10, 10, 0, 5).toUtc(), now), 0);
      expect(daysSinceReview(DateTime(2026, 10, 9, 23, 55).toUtc(), now), 1);
      expect(daysSinceReview(DateTime(2026, 10, 7, 12).toUtc(), now), 3);
      expect(daysSinceReview(DateTime(2026, 9, 30, 8).toUtc(), now), 10);
    });
  });

  group('RateLevel.of', () {
    test('is good from 70%, fair from 40% and poor below', () {
      expect(RateLevel.of(0.92), RateLevel.good);
      expect(RateLevel.of(0.7), RateLevel.good);
      expect(RateLevel.of(0.69), RateLevel.fair);
      expect(RateLevel.of(0.4), RateLevel.fair);
      expect(RateLevel.of(0.39), RateLevel.poor);
      expect(RateLevel.of(0), RateLevel.poor);
    });
  });

  group('combinedCorrectRate', () {
    test('adds up the answers of every card', () {
      final rate = combinedCorrectRate([
        summary('a', correct: 3, wrong: 1),
        summary('b', correct: 1, wrong: 3),
        summary('c'),
      ]);

      expect(rate, 0.5);
    });

    test('is null with no answers', () {
      expect(combinedCorrectRate([summary('a'), summary('b')]), isNull);
      expect(combinedCorrectRate(const <CardSummary>[]), isNull);
    });
  });

  group('matchesCardSearch', () {
    final bring = card('to **bring**', answer: 'traer');
    final atp = card(
      '¿Qué orgánulo produce el ATP?',
      options: ['Mitocondria', 'Ribosoma'],
    );

    test('an empty query matches every card', () {
      expect(matchesCardSearch(bring, ''), isTrue);
      expect(matchesCardSearch(bring, '   '), isTrue);
    });

    test('finds text in the question, answer and options', () {
      expect(matchesCardSearch(bring, 'bring'), isTrue);
      expect(matchesCardSearch(bring, 'traer'), isTrue);
      expect(matchesCardSearch(atp, 'ribosoma'), isTrue);
      expect(matchesCardSearch(atp, 'traer'), isFalse);
      expect(matchesCardSearch(bring, 'ribosoma'), isFalse);
    });

    test('ignores case, accents and bold or italic marks', () {
      expect(matchesCardSearch(atp, 'ORGANULO'), isTrue);
      expect(matchesCardSearch(bring, 'to bring'), isTrue);
      expect(matchesCardSearch(bring, ' Traer '), isTrue);
    });
  });

  group('CardSummary.correctRate', () {
    test('is null with no answers', () {
      expect(summary('a').correctRate, isNull);
    });

    test('is correct / (correct + wrong)', () {
      expect(summary('a', correct: 3, wrong: 1).correctRate, 0.75);
      expect(summary('a', wrong: 2).correctRate, 0);
    });
  });

  group('sortCards', () {
    test('newest puts the most recently created first', () {
      final cards = [
        summary('old', day: 1),
        summary('newest', day: 3),
        summary('middle', day: 2),
      ];

      expect(questions(sortCards(cards, CardSort.newest)), [
        'newest',
        'middle',
        'old',
      ]);
    });

    test('alphabetical ignores case, accents, opening marks and bold', () {
      final cards = [
        summary('to **bring**'),
        summary('¿Qué órgano…?'),
        summary('Árbol'),
        summary('adiós'),
        summary('Brújula'),
      ];

      expect(questions(sortCards(cards, CardSort.alphabetical)), [
        'adiós',
        'Árbol',
        'Brújula',
        '¿Qué órgano…?',
        'to **bring**',
      ]);
    });

    test('alphabetical puts the newest first when questions are equal', () {
      final cards = [summary('Same', day: 1), summary('same', day: 2)];

      expect(questions(sortCards(cards, CardSort.alphabetical)), [
        'same',
        'Same',
      ]);
    });

    test('most missed sorts by number of misses, then by lower % correct, '
        'then newest; never missed cards go last', () {
      final cards = [
        summary('never studied', day: 5),
        summary('1 miss of 1', wrong: 1, day: 1),
        summary('7 misses of 10', correct: 3, wrong: 7),
        summary('1 miss of 4', correct: 3, wrong: 1, day: 3),
        summary('only correct', correct: 4, day: 4),
        summary('1 miss of 2, newer', correct: 1, wrong: 1, day: 6),
        summary('1 miss of 2, older', correct: 1, wrong: 1, day: 2),
      ];

      expect(questions(sortCards(cards, CardSort.mostMissed)), [
        '7 misses of 10',
        '1 miss of 1',
        '1 miss of 2, newer',
        '1 miss of 2, older',
        '1 miss of 4',
        'never studied',
        'only correct',
      ]);
    });
  });
}
