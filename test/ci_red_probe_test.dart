import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Probe for T0.3: passes locally (so the pre-push hook lets it through)
// but fails on GitHub Actions, which sets the CI variable.
void main() {
  test('fails only on CI', () {
    expect(Platform.environment['CI'], isNull);
  });
}
