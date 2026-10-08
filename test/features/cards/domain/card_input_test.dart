import 'package:estudicards/features/cards/domain/card_input.dart';
import 'package:estudicards/features/cards/domain/flashcard.dart';
import 'package:flutter_test/flutter_test.dart';

/// A test card with one option per entry: `'A'` is wrong, `'A*'` is correct.
CardInput testCard(List<String> options, {bool allowMultiple = false}) =>
    CardInput(
      type: CardType.test,
      question: '¿Qué orgánulo produce el ATP?',
      allowMultiple: allowMultiple,
      options: [
        for (final option in options)
          CardOptionInput(
            text: option.endsWith('*')
                ? option.substring(0, option.length - 1)
                : option,
            isCorrect: option.endsWith('*'),
          ),
      ],
    );

void main() {
  group('simple card', () {
    test('with a question and an answer is valid', () {
      const input = CardInput(
        type: CardType.simple,
        question: 'to bring',
        answer: 'traer',
      );

      expect(input.validate(), isEmpty);
    });

    test('with no answer is invalid', () {
      const noAnswer = CardInput(type: CardType.simple, question: 'to bring');
      const blankAnswer = CardInput(
        type: CardType.simple,
        question: 'to bring',
        answer: '   ',
      );

      expect(noAnswer.validate(), [CardInputError.answerMissing]);
      expect(blankAnswer.validate(), [CardInputError.answerMissing]);
    });

    test('with no question is invalid', () {
      const input = CardInput(
        type: CardType.simple,
        question: ' ',
        answer: 'traer',
      );

      expect(input.validate(), [CardInputError.questionMissing]);
    });

    test('does not need options', () {
      const input = CardInput(
        type: CardType.simple,
        question: 'to bring',
        answer: 'traer',
        options: [CardOptionInput(text: 'A')],
      );

      expect(input.validate(), isEmpty);
    });
  });

  group('test card', () {
    test('with 2 to 6 options and one correct is valid', () {
      expect(testCard(['Ribosoma', 'Mitocondria*']).validate(), isEmpty);
      expect(testCard(['A', 'B*', 'C', 'D', 'E', 'F']).validate(), isEmpty);
    });

    test('does not need an answer', () {
      expect(testCard(['A', 'B*']).trimmedAnswer, isNull);
      expect(testCard(['A', 'B*']).validate(), isEmpty);
    });

    test('with no question is invalid', () {
      const input = CardInput(
        type: CardType.test,
        question: '',
        options: [
          CardOptionInput(text: 'A', isCorrect: true),
          CardOptionInput(text: 'B'),
        ],
      );

      expect(input.validate(), [CardInputError.questionMissing]);
    });

    test('with fewer than 2 options is invalid', () {
      expect(testCard(['A*']).validate(), [CardInputError.tooFewOptions]);
      expect(testCard([]).validate(), [
        CardInputError.tooFewOptions,
        CardInputError.noCorrectOption,
      ]);
    });

    test('with more than 6 options is invalid', () {
      expect(testCard(['A*', 'B', 'C', 'D', 'E', 'F', 'G']).validate(), [
        CardInputError.tooManyOptions,
      ]);
    });

    test('with no correct option is invalid', () {
      expect(testCard(['A', 'B', 'C']).validate(), [
        CardInputError.noCorrectOption,
      ]);
    });

    test('with 2 correct options is invalid without "allow multiple"', () {
      expect(testCard(['A*', 'B*', 'C']).validate(), [
        CardInputError.tooManyCorrectOptions,
      ]);
    });

    test('with 2 correct options is valid with "allow multiple"', () {
      expect(
        testCard(['A*', 'B*', 'C'], allowMultiple: true).validate(),
        isEmpty,
      );
    });

    test('with "allow multiple" still needs one correct option', () {
      expect(testCard(['A', 'B'], allowMultiple: true).validate(), [
        CardInputError.noCorrectOption,
      ]);
    });
  });

  group('empty options', () {
    test('do not count towards the 2 options', () {
      expect(testCard(['A*', '', '  ']).validate(), [
        CardInputError.tooFewOptions,
      ]);
    });

    test('do not count towards the 6 options', () {
      expect(
        testCard(['A*', 'B', '', 'C', 'D', ' ', 'E', 'F']).validate(),
        isEmpty,
      );
    });

    test('do not count as correct even when ticked', () {
      expect(testCard(['A', 'B', ' *']).validate(), [
        CardInputError.noCorrectOption,
      ]);
      expect(testCard(['A*', 'B', ' *']).validate(), isEmpty);
    });

    test('are left out of the options to store, which are trimmed', () {
      final input = testCard([' Ribosoma ', '', 'Mitocondria*', '  ']);

      expect(input.filledOptions.map((o) => o.text), [
        'Ribosoma',
        'Mitocondria',
      ]);
      expect(input.filledOptions.map((o) => o.isCorrect), [false, true]);
    });

    test('keep the ID of a stored option', () {
      const input = CardInput(
        type: CardType.test,
        question: 'Q',
        options: [CardOptionInput(id: 'stored', text: ' A ')],
      );

      expect(input.filledOptions.single.id, 'stored');
    });
  });

  group('text fields', () {
    test('are stored without surrounding spaces', () {
      const input = CardInput(
        type: CardType.simple,
        question: '  to **bring** ',
        answer: ' traer ',
        explanation: ' Art. 66 ',
        example: ' Can you bring it? ',
        notes: ' Irregular ',
      );

      expect(input.trimmedQuestion, 'to **bring**');
      expect(input.trimmedAnswer, 'traer');
      expect(input.trimmedExplanation, 'Art. 66');
      expect(input.trimmedExample, 'Can you bring it?');
      expect(input.trimmedNotes, 'Irregular');
    });

    test('that are blank become null', () {
      const input = CardInput(
        type: CardType.simple,
        question: 'to bring',
        answer: ' ',
        explanation: '',
        example: '  ',
        notes: '\n',
      );

      expect(input.trimmedAnswer, isNull);
      expect(input.trimmedExplanation, isNull);
      expect(input.trimmedExample, isNull);
      expect(input.trimmedNotes, isNull);
    });
  });

  test('CardType reads the stored value and falls back to simple', () {
    expect(CardType.fromStored('test'), CardType.test);
    expect(CardType.fromStored('simple'), CardType.simple);
    expect(CardType.fromStored('unknown'), CardType.simple);
  });

  test('InvalidCardException lists the errors in its message', () {
    expect(
      const InvalidCardException([CardInputError.answerMissing]).toString(),
      'InvalidCardException([CardInputError.answerMissing])',
    );
  });
}
