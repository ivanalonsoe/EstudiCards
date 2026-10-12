import 'package:estudicards/features/cards/domain/flashcard.dart';
import 'package:estudicards/features/study/domain/test_grading.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime.utc(2026, 10, 12);

/// A test card with options `a`, `b`, `c` and `d`; the ones in [correct] are
/// the correct ones.
Flashcard testCard({required Set<String> correct}) => Flashcard(
  id: 'card',
  deckId: 'deck',
  type: CardType.test,
  question: '¿Qué órganos forman las Cortes Generales?',
  allowMultiple: correct.length > 1,
  options: [
    for (final (index, id) in ['a', 'b', 'c', 'd'].indexed)
      CardOption(
        id: id,
        text: 'Option $id',
        isCorrect: correct.contains(id),
        position: index,
      ),
  ],
  createdAt: _now,
  updatedAt: _now,
);

void main() {
  group('one correct option', () {
    final card = testCard(correct: {'b'});

    test('ticking the correct option is correct', () {
      expect(isTestAnswerCorrect(card, {'b'}), isTrue);
    });

    test('ticking another option is wrong', () {
      expect(isTestAnswerCorrect(card, {'a'}), isFalse);
    });
  });

  group('multiple answer (no partial credit)', () {
    final card = testCard(correct: {'a', 'c'});

    test('ticking exactly the correct ones is correct', () {
      expect(isTestAnswerCorrect(card, {'c', 'a'}), isTrue);
    });

    test('one missing is wrong', () {
      expect(isTestAnswerCorrect(card, {'a'}), isFalse);
    });

    test('one extra is wrong', () {
      expect(isTestAnswerCorrect(card, {'a', 'b', 'c'}), isFalse);
    });
  });

  test('ticking nothing is wrong', () {
    expect(isTestAnswerCorrect(testCard(correct: {'b'}), {}), isFalse);
  });
}
