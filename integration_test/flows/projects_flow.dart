// Phase 1 wrap-up (TASKS.md T1.9): the whole life of a project. Run from
// `integration_test/app_test.dart`.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../app_flow.dart';

void projectsFlowTests() {
  testWidgets('create project → deck → archive → unarchive → delete → '
      'restore from the trash', (tester) async {
    await tester.pumpWidget(appWithTestDatabase());
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('dashboard.empty')), findsOneWidget);

    // Create a project and a deck in it.
    await createProject(tester, 'Inglés B2');
    expect(find.byKey(const Key('screen.project')), findsOneWidget);
    await createDeck(tester, 'Verbos irregulares');
    expect(find.text('Verbos irregulares'), findsOneWidget);

    // Archive it from its screen: back to an empty dashboard.
    await tapKey(tester, 'projectScreen.menu');
    await tapText(tester, 'Archivar');
    expect(find.byKey(const Key('dashboard.empty')), findsOneWidget);

    // Unarchive it from Archivados.
    await goTo(tester, 'archived');
    expect(find.text('Inglés B2'), findsOneWidget);
    await tapText(tester, 'Desarchivar');
    expect(find.byKey(const Key('archived.empty')), findsOneWidget);
    await goTo(tester, 'home');
    expect(find.text('1 baraja · 0 tarjetas'), findsOneWidget);

    // Delete it.
    await chooseInProjectCardMenu(tester, 'Eliminar');
    await tapKey(tester, 'confirmDialog.confirm');
    expect(find.byKey(const Key('dashboard.empty')), findsOneWidget);

    // Restore it from the trash, with its deck.
    await goTo(tester, 'trash');
    expect(find.text('Proyecto · 1 baraja · 0 tarjetas'), findsOneWidget);
    await tapText(tester, 'Restaurar');
    expect(find.byKey(const Key('trash.emptyState')), findsOneWidget);
    await goTo(tester, 'home');
    await tapText(tester, 'Inglés B2');
    expect(find.text('Verbos irregulares'), findsOneWidget);
  });
}
