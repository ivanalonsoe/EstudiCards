// E2E-02 (SPEC §10.2): a multiple-answer test card enters the error list
// when missed and leaves it after two correct answers in a row (R 7.4).
//
//   patrol test --target patrol_test/errors_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import '../integration_test/app_flow.dart';

void main() {
  patrolTest('E2E-02: a multiple-answer test card answered wrong goes to '
      'the errors and leaves them after two correct answers in a row', (
    $,
  ) async {
    final tester = $.tester;
    await $.pumpWidgetAndSettle(appWithTestDatabase());
    await createProject(tester, 'Biología');
    // A general deck: test cards never ask for the system voice.
    await createDeck(tester, 'Célula');
    await tapText(tester, 'Célula');
    await waitFor(tester, find.byKey(const Key('screen.deck')));
    const correct = {'Mitocondria', 'Cloroplasto'};
    await addMultipleAnswerCard(
      tester,
      '¿Qué orgánulos tienen ADN propio?',
      options: ['Mitocondria', 'Ribosoma', 'Cloroplasto'],
      correct: {0, 2},
    );

    // Wrong: only one of the two correct options.
    await tapKey(tester, 'deckScreen.study');
    await startSession(tester);
    await answerTestCard(tester, {'Mitocondria'});
    await $('Sesión terminada').waitUntilVisible();
    await backFromResults(tester);
    await $('Repasar errores (1)').waitUntilVisible();

    // The first correct answer is not enough (R 7.4).
    await tapKey(tester, 'projectScreen.reviewErrors');
    await $('Solo errores').waitUntilVisible();
    await startSession(tester);
    await answerTestCard(tester, correct);
    await $('¡Buen trabajo!').waitUntilVisible();
    await backFromResults(tester);
    await $('Repasar errores (1)').waitUntilVisible();

    // The second one in a row takes the card out of the errors.
    await tapKey(tester, 'projectScreen.reviewErrors');
    await startSession(tester);
    await answerTestCard(tester, correct);
    await $('¡Buen trabajo!').waitUntilVisible();
    await backFromResults(tester);
    await waitFor(tester, find.byKey(const Key('projectScreen.study')));
    expect($(const Key('projectScreen.reviewErrors')), findsNothing);
  });
}
