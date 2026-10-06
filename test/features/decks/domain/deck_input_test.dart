import 'package:estudicards/features/decks/domain/deck_input.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DeckInput.validate', () {
    test('a deck with a name and no colour is valid', () {
      expect(const DeckInput(name: 'Verbos').validate(), isEmpty);
    });

    test('counts the name without surrounding spaces', () {
      final input = DeckInput(name: '  ${'a' * 60}  ');

      expect(input.validate(), isEmpty);
      expect(input.trimmedName, 'a' * 60);
    });

    test('a blank description becomes null', () {
      const input = DeckInput(name: 'Verbos', description: '  ');

      expect(input.trimmedDescription, isNull);
    });
  });

  test('InvalidDeckException lists the errors in its message', () {
    expect(
      const InvalidDeckException([DeckInputError.nameTooLong]).toString(),
      'InvalidDeckException([DeckInputError.nameTooLong])',
    );
  });
}
