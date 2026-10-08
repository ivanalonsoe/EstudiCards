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

import 'flows/projects_flow.dart';

void main() {
  // Connects flutter_test to the real app running on the device.
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

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
}
