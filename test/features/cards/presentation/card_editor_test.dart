import 'dart:io';
import 'dart:typed_data';

import 'package:estudicards/app/router.dart';
import 'package:estudicards/core/clock.dart';
import 'package:estudicards/core/db/app_database.dart';
import 'package:estudicards/core/files/image_source.dart';
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
import '../../../helpers/fake_image_source.dart';
import '../../../helpers/fake_voice.dart';
import '../../../helpers/load_images.dart';
import '../../../helpers/test_app.dart';
import '../../../helpers/test_images.dart';
import 'card_editor_finders.dart';

void main() {
  late AppDatabase db;
  late FakeClock clock;
  late CardsRepository cards;
  late Project general;
  late Project english;
  late Deck constitution;

  /// A language deck (English → Spanish) of "Inglés B2".
  late Deck verbs;

  /// A general deck of the same project.
  late Deck classNotes;

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
    english = await projects.create(
      const ProjectInput(name: 'Inglés B2', color: 'blue', icon: 'globe'),
    );
    constitution = await decks.create(
      general.id,
      const DeckInput(name: 'Constitución'),
    );
    verbs = await decks.create(
      english.id,
      const DeckInput(
        name: 'Verbos irregulares',
        type: DeckType.language,
        sourceLang: 'en-GB',
        targetLang: 'es-ES',
      ),
    );
    classNotes = await decks.create(
      english.id,
      const DeckInput(name: 'Notas de clase'),
    );
  });

  Future<void> openNewCard(
    WidgetTester tester, {
    Deck? deck,
    Size size = mobile,
    Directory? imagesFolder,
    ImageSource? imageSource,
  }) {
    final target = deck ?? constitution;
    return pumpTestApp(
      tester,
      size: size,
      db: db,
      clock: clock,
      location: AppRoutes.newCard(target.projectId, target.id),
      imagesFolder: imagesFolder,
      imageSource: imageSource,
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

    for (final size in [mobile, desktop]) {
      testWidgets('"Eliminar tarjeta" deletes it with "Deshacer" and goes '
          'back to the deck (${size.width.toInt()} px)', (tester) async {
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
          size: size,
          db: db,
          clock: clock,
          location: AppRoutes.editCard(general.id, constitution.id, card.id),
        );

        await tester.tap(find.byKey(const Key('cardEditor.delete')));
        await tester.pumpAndSettle();
        expect(find.text('¿Eliminar 1 tarjeta?'), findsOneWidget);
        await tester.tap(find.byKey(const Key('confirmDialog.confirm')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('screen.deck')), findsOneWidget);
        expect(find.byKey(Key('cardRow.${card.id}')), findsNothing);
        expect(find.text('Tarjeta eliminada'), findsOneWidget);

        await tester.pump(const Duration(seconds: 6));
        await tester.pumpAndSettle();
        expect(await storedCards(), isEmpty);
      });
    }

    testWidgets('a new card has no "Eliminar tarjeta"', (tester) async {
      await openNewCard(tester);

      expect(find.byKey(const Key('cardEditor.delete')), findsNothing);
    });
  });

  group('test card', () {
    /// Fills the options from [texts] (more than 4 adds options first).
    Future<void> fillOptions(WidgetTester tester, List<String> texts) async {
      for (final (i, text) in texts.indexed) {
        if (i >= optionCount()) {
          await tapVisible(tester, addOptionButton);
          await tester.pump();
        }
        await tester.ensureVisible(optionField(i));
        await tester.enterText(optionField(i), text);
      }
      await tester.pump();
    }

    Future<void> tick(WidgetTester tester, int index) async {
      await tapVisible(tester, correctSelector(index));
      await tester.pump();
    }

    Future<void> turnOnTestType(WidgetTester tester) async {
      await tapVisible(tester, testTypeSwitch);
      await tester.pumpAndSettle();
    }

    testWidgets('turning on "Tipo test" replaces the answer with options and '
        'explanation', (tester) async {
      await openNewCard(tester);
      expect(answerField, findsOneWidget);
      expect(allowMultipleSwitch, findsNothing);

      await turnOnTestType(tester);

      expect(answerField, findsNothing);
      expect(optionCount(), 4);
      expect(explanationField, findsOneWidget);
      expect(allowMultipleSwitch, findsOneWidget);
      expect(find.text('4 de 6 · 0 correctas'), findsOneWidget);

      // Turning it off brings the answer back.
      await tapVisible(tester, testTypeSwitch);
      await tester.pumpAndSettle();
      expect(answerField, findsOneWidget);
      expect(optionCount(), 0);
    });

    testWidgets('you cannot add more than 6 options or remove below 2', (
      tester,
    ) async {
      await openNewCard(tester);
      await turnOnTestType(tester);

      await tapVisible(tester, addOptionButton);
      await tester.pump();
      await tester.tap(addOptionButton);
      await tester.pump();
      expect(optionCount(), 6);
      expect(isEnabled(tester, addOptionButton), isFalse);

      for (var i = 0; i < 4; i++) {
        await tapVisible(tester, removeOptionButton(0));
        await tester.pump();
      }
      expect(optionCount(), 2);
      expect(
        tester.widget<IconButton>(removeOptionButton(0)).onPressed,
        isNull,
      );
      expect(
        tester.widget<IconButton>(removeOptionButton(1)).onPressed,
        isNull,
      );
    });

    testWidgets('removing an option keeps the text of the others', (
      tester,
    ) async {
      await openNewCard(tester);
      await turnOnTestType(tester);
      await fillOptions(tester, ['Sídney', 'Canberra', 'Melbourne', 'Perth']);

      await tapVisible(tester, removeOptionButton(0));
      await tester.pump();

      expect(fieldText(tester, optionField(0)), 'Canberra');
      expect(fieldText(tester, optionField(2)), 'Perth');
    });

    testWidgets('with "allow multiple" off, ticking an option unticks the '
        'previous one', (tester) async {
      await openNewCard(tester);
      await turnOnTestType(tester);

      await tick(tester, 0);
      expect(isTicked(tester, 0), isTrue);

      await tick(tester, 2);
      expect(isTicked(tester, 2), isTrue);
      expect(isTicked(tester, 0), isFalse);
    });

    testWidgets('with "allow multiple" on, several options can be ticked', (
      tester,
    ) async {
      await openNewCard(tester);
      await turnOnTestType(tester);
      await tapVisible(tester, allowMultipleSwitch);
      await tester.pump();

      await tick(tester, 0);
      await tick(tester, 2);
      expect(isTicked(tester, 0), isTrue);
      expect(isTicked(tester, 2), isTrue);

      // Tapping a ticked option unticks it.
      await tick(tester, 0);
      expect(isTicked(tester, 0), isFalse);
    });

    testWidgets('turning off "allow multiple" with 2 ticked asks which one to '
        'keep', (tester) async {
      await openNewCard(tester);
      await turnOnTestType(tester);
      await fillOptions(tester, ['2', '4', '7', '9']);
      await tapVisible(tester, allowMultipleSwitch);
      await tester.pump();
      await tick(tester, 0);
      await tick(tester, 2);

      // "Cancelar" leaves everything as it was.
      await tapVisible(tester, allowMultipleSwitch);
      await tester.pumpAndSettle();
      expect(find.text('¿Qué opción es la correcta?'), findsOneWidget);
      await tester.tap(find.byKey(const Key('keepCorrectDialog.cancel')));
      await tester.pumpAndSettle();
      expect(tester.widget<SwitchListTile>(allowMultipleSwitch).value, isTrue);
      expect(isTicked(tester, 0) && isTicked(tester, 2), isTrue);

      // Choosing one keeps only that one and turns the option off.
      await tapVisible(tester, allowMultipleSwitch);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('keepCorrectDialog.option.2')));
      await tester.pumpAndSettle();
      expect(tester.widget<SwitchListTile>(allowMultipleSwitch).value, isFalse);
      expect(isTicked(tester, 2), isTrue);
      expect(isTicked(tester, 0), isFalse);
    });

    testWidgets('saves a test card with its options in order', (tester) async {
      await openNewCard(tester);
      await tester.enterText(questionField, '¿Qué números son primos?');
      await turnOnTestType(tester);
      await tapVisible(tester, allowMultipleSwitch);
      await tester.pump();
      await fillOptions(tester, ['2', '4', '7', '9']);
      await tick(tester, 0);
      await tick(tester, 2);
      await tester.ensureVisible(explanationField);
      await tester.enterText(
        explanationField,
        'Solo se dividen por 1 y por sí',
      );
      await tester.pump();
      expect(find.text('4 de 6 · 2 correctas'), findsOneWidget);

      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      final [card] = await storedCards();
      expect(card.type, CardType.test);
      expect(card.allowMultiple, isTrue);
      expect(card.answer, isNull);
      expect(card.explanation, 'Solo se dividen por 1 y por sí');
      expect(card.options.map((o) => o.text), ['2', '4', '7', '9']);
      expect(card.options.map((o) => o.isCorrect), [true, false, true, false]);
    });

    testWidgets('Save waits for 2 options and a correct one', (tester) async {
      await openNewCard(tester);
      await tester.enterText(questionField, '¿Capital de Australia?');
      await turnOnTestType(tester);

      await fillOptions(tester, ['Canberra']);
      await tick(tester, 0);
      expect(isEnabled(tester, saveButton), isFalse);
      expect(find.text('Escribe al menos 2 opciones'), findsOneWidget);

      await fillOptions(tester, ['Canberra', 'Sídney']);
      expect(isEnabled(tester, saveButton), isTrue);

      // The ticked option emptied: no correct option left.
      await tester.enterText(optionField(0), '');
      await tester.pump();
      expect(isEnabled(tester, saveButton), isFalse);
      expect(find.text('Marca la opción correcta'), findsOneWidget);
    });

    testWidgets('"Guardar y añadir otra" keeps the test type and "allow '
        'multiple"', (tester) async {
      await openNewCard(tester);
      await tester.enterText(questionField, '¿Qué números son primos?');
      await turnOnTestType(tester);
      await tapVisible(tester, allowMultipleSwitch);
      await tester.pump();
      await fillOptions(tester, ['2', '4']);
      await tick(tester, 0);

      await tester.tap(saveAndAddButton);
      await tester.pumpAndSettle();

      expect(await storedCards(), hasLength(1));
      expect(tester.widget<SwitchListTile>(testTypeSwitch).value, isTrue);
      expect(tester.widget<SwitchListTile>(allowMultipleSwitch).value, isTrue);
      expect(optionCount(), 4);
      expect(fieldText(tester, optionField(0)), isEmpty);
      expect(isTicked(tester, 0), isFalse);
    });

    testWidgets('editing a test card shows its options', (tester) async {
      final card = await cards.create(
        constitution.id,
        const CardInput(
          type: CardType.test,
          question: '¿Capital de Australia?',
          explanation: 'Desde 1913',
          options: [
            CardOptionInput(text: 'Sídney'),
            CardOptionInput(text: 'Canberra', isCorrect: true),
            CardOptionInput(text: 'Perth'),
          ],
        ),
      );
      await pumpTestApp(
        tester,
        size: mobile,
        db: db,
        clock: clock,
        location: AppRoutes.editCard(general.id, constitution.id, card.id),
      );

      expect(tester.widget<SwitchListTile>(testTypeSwitch).value, isTrue);
      expect(optionCount(), 3);
      expect(fieldText(tester, optionField(1)), 'Canberra');
      expect(isTicked(tester, 1), isTrue);
      expect(fieldText(tester, explanationField), 'Desde 1913');

      await fillOptions(tester, ['Sídney', 'Canberra', 'Perth', 'Melbourne']);
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      final [stored] = await storedCards();
      expect(stored.options.map((o) => o.text), [
        'Sídney',
        'Canberra',
        'Perth',
        'Melbourne',
      ]);
      // The options that were already there keep their ID.
      expect(stored.options[1].id, card.options[1].id);
    });
  });

  group('images', () {
    late Directory folder;
    late FakeImageSource gallery;

    setUp(() {
      folder = createTempFolder();
      gallery = FakeImageSource(pngBytes(4000, 3000));
    });

    Future<void> open(WidgetTester tester) =>
        openNewCard(tester, imagesFolder: folder, imageSource: gallery);

    List<String> storedFiles() => [
      for (final file in folder.listSync()) file.uri.pathSegments.last,
    ];

    Future<void> fillSimple(WidgetTester tester) async {
      await tester.enterText(questionField, '¿Qué orgánulo aparece?');
      await tester.enterText(answerField, 'La mitocondria');
      await tester.pump();
    }

    testWidgets('an image picked for the question is shown and saved', (
      tester,
    ) async {
      await open(tester);
      await fillSimple(tester);

      await tapVisible(
        tester,
        find.byKey(const Key('cardEditor.question.image')),
      );
      await tester.pumpAndSettle();

      expect(gallery.opened, 1);
      expect(
        find.byKey(const Key('cardEditor.question.imagePreview')),
        findsOneWidget,
      );
      // The preview card shows it too.
      expect(
        find.descendant(
          of: find.byKey(const Key('studyCard.front')),
          matching: find.byType(Image),
        ),
        findsOneWidget,
      );

      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      final [card] = await storedCards();
      expect(card.questionImage, isNotNull);
      expect(storedFiles(), [card.questionImage]);
    });

    testWidgets('removing the image before saving deletes its file', (
      tester,
    ) async {
      await open(tester);
      await fillSimple(tester);
      await tapVisible(
        tester,
        find.byKey(const Key('cardEditor.answer.image')),
      );
      await tester.pumpAndSettle();
      expect(storedFiles(), hasLength(1));

      await tapVisible(
        tester,
        find.byKey(const Key('cardEditor.answer.removeImage')),
      );
      await tester.pumpAndSettle();
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      expect((await storedCards()).single.answerImage, isNull);
      expect(storedFiles(), isEmpty);
    });

    testWidgets('leaving without saving deletes the picked images', (
      tester,
    ) async {
      await open(tester);
      await tapVisible(
        tester,
        find.byKey(const Key('cardEditor.question.image')),
      );
      await tester.pumpAndSettle();
      expect(storedFiles(), hasLength(1));

      await tester.tap(closeButton);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirmDialog.confirm')));
      await tester.pumpAndSettle();

      expect(storedFiles(), isEmpty);
    });

    testWidgets('a test card adds its image with the explanation', (
      tester,
    ) async {
      await open(tester);
      await tester.enterText(questionField, '¿Capital de Australia?');
      await tapVisible(tester, testTypeSwitch);
      await tester.pumpAndSettle();
      await tester.enterText(optionField(0), 'Canberra');
      await tester.enterText(optionField(1), 'Sídney');
      await tapVisible(tester, correctSelector(0));
      await tester.pump();

      await tapVisible(
        tester,
        find.byKey(const Key('cardEditor.explanation.image')),
      );
      await tester.pumpAndSettle();
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      expect((await storedCards()).single.answerImage, isNotNull);
    });

    testWidgets('cancelling the picker changes nothing', (tester) async {
      gallery.next = null;
      await open(tester);

      await tapVisible(
        tester,
        find.byKey(const Key('cardEditor.question.image')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('cardEditor.question.imagePreview')),
        findsNothing,
      );
      expect(storedFiles(), isEmpty);
    });

    testWidgets('a card whose image file is missing opens with its question '
        'and answer, and "Imagen no disponible" in the thumbnail', (
      tester,
    ) async {
      // As after Android restores its copy of the app, which leaves the
      // images out: the card still names a file that is not in the folder.
      final card = await cards.create(
        constitution.id,
        const CardInput(
          type: CardType.simple,
          question: '¿Qué orgánulo aparece?',
          answer: 'La mitocondria',
          questionImage: 'lost.jpg',
        ),
      );
      await pumpTestApp(
        tester,
        size: mobile,
        db: db,
        clock: clock,
        location: AppRoutes.editCard(general.id, constitution.id, card.id),
        imagesFolder: folder,
      );
      await loadImages(tester);

      expect(fieldText(tester, questionField), '¿Qué orgánulo aparece?');
      expect(fieldText(tester, answerField), 'La mitocondria');
      expect(
        find.descendant(
          of: find.byKey(const Key('cardEditor.question.imagePreview')),
          matching: find.text('Imagen no disponible'),
        ),
        findsOneWidget,
      );
      // "Quitar imagen" lets the user clear it.
      expect(
        find.byKey(const Key('cardEditor.question.removeImage')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('a file that is not an image shows a message', (tester) async {
      gallery.next = Uint8List.fromList([1, 2, 3]);
      await open(tester);

      await tapVisible(
        tester,
        find.byKey(const Key('cardEditor.question.image')),
      );
      await tester.pumpAndSettle();

      expect(find.text('No se ha podido abrir la imagen'), findsOneWidget);
      expect(storedFiles(), isEmpty);
    });
  });

  group('preview', () {
    final front = find.byKey(const Key('studyCard.front'));
    final back = find.byKey(const Key('studyCard.back'));

    testWidgets('tapping the preview shows the back', (tester) async {
      await openNewCard(tester);
      await tester.enterText(questionField, '¿Qué órgano ejerce la potestad?');
      await tester.enterText(answerField, 'Las Cortes Generales');
      await tester.pump();

      expect(front, findsOneWidget);
      expect(
        find.descendant(
          of: front,
          matching: find.text('¿Qué órgano ejerce la potestad?'),
        ),
        findsOneWidget,
      );

      await tapVisible(tester, front);
      await tester.pumpAndSettle();

      expect(back, findsOneWidget);
      expect(
        find.descendant(of: back, matching: find.text('Las Cortes Generales')),
        findsOneWidget,
      );
    });

    testWidgets('the preview updates while typing', (tester) async {
      await openNewCard(tester, deck: verbs);
      await tester.enterText(questionField, 'to **bring**');
      await tester.pump();

      expect(
        find.descendant(of: front, matching: find.text('to bring')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: front,
          matching: find.text('Inglés (R. U.) → Español'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('the back of a test card shows the solution', (tester) async {
      await openNewCard(tester);
      await tapVisible(tester, testTypeSwitch);
      await tester.pumpAndSettle();
      await tester.enterText(optionField(0), 'Canberra');
      await tester.tap(correctSelector(0));
      await tester.pump();

      await tapVisible(tester, front);
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byKey(const Key('studyCard.option.0')),
          matching: find.byIcon(Icons.check_circle_rounded),
        ),
        findsOneWidget,
      );
    });

    testWidgets('on desktop "Anverso" and "Reverso" choose the side', (
      tester,
    ) async {
      await openNewCard(tester, size: desktop);
      await tester.enterText(questionField, 'to bring');
      await tester.enterText(answerField, 'traer');
      await tester.pump();

      expect(find.text('VISTA PREVIA'), findsOneWidget);
      await tester.tap(find.byKey(const Key('cardEditor.preview.back')));
      await tester.pumpAndSettle();
      expect(back, findsOneWidget);

      await tester.tap(find.byKey(const Key('cardEditor.preview.front')));
      await tester.pumpAndSettle();
      expect(front, findsOneWidget);
    });
  });

  group('language fields', () {
    testWidgets('in a general deck, "Frase de ejemplo" and "Notas" are not '
        'shown', (tester) async {
      await openNewCard(tester);

      expect(find.text('Pregunta'), findsOneWidget);
      expect(find.text('Respuesta'), findsOneWidget);
      expect(exampleField, findsNothing);
      expect(notesField, findsNothing);
    });

    testWidgets('they follow the deck, not the project', (tester) async {
      // "Inglés B2" also has a language deck (see the next test), but this
      // deck is general.
      await openNewCard(tester, deck: classNotes);

      expect(find.text('Pregunta'), findsOneWidget);
      expect(exampleField, findsNothing);
      expect(notesField, findsNothing);
      // The preview has no language pair either.
      expect(
        find.descendant(
          of: find.byKey(const Key('studyCard.front')),
          matching: find.textContaining('→'),
        ),
        findsNothing,
      );
    });

    testWidgets('a card keeps its example and notes in a general deck', (
      tester,
    ) async {
      final card = await cards.create(
        classNotes.id,
        const CardInput(
          type: CardType.simple,
          question: 'to bring',
          answer: 'traer',
          example: 'Can you bring me some water?',
          notes: 'Verbo irregular',
        ),
      );
      await pumpTestApp(
        tester,
        size: mobile,
        db: db,
        clock: clock,
        location: AppRoutes.editCard(english.id, classNotes.id, card.id),
      );

      expect(exampleField, findsNothing);
      await tester.enterText(answerField, 'traer, llevar');
      await tester.pump();
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      final stored = (await cards.getById(card.id))!;
      expect(stored.answer, 'traer, llevar');
      expect(stored.example, 'Can you bring me some water?');
      expect(stored.notes, 'Verbo irregular');
    });

    testWidgets('a language deck shows them and saves them', (tester) async {
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

  group('voice (T2.7)', () {
    Finder speaker(String face, String part) => find.descendant(
      of: find.byKey(Key('studyCard.$face.speak.$part')),
      matching: find.byType(IconButton),
    );

    Future<void> openVerb(WidgetTester tester, FakeVoice voice) async {
      final card = await cards.create(
        verbs.id,
        const CardInput(
          type: CardType.simple,
          question: 'to **bring**',
          answer: 'traer',
          example: 'Can you bring me some water?',
        ),
      );
      await pumpTestApp(
        tester,
        size: mobile,
        db: db,
        clock: clock,
        location: AppRoutes.editCard(english.id, verbs.id, card.id),
        voice: voice,
      );
    }

    testWidgets('the question is read in the source language and the answer '
        'and example as the deck says', (tester) async {
      final voice = FakeVoice();
      await openVerb(tester, voice);
      final front = find.byKey(const Key('studyCard.front'));

      await tapVisible(tester, speaker('front', 'question'));
      expect(voice.spoken, [('to bring', 'en-GB')]);
      // The speaker does not turn the card.
      expect(front, findsOneWidget);

      // Turn it by a corner: the centre of the card is the speaker.
      await tester.tapAt(tester.getTopLeft(front) + const Offset(30, 30));
      await tester.pumpAndSettle();
      await tapVisible(tester, speaker('back', 'answer'));
      await tapVisible(tester, speaker('back', 'example'));

      expect(voice.spoken, [
        ('to bring', 'en-GB'),
        ('traer', 'es-ES'),
        ('Can you bring me some water?', 'en-GB'),
      ]);
    });

    testWidgets('with no voice installed, the button is disabled and the '
        'notice is shown', (tester) async {
      final voice = FakeVoice(missing: {'en-GB'});
      await openVerb(tester, voice);

      final button = speaker('front', 'question');
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      expect(tester.widget<IconButton>(button).onPressed, isNull);
      final notice = find.descendant(
        of: find.byKey(const Key('studyCard.front.speak.question')),
        matching: find.text('Sin voz'),
      );
      expect(notice, findsOneWidget);

      await tester.tap(notice);
      await tester.pumpAndSettle();
      expect(find.text('No hay voz para Inglés (R. U.)'), findsOneWidget);
      // The tests run as Android.
      expect(find.textContaining('Salida de texto a voz'), findsOneWidget);
      expect(voice.spoken, isEmpty);
    });

    testWidgets('a card in a general deck has no speaker button', (
      tester,
    ) async {
      await openNewCard(tester, deck: classNotes);
      await tester.enterText(questionField, 'Célula');
      await tester.pump();

      expect(
        find.byKey(const Key('studyCard.front.speak.question')),
        findsNothing,
      );
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
