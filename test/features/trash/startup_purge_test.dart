import 'package:drift/drift.dart' show Value;
import 'package:estudicards/core/clock.dart';
import 'package:estudicards/core/db/app_database.dart';
import 'package:estudicards/features/projects/data/projects_dao.dart';
import 'package:estudicards/features/projects/data/projects_repository.dart';
import 'package:estudicards/features/projects/domain/project_input.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_app.dart';

void main() {
  testWidgets('starting the app purges the expired trash (R 7.1)', (
    tester,
  ) async {
    final db = createTestDatabase();
    final clock = FakeClock(DateTime.utc(2026, 10, 20, 12));
    final projects = ProjectsRepository(ProjectsDao(db), clock);
    final expired = await projects.create(
      const ProjectInput(name: 'Historia', color: 'violet', icon: 'book'),
    );
    final recent = await projects.create(
      const ProjectInput(name: 'Química', color: 'green', icon: 'flask'),
    );
    // Moved to the trash 15 and 3 days before the app starts.
    Future<void> trashedAt(String id, Duration ago) =>
        (db.update(db.projects)..where((p) => p.id.equals(id))).write(
          ProjectsCompanion(deletedAt: Value(clock.now().subtract(ago))),
        );
    await trashedAt(expired.id, const Duration(days: 15));
    await trashedAt(recent.id, const Duration(days: 3));

    await pumpTestApp(tester, size: mobile, db: db, clock: clock);

    expect(await projects.getById(expired.id), isNull);
    expect(await projects.getById(recent.id), isNotNull);
  });
}
