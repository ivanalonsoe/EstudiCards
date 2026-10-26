import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

/// A `uses:` line pinned to a full commit SHA, with the version that commit
/// is as a comment (Dependabot keeps that comment up to date):
///
///     uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
final _pinnedUses = RegExp(r'uses:\s+[\w.-]+/[\w./-]+@[0-9a-f]{40}\s+#\s+v\d');

void main() {
  test('every action in the workflows is pinned to a full commit SHA', () {
    final workflows = Directory('.github/workflows')
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.yml'));
    expect(workflows, isNotEmpty);

    final unpinned = <String>[];
    var found = 0;
    for (final file in workflows) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (!lines[i].contains(RegExp(r'^\s*(-\s+)?uses:'))) continue;
        found++;
        if (!_pinnedUses.hasMatch(lines[i])) {
          unpinned.add('${file.path}:${i + 1}: ${lines[i].trim()}');
        }
      }
    }

    expect(found, greaterThan(0));
    expect(unpinned, isEmpty, reason: 'Pin these to a commit SHA:');
  });

  test('Dependabot proposes updates for the actions every week', () {
    final file = File('.github/dependabot.yml');
    expect(file.existsSync(), isTrue, reason: '.github/dependabot.yml');

    final config = loadYaml(file.readAsStringSync()) as YamlMap;
    final updates = (config['updates'] as YamlList).cast<YamlMap>();
    final actions = updates.where(
      (update) => update['package-ecosystem'] == 'github-actions',
    );

    expect(actions, hasLength(1));
    expect(actions.single['directory'], '/');
    expect((actions.single['schedule'] as YamlMap)['interval'], 'weekly');
  });
}
