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
    ),
  );

  Future<Deck> createDeck(
    Project project,
    String name, {
    int cards = 0,
    String? sourceLang,
    String? targetLang,
  }) async {
    final deck = await decks.create(
      project.id,
      DeckInput(
        name: name,
        type: sourceLang == null ? DeckType.general : DeckType.language,
        sourceLang: sourceLang,
        targetLang: targetLang,
      ),
    );
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

    testWidgets('a language deck shows its language pair; a general one '
        'shows none', (tester) async {
      final project = await createEnglish();
      final translation = await createDeck(
        project,
        'Verbos irregulares',
        sourceLang: 'en-GB',
        targetLang: 'es-ES',
      );
      final definitions = await createDeck(
        project,
        'Definitions',
        sourceLang: 'en-GB',
        targetLang: 'en-GB',
      );
      final general = await createDeck(project, 'Notas de clase');

      await openProject(tester, project);

      // The pair ends the details line (decided with the owner in T4.3).
      String detailsOf(Deck deck) => tester
          .widget<Text>(find.byKey(Key('deckTile.${deck.id}.details')))
          .textSpan!
          .toPlainText(includeSemanticsLabels: false);
      expect(detailsOf(translation), '0 tarjetas · — aciertos · EN → ES');
      expect(detailsOf(definitions), '0 tarjetas · — aciertos · EN → EN');
      expect(detailsOf(general), '0 tarjetas · — aciertos');
      // Screen readers hear the full names, as part of the deck's row.
      expect(
        tester.getSemantics(deckTile(translation)).label,
        contains('Inglés (R. U.) → Español'),
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
      // The languages belong to each deck, not to the project header.
      expect(find.text('Nivel intermedio alto'), findsOneWidget);
      // With no answers yet, % correct is "—" and there are no errors.
      Finder metric(String key, String value) => find.descendant(
        of: find.byKey(Key('projectScreen.metric.$key')),
        matching: find.text(value),
      );
      expect(metric('cards', '3'), findsOneWidget);
      expect(metric('correct', '—'), findsOneWidget);
      expect(metric('errors', '0'), findsOneWidget);
    });

    testWidgets('with 3 errors, "Repasar errores (3)" is shown, the metrics '
        'show % correct and errors, and each deck its errors', (tester) async {
      final project = await createEnglish();
      final verbs = await createDeck(
        project,
        'Verbos',
        sourceLang: 'en-GB',
        targetLang: 'es-ES',
      );
      final phrasal = await createDeck(project, 'Phrasal verbs');
      final travel = await createDeck(project, 'Viajes');
      final a = await addTestCard(db, verbs.id);
      final b = await addTestCard(db, verbs.id);
      final c = await addTestCard(db, phrasal.id);
      final d = await addTestCard(db, travel.id);
      Future<void> answer(String card, List<String> results) => addTestAnswers(
        db,
        projectId: project.id,
        cardId: card,
        results: results,
      );
      await answer(a, ['correct', 'wrong']);
      await answer(b, ['wrong']);
      await answer(c, ['wrong']);
      await answer(d, ['correct', 'correct', 'correct']);

      // A tall phone, so every deck is on screen.
      await openProject(tester, project, size: const Size(390, 1400));

      Finder metric(String key, String value) => find.descendant(
        of: find.byKey(Key('projectScreen.metric.$key')),
        matching: find.text(value),
      );
      expect(metric('correct', '57%'), findsOneWidget);
      expect(metric('errors', '3'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('projectScreen.reviewErrors')),
          matching: find.text('Repasar errores (3)'),
        ),
        findsOneWidget,
      );
      Finder errorsOf(Deck deck) =>
          find.byKey(Key('deckTile.${deck.id}.errors'));
      expect(
        find.descendant(of: errorsOf(verbs), matching: find.text('2 errores')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: errorsOf(phrasal), matching: find.text('1 error')),
        findsOneWidget,
      );
      expect(errorsOf(travel), findsNothing);
      // The language pair moved to the details line (decided with the
      // owner), so the errors chip takes the design's place.
      String detailsOf(Deck deck) => tester
          .widget<Text>(find.byKey(Key('deckTile.${deck.id}.details')))
          .textSpan!
          .toPlainText(includeSemanticsLabels: false);
      expect(detailsOf(verbs), '2 tarjetas · 33% aciertos · EN → ES');
      expect(detailsOf(travel), '1 tarjeta · 100% aciertos');
    });

    testWidgets('with no errors, "Repasar errores" is not shown', (
      tester,
    ) async {
      final project = await createEnglish();
      final deck = await createDeck(project, 'Verbos');
      await addTestAnswers(
        db,
        projectId: project.id,
        cardId: await addTestCard(db, deck.id),
        results: ['correct'],
      );

      await openProject(tester, project);

      expect(find.byKey(const Key('projectScreen.reviewErrors')), findsNothing);
      expect(find.byKey(Key('deckTile.${deck.id}.errors')), findsNothing);
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

    testWidgets('the header shows % correct and "Repasar errores (1)"', (
      tester,
    ) async {
      final project = await createEnglish();
      final deck = await createDeck(project, 'Verbos');
      await addTestAnswers(
        db,
        projectId: project.id,
        cardId: await addTestCard(db, deck.id),
        results: ['correct', 'wrong'],
      );

      await openProject(tester, project, size: desktop);

      expect(
        find.text('Nivel intermedio alto · 1 tarjeta · 50% aciertos'),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('projectScreen.reviewErrors')),
          matching: find.text('Repasar errores (1)'),
        ),
        findsOneWidget,
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
