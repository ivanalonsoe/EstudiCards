// Android's own copy of the app's data: the backup to the user's Google
// account and the transfer to a new phone. The rules files list what goes
// in it; once a rule includes something, everything else is left out.
// Only the database travels (it holds the settings too, in the `settings`
// table): images and the automatic backups would push the copy over
// Android's 25 MB limit, and then Android silently skips the whole copy.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _manifest = 'android/app/src/main/AndroidManifest.xml';
const _backupRules = 'android/app/src/main/res/xml/backup_rules.xml';
const _extractionRules =
    'android/app/src/main/res/xml/data_extraction_rules.xml';

/// The database and its auxiliary files, relative to the app's data folder
/// (`getApplicationDocumentsDirectory` is `app_flutter/` on Android).
const _databaseFiles = {
  'app_flutter/estudicards.sqlite',
  'app_flutter/estudicards.sqlite-wal',
  'app_flutter/estudicards.sqlite-journal',
};

/// The `domain/path` of every `<include>` in [xml].
Set<String> _included(String xml) => {
  for (final match in RegExp(
    r'<include\s+domain="([^"]+)"\s+path="([^"]+)"\s*/>',
  ).allMatches(xml))
    '${match.group(1)}/${match.group(2)}',
};

/// The text between `<tag>` and `</tag>` in [xml].
String _section(String xml, String tag) {
  final match = RegExp('<$tag>(.*?)</$tag>', dotAll: true).firstMatch(xml);
  expect(match, isNotNull, reason: 'no <$tag> section');
  return match!.group(1)!;
}

void main() {
  final expected = {for (final file in _databaseFiles) 'root/$file'};

  test('the manifest declares the rules for every Android version', () {
    final application = RegExp('<application[^>]*>')
        .firstMatch(File(_manifest).readAsStringSync())!
        .group(0)!;

    // Android 12 and later read `dataExtractionRules`; older versions read
    // `fullBackupContent`.
    expect(
      application,
      contains('android:dataExtractionRules="@xml/data_extraction_rules"'),
    );
    expect(
      application,
      contains('android:fullBackupContent="@xml/backup_rules"'),
    );
  });

  test('the rules for Android 11 and older include only the database', () {
    expect(_included(File(_backupRules).readAsStringSync()), expected);
  });

  for (final section in ['cloud-backup', 'device-transfer']) {
    test('the $section rules include only the database', () {
      final xml = File(_extractionRules).readAsStringSync();

      expect(_included(_section(xml, section)), expected);
    });
  }

  test('no rule includes the images, the automatic backups or the cache', () {
    final included = {
      ..._included(File(_backupRules).readAsStringSync()),
      ..._included(File(_extractionRules).readAsStringSync()),
    };

    for (final path in included) {
      expect(path, isNot(contains('images')));
      expect(path, isNot(contains('backups')));
      expect(path, isNot(contains('cache')));
      // A folder (`app_flutter/` or the root itself) would bring them along.
      expect(path, isNot(endsWith('/')));
    }
  });
}
