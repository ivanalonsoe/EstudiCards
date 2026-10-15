// E2E-01 and E2E-03 (SPEC §10.2): the first study session, and the timers.
//
//   patrol test --target patrol_test/study_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import '../integration_test/app_flow.dart';

void main() {
  patrolTest('E2E-01: create a project, a language deck and 3 cards, study '
      'them and see the results', ($) async {
    final tester = $.tester;
    await $.pumpWidgetAndSettle(appWithTestDatabase());
    await createProject(tester, 'Inglés B2');
    await createLanguageDeck(tester, 'Verbos irregulares');
    await tapText(tester, 'Verbos irregulares');
    await waitFor(tester, find.byKey(const Key('screen.deck')));
    await addSimpleCard(tester, 'to bring', 'traer');
    await addSimpleCard(tester, 'to seek', 'buscar');
    await addSimpleCard(tester, 'to bear', 'soportar');

    await tapKey(tester, 'deckScreen.study');
    await $('3 tarjetas disponibles · se usarán todas').waitUntilVisible();
    await startSession(tester);
    for (var i = 0; i < 3; i++) {
      await answerCorrectly(tester);
    }

    await $('¡Buen trabajo!').waitUntilVisible();
    await $('100%').waitUntilVisible();
  });

  patrolTest('E2E-03: an expired per-question timer counts as wrong, and an '
      'expired global timer ends the session with the unanswered cards', (
    $,
  ) async {
    final tester = $.tester;
    await $.pumpWidgetAndSettle(appWithTestDatabase());
    await createProject(tester, 'Biología');
    await createDeck(tester, 'Célula');
    await tapText(tester, 'Célula');
    await waitFor(tester, find.byKey(const Key('screen.deck')));
    await addSimpleCard(tester, 'Mitocondria', 'Produce el ATP');
    await addSimpleCard(tester, 'Ribosoma', 'Fabrica proteínas');

    // 5 seconds per question; the first card runs out, then "Salir".
    await tapKey(tester, 'deckScreen.study');
    await chooseTimer(tester, 'perCard', steps: 5);
    await $('5 s').waitUntilVisible();
    await startSession(tester);
    // `waitUntilVisible` waits in real time, longer than the 5 seconds.
    await $(const Key('session.next')).waitUntilVisible();
    expect($(const Key('session.wrongCount')).text, '1');
    await tapKey(tester, 'session.next');
    await tapKey(tester, 'session.exit');
    await tapKey(tester, 'confirmDialog.confirm');
    await $('Sesión terminada').waitUntilVisible();
    // On a short phone screen the list is below the fold: `scrollTo`
    // scrolls until it is visible.
    await $('No respondidas (1)').scrollTo();

    // A 1-minute global timer: nothing is answered and the session ends.
    await backFromResults(tester);
    await tapKey(tester, 'projectScreen.study');
    await chooseTimer(tester, 'global', steps: 2);
    await $('1 min').waitUntilVisible();
    await startSession(tester);
    await $('¡Se acabó el tiempo!')
        .waitUntilVisible(timeout: const Duration(seconds: 90));
    await $('No respondidas (2)').scrollTo();
  });
}
