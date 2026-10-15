// Integration tests run the whole app on a real device or desktop window,
// not in the simulated test environment of test/ (SPEC §10.2).
//
//   flutter test integration_test -d windows
//
// This is the only `_test.dart` file in this folder: on desktop, Flutter
// starts the app once per test file and cannot start it a second time in
// the same run. Each flow lives in `flows/` and is called from here.
import 'package:estudicards/app/app.dart';
import 'package:estudicards/features/trash/presentation/trash_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'flows/cards_flow.dart';
import 'flows/projects_flow.dart';
import 'flows/study_flow.dart';

void main() {
  // Connects flutter_test to the real app running on the device.
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  // Typing goes through the simulated keyboard of flutter_test, never the
  // device's own keyboard. On Android the system keyboard keeps its own copy
  // of a field and, on a slow emulator, sent the old text back over what a
  // test had typed.
  binding.testTextInput.register();

  testWidgets('the app starts and shows the home screen', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: EstudiCardsApp()));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('screen.dashboard')), findsOneWidget);
    expect(find.text('EstudiCards'), findsWidgets);

    // This test opens the real database. Let the startup purge finish
    // before the next test replaces the app and the database closes.
    final container = ProviderScope.containerOf(
      tester.element(find.byType(EstudiCardsApp)),
    );
    await container.read(startupPurgeProvider.future);
  });

  group('projects', projectsFlowTests);
  group('cards', cardsFlowTests);
  group('study', studyFlowTests);
}
