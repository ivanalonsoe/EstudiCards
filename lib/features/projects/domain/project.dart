// Domain model: the project as the rest of the app sees it. It is plain Dart
// (no Flutter, no Drift), so business rules and screens do not depend on how
// the database stores it. The repository converts database rows into these.

/// `general` | `language` (SPEC §4.2). The enum name is the stored value.
enum ProjectType {
  general,
  language;

  /// The type for a stored value. Unknown values fall back to [general].
  static ProjectType fromStored(String value) =>
      values.asNameMap()[value] ?? general;
}

class Project {
  const new({
    required this.id,
    required this.name,
    required this.color,
    required this.icon,
    required this.type,
    required this.isFavorite,
    required this.isArchived,
    required this.createdAt,
    required this.updatedAt,
    this.description,
    this.sourceLang,
    this.targetLang,
    this.lastUsedAt,
  });

  final String id;
  final String name;
  final String? description;

  /// Key from the project palette, e.g. `orange` (see `ProjectColor`).
  final String color;
  final String icon;
  final ProjectType type;

  /// BCP-47 codes, e.g. `en-GB`. They are kept when a language project
  /// becomes general, so switching back restores them (US-02 AC2).
  final String? sourceLang;
  final String? targetLang;
  final bool isFavorite;
  final bool isArchived;
  final DateTime? lastUsedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
}
