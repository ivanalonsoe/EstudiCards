// Helpers shared by the integration tests (integration_test/) and the E2E
// tests (patrol_test/). They drive the app through the screen, the way a
// user does, on any window size: a sidebar on desktop, a side menu and the
// back button on a phone.
import 'package:drift/native.dart';
import 'package:estudicards/app/app.dart';
import 'package:estudicards/core/db/app_database.dart';
import 'package:estudicards/core/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// The whole app with an in-memory database, so tests never touch the
/// data of the app installed on the device.
Widget appWithTestDatabase() {
  final db = AppDatabase(NativeDatabase.memory());
  return ProviderScope(
    overrides: [databaseProvider.overrideWithValue(db)],
    child: const EstudiCardsApp(),
  );
}

/// Flutter's Spanish tooltip for the button that opens the side menu.
const _openMenuTooltip = 'Abrir el menú de navegación';

/// Opens a screen of the general menu: `home`, `archived`, `trash`…
Future<void> goTo(WidgetTester tester, String destination) async {
  final item = find.byKey(Key('nav.$destination'));
  if (item.evaluate().isEmpty) {
    // A phone: go back to the dashboard, which has the side menu.
    while (find.byType(BackButton).evaluate().isNotEmpty) {
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
    }
    if (destination == 'home') return;
    await tester.tap(find.byTooltip(_openMenuTooltip));
    await tester.pumpAndSettle();
  }
  await tester.tap(item);
  await tester.pumpAndSettle();
}

/// Taps [key], scrolling to it first if it is off screen.
Future<void> tapKey(WidgetTester tester, String key) async {
  final finder = find.byKey(Key(key));
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Taps the visible text [text], scrolling to it first if needed.
Future<void> tapText(WidgetTester tester, String text) async {
  final finder = find.text(text).last;
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Creates a project from the dashboard; the app then opens it.
Future<void> createProject(WidgetTester tester, String name) async {
  await tapKey(tester, 'dashboard.newProject');
  await tester.enterText(find.byKey(const Key('projectForm.name')), name);
  await tester.pumpAndSettle();
  await tapKey(tester, 'projectForm.save');
}

/// Creates a deck from the project screen.
Future<void> createDeck(WidgetTester tester, String name) async {
  await tapKey(tester, 'projectScreen.newDeck');
  await tester.enterText(find.byKey(const Key('deckForm.name')), name);
  await tester.pumpAndSettle();
  await tapKey(tester, 'deckForm.save');
}

/// Chooses [item] in the ⋮ menu of the only project on the dashboard.
Future<void> chooseInProjectCardMenu(WidgetTester tester, String item) async {
  await tester.tap(find.byTooltip('Opciones del proyecto'));
  await tester.pumpAndSettle();
  await tapText(tester, item);
}
