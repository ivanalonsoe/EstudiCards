/// A deck as the rest of the app sees it (plain Dart, see `Project`).
class Deck {
  const new({
    required this.id,
    required this.projectId,
    required this.name,
    required this.color,
    required this.inheritsColor,
    required this.createdAt,
    required this.updatedAt,
    this.description,
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
  final DateTime? lastUsedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
}
