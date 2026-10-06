// A repository is the single entry point the app uses to read and save
// projects. It validates the input, generates IDs, takes the time from the
// injectable clock and turns database rows into domain models, so screens
// never deal with Drift directly.
import 'package:drift/drift.dart';
import 'package:estudicards/core/clock.dart';
import 'package:estudicards/core/db/app_database.dart';
import 'package:estudicards/core/ids.dart';
import 'package:estudicards/features/projects/data/projects_dao.dart';
import 'package:estudicards/features/projects/domain/project.dart';
import 'package:estudicards/features/projects/domain/project_input.dart';

class ProjectsRepository {
  new(this._dao, this._clock);

  final ProjectsDao _dao;
  final Clock _clock;

  /// Throws [InvalidProjectException] if [input] is not valid.
  Future<Project> create(ProjectInput input) async {
    _checkValid(input);
    final now = _clock.now();
    final isLanguage = input.type == ProjectType.language;
    final row = await _dao.insertProject(
      ProjectsCompanion.insert(
        id: newId(),
        name: input.trimmedName,
        description: Value(input.trimmedDescription),
        color: input.color,
        icon: input.icon,
        type: input.type.name,
        sourceLang: Value(isLanguage ? input.sourceLang : null),
        targetLang: Value(isLanguage ? input.targetLang : null),
        createdAt: now,
        updatedAt: now,
      ),
    );
    return _toProject(row);
  }

  /// Replaces the fields the user edits (P02). Throws
  /// [InvalidProjectException] if [input] is not valid.
  ///
  /// A general project keeps the languages already stored: switching from
  /// "Idioma" to "General" hides them but does not delete them (US-02 AC2).
  Future<Project> update(String id, ProjectInput input) async {
    _checkValid(input);
    final isLanguage = input.type == ProjectType.language;
    final row = await _dao.updateProject(
      id,
      ProjectsCompanion(
        name: Value(input.trimmedName),
        description: Value(input.trimmedDescription),
        color: Value(input.color),
        icon: Value(input.icon),
        type: Value(input.type.name),
        // `Value.absent()` leaves the column as it is.
        sourceLang: isLanguage ? Value(input.sourceLang) : const .absent(),
        targetLang: isLanguage ? Value(input.targetLang) : const .absent(),
        updatedAt: Value(_clock.now()),
      ),
    );
    if (row == null) throw StateError('No project with id $id');
    return _toProject(row);
  }

  Future<Project?> getById(String id) async {
    final row = await _dao.findById(id);
    return row == null ? null : _toProject(row);
  }

  /// The dashboard list, updated whenever a project changes (US-05 AC1).
  Stream<List<Project>> watchProjects() =>
      _dao.watchActive().map((rows) => rows.map(_toProject).toList());

  Future<void> setFavorite(String id, {required bool isFavorite}) =>
      _dao.updateProject(
        id,
        ProjectsCompanion(
          isFavorite: Value(isFavorite),
          updatedAt: Value(_clock.now()),
        ),
      );

  /// Archived projects leave the dashboard and are listed under "Archivados"
  /// (US-05 AC2).
  Future<void> setArchived(String id, {required bool isArchived}) =>
      _dao.updateProject(
        id,
        ProjectsCompanion(
          isArchived: Value(isArchived),
          updatedAt: Value(_clock.now()),
        ),
      );

  /// Records that the project was opened or studied (R 7.7). It does not
  /// change `updatedAt`, which only tracks edits.
  Future<void> markUsed(String id) => _dao.updateProject(
    id,
    ProjectsCompanion(lastUsedAt: Value(_clock.now())),
  );

  static void _checkValid(ProjectInput input) {
    final errors = input.validate();
    if (errors.isNotEmpty) throw InvalidProjectException(errors);
  }

  static Project _toProject(ProjectRow row) => Project(
    id: row.id,
    name: row.name,
    description: row.description,
    color: row.color,
    icon: row.icon,
    type: ProjectType.fromStored(row.type),
    sourceLang: row.sourceLang,
    targetLang: row.targetLang,
    isFavorite: row.isFavorite,
    isArchived: row.isArchived,
    lastUsedAt: row.lastUsedAt,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
  );
}
