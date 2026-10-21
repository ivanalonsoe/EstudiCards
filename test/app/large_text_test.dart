// T6.3 (SPEC §9, DESIGN_BRIEF §9): the main screens work with the system
// text at 200%, on mobile and desktop. A widget that does not fit makes
// Flutter report an overflow, which fails the test.
import 'package:flutter_test/flutter_test.dart';

import '../helpers/sample_screens.dart';
import '../helpers/test_app.dart';

void main() {
  for (final screen in mainScreens) {
    for (final (form, size) in [('mobile', mobile), ('desktop', desktop)]) {
      testWidgets('${screen.name} ($form) fits with the system text at '
          '200%', (tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

        // An overflow is reported by Flutter, with the widget that does not
        // fit, and fails the test.
        await pumpSampleScreen(tester, screen, size: size);
      });
    }
  }
}
