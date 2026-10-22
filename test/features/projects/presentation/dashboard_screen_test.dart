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
import '../../../helpers/test_data.dart';

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

  /// Adds a deck with [count] cards to [project] and returns their IDs.
  Future<List<String>> addCards(Project project, int count) async {
    final deck = await DecksRepository(
      DecksDao(db),
      clock,
    ).create(project.id, const DeckInput(name: 'Verbos'));
    return [for (var i = 0; i < count; i++) await addTestCard(db, deck.id)];
  }

  /// Answers [cardId] with [results], by default this morning.
  Future<void> answer(
    Project project,
    String cardId,
    List<String> results, {
    DateTime? at,
  }) => addTestAnswers(
    db,
    projectId: project.id,
    cardId: cardId,
    results: results,
    at: at ?? DateTime.utc(2026, 10, 6, 9),
  );

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

    testWidgets('the header shows the streak: 0 days with no answers', (
      tester,
    ) async {
      await createSampleProjects();
      await pumpTestApp(tester, size: mobile, db: db, clock: clock);

      expect(find.text('0 días'), findsOneWidget);
    });

    testWidgets('the header shows the days in a row with answers', (
      tester,
    ) async {
      final project = await createProject('Inglés B2');
      final [card] = await addCards(project, 1);
      await answer(project, card, ['correct'], at: DateTime.utc(2026, 10, 5));
      await answer(project, card, ['correct'], at: DateTime.utc(2026, 10, 6));

      await pumpTestApp(tester, size: mobile, db: db, clock: clock);

      expect(find.text('2 días'), findsOneWidget);
    });

    testWidgets('a card shows its % correct, when it was last studied and '
        '"Repasar errores (3)"', (tester) async {
      final project = await createProject('Inglés B2');
      final [a, b, c] = await addCards(project, 3);
      final yesterday = DateTime.utc(2026, 10, 5, 18);
      await answer(project, a, ['correct', 'wrong'], at: yesterday);
      await answer(project, b, ['wrong'], at: yesterday);
      await answer(project, c, ['wrong'], at: yesterday);

      await pumpTestApp(tester, size: mobile, db: db, clock: clock);

      Finder inCard(Finder finder) =>
          find.descendant(of: projectCard(project), matching: finder);
      expect(inCard(find.text('25% aciertos')), findsOneWidget);
      expect(inCard(find.text('Ayer')), findsOneWidget);
      expect(
        inCard(find.byKey(Key('projectCard.${project.id}.reviewErrors'))),
        findsOneWidget,
      );
      expect(inCard(find.text('Repasar errores (3)')), findsOneWidget);
      expect(inCard(find.text('Sin errores pendientes')), findsNothing);
    });

    testWidgets('with no errors, "Repasar errores" is not shown', (
      tester,
    ) async {
      final project = await createProject('Inglés B2');
      final [card] = await addCards(project, 1);
      await answer(project, card, ['correct']);

      await pumpTestApp(tester, size: mobile, db: db, clock: clock);

      expect(
        find.byKey(Key('projectCard.${project.id}.reviewErrors')),
        findsNothing,
      );
      expect(find.text('Sin errores pendientes'), findsOneWidget);
      expect(find.text('100% aciertos'), findsOneWidget);
      expect(find.text('Hoy'), findsOneWidget);
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

    testWidgets('the header shows the streak with its record, the cards of '
        'the last 7 days and the pending errors', (tester) async {
      final english = await createProject('Inglés B2');
      final law = await createProject('Oposiciones · Tema 3');
      await createProject('Biología 2º Bach.');
      final [a, b, c] = await addCards(english, 3);
      final [d] = await addCards(law, 1);
      // A 3-day run a week ago (the record), then yesterday and today.
      for (final day in [27, 28, 29]) {
        await answer(english, a, ['correct'], at: DateTime.utc(2026, 9, day));
      }
      await answer(english, a, ['wrong'], at: DateTime.utc(2026, 10, 5));
      await answer(english, b, ['wrong'], at: DateTime.utc(2026, 10, 6));
      await answer(english, c, ['wrong', 'correct']);
      await answer(law, d, ['wrong']);

      await pumpTestApp(tester, size: desktop, db: db, clock: clock);

      final streak = find.byKey(const Key('dashboard.streak'));
      expect(
        find.descendant(of: streak, matching: find.text('2 días')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: streak,
          matching: find.text('Racha actual · récord 3'),
        ),
        findsOneWidget,
      );
      final week = find.byKey(const Key('dashboard.lastWeek'));
      expect(
        find.descendant(of: week, matching: find.text('5')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: week, matching: find.text('tarjetas en 7 días')),
        findsOneWidget,
      );
      // After the daily goal's sentence (on by default).
      expect(
        find.textContaining('Tienes 4 errores pendientes en 2 proyectos.'),
        findsOneWidget,
      );
    });

    testWidgets('with no errors, the header does not mention them', (
      tester,
    ) async {
      await createSampleProjects();
      await pumpTestApp(tester, size: desktop, db: db, clock: clock);

      expect(find.textContaining('errores pendientes en'), findsNothing);
    });

    testWidgets('the sidebar shows the pending errors of each project', (
      tester,
    ) async {
      final english = await createProject('Inglés B2');
      final law = await createProject('Oposiciones · Tema 3');
      final [a, b] = await addCards(english, 2);
      await answer(english, a, ['wrong']);
      await answer(english, b, ['wrong']);

      await pumpTestApp(tester, size: desktop, db: db, clock: clock);

      expect(
        find.descendant(
          of: find.byKey(Key('sidebar.project.${english.id}.errors')),
          matching: find.text('2'),
        ),
        findsOneWidget,
      );
      expect(find.byKey(Key('sidebar.project.${law.id}.errors')), findsNothing);
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
