enum TrashItemType { project, deck }

/// A project or a deck in the trash, as P15 lists it.
class TrashItem {
  const new({
    required this.type,
    required this.id,
    required this.name,
    required this.color,
    required this.cardCount,
    required this.deletedAt,
    this.icon,
    this.deckCount = 0,
    this.projectName,
  });

  final TrashItemType type;
  final String id;
  final String name;

  /// Palette key; a deck without its own colour uses its project's.
  final String color;

  /// The project's icon key; null for a deck.
  final String? icon;

  /// A project's decks that are not in the trash themselves; 0 for a deck.
  final int deckCount;
  final int cardCount;

  /// The project a deck belongs to; null for a project.
  final String? projectName;
  final DateTime deletedAt;
}
