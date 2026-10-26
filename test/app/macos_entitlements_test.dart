// The macOS sandbox permissions (entitlements). A sandboxed app can only
// touch the files the user picks, and only in the way its entitlements
// allow: "Guardar como…" (export, "Exportar todo") writes the file the user
// chose, so it needs read-write, while the app must still never reach the
// network.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The keys an entitlements file sets to `<true/>`.
Set<String> _enabledKeys(String path) => {
  for (final match in RegExp(
    r'<key>([^<]+)</key>\s*<true/>',
  ).allMatches(File(path).readAsStringSync()))
    match.group(1)!,
};

void main() {
  for (final path in [
    'macos/Runner/Release.entitlements',
    'macos/Runner/DebugProfile.entitlements',
  ]) {
    group(path, () {
      test('lets the app write the files the user picks', () {
        final keys = _enabledKeys(path);

        expect(keys, contains('com.apple.security.app-sandbox'));
        expect(
          keys,
          contains('com.apple.security.files.user-selected.read-write'),
        );
      });

      test('has no read-only file access left', () {
        expect(
          File(path).readAsStringSync(),
          isNot(contains('com.apple.security.files.user-selected.read-only')),
        );
      });

      test('never lets the app connect to the network', () {
        expect(
          File(path).readAsStringSync(),
          isNot(contains('com.apple.security.network.client')),
        );
      });
    });
  }
}
