// End-to-end (E2E) tests with Patrol: like integration tests, but they can
// also control the phone itself (system dialogs, file picker, share sheet,
// permissions) through `$.platform` (SPEC §10.2).
//
//   patrol test               # on a running emulator or connected device
import 'package:estudicards/app/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

void main() {
  // `$` is Patrol's tester: it finds widgets ($(Key(...))) and drives the
  // app and the device.
  patrolTest('the app starts on the device and shows the home screen', (
    $,
  ) async {
    await $.pumpWidgetAndSettle(const EstudiCardsApp());

    expect($(const Key('screen.dashboard')), findsOneWidget);
    expect($('EstudiCards'), findsWidgets);
  });
}
