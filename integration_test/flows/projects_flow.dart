// Phase 1 wrap-up (TASKS.md T1.9): the whole life of a project. Run from
// `integration_test/app_test.dart`.
//
// Checks use `expectSoon`, which waits for the screen to show the result:
// on a real device the database answers asynchronously.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../app_flow.dart';

void projectsFlowTests() {
  testWidgets('create project → deck → archive → unarchive → delete → '
      'restore from the trash', (tester) async {
    await tester.pumpWidget(appWithTestDatabase());
    await expectSoon(tester, find.byKey(const Key('dashboard.empty')));

    // Create a project and a deck in it.
    await createProject(tester, 'Inglés B2');
    await createDeck(tester, 'Verbos irregulares');
    await expectSoon(tester, find.text('Verbos irregulares'));

    // Archive it from its screen: back to an empty dashboard.
    await tapKey(tester, 'projectScreen.menu');
    await tapText(tester, 'Archivar');
    await expectSoon(tester, find.byKey(const Key('dashboard.empty')));

    // Unarchive it from Archivados.
    await goTo(tester, 'archived');
    await expectSoon(tester, find.text('Inglés B2'));
    await tapText(tester, 'Desarchivar');
    await expectSoon(tester, find.byKey(const Key('archived.empty')));
    await goTo(tester, 'home');
    await expectSoon(tester, find.text('1 baraja · 0 tarjetas'));

    // Delete it.
    await chooseInProjectCardMenu(tester, 'Eliminar');
    await tapKey(tester, 'confirmDialog.confirm');
    await expectSoon(tester, find.byKey(const Key('dashboard.empty')));

    // Restore it from the trash, with its deck.
    await goTo(tester, 'trash');
    await expectSoon(tester, find.text('Proyecto · 1 baraja · 0 tarjetas'));
    await tapText(tester, 'Restaurar');
    await expectSoon(tester, find.byKey(const Key('trash.emptyState')));
    await goTo(tester, 'home');
    await tapText(tester, 'Inglés B2');
    await expectSoon(tester, find.text('Verbos irregulares'));
  });
}
