import 'package:drift/drift.dart' show Value;
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

  group('selection (T2.9)', () {
    late Deck classNotes;
    late Deck trashed;
    late Deck otherProjectDeck;

    setUp(() async {
      // Same project: a general deck and a deck in the trash.
      classNotes = await decks.create(
        project.id,
        const DeckInput(name: 'Notas de clase'),
      );
      trashed = await decks.create(
        project.id,
        const DeckInput(name: 'Borrada'),
      );
      await (db.update(db.decks)..where((d) => d.id.equals(trashed.id))).write(
        DecksCompanion(deletedAt: Value(clock.now())),
      );
      final biology = await ProjectsRepository(ProjectsDao(db), clock).create(
        const ProjectInput(name: 'Biología', color: 'green', icon: 'flask'),
      );
      otherProjectDeck = await decks.create(
        biology.id,
        const DeckInput(name: 'Célula'),
      );
    });

    Finder select(Flashcard card) =>
        find.byKey(Key('cardRow.${card.id}.select'));
    final bar = find.byKey(const Key('deckScreen.selectionBar'));

    Future<List<String>> storedIdsIn(Deck deck) async => [
      for (final row in await (db.select(
        db.cards,
      )..where((c) => c.deckId.equals(deck.id))).get())
        row.id,
    ];

    testWidgets('a long press starts selecting on mobile', (tester) async {
      final bring = await addSimple('to bring', 'traer');
      final seek = await addSimple('to seek', 'buscar');
      await openDeck(tester);
      expect(select(bring), findsNothing);
      expect(bar, findsNothing);

      await tester.longPress(row(bring));
      await tester.pumpAndSettle();
      expect(find.text('1 seleccionada'), findsOneWidget);

      // While selecting, a tap selects instead of opening the card.
      await tester.tap(row(seek));
      await tester.pumpAndSettle();
      expect(find.text('2 seleccionadas'), findsOneWidget);
      expect(find.byKey(const Key('screen.editCard')), findsNothing);

      await tester.tap(row(seek));
      await tester.pumpAndSettle();
      expect(find.text('1 seleccionada'), findsOneWidget);

      await tester.tap(find.byKey(const Key('deckScreen.clearSelection')));
      await tester.pumpAndSettle();
      expect(bar, findsNothing);
      expect(select(bring), findsNothing);
    });

    testWidgets('desktop rows have checkboxes, and the heading one selects '
        'all', (tester) async {
      final bring = await addSimple('to bring', 'traer');
      final seek = await addSimple('to seek', 'buscar');
      await openDeck(tester, size: desktop);

      await tester.tap(select(bring));
      await tester.pumpAndSettle();
      expect(find.text('1 seleccionada'), findsOneWidget);

      await tester.tap(find.byKey(const Key('deckScreen.selectAll')));
      await tester.pumpAndSettle();
      expect(find.text('2 seleccionadas'), findsOneWidget);

      await tester.tap(find.byKey(const Key('deckScreen.selectAll')));
      await tester.pumpAndSettle();
      expect(bar, findsNothing);
      expect(tester.widget<Checkbox>(select(seek)).value, isFalse);
    });

    testWidgets('"Mover a…" only offers decks from the same project, of '
        'either type', (tester) async {
      final bring = await addSimple('to bring', 'traer');
      final seek = await addSimple('to seek', 'buscar');
      await openDeck(tester);
      await tester.longPress(row(bring));
      await tester.pumpAndSettle();
      await tester.tap(row(seek));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('deckScreen.moveTo')));
      await tester.pumpAndSettle();

      expect(find.text('Mover a…'), findsOneWidget);
      Finder option(Deck deck) => find.byKey(Key('deckPicker.${deck.id}'));
      expect(option(classNotes), findsOneWidget);
      // Not the deck the cards are in, not a deck in the trash and not a
      // deck of another project.
      expect(option(verbs), findsNothing);
      expect(option(trashed), findsNothing);
      expect(option(otherProjectDeck), findsNothing);

      await tester.tap(option(classNotes));
      await tester.pumpAndSettle();
      // A general deck: the app warns first (see the tests below).
      await tester.tap(find.byKey(const Key('confirmDialog.confirm')));
      await tester.pumpAndSettle();

      expect(row(bring), findsNothing);
      expect(row(seek), findsNothing);
      expect(bar, findsNothing);
      expect(
        find.text('2 tarjetas movidas a «Notas de clase»'),
        findsOneWidget,
      );
      expect(
        await storedIdsIn(classNotes),
        unorderedEquals([bring.id, seek.id]),
      );
    });

    testWidgets('"Copiar a…" leaves the cards and creates copies', (
      tester,
    ) async {
      final bring = await addSimple('to bring', 'traer');
      await openDeck(tester, size: desktop);

      await tester.tap(find.byKey(Key('cardRow.${bring.id}.menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Copiar a…'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(Key('deckPicker.${classNotes.id}')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirmDialog.confirm')));
      await tester.pumpAndSettle();

      expect(row(bring), findsOneWidget);
      expect(find.text('Tarjeta copiada a «Notas de clase»'), findsOneWidget);
      final [copyId] = await storedIdsIn(classNotes);
      expect(copyId, isNot(bring.id));
    });

    group('warning for another type or other languages', () {
      late Deck phrasal;

      setUp(() async {
        // A language deck with the same languages as `verbs`.
        phrasal = await decks.create(
          project.id,
          const DeckInput(
            name: 'Phrasal verbs',
            type: DeckType.language,
            sourceLang: 'en-GB',
            targetLang: 'es-ES',
          ),
        );
      });

      Future<void> moveToWithMenu(
        WidgetTester tester,
        Flashcard card,
        Deck target, {
        String action = 'Mover a…',
      }) async {
        await tester.tap(find.byKey(Key('cardRow.${card.id}.menu')));
        await tester.pumpAndSettle();
        await tester.tap(find.text(action));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(Key('deckPicker.${target.id}')));
        await tester.pumpAndSettle();
      }

      testWidgets('moving to a general deck says the example and notes will '
          'be hidden; cancelling keeps the card', (tester) async {
        final bring = await cards.create(
          verbs.id,
          const CardInput(
            type: CardType.simple,
            question: 'to bring',
            answer: 'traer',
            example: 'Can you bring me some water?',
          ),
        );
        await openDeck(tester, size: desktop);

        await moveToWithMenu(tester, bring, classNotes);

        expect(
          find.text('¿Mover 1 tarjeta a «Notas de clase»?'),
          findsOneWidget,
        );
        expect(
          find.textContaining(
            'el ejemplo y las notas de 1 tarjeta se ocultarán (no se borran)',
          ),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const Key('confirmDialog.cancel')));
        await tester.pumpAndSettle();

        expect(row(bring), findsOneWidget);
        expect(await storedIdsIn(verbs), [bring.id]);
      });

      testWidgets('a deck with the same type and languages needs no warning', (
        tester,
      ) async {
        final bring = await addSimple('to bring', 'traer');
        await openDeck(tester, size: desktop);

        await moveToWithMenu(tester, bring, phrasal);

        expect(find.byKey(const Key('confirmDialog')), findsNothing);
        expect(await storedIdsIn(phrasal), [bring.id]);
      });

      testWidgets('copying from a general deck to a language one names its '
          'languages', (tester) async {
        final cell = await cards.create(
          classNotes.id,
          const CardInput(
            type: CardType.simple,
            question: 'Célula',
            answer: 'Unidad de vida',
          ),
        );
        await openDeck(tester, size: desktop, deck: classNotes);

        await moveToWithMenu(tester, cell, verbs, action: 'Copiar a…');

        expect(
          find.text('¿Copiar 1 tarjeta a «Verbos irregulares»?'),
          findsOneWidget,
        );
        expect(
          find.textContaining('Es una baraja de idioma (EN → ES)'),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const Key('confirmDialog.confirm')));
        await tester.pumpAndSettle();

        expect(await storedIdsIn(verbs), hasLength(1));
      });

      testWidgets('between language decks with other languages, it names '
          'both pairs', (tester) async {
        final definitions = await decks.create(
          project.id,
          const DeckInput(
            name: 'Definitions',
            type: DeckType.language,
            sourceLang: 'en-GB',
            targetLang: 'en-GB',
          ),
        );
        final bring = await addSimple('to bring', 'traer');
        await openDeck(tester, size: desktop);

        await moveToWithMenu(tester, bring, definitions);

        expect(
          find.textContaining('Los idiomas cambian de EN → ES a EN → EN'),
          findsOneWidget,
        );
      });
    });

    testWidgets('with no other decks, the picker says so', (tester) async {
      final notes = await addSimple('to bring', 'traer');
      // The only other deck of the project goes to the trash too.
      await (db.update(db.decks)..where((d) => d.id.equals(classNotes.id)))
          .write(DecksCompanion(deletedAt: Value(clock.now())));
      await openDeck(tester, size: desktop);

      await tester.tap(find.byKey(Key('cardRow.${notes.id}.menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mover a…'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('deckPicker.empty')), findsOneWidget);
      expect(
        find.text('No hay otras barajas en este proyecto'),
        findsOneWidget,
      );
    });

    testWidgets('deleting cards and tapping "Deshacer" recovers them', (
      tester,
    ) async {
      final bring = await addSimple('to bring', 'traer', correct: 3);
      final seek = await addSimple('to seek', 'buscar');
      await openDeck(tester);
      await tester.longPress(row(bring));
      await tester.pumpAndSettle();
      await tester.tap(row(seek));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('deckScreen.deleteSelected')));
      await tester.pumpAndSettle();
      expect(find.text('¿Eliminar 2 tarjetas?'), findsOneWidget);
      await tester.tap(find.byKey(const Key('confirmDialog.confirm')));
      await tester.pumpAndSettle();

      expect(row(bring), findsNothing);
      expect(find.text('2 tarjetas eliminadas'), findsOneWidget);

      await tester.tap(find.text('Deshacer'));
      await tester.pumpAndSettle();

      expect(row(bring), findsOneWidget);
      expect(row(seek), findsOneWidget);
      expect(inRow(bring, '100%'), findsOneWidget);
      expect(await storedIdsIn(verbs), hasLength(2));
    });

    testWidgets('without "Deshacer", deleted cards are gone for good', (
      tester,
    ) async {
      final bring = await addSimple('to bring', 'traer');
      final seek = await addSimple('to seek', 'buscar');
      await openDeck(tester, size: desktop);

      await tester.tap(find.byKey(Key('cardRow.${bring.id}.menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Eliminar'));
      await tester.pumpAndSettle();
      expect(find.text('¿Eliminar 1 tarjeta?'), findsOneWidget);
      await tester.tap(find.byKey(const Key('confirmDialog.confirm')));
      await tester.pumpAndSettle();
      expect(row(bring), findsNothing);
      expect(find.text('Tarjeta eliminada'), findsOneWidget);

      // The snackbar lasts 5 seconds.
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();

      expect(find.text('Tarjeta eliminada'), findsNothing);
      expect(await storedIdsIn(verbs), [seek.id]);
      expect(row(bring), findsNothing);
    });

    testWidgets('cancelling the deletion keeps the cards selected', (
      tester,
    ) async {
      final bring = await addSimple('to bring', 'traer');
      await openDeck(tester);
      await tester.longPress(row(bring));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('deckScreen.deleteSelected')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirmDialog.cancel')));
      await tester.pumpAndSettle();

      expect(row(bring), findsOneWidget);
      expect(find.text('1 seleccionada'), findsOneWidget);
    });
  });
}
