import 'package:estudicards/features/projects/domain/project.dart';

/// Why a [ProjectInput] is not valid.
enum ProjectInputError {
  nameMissing,
  nameTooLong,
  descriptionTooLong,
  languagesMissing,
}

/// Thrown when saving a project whose input is not valid.
class InvalidProjectException implements Exception {
  const new(this.errors);

  final List<ProjectInputError> errors;

  @override
  String toString() => 'InvalidProjectException($errors)';
}

/// What the user fills in to create or edit a project (P02).
class ProjectInput {
  const new({
    required this.name,
    required this.color,
    required this.icon,
    this.description,
    this.type = ProjectType.general,
    this.sourceLang,
    this.targetLang,
  });

  final String name;
  final String? description;
  final String color;
  final String icon;
  final ProjectType type;
  final String? sourceLang;
  final String? targetLang;

  static const maxNameLength = 60;
  static const maxDescriptionLength = 300;

  /// The name without surrounding spaces, as it is stored.
  String get trimmedName => name.trim();

  /// The description without surrounding spaces; null when it is empty.
  String? get trimmedDescription {
    final trimmed = description?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  /// The rules from US-01: name 1–60 characters, description up to 300, and
  /// both languages for a language project. Empty list = valid.
  List<ProjectInputError> validate() => [
    if (trimmedName.isEmpty) ProjectInputError.nameMissing,
    if (trimmedName.length > maxNameLength) ProjectInputError.nameTooLong,
    if ((trimmedDescription?.length ?? 0) > maxDescriptionLength)
      ProjectInputError.descriptionTooLong,
    if (type == ProjectType.language &&
        (_isBlank(sourceLang) || _isBlank(targetLang)))
      ProjectInputError.languagesMissing,
  ];

  static bool _isBlank(String? value) => value == null || value.trim().isEmpty;
}
