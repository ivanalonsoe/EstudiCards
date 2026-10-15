// Phase 3 wrap-up (TASKS.md T3.10): a full study session with a simple card
// and a test card, without a timer and then with a per-question timer that
// runs out. Run from `integration_test/app_test.dart`.
//
// The deck is general, so the system voice is never asked for. The cards
// come in a random order, so each step answers whichever card is shown.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../app_flow.dart';

void studyFlowTests() {
  testWidgets('a full session with simple and test cards, with and without '
      'a timer', (tester) async {
    await tester.pumpWidget(appWithTestDatabase());
    await waitFor(tester, find.byKey(const Key('dashboard.empty')));
    await createProject(tester, 'Biología');
    await createDeck(tester, 'Célula');
    await tapText(tester, 'Célula');
    await waitFor(tester, find.byKey(const Key('screen.deck')));
    await addSimpleCard(tester, 'Mitocondria', 'Produce el ATP');
    await addTestCard(
      tester,
      '¿Qué orgánulo hace la fotosíntesis?',
      wrong: 'Ribosoma',
      correct: 'Cloroplasto',
    );

    // Without a timer, from the deck: both cards right.
    await tapKey(tester, 'deckScreen.study');
    await expectSoon(
      tester,
      find.text('2 tarjetas disponibles · se usarán todas'),
    );
    await startSession(tester);
    for (var i = 0; i < 2; i++) {
      await answerCorrectly(tester, correctOptions: {'Cloroplasto'});
    }
    await expectSoon(tester, find.text('¡Buen trabajo!'));
    await expectSoon(tester, find.text('100%'));

    // With 10 seconds per question: the first card runs out (wrong) and
    // the second is answered right.
    await backFromResults(tester);
    await tapKey(tester, 'projectScreen.study');
    await chooseTimer(tester, 'perCard', steps: 4);
    await expectSoon(tester, find.text('10 s'));
    await startSession(tester);
    // Integration tests run in real time.
    await Future<void>.delayed(const Duration(seconds: 11));
    await tester.pumpAndSettle();
    await tapKey(tester, 'session.next');
    await answerCorrectly(tester, correctOptions: {'Cloroplasto'});

    await expectSoon(tester, find.text('Sesión terminada'));
    await expectSoon(tester, find.text('50%'));
  });
}
