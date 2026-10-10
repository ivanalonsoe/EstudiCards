/// `general` | `language` (SPEC §4.2). The enum name is the stored value.
enum DeckType {
  general,
  language;

  /// The type for a stored value. Unknown values fall back to [general].
  static DeckType fromStored(String value) =>
      values.asNameMap()[value] ?? general;
}

/// A deck as the rest of the app sees it (plain Dart, see `Project`).
class Deck {
  const new({
    required this.id,
    required this.projectId,
    required this.name,
    required this.color,
    required this.inheritsColor,
    required this.type,
    required this.createdAt,
    required this.updatedAt,
    this.description,
    this.sourceLang,
    this.targetLang,
    this.lastUsedAt,
  });

  final String id;
  final String projectId;
  final String name;
  final String? description;

  /// The palette key to paint the deck with: its own colour or, when it has
  /// none, its project's (US-06 AC1).
  final String color;

  /// True when the deck has no colour of its own and shows the project's.
  final bool inheritsColor;

  /// A language deck gets voice, reverse mode, example and notes.
  final DeckType type;

  /// BCP-47 codes, e.g. `en-GB`. They are kept when a language deck becomes
  /// general, so switching back restores them (US-06 AC3).
  final String? sourceLang;
  final String? targetLang;
  final DateTime? lastUsedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isLanguage => type == DeckType.language;
}
