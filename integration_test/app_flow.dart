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

/// Waits until [finder] finds something, for at most [timeout].
///
/// On a real device the database answers asynchronously, and
/// `pumpAndSettle` only waits for animations, not for those answers. On a
/// slow device (like the CI emulator) a screen can still be loading when
/// the next step looks for one of its widgets, so every step waits first.
Future<void> waitFor(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 15),
}) async {
  // Integration tests run in real time, so a real clock is right here.
  final deadline = DateTime.now().add(timeout);
  while (finder.evaluate().isEmpty) {
    if (DateTime.now().isAfter(deadline)) {
      throw TestFailure('Timed out after $timeout waiting for $finder');
    }
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

/// Waits for [finder] and checks it finds exactly one widget.
Future<void> expectSoon(WidgetTester tester, Finder finder) async {
  await waitFor(tester, finder);
  expect(finder, findsOneWidget);
}

/// Opens a screen of the general menu: `home`, `archived`, `trash`…
Future<void> goTo(WidgetTester tester, String destination) async {
  final item = find.byKey(Key('nav.$destination'));
  final sidebar = find.byKey(const Key('shell.sidebar'));
  if (sidebar.evaluate().isEmpty) {
    // A phone: go back to the dashboard, which has the side menu.
    while (find.byType(BackButton).evaluate().isNotEmpty) {
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
    }
    await waitFor(tester, find.byKey(const Key('screen.dashboard')));
    if (destination == 'home') return;
    await tester.tap(find.byTooltip(_openMenuTooltip));
    await tester.pumpAndSettle();
  }
  await waitFor(tester, item);
  await tester.tap(item);
  await tester.pumpAndSettle();
}

/// Taps [finder] once it appears, scrolling to it first if it is off
/// screen.
Future<void> _tap(WidgetTester tester, Finder finder) async {
  await waitFor(tester, finder);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Taps the widget with [key].
Future<void> tapKey(WidgetTester tester, String key) =>
    _tap(tester, find.byKey(Key(key)));

/// Taps the visible text [text] (the last one if there are several).
Future<void> tapText(WidgetTester tester, String text) =>
    _tap(tester, find.text(text).last);

/// Types [text] into the field with [key] once it appears.
Future<void> enterTextInKey(
  WidgetTester tester,
  String key,
  String text,
) async {
  final field = find.byKey(Key(key));
  await waitFor(tester, field);
  await tester.enterText(field, text);
  await tester.pumpAndSettle();
}

/// Creates a project from the dashboard; the app then opens it.
Future<void> createProject(WidgetTester tester, String name) async {
  await tapKey(tester, 'dashboard.newProject');
  await enterTextInKey(tester, 'projectForm.name', name);
  await tapKey(tester, 'projectForm.save');
  // The project screen shows its menu once the project has loaded.
  await waitFor(tester, find.byKey(const Key('projectScreen.menu')));
}

/// Creates a deck from the project screen.
Future<void> createDeck(WidgetTester tester, String name) async {
  await tapKey(tester, 'projectScreen.newDeck');
  await enterTextInKey(tester, 'deckForm.name', name);
  await tapKey(tester, 'deckForm.save');
}

/// Chooses [item] in the ⋮ menu of the only project on the dashboard.
Future<void> chooseInProjectCardMenu(WidgetTester tester, String item) async {
  await _tap(tester, find.byTooltip('Opciones del proyecto'));
  await tapText(tester, item);
}
