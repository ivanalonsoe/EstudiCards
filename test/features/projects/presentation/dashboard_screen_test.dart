import 'package:estudicards/app/router.dart';
import 'package:estudicards/core/clock.dart';
import 'package:estudicards/core/db/app_database.dart';
import 'package:estudicards/features/decks/data/decks_dao.dart';
import 'package:estudicards/features/decks/data/decks_repository.dart';
import 'package:estudicards/features/decks/domain/deck_input.dart';
import 'package:estudicards/features/projects/data/projects_dao.dart';
import 'package:estudicards/features/projects/data/projects_repository.dart';
import 'package:estudicards/features/projects/domain/project.dart';
import 'package:estudicards/features/projects/domain/project_input.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/test_app.dart';

void main() {
  late AppDatabase db;
  late FakeClock clock;
  late ProjectsRepository projects;

  setUp(() {
    db = createTestDatabase();
    clock = FakeClock(DateTime.utc(2026, 10, 6, 12));
    projects = ProjectsRepository(ProjectsDao(db), clock);
  });

  Future<Project> createProject(String name, {String icon = 'book'}) async {
    final project = await projects.create(
      ProjectInput(name: name, color: 'blue', icon: icon),
    );
    clock.advance(const Duration(minutes: 1));
    return project;
  }

  /// Creates the three sample projects; "Inglés B2" is the oldest but a
  /// favourite.
  Future<List<Project>> createSampleProjects() async {
    final english = await createProject('Inglés B2', icon: 'globe');
    final law = await createProject('Oposiciones · Tema 3', icon: 'scales');
    final biology = await createProject('Biología 2º Bach.', icon: 'flask');
    await projects.setFavorite(english.id, isFavorite: true);
    return [english, law, biology];
  }

  Finder projectCard(Project project) =>
      find.byKey(Key('projectCard.${project.id}'));

  // A phone tall enough to show three project cards without scrolling.
  const tallMobile = Size(390, 1400);

  group('mobile', () {
    testWidgets('with no projects, the empty state is shown', (tester) async {
      await pumpTestApp(tester, size: mobile, db: db, clock: clock);

      expect(find.byKey(const Key('dashboard.empty')), findsOneWidget);
      expect(find.text('Crea tu primer proyecto'), findsOneWidget);
      expect(find.byKey(const Key('dashboard.newProject')), findsOneWidget);
      expect(find.byKey(const Key('dashboard.search')), findsNothing);
    });

    testWidgets('with 3 projects, 3 cards are shown, the favourite first', (
      tester,
    ) async {
      final [english, law, biology] = await createSampleProjects();

      await pumpTestApp(tester, size: tallMobile, db: db, clock: clock);

      expect(find.byKey(const Key('dashboard.empty')), findsNothing);
      for (final project in [english, law, biology]) {
        expect(projectCard(project), findsOneWidget);
      }
      // The favourite first, then the most recently created.
      final tops = [
        english,
        biology,
        law,
      ].map((p) => tester.getTopLeft(projectCard(p)).dy).toList();
      expect(tops, [...tops]..sort());
      expect(find.text('FAVORITOS'), findsOneWidget);
      expect(find.text('RECIENTES'), findsOneWidget);
    });

    testWidgets('a card shows its number of decks and cards', (tester) async {
      final project = await createProject('Inglés B2');
      final decks = DecksRepository(DecksDao(db), clock);
      await decks.create(project.id, const DeckInput(name: 'Verbos'));
      await decks.create(project.id, const DeckInput(name: 'Phrasal verbs'));

      await pumpTestApp(tester, size: mobile, db: db, clock: clock);

      expect(
        find.descendant(
          of: projectCard(project),
          matching: find.text('2 barajas · 0 tarjetas'),
        ),
        findsOneWidget,
      );
      // No statistics until phase 4: no percentage and no pending errors.
      expect(find.text('— aciertos'), findsOneWidget);
      expect(find.text('Sin errores pendientes'), findsOneWidget);
    });

    testWidgets('searching "ingles" finds "Inglés B2"', (tester) async {
      final [english, law, biology] = await createSampleProjects();
      await pumpTestApp(tester, size: mobile, db: db, clock: clock);

      await tester.enterText(
        find.byKey(const Key('dashboard.search')),
        'ingles',
      );
      await tester.pumpAndSettle();

      expect(projectCard(english), findsOneWidget);
      expect(projectCard(law), findsNothing);
      expect(projectCard(biology), findsNothing);
    });

    testWidgets('a search with no results says so', (tester) async {
      await createSampleProjects();
      await pumpTestApp(tester, size: mobile, db: db, clock: clock);

      await tester.enterText(
        find.byKey(const Key('dashboard.search')),
        'química',
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('dashboard.noResults')), findsOneWidget);
      expect(
        find.text('Ningún proyecto coincide con «química»'),
        findsOneWidget,
      );
    });

    testWidgets('the header shows the streak, at 0 until phase 4', (
      tester,
    ) async {
      await createSampleProjects();
      await pumpTestApp(tester, size: mobile, db: db, clock: clock);

      expect(find.text('0 días'), findsOneWidget);
    });

    testWidgets('tapping a card opens the project and marks it as used', (
      tester,
    ) async {
      final [english, ...] = await createSampleProjects();
      await pumpTestApp(tester, size: mobile, db: db, clock: clock);

      await tester.tap(projectCard(english));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('screen.project')), findsOneWidget);
      final stored = await projects.getById(english.id);
      expect(stored!.lastUsedAt, clock.now());
    });

    testWidgets('the menu marks a project as favourite', (tester) async {
      final law = await createProject('Oposiciones · Tema 3');
      final biology = await createProject('Biología 2º Bach.');
      await pumpTestApp(tester, size: tallMobile, db: db, clock: clock);
      expect(
        tester.getTopLeft(projectCard(biology)).dy,
        lessThan(tester.getTopLeft(projectCard(law)).dy),
      );

      await tester.tap(find.byKey(Key('projectCard.${law.id}.menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Marcar como favorito'));
      await tester.pumpAndSettle();

      expect((await projects.getById(law.id))!.isFavorite, isTrue);
      expect(
        tester.getTopLeft(projectCard(law)).dy,
        lessThan(tester.getTopLeft(projectCard(biology)).dy),
      );
    });
  });

  group('desktop', () {
    Finder sidebarProject(Project project) =>
        find.byKey(Key('sidebar.project.${project.id}'));

    testWidgets('shows the projects in the grid and in the sidebar', (
      tester,
    ) async {
      final sample = await createSampleProjects();

      await pumpTestApp(tester, size: desktop, db: db, clock: clock);

      for (final project in sample) {
        expect(projectCard(project), findsOneWidget);
        expect(sidebarProject(project), findsOneWidget);
      }
      expect(find.text('Tus proyectos'), findsOneWidget);
      expect(find.byKey(const Key('dashboard.newProject')), findsOneWidget);
      // The favourite is listed under its own heading in the sidebar.
      final favouritesHeading = tester.getTopLeft(find.text('FAVORITOS')).dy;
      final projectsHeading = tester.getTopLeft(find.text('PROYECTOS')).dy;
      final english = tester.getTopLeft(sidebarProject(sample.first)).dy;
      expect(english, greaterThan(favouritesHeading));
      expect(english, lessThan(projectsHeading));
    });

    testWidgets('the sidebar search filters the projects', (tester) async {
      final [english, law, biology] = await createSampleProjects();
      await pumpTestApp(tester, size: desktop, db: db, clock: clock);

      await tester.enterText(find.byKey(const Key('sidebar.search')), 'BIO');
      await tester.pumpAndSettle();

      expect(sidebarProject(biology), findsOneWidget);
      expect(projectCard(biology), findsOneWidget);
      for (final hidden in [english, law]) {
        expect(sidebarProject(hidden), findsNothing);
        expect(projectCard(hidden), findsNothing);
      }
    });

    testWidgets('a sidebar project opens the project screen', (tester) async {
      final [english, ...] = await createSampleProjects();
      final router = await pumpTestApp(
        tester,
        size: desktop,
        db: db,
        clock: clock,
      );

      await tester.tap(sidebarProject(english));
      await tester.pumpAndSettle();

      expect(
        router.routerDelegate.currentConfiguration.uri.path,
        AppRoutes.project(english.id),
      );
      final tile = tester.widget<ListTile>(sidebarProject(english));
      expect(tile.selected, isTrue);
    });
  });
}
