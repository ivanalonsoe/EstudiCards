// Integration tests run the whole app on a real device or desktop window,
// not in the simulated test environment of test/ (SPEC §10.2).
//
//   flutter test integration_test -d windows
import 'package:estudicards/app/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  // Connects flutter_test to the real app running on the device.
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the app starts and shows the home screen', (tester) async {
    await tester.pumpWidget(const EstudiCardsApp());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('screen.dashboard')), findsOneWidget);
    expect(find.text('EstudiCards'), findsWidgets);
  });
}
