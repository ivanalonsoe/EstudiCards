// E2E-06 (SPEC §10.2): delete a project → undo; delete it again → restore
// it from the trash.
//
//   patrol test --target patrol_test/trash_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import '../integration_test/app_flow.dart';

void main() {
  patrolTest('E2E-06: delete a project, undo, delete again and restore it '
      'from the trash', ($) async {
    final tester = $.tester;
    await $.pumpWidgetAndSettle(appWithTestDatabase());
    await createProject(tester, 'Oposiciones · Tema 3');
    await goTo(tester, 'home');

    // Delete and undo within the 5 seconds.
    await chooseInProjectCardMenu(tester, 'Eliminar');
    expect(
      $(
        'Se moverán a la papelera 0 barajas y 0 tarjetas. '
        'Podrás recuperarlo durante 15 días.',
      ),
      findsOneWidget,
    );
    await tapKey(tester, 'confirmDialog.confirm');
    expect($(const Key('dashboard.empty')), findsOneWidget);
    await $('Deshacer').tap();
    expect($('Oposiciones · Tema 3'), findsOneWidget);

    // Delete again and restore it from the trash.
    await chooseInProjectCardMenu(tester, 'Eliminar');
    await tapKey(tester, 'confirmDialog.confirm');
    await goTo(tester, 'trash');
    expect($('Se elimina en 15 días'), findsOneWidget);
    await $('Restaurar').tap();
    expect($(const Key('trash.emptyState')), findsOneWidget);
    await goTo(tester, 'home');
    expect($('Oposiciones · Tema 3'), findsOneWidget);
  });
}
