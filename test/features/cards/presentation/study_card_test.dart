import 'package:estudicards/features/cards/domain/flashcard.dart';
import 'package:estudicards/features/cards/presentation/study_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/motion.dart';
import '../../../helpers/pump_widget.dart';
import '../../../helpers/test_images.dart';

final _now = DateTime.utc(2026, 10, 9);

Flashcard simpleCard({
  String question = '¿Qué órgano ejerce la potestad legislativa del Estado?',
  String answer = 'Las Cortes Generales',
  String? example,
  String? notes,
}) => Flashcard(
  id: 'c1',
  deckId: 'd1',
  type: CardType.simple,
  question: question,
  answer: answer,
  example: example,
  notes: notes,
  allowMultiple: false,
  createdAt: _now,
  updatedAt: _now,
);

/// ¿Qué orgánulo produce la mayor parte del ATP? with Mitocondria correct.
Flashcard testCard({bool allowMultiple = false, String? explanation}) =>
    Flashcard(
      id: 'c2',
      deckId: 'd1',
      type: CardType.test,
      question: '¿Qué orgánulo produce la mayor parte del ATP de la célula?',
      explanation: explanation,
      allowMultiple: allowMultiple,
      options: [
        for (final (i, text) in [
          'Ribosoma',
          'Mitocondria',
          'Aparato de Golgi',
          'Lisosoma',
        ].indexed)
          CardOption(
            id: 'o$i',
            text: text,
            isCorrect: i == 1 || (allowMultiple && i == 2),
            position: i,
          ),
      ],
      createdAt: _now,
      updatedAt: _now,
    );

Finder option(int index) => find.byKey(Key('studyCard.option.$index'));

/// Whether the option at [index] shows [icon] as its marker.
Finder marker(int index, IconData icon) =>
    find.descendant(of: option(index), matching: find.byIcon(icon));

void main() {
  Future<void> pumpCard(
    WidgetTester tester,
    Flashcard card, {
    CardFace face = CardFace.front,
    Set<String> selected = const {},
    bool checked = false,
    bool? answeredCorrectly,
    String? languagePair,
  }) => pumpComponent(
    tester,
    StudyCard(
      card: card,
      label: 'Biología 2º Bach. · Célula',
      color: 'green',
      face: face,
      languagePair: languagePair,
      selectedOptionIds: selected,
      checked: checked,
      answeredCorrectly: answeredCorrectly,
    ),
  );

  group('simple card', () {
    testWidgets('the front shows the question, its type and the flip hint', (
      tester,
    ) async {
      await pumpCard(tester, simpleCard());

      expect(find.byKey(const Key('studyCard.front')), findsOneWidget);
      expect(find.byKey(const Key('studyCard.back')), findsNothing);
      expect(find.text('Biología 2º Bach. · Célula'), findsOneWidget);
      expect(find.text('Simple'), findsOneWidget);
      expect(
        find.text('¿Qué órgano ejerce la potestad legislativa del Estado?'),
        findsOneWidget,
      );
      expect(find.text('Toca para girar'), findsOneWidget);
      expect(find.text('Las Cortes Generales'), findsNothing);
    });

    testWidgets('the back shows the answer under the question', (tester) async {
      await pumpCard(tester, simpleCard(), face: CardFace.back);

      expect(find.byKey(const Key('studyCard.back')), findsOneWidget);
      expect(find.text('Respuesta'), findsOneWidget);
      expect(find.text('Las Cortes Generales'), findsOneWidget);
      expect(
        find.text('¿Qué órgano ejerce la potestad legislativa del Estado?'),
        findsOneWidget,
      );
      expect(find.text('Toca para volver'), findsOneWidget);
    });

    testWidgets('bold text is drawn bold, without the asterisks', (
      tester,
    ) async {
      await pumpCard(
        tester,
        simpleCard(question: 'Can you **bring** me some water?'),
      );

      final text = find.text('Can you bring me some water?');
      expect(text, findsOneWidget);
      final span = tester.widget<Text>(text).textSpan! as TextSpan;
      final bring = span.children!.cast<TextSpan>().singleWhere(
        (s) => s.text == 'bring',
      );
      expect(bring.style?.fontWeight, FontWeight.w800);
    });

    testWidgets('a language card shows the languages, example and notes', (
      tester,
    ) async {
      await pumpCard(
        tester,
        simpleCard(
          question: 'to bring',
          answer: 'traer',
          example: 'Can you **bring** me some water?',
          notes: 'Verbo irregular. Mismo pasado y participio.',
        ),
        face: CardFace.back,
        languagePair: 'Inglés → Español',
      );

      expect(find.text('Inglés → Español'), findsOneWidget);
      expect(find.text('traer'), findsOneWidget);
      expect(find.text('EJEMPLO'), findsOneWidget);
      expect(find.text('Can you bring me some water?'), findsOneWidget);
      expect(find.text('NOTAS'), findsOneWidget);
    });

    testWidgets('a general card shows no example or notes', (tester) async {
      await pumpCard(tester, simpleCard(), face: CardFace.back);

      expect(find.text('EJEMPLO'), findsNothing);
      expect(find.text('NOTAS'), findsNothing);
    });

    testWidgets('a long answer scrolls inside the card', (tester) async {
      await pumpCard(
        tester,
        simpleCard(answer: 'Los españoles son iguales ante la ley. ' * 20),
        face: CardFace.back,
      );

      expect(tester.takeException(), isNull);
      expect(
        find.descendant(
          of: find.byKey(const Key('studyCard.back')),
          matching: find.byType(Scrollable),
        ),
        findsOneWidget,
      );
    });
  });

  group('test card', () {
    testWidgets('a test card shows its options with the right marker (radio '
        'or checkbox)', (tester) async {
      await pumpCard(tester, testCard());

      expect(find.text('Test'), findsOneWidget);
      for (var i = 0; i < 4; i++) {
        expect(marker(i, Icons.radio_button_unchecked_rounded), findsOneWidget);
      }
      expect(find.text('Varias respuestas correctas'), findsNothing);

      await pumpCard(tester, testCard(allowMultiple: true));

      for (var i = 0; i < 4; i++) {
        expect(
          marker(i, Icons.check_box_outline_blank_rounded),
          findsOneWidget,
        );
      }
      expect(find.text('Varias respuestas correctas'), findsOneWidget);
    });

    testWidgets('a selected option is marked before checking', (tester) async {
      await pumpCard(tester, testCard(), selected: {'o1'});

      expect(marker(1, Icons.radio_button_checked_rounded), findsOneWidget);
      expect(marker(0, Icons.radio_button_unchecked_rounded), findsOneWidget);
      // Nothing says yet whether it is right.
      expect(find.text('¡Correcto!'), findsNothing);
      expect(find.text('Tu respuesta'), findsNothing);
    });

    testWidgets('after a correct answer, it is marked with ✓ and the '
        'explanation is shown', (tester) async {
      await pumpCard(
        tester,
        testCard(explanation: 'La mitocondria realiza la respiración.'),
        selected: {'o1'},
        checked: true,
        answeredCorrectly: true,
      );

      expect(find.text('¡Correcto!'), findsOneWidget);
      expect(marker(1, Icons.check_circle_rounded), findsOneWidget);
      expect(
        find.descendant(of: option(1), matching: find.text('Tu respuesta')),
        findsOneWidget,
      );
      expect(
        find.textContaining('La mitocondria realiza la respiración.'),
        findsOneWidget,
      );
    });

    testWidgets('after a wrong answer, the ticked option has ✗ and the '
        'correct one ✓', (tester) async {
      await pumpCard(
        tester,
        testCard(explanation: 'La mitocondria realiza la respiración.'),
        selected: {'o0'},
        checked: true,
        answeredCorrectly: false,
      );

      expect(find.text('Incorrecto'), findsOneWidget);
      expect(marker(0, Icons.cancel_rounded), findsOneWidget);
      expect(
        find.descendant(of: option(0), matching: find.text('Tu respuesta')),
        findsOneWidget,
      );
      expect(marker(1, Icons.check_circle_rounded), findsOneWidget);
      expect(
        find.descendant(of: option(1), matching: find.text('Correcta')),
        findsOneWidget,
      );
    });

    testWidgets('the solution, with no answer, marks the correct options', (
      tester,
    ) async {
      await pumpCard(
        tester,
        testCard(allowMultiple: true),
        face: CardFace.back,
        checked: true,
      );

      expect(marker(1, Icons.check_box_rounded), findsOneWidget);
      expect(marker(2, Icons.check_box_rounded), findsOneWidget);
      expect(marker(0, Icons.check_box_outline_blank_rounded), findsOneWidget);
      expect(find.text('¡Correcto!'), findsNothing);
      expect(find.text('Incorrecto'), findsNothing);
    });
  });

  group('images', () {
    final image = MemoryImage(pngBytes(40, 30));

    Finder imageIn(String face) => find.descendant(
      of: find.byKey(Key('studyCard.$face')),
      matching: find.byType(Image),
    );

    testWidgets('the question image is shown above the question', (
      tester,
    ) async {
      await pumpComponent(
        tester,
        StudyCard(
          card: simpleCard(),
          label: 'Biología 2º Bach. · Célula',
          color: 'green',
          face: CardFace.front,
          questionImage: image,
        ),
      );

      expect(imageIn('front'), findsOneWidget);
      expect(
        tester.getTopLeft(imageIn('front')).dy,
        lessThan(
          tester
              .getTopLeft(
                find.text(
                  '¿Qué órgano ejerce la potestad legislativa del Estado?',
                ),
              )
              .dy,
        ),
      );
    });

    testWidgets('the answer image is shown on the back', (tester) async {
      await pumpComponent(
        tester,
        StudyCard(
          card: simpleCard(),
          label: 'Biología 2º Bach. · Célula',
          color: 'green',
          face: CardFace.back,
          answerImage: image,
        ),
      );

      expect(imageIn('back'), findsOneWidget);
    });

    testWidgets('a test card shows the answer image with the explanation', (
      tester,
    ) async {
      final card = testCard(explanation: 'La mitocondria.');
      Future<void> pump({required bool checked}) => pumpComponent(
        tester,
        StudyCard(
          card: card,
          label: 'Biología 2º Bach. · Célula',
          color: 'green',
          face: CardFace.front,
          checked: checked,
          answerImage: image,
        ),
      );

      await pump(checked: false);
      expect(imageIn('front'), findsNothing);

      await pump(checked: true);
      expect(imageIn('front'), findsOneWidget);
    });
  });

  testWidgets('changing the face flips the card with an animation', (
    tester,
  ) async {
    await pumpCard(tester, simpleCard());

    await pumpCard(tester, simpleCard(), face: CardFace.back);
    // Halfway through, the card is still turning.
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const Key('studyCard.back')), findsNothing);
    expect(isTurned(tester), isTrue);

    await tester.pumpAndSettle();
    expect(find.byKey(const Key('studyCard.back')), findsOneWidget);
    expect(isTurned(tester), isFalse);
  });

  testWidgets('with reduced motion, the flip animation is not used: the '
      'card fades to the other face', (tester) async {
    reduceMotion(tester);
    await pumpCard(tester, simpleCard());

    await pumpCard(tester, simpleCard(), face: CardFace.back);
    await tester.pump(const Duration(milliseconds: 100));

    // Both faces are on screen, one fading out and the other in, and
    // nothing turns.
    expect(find.byKey(const Key('studyCard.front')), findsOneWidget);
    expect(find.byKey(const Key('studyCard.back')), findsOneWidget);
    expect(isTurned(tester), isFalse);

    await tester.pumpAndSettle();
    expect(find.byKey(const Key('studyCard.front')), findsNothing);
    expect(find.byKey(const Key('studyCard.back')), findsOneWidget);
  });

  group('in a study session', () {
    testWidgets('the options are shown in the order given', (tester) async {
      final card = testCard();
      await pumpComponent(
        tester,
        StudyCard(
          card: card,
          label: 'Biología',
          color: 'green',
          face: CardFace.front,
          options: card.options.reversed.toList(),
        ),
      );

      final tops = [
        for (final text in ['Lisosoma', 'Aparato de Golgi', 'Ribosoma'])
          tester.getTopLeft(find.text(text)).dy,
      ];
      expect(tops, orderedEquals([...tops]..sort()));
      expect(
        find.descendant(of: option(0), matching: find.text('Lisosoma')),
        findsOneWidget,
      );
    });

    testWidgets('tapping an option reports it until the solution is shown', (
      tester,
    ) async {
      final tapped = <String>[];
      Future<void> pump({required bool checked}) => pumpComponent(
        tester,
        StudyCard(
          card: testCard(),
          label: 'Biología',
          color: 'green',
          face: CardFace.front,
          checked: checked,
          onOptionTap: tapped.add,
        ),
      );

      await pump(checked: false);
      await tester.tap(find.text('Mitocondria'));
      expect(tapped, ['o1']);

      await pump(checked: true);
      await tester.tap(find.text('Ribosoma'));
      expect(tapped, ['o1']);
    });

    testWidgets('in reverse, the front shows the answer and the back the '
        'question under it', (tester) async {
      Future<void> pump(CardFace face) => pumpComponent(
        tester,
        StudyCard(
          card: simpleCard(question: 'to bring', answer: 'traer'),
          label: 'Inglés B2 · Verbos',
          color: 'blue',
          face: face,
          languagePair: 'Español → Inglés',
          reversed: true,
          speechLanguages: (source: 'en-GB', target: 'es-ES'),
          speaker: (speech) => Text('🔊 ${speech.language}'),
        ),
      );

      await pump(CardFace.front);
      expect(find.text('traer'), findsOneWidget);
      expect(find.text('to bring'), findsNothing);
      // The answer is read in the target language.
      expect(
        find.descendant(
          of: find.byKey(const Key('studyCard.front.speak.answer')),
          matching: find.text('🔊 es-ES'),
        ),
        findsOneWidget,
      );

      await pump(CardFace.back);
      await tester.pumpAndSettle();
      final small = tester.getTopLeft(find.text('traer')).dy;
      final big = tester.getTopLeft(find.text('to bring')).dy;
      expect(small, lessThan(big));
      expect(tester.widget<Text>(find.text('to bring')).style?.fontSize, 26);
    });
  });
}
