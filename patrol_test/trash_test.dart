// E2E-06 (SPEC §10.2): delete a project → undo; delete it again → restore
// it from the trash.
//
//   patrol test --target patrol_test/trash_test.dart
import 'package:flutter/material.dart';
import 'package:patrol/patrol.dart';

import '../integration_test/app_flow.dart';

void main() {
  patrolTest('E2E-06: delete a project, undo, delete again and restore it '
      'from the trash', ($) async {
    final tester = $.tester;
    await $.pumpWidgetAndSettle(appWithTestDatabase());
    await createProject(tester, 'Oposiciones · Tema 3');
    await goTo(tester, 'home');

    // `waitUntilVisible` waits for the database to answer before checking
    // (see `waitFor` in app_flow.dart).

    // Delete and undo within the 5 seconds.
    await chooseInProjectCardMenu(tester, 'Eliminar');
    await $(
      'Se moverán a la papelera 0 barajas y 0 tarjetas. '
      'Podrás recuperarlo durante 15 días.',
    ).waitUntilVisible();
    await tapKey(tester, 'confirmDialog.confirm');
    await $(const Key('dashboard.empty')).waitUntilVisible();
    await $('Deshacer').tap();
    await $('Oposiciones · Tema 3').waitUntilVisible();

    // Delete again and restore it from the trash.
    await chooseInProjectCardMenu(tester, 'Eliminar');
    await tapKey(tester, 'confirmDialog.confirm');
    await goTo(tester, 'trash');
    await $('Se elimina en 15 días').waitUntilVisible();
    await $('Restaurar').tap();
    await $(const Key('trash.emptyState')).waitUntilVisible();
    await goTo(tester, 'home');
    await $('Oposiciones · Tema 3').waitUntilVisible();
  });
}
