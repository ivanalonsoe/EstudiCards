// Domain model: the project as the rest of the app sees it. It is plain Dart
// (no Flutter, no Drift), so business rules and screens do not depend on how
// the database stores it. The repository converts database rows into these.
//
// The type (general or language) and the languages belong to each deck
// (`Deck`), so one project can mix both types (T2.10).

class Project {
  const new({
    required this.id,
    required this.name,
    required this.color,
    required this.icon,
    required this.isFavorite,
    required this.isArchived,
    required this.createdAt,
    required this.updatedAt,
    this.description,
    this.lastUsedAt,
    this.archivedAt,
  });

  final String id;
  final String name;
  final String? description;

  /// Key from the project palette, e.g. `orange` (see `ProjectColor`).
  final String color;
  final String icon;
  final bool isFavorite;
  final bool isArchived;

  /// When it was archived; null if it is not, or if it was archived before
  /// this was recorded.
  final DateTime? archivedAt;
  final DateTime? lastUsedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
}
