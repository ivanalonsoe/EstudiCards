import 'package:estudicards/app/router.dart';
import 'package:estudicards/core/clock.dart';
import 'package:estudicards/core/db/app_database.dart';
import 'package:estudicards/features/projects/data/projects_dao.dart';
import 'package:estudicards/features/projects/data/projects_repository.dart';
import 'package:estudicards/features/projects/domain/project.dart';
import 'package:estudicards/features/projects/domain/project_input.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../helpers/test_app.dart';

void main() {
  late AppDatabase db;
  late FakeClock clock;
  late ProjectsRepository projects;
  late Project german;

  setUp(() async {
    db = createTestDatabase();
    clock = FakeClock(DateTime.utc(2026, 10, 6, 12));
    projects = ProjectsRepository(ProjectsDao(db), clock);
    german = await projects.create(
      const ProjectInput(name: 'Alemán A1', color: 'amber', icon: 'globe'),
    );
  });

  Finder card(Project p) => find.byKey(Key('projectCard.${p.id}'));
  Finder archivedItem(Project p) => find.byKey(Key('archivedItem.${p.id}'));

  /// The stored row, read with a plain query (see `test_app.dart`).
  Future<ProjectRow> stored(Project p) =>
      (db.select(db.projects)..where((row) => row.id.equals(p.id))).getSingle();

  Future<void> chooseInMenu(WidgetTester tester, Key menu, String item) async {
    await tester.tap(find.byKey(menu));
    await tester.pumpAndSettle();
    await tester.tap(find.text(item));
    await tester.pumpAndSettle();
  }

  Future<GoRouter> archiveFromDashboard(WidgetTester tester) async {
    final router = await pumpTestApp(
      tester,
      size: mobile,
      db: db,
      clock: clock,
    );
    await chooseInMenu(
      tester,
      Key('projectCard.${german.id}.menu'),
      'Archivar',
    );
    return router;
  }

  testWidgets('archiving a project removes it from the dashboard and it '
      'appears under Archived', (tester) async {
    final router = await archiveFromDashboard(tester);

    expect(card(german), findsNothing);
    expect(find.text('«Alemán A1» se ha archivado'), findsOneWidget);

    router.go(AppRoutes.archived);
    await tester.pumpAndSettle();

    expect(archivedItem(german), findsOneWidget);
    expect(
      find.descendant(
        of: archivedItem(german),
        matching: find.text('Archivado el 6 oct'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('"Deshacer" after archiving brings the project back', (
    tester,
  ) async {
    await archiveFromDashboard(tester);

    await tester.tap(find.text('Deshacer'));
    await tester.pumpAndSettle();

    expect(card(german), findsOneWidget);
    expect((await stored(german)).isArchived, isFalse);
  });

  testWidgets('unarchiving brings it back to the dashboard', (tester) async {
    await projects.setArchived(german.id, isArchived: true);
    final router = await pumpTestApp(
      tester,
      size: mobile,
      db: db,
      clock: clock,
      location: AppRoutes.archived,
    );

    await tester.tap(find.byKey(Key('archivedItem.${german.id}.unarchive')));
    await tester.pumpAndSettle();

    expect(archivedItem(german), findsNothing);
    expect(find.byKey(const Key('archived.empty')), findsOneWidget);
    router.go(AppRoutes.home);
    await tester.pumpAndSettle();
    expect(card(german), findsOneWidget);
  });

  testWidgets('a project archived from its own screen goes back to the '
      'dashboard', (tester) async {
    await pumpTestApp(
      tester,
      size: mobile,
      db: db,
      clock: clock,
      location: AppRoutes.project(german.id),
    );

    await chooseInMenu(tester, const Key('projectScreen.menu'), 'Archivar');

    expect(find.byKey(const Key('screen.dashboard')), findsOneWidget);
    expect((await stored(german)).isArchived, isTrue);
  });

  testWidgets('"Eliminar" in Archived moves the project to the trash', (
    tester,
  ) async {
    await projects.setArchived(german.id, isArchived: true);
    await pumpTestApp(
      tester,
      size: mobile,
      db: db,
      clock: clock,
      location: AppRoutes.archived,
    );

    await tester.tap(find.byKey(Key('archivedItem.${german.id}.delete')));
    await tester.pumpAndSettle();
    expect(find.text('¿Eliminar «Alemán A1»?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('confirmDialog.confirm')));
    await tester.pumpAndSettle();

    expect(archivedItem(german), findsNothing);
    expect((await stored(german)).deletedAt, clock.now());
  });

  testWidgets('with nothing archived, the empty state is shown', (
    tester,
  ) async {
    await pumpTestApp(
      tester,
      size: mobile,
      db: db,
      clock: clock,
      location: AppRoutes.archived,
    );

    expect(find.byKey(const Key('screen.archived')), findsOneWidget);
    expect(find.byKey(const Key('archived.empty')), findsOneWidget);
  });
}
