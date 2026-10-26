import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

const _ciPath = '.github/workflows/ci.yml';
const _releasePath = '.github/workflows/release.yml';

YamlMap _load(String path) =>
    loadYaml(File(path).readAsStringSync()) as YamlMap;

/// The jobs of a workflow, by id.
Map<String, YamlMap> _jobs(YamlMap workflow) =>
    (workflow['jobs'] as YamlMap).cast<String, YamlMap>();

List<YamlMap> _steps(YamlMap job) =>
    (job['steps'] as YamlList? ?? YamlList()).cast<YamlMap>();

/// Every step of a workflow, labelled "job › step" for failure messages.
Map<String, YamlMap> _allSteps(YamlMap workflow) => {
  for (final MapEntry(key: id, value: job) in _jobs(workflow).entries)
    for (final (i, step) in _steps(job).indexed)
      '$id › ${step['name'] ?? i}': step,
};

String _run(YamlMap step) => step['run'] as String? ?? '';

bool _uses(YamlMap step, String action) =>
    (step['uses'] as String? ?? '').startsWith('$action@');

/// Every key in [node], at any depth.
Iterable<Object?> _keys(Object? node) sync* {
  if (node is YamlMap) {
    for (final MapEntry(:key, :value) in node.entries) {
      yield key;
      yield* _keys(value);
    }
  } else if (node is YamlList) {
    for (final item in node) {
      yield* _keys(item);
    }
  }
}

void main() {
  final release = _load(_releasePath);

  test('the release builds use no caches from earlier runs', () {
    expect(_keys(release), isNot(contains('cache')));
  });

  test('every pub get in the release keeps to pubspec.lock', () {
    final pubGets = _allSteps(release).entries
        .where((step) => _run(step.value).contains('pub get'));

    expect(pubGets, isNotEmpty);
    for (final step in pubGets) {
      expect(
        _run(step.value),
        contains('--enforce-lockfile'),
        reason: step.key,
      );
    }
  });

  test('no checkout leaves the job token in .git/config', () {
    for (final path in [_ciPath, _releasePath]) {
      final checkouts = _allSteps(_load(path)).entries
          .where((step) => _uses(step.value, 'actions/checkout'));

      expect(checkouts, isNotEmpty, reason: path);
      for (final step in checkouts) {
        final options = step.value['with'] as YamlMap?;
        expect(
          options?['persist-credentials'],
          isFalse,
          reason: '$path: ${step.key}',
        );
      }
    }
  });

  test('Inno Setup is installed at a fixed version', () {
    final installs = _allSteps(release).values
        .map(_run)
        .where((run) => run.contains('choco install innosetup'));

    expect(installs, hasLength(1));
    expect(installs.single, matches(RegExp(r'--version[ =]\d+\.\d+\.\d+')));
  });

  group('the GitHub Release', () {
    final releaseJob = _jobs(release).values.singleWhere(
      (job) => _steps(job).any((step) => _run(step).contains('gh release')),
    );
    final steps = _steps(releaseJob);
    final publish = steps.indexWhere(
      (step) => _run(step).contains('gh release create'),
    );

    test('attaches SHA256SUMS.txt, written from the installers', () {
      final checksums = steps.indexWhere(
        (step) =>
            _run(step).contains('sha256sum') &&
            _run(step).contains('SHA256SUMS.txt'),
      );

      expect(checksums, isNot(-1), reason: 'a step writes SHA256SUMS.txt');
      expect(checksums, lessThan(publish));
      expect(_run(steps[publish]), contains('dist/SHA256SUMS.txt'));
    });

    test('attests every installer it attaches before publishing', () {
      final attest = steps.indexWhere(
        (step) => _uses(step, 'actions/attest-build-provenance'),
      );
      expect(attest, isNot(-1), reason: 'an attest-build-provenance step');
      expect(attest, lessThan(publish));

      // The release attaches the installers with the same pattern.
      final subject = (steps[attest]['with'] as YamlMap)['subject-path'];
      expect(subject, isA<String>());
      expect(_run(steps[publish]), contains(subject as String));
    });
  });

  test('only the jobs that attest can get an OIDC token or attest', () {
    for (final path in [_ciPath, _releasePath]) {
      final workflow = _load(path);
      final topLevel = workflow['permissions'] as YamlMap;
      expect(topLevel.keys, isNot(contains('id-token')), reason: path);
      expect(topLevel.keys, isNot(contains('attestations')), reason: path);

      for (final MapEntry(key: id, value: job) in _jobs(workflow).entries) {
        final attests = _steps(job)
            .any((step) => _uses(step, 'actions/attest-build-provenance'));
        final permissions = job['permissions'] as YamlMap? ?? YamlMap();
        final expected = attests ? 'write' : null;

        expect(permissions['id-token'], expected, reason: '$path: $id');
        expect(permissions['attestations'], expected, reason: '$path: $id');
      }
    }
  });
}
