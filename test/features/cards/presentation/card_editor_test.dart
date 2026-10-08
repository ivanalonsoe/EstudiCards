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
import 'card_editor_finders.dart';

void main() {
  late AppDatabase db;
  late FakeClock clock;
  late CardsRepository cards;
  late Project general;
  late Project language;
  late Deck constitution;
  late Deck verbs;

  setUp(() async {
    db = createTestDatabase();
    clock = FakeClock(DateTime.utc(2026, 10, 6, 12));
    cards = CardsRepository(CardsDao(db), clock, FakeImageFiles());
    final projects = ProjectsRepository(ProjectsDao(db), clock);
    final decks = DecksRepository(DecksDao(db), clock);
    general = await projects.create(
      const ProjectInput(
        name: 'Oposiciones · Tema 3',
        color: 'orange',
        icon: 'scales',
      ),
    );
    language = await projects.create(
      const ProjectInput(
        name: 'Inglés B2',
        color: 'blue',
        icon: 'globe',
        type: ProjectType.language,
        sourceLang: 'en-GB',
        targetLang: 'es-ES',
      ),
    );
    constitution = await decks.create(
      general.id,
      const DeckInput(name: 'Constitución'),
    );
    verbs = await decks.create(
      language.id,
      const DeckInput(name: 'Verbos irregulares'),
    );
  });

  Future<void> openNewCard(
    WidgetTester tester, {
    Deck? deck,
    Size size = mobile,
  }) {
    final target = deck ?? constitution;
    return pumpTestApp(
      tester,
      size: size,
      db: db,
      clock: clock,
      location: AppRoutes.newCard(target.projectId, target.id),
    );
  }

  /// The cards in the database, read with a plain query (see
  /// `test/helpers/test_app.dart`).
  Future<List<Flashcard>> storedCards() async {
    final rows = await db.select(db.cards).get();
    return [for (final row in rows) (await cards.getById(row.id))!];
  }

  group('simple card', () {
    testWidgets('Save is disabled without a question or without an answer', (
      tester,
    ) async {
      await openNewCard(tester);

      expect(find.byKey(const Key('cardEditor')), findsOneWidget);
      expect(isEnabled(tester, saveButton), isFalse);

      await tester.enterText(questionField, '¿Qué órgano ejerce la potestad?');
      await tester.pump();
      expect(isEnabled(tester, saveButton), isFalse);

      await tester.enterText(answerField, 'Las Cortes Generales');
      await tester.pump();
      expect(isEnabled(tester, saveButton), isTrue);
      expect(isEnabled(tester, saveAndAddButton), isTrue);

      await tester.enterText(questionField, '   ');
      await tester.pump();
      expect(isEnabled(tester, saveButton), isFalse);
      expect(isEnabled(tester, saveAndAddButton), isFalse);
    });

    testWidgets('"Guardar" saves the card and goes back to the deck', (
      tester,
    ) async {
      await openNewCard(tester);

      await tester.enterText(
        questionField,
        ' ¿Qué órgano ejerce la potestad? ',
      );
      await tester.enterText(answerField, 'Las Cortes Generales');
      await tester.pump();
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      final [card] = await storedCards();
      expect(card.deckId, constitution.id);
      expect(card.type, CardType.simple);
      expect(card.question, '¿Qué órgano ejerce la potestad?');
      expect(card.answer, 'Las Cortes Generales');
      expect(find.byKey(const Key('cardEditor')), findsNothing);
      expect(find.byKey(const Key('screen.deck')), findsOneWidget);
    });

    testWidgets('"Guardar y añadir otra" clears the form, keeps the type and '
        'focuses the question', (tester) async {
      await openNewCard(tester);

      await tester.enterText(questionField, 'to bring');
      await tester.enterText(answerField, 'traer');
      await tester.pump();
      await tester.tap(saveAndAddButton);
      await tester.pumpAndSettle();

      expect((await storedCards()).single.question, 'to bring');
      expect(find.byKey(const Key('cardEditor')), findsOneWidget);
      expect(fieldText(tester, questionField), isEmpty);
      expect(fieldText(tester, answerField), isEmpty);
      expect(answerField, findsOneWidget, reason: 'still a simple card');
      expect(hasFocus(tester, questionField), isTrue);
      expect(find.text('Tarjeta guardada'), findsOneWidget);
      expect(isEnabled(tester, saveButton), isFalse);
    });

    testWidgets('the formatting bar makes the selected text bold or italic', (
      tester,
    ) async {
      await openNewCard(tester);
      await tester.enterText(questionField, 'Can you bring me some water?');
      setSelection(tester, questionField, 8, 13);

      await tester.tap(find.byKey(const Key('cardEditor.question.bold')));
      await tester.pump();
      expect(
        fieldText(tester, questionField),
        'Can you **bring** me some water?',
      );

      setSelection(tester, questionField, 21, 25);
      await tester.tap(find.byKey(const Key('cardEditor.question.italic')));
      await tester.pump();
      expect(
        fieldText(tester, questionField),
        'Can you **bring** me *some* water?',
      );
    });

    testWidgets('editing loads the card and saves the changes', (tester) async {
      final card = await cards.create(
        constitution.id,
        const CardInput(
          type: CardType.simple,
          question: '¿Qué órgano ejerce la potestad legislativa?',
          answer: 'Las Cortes',
        ),
      );
      await pumpTestApp(
        tester,
        size: mobile,
        db: db,
        clock: clock,
        location: AppRoutes.editCard(general.id, constitution.id, card.id),
      );

      expect(find.text('Editar tarjeta'), findsOneWidget);
      expect(fieldText(tester, answerField), 'Las Cortes');
      // "Guardar y añadir otra" is only for new cards.
      expect(saveAndAddButton, findsNothing);

      await tester.enterText(answerField, 'Las Cortes Generales');
      await tester.pump();
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      final [stored] = await storedCards();
      expect(stored.id, card.id);
      expect(stored.answer, 'Las Cortes Generales');
    });

    testWidgets('an unknown card shows that it no longer exists', (
      tester,
    ) async {
      await pumpTestApp(
        tester,
        size: mobile,
        db: db,
        clock: clock,
        location: AppRoutes.editCard(general.id, constitution.id, 'missing'),
      );

      expect(find.text('Esta tarjeta ya no existe'), findsOneWidget);
    });
  });

  group('language fields', () {
    testWidgets('in a general project, "Frase de ejemplo" and "Notas" are not '
        'shown', (tester) async {
      await openNewCard(tester);

      expect(find.text('Pregunta'), findsOneWidget);
      expect(find.text('Respuesta'), findsOneWidget);
      expect(exampleField, findsNothing);
      expect(notesField, findsNothing);
    });

    testWidgets('a language project shows them and saves them', (tester) async {
      await openNewCard(tester, deck: verbs);

      expect(find.text('Palabra o pregunta'), findsOneWidget);
      expect(find.text('Traducción o respuesta'), findsOneWidget);
      expect(find.text('Frase de ejemplo (opcional)'), findsOneWidget);
      expect(find.text('Notas (opcional)'), findsOneWidget);

      await tester.enterText(questionField, 'to bring');
      await tester.enterText(answerField, 'traer');
      await tester.enterText(exampleField, 'Can you **bring** me some water?');
      await tester.enterText(notesField, 'Verbo irregular');
      await tester.pump();
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      final [card] = await storedCards();
      expect(card.example, 'Can you **bring** me some water?');
      expect(card.notes, 'Verbo irregular');
    });
  });

  group('leaving', () {
    testWidgets('closing with no changes does not ask', (tester) async {
      await openNewCard(tester);

      await tester.tap(closeButton);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('confirmDialog')), findsNothing);
      expect(find.byKey(const Key('screen.deck')), findsOneWidget);
    });

    testWidgets('closing with changes asks before discarding them', (
      tester,
    ) async {
      await openNewCard(tester);
      await tester.enterText(questionField, 'to bring');
      await tester.pump();

      await tester.tap(closeButton);
      await tester.pumpAndSettle();
      expect(find.text('¿Descartar los cambios?'), findsOneWidget);

      // "Cancelar" keeps editing.
      await tester.tap(find.byKey(const Key('confirmDialog.cancel')));
      await tester.pumpAndSettle();
      expect(fieldText(tester, questionField), 'to bring');

      await tester.tap(closeButton);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirmDialog.confirm')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('screen.deck')), findsOneWidget);
      expect(await storedCards(), isEmpty);
    });
  });

  testWidgets('on desktop the actions are in the header, next to the sidebar', (
    tester,
  ) async {
    await openNewCard(tester, size: desktop);

    expect(find.byKey(const Key('shell.sidebar')), findsOneWidget);
    expect(find.text('Nueva tarjeta'), findsWidgets);
    expect(cancelButton, findsOneWidget);
    expect(saveAndAddButton, findsOneWidget);

    await tester.tap(cancelButton);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('screen.deck')), findsOneWidget);
  });

  testWidgets('"Añadir tarjeta" on the deck screen opens the editor', (
    tester,
  ) async {
    await pumpTestApp(
      tester,
      size: mobile,
      db: db,
      clock: clock,
      location: AppRoutes.deck(general.id, constitution.id),
    );

    await tester.tap(find.byKey(const Key('deckScreen.addCard')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('cardEditor')), findsOneWidget);
    expect(find.text('Nueva tarjeta'), findsOneWidget);
  });
}
