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
import 'package:estudicards/features/projects/domain/project_summary.dart';
import 'package:estudicards/features/stats/domain/metrics.dart';

class ProjectsRepository {
  new(this._dao, this._clock);

  final ProjectsDao _dao;
  final Clock _clock;

  /// Throws [InvalidProjectException] if [input] is not valid.
  Future<Project> create(ProjectInput input) async {
    _checkValid(input);
    final now = _clock.now();
    final row = await _dao.insertProject(
      ProjectsCompanion.insert(
        id: newId(),
        name: input.trimmedName,
        description: Value(input.trimmedDescription),
        color: input.color,
        icon: input.icon,
        createdAt: now,
        updatedAt: now,
      ),
    );
    return _toProject(row);
  }

  /// Replaces the fields the user edits (P02). Throws
  /// [InvalidProjectException] if [input] is not valid.
  Future<Project> update(String id, ProjectInput input) async {
    _checkValid(input);
    final row = await _dao.updateProject(
      id,
      ProjectsCompanion(
        name: Value(input.trimmedName),
        description: Value(input.trimmedDescription),
        color: Value(input.color),
        icon: Value(input.icon),
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

  /// The project with [id], updated whenever it changes (P03); null if
  /// there is none.
  Stream<Project?> watchProject(String id) =>
      _dao.watchById(id).map((row) => row == null ? null : _toProject(row));

  /// The dashboard list, updated whenever a project changes (US-05 AC1).
  Stream<List<ProjectSummary>> watchProjects() =>
      _dao.watchActive().map(_toSummaries);

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
  Future<void> setArchived(String id, {required bool isArchived}) {
    final now = _clock.now();
    return _dao.updateProject(
      id,
      ProjectsCompanion(
        isArchived: Value(isArchived),
        archivedAt: Value(isArchived ? now : null),
        updatedAt: Value(now),
      ),
    );
  }

  /// P14: archived projects not in the trash, the most recently archived
  /// first, with their counts.
  Stream<List<ProjectSummary>> watchArchived() =>
      _dao.watchArchived().map(_toSummaries);

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

  static List<ProjectSummary> _toSummaries(List<ProjectWithCounts> rows) => [
    for (final row in rows)
      ProjectSummary(
        project: _toProject(row.project),
        deckCount: row.deckCount,
        cardCount: row.cardCount,
        answers: AnswerCounts(correct: row.correctCount, wrong: row.wrongCount),
        errorCount: row.errorCount,
        lastStudiedAt: row.lastStudiedAt,
      ),
  ];

  static Project _toProject(ProjectRow row) => Project(
    id: row.id,
    name: row.name,
    description: row.description,
    color: row.color,
    icon: row.icon,
    isFavorite: row.isFavorite,
    isArchived: row.isArchived,
    archivedAt: row.archivedAt,
    lastUsedAt: row.lastUsedAt,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
  );
}
