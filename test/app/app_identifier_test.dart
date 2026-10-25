// The app's identifier on every platform: Android's application ID, the
// Apple bundle ID and the Windows company name. Stores and systems use it
// to tell this app apart from any other, so it never changes after a
// release (decided with the owner: `dev.ivalon.estudicards`).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _identifier = 'dev.ivalon.estudicards';

/// The project files that hold the identifier (the Android sources and
/// manifests, not their images).
final List<String> _platformFiles = [
  'pubspec.yaml',
  'android/app/build.gradle.kts',
  for (final entity in Directory('android/app/src').listSync(recursive: true))
    if (entity is File && RegExp(r'\.(kt|java|xml)$').hasMatch(entity.path))
      entity.path,
  'ios/Runner.xcodeproj/project.pbxproj',
  'macos/Runner.xcodeproj/project.pbxproj',
  'macos/Runner/Configs/AppInfo.xcconfig',
  'windows/runner/Runner.rc',
];

void main() {
  test('no platform file uses the old identifier', () {
    final old = RegExp(r'com\.ivanalonsoe');
    final withOld = [
      for (final path in _platformFiles)
        if (old.hasMatch(File(path).readAsStringSync())) path,
    ];
    expect(withOld, isEmpty);
  });

  test('Android, iOS and macOS use $_identifier', () {
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();
    expect(gradle, contains('namespace = "$_identifier"'));
    expect(gradle, contains('applicationId = "$_identifier"'));
    expect(
      File('macos/Runner/Configs/AppInfo.xcconfig').readAsStringSync(),
      matches(RegExp('PRODUCT_BUNDLE_IDENTIFIER = $_identifier\r?\n')),
    );
    expect(
      File('ios/Runner.xcodeproj/project.pbxproj').readAsStringSync(),
      contains('PRODUCT_BUNDLE_IDENTIFIER = $_identifier;'),
    );
  });

  test("Android's main activity lives in the identifier's package", () {
    final activity = File(
      'android/app/src/main/kotlin/dev/ivalon/estudicards/MainActivity.kt',
    );
    expect(
      activity.readAsStringSync(),
      matches(RegExp('^package $_identifier\r?\n')),
    );
  });

  test('Patrol drives the app with the same identifier', () {
    expect(
      File('pubspec.yaml').readAsStringSync(),
      contains('package_name: $_identifier'),
    );
  });
}
