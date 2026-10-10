import 'package:estudicards/app/router.dart';
import 'package:estudicards/core/clock.dart';
import 'package:estudicards/core/db/app_database.dart';
import 'package:estudicards/features/cards/data/cards_dao.dart';
import 'package:estudicards/features/cards/data/cards_repository.dart';
import 'package:estudicards/features/cards/domain/card_input.dart';
import 'package:estudicards/features/cards/domain/flashcard.dart';
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

import '../../../helpers/fake_image_files.dart';
import '../../../helpers/test_app.dart';
import '../../../helpers/test_data.dart';

void main() {
  late AppDatabase db;
  late FakeClock clock;
  late CardsRepository cards;
  late DecksRepository decks;
  late Project project;
  late Deck verbs;

  setUp(() async {
    db = createTestDatabase();
    clock = FakeClock(DateTime.utc(2026, 10, 6, 12));
    cards = CardsRepository(CardsDao(db), clock, FakeImageFiles());
    decks = DecksRepository(DecksDao(db), clock);
    project = await ProjectsRepository(ProjectsDao(db), clock).create(
      const ProjectInput(name: 'Inglés B2', color: 'blue', icon: 'globe'),
    );
    verbs = await decks.create(
      project.id,
      const DeckInput(
        name: 'Verbos irregulares',
        type: DeckType.language,
        sourceLang: 'en-GB',
        targetLang: 'es-ES',
      ),
    );
  });

  /// Creates a simple card a minute after the previous one, with its
  /// results.
  Future<Flashcard> addSimple(
    String question,
    String answer, {
    int correct = 0,
    int wrong = 0,
    DateTime? reviewedAt,
  }) async {
    final card = await cards.create(
      verbs.id,
      CardInput(type: CardType.simple, question: question, answer: answer),
    );
    if (correct + wrong > 0) {
      await addTestStats(
        db,
        card.id,
        correct: correct,
        wrong: wrong,
        lastAttemptAt: reviewedAt ?? clock.now(),
      );
    }
    clock.advance(const Duration(minutes: 1));
    return card;
  }

  Future<Flashcard> addTest() async {
    final card = await cards.create(
      verbs.id,
      const CardInput(
        type: CardType.test,
        question: '¿Qué verbos son irregulares?',
        allowMultiple: true,
        options: [
          CardOptionInput(text: 'go', isCorrect: true),
          CardOptionInput(text: 'walk'),
          CardOptionInput(text: 'eat', isCorrect: true),
        ],
      ),
    );
    await addTestStats(
      db,
      card.id,
      correct: 6,
      wrong: 5,
      lastAttemptAt: clock.now().subtract(const Duration(days: 1)),
    );
    clock.advance(const Duration(minutes: 1));
    return card;
  }

  Future<void> openDeck(
    WidgetTester tester, {
    Size size = mobile,
    Deck? deck,
  }) => pumpTestApp(
    tester,
    size: size,
    db: db,
    clock: clock,
    location: AppRoutes.deck(project.id, (deck ?? verbs).id),
  );

  Finder row(Flashcard card) => find.byKey(Key('cardRow.${card.id}'));
  Finder inRow(Flashcard card, String text) =>
      find.descendant(of: row(card), matching: find.text(text));
  final search = find.byKey(const Key('deckScreen.search'));

  /// The cards' questions in the order shown, top to bottom.
  List<String> shownOrder(WidgetTester tester, List<Flashcard> all) {
    final shown =
        [
          for (final card in all)
            if (tester.any(row(card))) card,
        ]..sort(
          (a, b) => tester
              .getTopLeft(row(a))
              .dy
              .compareTo(tester.getTopLeft(row(b)).dy),
        );
    return [for (final card in shown) card.question];
  }

  /// Picks a sort order: a menu on mobile, a segmented control on desktop.
  Future<void> chooseSort(WidgetTester tester, String name) async {
    final menu = find.byKey(const Key('deckScreen.sort'));
    if (tester.any(menu)) {
      await tester.tap(menu);
      await tester.pumpAndSettle();
    }
    await tester.tap(find.byKey(Key('deckScreen.sort.$name')).last);
    await tester.pumpAndSettle();
  }

  group('mobile', () {
    testWidgets('the list shows each card with its type and % correct', (
      tester,
    ) async {
      final bring = await addSimple('to bring', 'traer', correct: 11, wrong: 1);
      final irregular = await addTest();
      final bind = await addSimple('to bind', 'atar');

      await openDeck(tester);

      expect(find.byKey(const Key('screen.deck')), findsOneWidget);
      expect(inRow(bring, 'Simple'), findsOneWidget);
      expect(inRow(bring, '92%'), findsOneWidget);
      expect(inRow(irregular, 'Test'), findsOneWidget);
      expect(inRow(irregular, '55%'), findsOneWidget);
      // Never studied.
      expect(inRow(bind, '—'), findsOneWidget);
      // Newest first by default.
      expect(shownOrder(tester, [bring, irregular, bind]), [
        'to bind',
        '¿Qué verbos son irregulares?',
        'to bring',
      ]);
    });

    testWidgets('the header shows the project, the language pair, the cards '
        'and the % correct', (tester) async {
      await addSimple('to bring', 'traer', correct: 11, wrong: 1);
      await addTest();
      await addSimple('to bind', 'atar');

      await openDeck(tester);

      expect(find.text('Verbos irregulares'), findsOneWidget);
      // 17 correct and 6 wrong answers: 74%.
      expect(
        find.text('Inglés B2 · EN → ES · 3 tarjetas · 74% aciertos'),
        findsOneWidget,
      );
    });

    testWidgets('search filters as you type', (tester) async {
      final bring = await addSimple('to bring', 'traer');
      final irregular = await addTest();
      final bind = await addSimple('to bind', 'atar');
      await openDeck(tester);

      await tester.enterText(search, 'irreg');
      await tester.pumpAndSettle();
      expect(row(irregular), findsOneWidget);
      expect(row(bring), findsNothing);
      expect(row(bind), findsNothing);

      // The answer and the options count, ignoring case.
      await tester.enterText(search, 'TRAER');
      await tester.pumpAndSettle();
      expect(row(bring), findsOneWidget);
      expect(row(irregular), findsNothing);

      await tester.enterText(search, 'xyz');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('deckScreen.noResults')), findsOneWidget);
      expect(find.text('Ninguna tarjeta coincide con «xyz»'), findsOneWidget);

      await tester.enterText(search, '');
      await tester.pumpAndSettle();
      expect(row(bring), findsOneWidget);
      expect(row(irregular), findsOneWidget);
      expect(row(bind), findsOneWidget);
    });

    testWidgets('the sort menu changes the order', (tester) async {
      final bring = await addSimple('to bring', 'traer', correct: 1, wrong: 6);
      final arise = await addSimple('to arise', 'surgir', wrong: 4);
      final irregular = await addTest();
      await openDeck(tester);

      await chooseSort(tester, 'alphabetical');
      expect(shownOrder(tester, [bring, arise, irregular]), [
        '¿Qué verbos son irregulares?',
        'to arise',
        'to bring',
      ]);

      // 6, 5 and 4 misses.
      await chooseSort(tester, 'mostMissed');
      expect(shownOrder(tester, [bring, arise, irregular]), [
        'to bring',
        '¿Qué verbos son irregulares?',
        'to arise',
      ]);

      await chooseSort(tester, 'newest');
      expect(shownOrder(tester, [bring, arise, irregular]), [
        '¿Qué verbos son irregulares?',
        'to arise',
        'to bring',
      ]);
    });

    testWidgets('with no cards, the empty state is shown', (tester) async {
      await openDeck(tester);

      expect(find.byKey(const Key('deckScreen.empty')), findsOneWidget);
      expect(find.text('Añade tu primera tarjeta'), findsOneWidget);
      // Importing arrives in phase 5 (decided with the owner).
      expect(find.textContaining('CSV'), findsNothing);
      expect(find.textContaining('plantilla'), findsNothing);
      expect(search, findsNothing);
    });

    testWidgets('tapping a card opens it in the editor', (tester) async {
      final bring = await addSimple('to bring', 'traer');
      await openDeck(tester);

      await tester.tap(row(bring));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('screen.editCard')), findsOneWidget);
    });

    testWidgets('"Añadir tarjeta" opens the editor for a new card', (
      tester,
    ) async {
      await openDeck(tester);

      await tester.tap(find.byKey(const Key('deckScreen.addCard')).first);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('screen.newCard')), findsOneWidget);
    });

    testWidgets('a general deck shows no language pair', (tester) async {
      final notes = await decks.create(
        project.id,
        const DeckInput(name: 'Notas de clase'),
      );

      await openDeck(tester, deck: notes);

      expect(find.text('Inglés B2 · 0 tarjetas · — aciertos'), findsOneWidget);
    });

    testWidgets('"Eliminar baraja" in the menu goes back to the project', (
      tester,
    ) async {
      await openDeck(tester);

      await tester.tap(find.byKey(const Key('deckScreen.menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Eliminar baraja'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirmDialog.confirm')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('screen.project')), findsOneWidget);
      expect((await decks.getById(verbs.id))!.id, verbs.id);
      expect(find.text('Deshacer'), findsOneWidget);
    });

    testWidgets('an unknown deck shows a message', (tester) async {
      await pumpTestApp(
        tester,
        size: mobile,
        db: db,
        clock: clock,
        location: AppRoutes.deck(project.id, 'missing'),
      );

      expect(find.byKey(const Key('deckScreen.notFound')), findsOneWidget);
      expect(find.text('Esta baraja ya no existe'), findsOneWidget);
    });
  });

  group('desktop', () {
    testWidgets('the cards are a table with results and the last review', (
      tester,
    ) async {
      final bring = await addSimple('to bring', 'traer', correct: 11, wrong: 1);
      final irregular = await addTest();
      final bind = await addSimple('to bind', 'atar');

      await openDeck(tester, size: desktop);

      for (final column in [
        'PREGUNTA',
        'TIPO',
        'ACIERTOS',
        'FALLOS',
        '% ACIERTOS',
        'ÚLTIMO REPASO',
      ]) {
        expect(find.text(column), findsOneWidget, reason: column);
      }
      expect(inRow(bring, '11'), findsOneWidget);
      expect(inRow(bring, '1'), findsOneWidget);
      expect(inRow(bring, '92%'), findsOneWidget);
      expect(inRow(bring, 'Hoy'), findsOneWidget);
      expect(inRow(irregular, 'Ayer'), findsOneWidget);
      expect(inRow(bind, 'Nunca'), findsOneWidget);
      expect(find.text('EN → ES · 3 tarjetas · 74% aciertos'), findsOneWidget);
    });

    testWidgets('the segmented control changes the order', (tester) async {
      final arise = await addSimple('to arise', 'surgir');
      final bring = await addSimple('to bring', 'traer');
      await openDeck(tester, size: desktop);

      expect(shownOrder(tester, [bring, arise]), ['to bring', 'to arise']);
      await chooseSort(tester, 'alphabetical');
      expect(shownOrder(tester, [bring, arise]), ['to arise', 'to bring']);
      await chooseSort(tester, 'newest');
      expect(shownOrder(tester, [bring, arise]), ['to bring', 'to arise']);
    });

    testWidgets('a review days ago says how many', (tester) async {
      final seek = await addSimple(
        'to seek',
        'buscar',
        correct: 1,
        reviewedAt: clock.now().subtract(const Duration(days: 3)),
      );
      await openDeck(tester, size: desktop);

      expect(inRow(seek, 'Hace 3 días'), findsOneWidget);
    });
  });
}
