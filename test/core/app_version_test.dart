import 'dart:io';

import 'package:estudicards/core/app_version.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('appVersion matches the version in pubspec.yaml', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final version = RegExp(
      r'^version: (\d+\.\d+\.\d+)',
      multiLine: true,
    ).firstMatch(pubspec)!.group(1);

    expect(appVersion, version);
  });
}
