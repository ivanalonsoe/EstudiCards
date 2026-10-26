import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  // `git check-ignore` answers whether git would ignore a path, using every
  // .gitignore in the repository; the files do not need to exist.
  // `--no-index` also answers for paths git already tracks.
  for (final path in [
    'upload.keystore',
    'upload.p12',
    'key.properties',
    'android/app/upload.jks',
    'some/folder/release.keystore',
  ]) {
    test('git ignores the signing key file $path', () {
      final result = Process.runSync('git', [
        'check-ignore',
        '--no-index',
        '--quiet',
        path,
      ]);

      expect(result.exitCode, 0, reason: '$path is not ignored');
    });
  }
}
