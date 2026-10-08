import 'package:estudicards/features/cards/domain/flashcard.dart';

/// Why a [CardInput] is not valid.
enum CardInputError {
  questionMissing,
  answerMissing,
  tooFewOptions,
  tooManyOptions,
  noCorrectOption,
  tooManyCorrectOptions,
}

/// Thrown when saving a card whose input is not valid.
class InvalidCardException implements Exception {
  const new(this.errors);

  final List<CardInputError> errors;

  @override
  String toString() => 'InvalidCardException($errors)';
}

/// One option as the user fills it in the editor.
class CardOptionInput {
  const new({required this.text, this.isCorrect = false, this.id});

  /// The ID of an option that is already stored; null for a new one.
  final String? id;
  final String text;
  final bool isCorrect;
}

/// What the user fills in to create or edit a card (P06).
class CardInput {
  const new({
    required this.type,
    required this.question,
    this.questionImage,
    this.answer,
    this.answerImage,
    this.explanation,
    this.allowMultiple = false,
    this.example,
    this.notes,
    this.options = const [],
  });

  final CardType type;
  final String question;
  final String? questionImage;
  final String? answer;
  final String? answerImage;
  final String? explanation;
  final bool allowMultiple;
  final String? example;
  final String? notes;
  final List<CardOptionInput> options;

  static const minOptions = 2;
  static const maxOptions = 6;

  /// The question without surrounding spaces, as it is stored.
  String get trimmedQuestion => question.trim();

  // The optional texts without surrounding spaces; null when they are empty.
  String? get trimmedAnswer => _trimToNull(answer);
  String? get trimmedExplanation => _trimToNull(explanation);
  String? get trimmedExample => _trimToNull(example);
  String? get trimmedNotes => _trimToNull(notes);

  /// The options with text, trimmed, in the order the user sees them. Empty
  /// options are left out: they are not stored and do not count.
  List<CardOptionInput> get filledOptions => [
    for (final option in options)
      if (option.text.trim().isNotEmpty)
        CardOptionInput(
          id: option.id,
          text: option.text.trim(),
          isCorrect: option.isCorrect,
        ),
  ];

  /// The rules from US-08 and US-09 AC3. Empty list = valid.
  ///
  /// A simple card needs a question and an answer. A test card needs a
  /// question, 2 to 6 options with text and at least one correct; without
  /// "Permitir varias correctas", exactly one.
  List<CardInputError> validate() {
    final errors = <CardInputError>[
      if (trimmedQuestion.isEmpty) .questionMissing,
    ];
    switch (type) {
      case CardType.simple:
        if (trimmedAnswer == null) errors.add(.answerMissing);
      case CardType.test:
        final filled = filledOptions;
        final correctCount = filled.where((o) => o.isCorrect).length;
        if (filled.length < minOptions) errors.add(.tooFewOptions);
        if (filled.length > maxOptions) errors.add(.tooManyOptions);
        if (correctCount == 0) errors.add(.noCorrectOption);
        if (!allowMultiple && correctCount > 1) {
          errors.add(.tooManyCorrectOptions);
        }
    }
    return errors;
  }

  static String? _trimToNull(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
