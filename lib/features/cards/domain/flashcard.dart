// Domain model: a card as the rest of the app sees it (plain Dart, see
// `Project`). It is called `Flashcard` because Flutter already has a `Card`
// widget, and a screen that used both names would need import prefixes.

/// `simple` | `test` (SPEC §4.2). The enum name is the stored value.
enum CardType {
  simple,
  test;

  /// The type for a stored value. Unknown values fall back to [simple].
  static CardType fromStored(String value) =>
      values.asNameMap()[value] ?? simple;
}

/// One answer option of a test card.
class CardOption {
  const new({
    required this.id,
    required this.text,
    required this.isCorrect,
    required this.position,
  });

  final String id;
  final String text;
  final bool isCorrect;

  /// Order while editing, from 0. Options are shuffled when studying.
  final int position;
}

class Flashcard {
  const new({
    required this.id,
    required this.deckId,
    required this.type,
    required this.question,
    required this.allowMultiple,
    required this.createdAt,
    required this.updatedAt,
    this.questionImage,
    this.answer,
    this.answerImage,
    this.explanation,
    this.example,
    this.notes,
    this.options = const [],
  });

  final String id;
  final String deckId;
  final CardType type;

  /// Supports `**bold**` and `*italic*`.
  final String question;

  /// Image paths, relative to the images folder (SPEC §3.4).
  final String? questionImage;

  /// Simple cards only.
  final String? answer;

  /// On a test card it is shown with the explanation.
  final String? answerImage;

  /// Test cards only, optional.
  final String? explanation;

  /// Test cards only: several options can be correct.
  final bool allowMultiple;

  /// Language projects only. Kept when a project becomes general, like its
  /// languages (US-02 AC2).
  final String? example;
  final String? notes;

  /// Test cards only, sorted by [CardOption.position].
  final List<CardOption> options;
  final DateTime createdAt;
  final DateTime updatedAt;
}
