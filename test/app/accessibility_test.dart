// T6.3 (SPEC §9, DESIGN_BRIEF §9): the main screens follow Flutter's
// accessibility guidelines on mobile and desktop.
//
// - Touch targets: everything that can be tapped is at least 48 × 48 dp.
// - Labels: everything that can be tapped says what it is to a screen
//   reader (in Spanish, from app_es.arb).
// - Contrast: text reaches WCAG AA against what is behind it, in the light
//   and the dark theme.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/sample_screens.dart';
import '../helpers/test_app.dart';

void main() {
  for (final screen in mainScreens) {
    for (final (form, size) in [('mobile', mobile), ('desktop', desktop)]) {
      testWidgets('${screen.name} ($form): touch targets of 48 dp and a '
          'label on everything that can be tapped', (tester) async {
        final semantics = tester.ensureSemantics();
        await pumpSampleScreen(tester, screen, size: size);

        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        semantics.dispose();
      });

      for (final brightness in Brightness.values) {
        testWidgets('${screen.name} ($form, ${brightness.name}): text '
            'contrast', (tester) async {
          tester.platformDispatcher.platformBrightnessTestValue = brightness;
          addTearDown(
            tester.platformDispatcher.clearPlatformBrightnessTestValue,
          );
          final semantics = tester.ensureSemantics();
          await pumpSampleScreen(tester, screen, size: size);

          await expectLater(tester, meetsGuideline(textContrastGuideline));
          semantics.dispose();
        });
      }
    }
  }
}
