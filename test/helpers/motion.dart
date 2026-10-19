import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Turns on the system's "reduce motion" setting for this test
/// (`MediaQuery.disableAnimations`).
void reduceMotion(WidgetTester tester) {
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
}

/// Whether the study card is caught halfway through a turn around its
/// vertical axis: some `Transform` inside it is rotated by an angle other
/// than 0 or 180° (the matrix's first entry, the cosine of the angle, is
/// neither 1 nor -1). The back is drawn turned 180° twice, which is flat.
bool isTurned(WidgetTester tester) => tester
    .widgetList<Transform>(
      find.descendant(
        of: find.byKey(const Key('studyCard')),
        matching: find.byType(Transform),
      ),
    )
    .any((transform) => transform.transform.entry(0, 0).abs() < 0.999);
