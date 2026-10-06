// A DAO (Data Access Object) groups the SQL queries for one table. It only
// reads and writes rows; validation, IDs and the clock live in the
// repository, which is what the rest of the app uses.
//
// `@DriftAccessor` makes `build_runner` generate `_$ProjectsDaoMixin`, which
// gives the DAO the `projects` table accessor.
import 'package:drift/drift.dart';
import 'package:estudicards/core/db/app_database.dart';

part 'projects_dao.g.dart';

@DriftAccessor(tables: [Projects])
class ProjectsDao extends DatabaseAccessor<AppDatabase>
    with _$ProjectsDaoMixin {
  new(super.attachedDatabase);

  Future<ProjectRow> insertProject(ProjectsCompanion project) =>
      into(projects).insertReturning(project);

  /// Writes the given columns and returns the updated row, or null if there
  /// is no project with that [id].
  Future<ProjectRow?> updateProject(
    String id,
    ProjectsCompanion changes,
  ) async {
    final rows = await (update(
      projects,
    )..where((p) => p.id.equals(id))).writeReturning(changes);
    return rows.singleOrNull;
  }

  Future<ProjectRow?> findById(String id) =>
      (select(projects)..where((p) => p.id.equals(id))).getSingleOrNull();

  /// The dashboard list (US-05 AC1): not archived and not in the trash,
  /// favourites first, then the most recently used. A project never used
  /// counts from its creation time.
  ///
  /// `watch()` returns a stream that emits a new list every time the table
  /// changes, so the screen updates by itself.
  Stream<List<ProjectRow>> watchActive() {
    final query = select(projects)
      ..where((p) => p.isArchived.not() & p.deletedAt.isNull())
      ..orderBy([
        (p) => OrderingTerm.desc(p.isFavorite),
        (p) => OrderingTerm.desc(coalesce([p.lastUsedAt, p.createdAt])),
        (p) => OrderingTerm.asc(p.name),
      ]);
    return query.watch();
  }
}
