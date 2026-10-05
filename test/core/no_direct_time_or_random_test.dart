import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The only files allowed to read the real time or create a `Random`
/// (SPEC §10.3). Everything else receives a `Clock` or a `Random`.
const allowedFiles = {'lib/core/clock.dart', 'lib/core/random.dart'};

/// Source files in `lib/`, written by us (not generated).
List<File> sourceFiles() =>
    Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart') && !f.path.endsWith('.g.dart'))
        .toList();

String relativePath(File file) => file.path.replaceAll(r'\', '/');

/// Files outside [allowedFiles] whose code matches [pattern].
List<String> filesUsing(RegExp pattern) => [
  for (final file in sourceFiles())
    if (!allowedFiles.contains(relativePath(file)) &&
        pattern.hasMatch(file.readAsStringSync()))
      relativePath(file),
];

void main() {
  test('no file in lib/ reads the time directly', () {
    expect(
      filesUsing(RegExp(r'DateTime\.(now|timestamp)\(')),
      isEmpty,
      reason: 'use the injectable Clock from core/clock.dart',
    );
  });

  test('no file in lib/ creates a Random directly', () {
    expect(
      filesUsing(RegExp(r'\bRandom(\.secure)?\(')),
      isEmpty,
      reason: 'receive a Random, created with core/random.dart',
    );
  });
}
