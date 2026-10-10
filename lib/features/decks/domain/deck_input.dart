import 'package:estudicards/features/decks/domain/deck.dart';

/// Why a [DeckInput] is not valid.
enum DeckInputError { nameMissing, nameTooLong, languagesMissing }

/// Thrown when saving a deck whose input is not valid.
class InvalidDeckException implements Exception {
  const new(this.errors);

  final List<DeckInputError> errors;

  @override
  String toString() => 'InvalidDeckException($errors)';
}

/// What the user fills in to create or edit a deck (P04).
class DeckInput {
  const new({
    required this.name,
    this.description,
    this.color,
    this.type = DeckType.general,
    this.sourceLang,
    this.targetLang,
  });

  final String name;
  final String? description;

  /// Palette key, or null to inherit the project's colour.
  final String? color;
  final DeckType type;
  final String? sourceLang;
  final String? targetLang;

  static const maxNameLength = 60;

  /// The name without surrounding spaces, as it is stored.
  String get trimmedName => name.trim();

  /// The description without surrounding spaces; null when it is empty.
  String? get trimmedDescription {
    final trimmed = description?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  /// The rules from US-06: name 1–60 characters, and both languages for a
  /// language deck (they may be the same). Empty list = valid.
  List<DeckInputError> validate() => [
    if (trimmedName.isEmpty) DeckInputError.nameMissing,
    if (trimmedName.length > maxNameLength) DeckInputError.nameTooLong,
    if (type == DeckType.language &&
        (_isBlank(sourceLang) || _isBlank(targetLang)))
      DeckInputError.languagesMissing,
  ];

  static bool _isBlank(String? value) => value == null || value.trim().isEmpty;
}
