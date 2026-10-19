// E2E-08 (SPEC §10.2): switch to the dark theme and change the card text
// size; both persist after restarting the app.
//
//   patrol test --target patrol_test/settings_test.dart
import 'dart:io';

import 'package:drift/native.dart';
import 'package:estudicards/core/db/app_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import '../integration_test/app_flow.dart';

void main() {
  patrolTest('E2E-08: the dark theme and the card text size persist after '
      'restarting the app', ($) async {
    final tester = $.tester;
    // A database file instead of one in memory, so it outlives the app. It
    // is in a temporary folder, never the data of the installed app.
    final folder = Directory.systemTemp.createTempSync('estudicards_e2e08');
    addTearDown(() => folder.deleteSync(recursive: true));
    final file = File('${folder.path}/estudicards.sqlite');
    Brightness brightness() =>
        Theme.of(tester.element(find.byType(Scaffold).first)).brightness;

    var db = AppDatabase(NativeDatabase(file));
    await $.pumpWidgetAndSettle(appWithTestDatabase(db: db));
    await goTo(tester, 'settings');
    await tapKey(tester, 'settings.theme.dark');
    expect(brightness(), Brightness.dark);
    final slider = find.byKey(const Key('settings.cardTextScale'));
    await tester.ensureVisible(slider);
    await tester.drag(slider, const Offset(800, 0));
    await tester.pumpAndSettle();
    await $('160%').waitUntilVisible();

    // Close the app and its database, then start it again on the same file.
    await $.pumpWidgetAndSettle(const SizedBox());
    await db.close();
    db = AppDatabase(NativeDatabase(file));
    addTearDown(db.close);
    await $.pumpWidgetAndSettle(appWithTestDatabase(db: db));

    await waitFor(tester, find.byKey(const Key('screen.dashboard')));
    expect(brightness(), Brightness.dark);
    await goTo(tester, 'settings');
    await $('160%').waitUntilVisible();
  });
}
