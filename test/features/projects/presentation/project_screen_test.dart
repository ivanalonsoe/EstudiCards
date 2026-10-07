import 'package:estudicards/app/router.dart';
import 'package:estudicards/core/clock.dart';
import 'package:estudicards/core/db/app_database.dart';
import 'package:estudicards/features/decks/data/decks_dao.dart';
import 'package:estudicards/features/decks/data/decks_repository.dart';
import 'package:estudicards/features/decks/domain/deck.dart';
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
  late DecksRepository decks;

  setUp(() {
    db = createTestDatabase();
    clock = FakeClock(DateTime.utc(2026, 10, 6, 12));
    projects = ProjectsRepository(ProjectsDao(db), clock);
    decks = DecksRepository(DecksDao(db), clock);
  });

  Future<Project> createEnglish() => projects.create(
    const ProjectInput(
      name: 'Inglés B2',
      description: 'Nivel intermedio alto',
      color: 'blue',
      icon: 'globe',
      type: ProjectType.language,
      sourceLang: 'en-GB',
      targetLang: 'es-ES',
    ),
  );

  Future<Deck> createDeck(Project project, String name, {int cards = 0}) async {
    final deck = await decks.create(project.id, DeckInput(name: name));
    for (var i = 0; i < cards; i++) {
      await addTestCard(db, deck.id);
    }
    clock.advance(const Duration(minutes: 1));
    return deck;
  }

  Future<void> openProject(
    WidgetTester tester,
    Project project, {
    Size size = mobile,
  }) => pumpTestApp(
    tester,
    size: size,
    db: db,
    clock: clock,
    location: AppRoutes.project(project.id),
  );

  Finder deckTile(Deck deck) => find.byKey(Key('deckTile.${deck.id}'));

  group('mobile', () {
    testWidgets("shows the project's decks with their number of cards", (
      tester,
    ) async {
      final project = await createEnglish();
      final verbs = await createDeck(project, 'Verbos irregulares', cards: 2);
      final phrasal = await createDeck(project, 'Phrasal verbs', cards: 1);

      await openProject(tester, project);

      expect(find.byKey(const Key('projectScreen.empty')), findsNothing);
      expect(
        find.descendant(
          of: deckTile(verbs),
          matching: find.text('2 tarjetas · — aciertos'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: deckTile(phrasal),
          matching: find.text('1 tarjeta · — aciertos'),
        ),
        findsOneWidget,
      );
      // Oldest first.
      expect(
        tester.getTopLeft(deckTile(verbs)).dy,
        lessThan(tester.getTopLeft(deckTile(phrasal)).dy),
      );
    });

    testWidgets('with no decks, the empty state is shown', (tester) async {
      final project = await createEnglish();

      await openProject(tester, project);

      expect(find.byKey(const Key('projectScreen.empty')), findsOneWidget);
      expect(
        find.text('Crea una baraja para empezar a añadir tarjetas'),
        findsOneWidget,
      );
    });

    testWidgets('the header shows the details and the metrics', (tester) async {
      final project = await createEnglish();
      await createDeck(project, 'Verbos', cards: 2);
      await createDeck(project, 'Phrasal verbs', cards: 1);

      await openProject(tester, project);

      expect(find.text('Inglés B2'), findsOneWidget);
      expect(
        find.text('Inglés (R. U.) → Español · Nivel intermedio alto'),
        findsOneWidget,
      );
      // Real card count; % correct and errors arrive in phase 4.
      Finder metric(String key, String value) => find.descendant(
        of: find.byKey(Key('projectScreen.metric.$key')),
        matching: find.text(value),
      );
      expect(metric('cards', '3'), findsOneWidget);
      expect(metric('correct', '—'), findsOneWidget);
      expect(metric('errors', '0'), findsOneWidget);
    });

    testWidgets('the statistics tab shows that there is no data yet', (
      tester,
    ) async {
      final project = await createEnglish();
      final deck = await createDeck(project, 'Verbos');
      await openProject(tester, project);

      await tester.tap(find.byKey(const Key('projectScreen.tab.statistics')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('projectScreen.noStatistics')),
        findsOneWidget,
      );
      expect(deckTile(deck), findsNothing);

      await tester.tap(find.byKey(const Key('projectScreen.tab.decks')));
      await tester.pumpAndSettle();
      expect(deckTile(deck), findsOneWidget);
    });

    testWidgets('tapping a deck opens it and marks it as used', (tester) async {
      final project = await createEnglish();
      final deck = await createDeck(project, 'Verbos');
      await openProject(tester, project);

      await tester.tap(deckTile(deck));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('screen.deck')), findsOneWidget);
      expect((await decks.getById(deck.id))!.lastUsedAt, clock.now());
    });

    testWidgets('"Editar proyecto" in the menu updates the header', (
      tester,
    ) async {
      final project = await createEnglish();
      await openProject(tester, project);

      await tester.tap(find.byKey(const Key('projectScreen.menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Editar proyecto'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('projectForm.name')),
        'Inglés C1',
      );
      await tester.tap(find.byKey(const Key('projectForm.save')));
      await tester.pumpAndSettle();

      expect(find.text('Inglés C1'), findsOneWidget);
      expect(find.byKey(const Key('screen.project')), findsOneWidget);
    });

    testWidgets('an unknown project says it does not exist', (tester) async {
      await pumpTestApp(
        tester,
        size: mobile,
        db: db,
        clock: clock,
        location: AppRoutes.project('missing'),
      );

      expect(find.byKey(const Key('projectScreen.notFound')), findsOneWidget);
    });
  });

  group('desktop', () {
    testWidgets('shows the decks and the summary side by side', (tester) async {
      final project = await createEnglish();
      final deck = await createDeck(project, 'Verbos', cards: 2);

      await openProject(tester, project, size: desktop);

      final summary = find.byKey(const Key('projectScreen.summary'));
      expect(deckTile(deck), findsOneWidget);
      expect(summary, findsOneWidget);
      expect(
        tester.getTopLeft(summary).dx,
        greaterThan(tester.getTopRight(deckTile(deck)).dx),
      );
      // No tabs on desktop: the summary takes their place.
      expect(
        find.byKey(const Key('projectScreen.tab.statistics')),
        findsNothing,
      );
    });

    testWidgets('the breadcrumb goes back to the dashboard', (tester) async {
      final project = await createEnglish();
      await openProject(tester, project, size: desktop);

      await tester.tap(find.byKey(const Key('projectScreen.breadcrumbHome')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('screen.dashboard')), findsOneWidget);
    });
  });
}
