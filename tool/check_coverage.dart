// Checks the coverage thresholds from SPEC §10.2 and fails CI if they are
// not met. Run it after `flutter test --coverage`:
//
//   dart run tool/check_coverage.dart [path/to/lcov.info]
//
// The report (lcov.info) lists, for each source file, the lines that can run
// (LF, "lines found") and the lines the tests actually ran (LH, "lines hit").
import 'dart:io';

/// Minimum percentage of lines covered across all of `lib/`.
const double minOverallCoverage = 70;

/// Minimum percentage of lines covered in the `domain/` folders.
const double minDomainCoverage = 90;

class FileCoverage {
  const new({required this.linesFound, required this.linesHit});

  final int linesFound;
  final int linesHit;
}

class CoverageResult {
  const new({
    required this.overall,
    required this.domain,
    required this.failures,
  });

  final double overall;

  /// `null` when there is no `domain/` code yet, so its threshold is skipped.
  final double? domain;

  /// One message per threshold that was not met. Empty means success.
  final List<String> failures;

  bool get passed => failures.isEmpty;
}

/// Reads an lcov report into a map from file path to its line counts.
/// Paths always use forward slashes, whatever the platform.
Map<String, FileCoverage> parseLcov(String content) {
  final files = <String, FileCoverage>{};
  String? path;
  var found = 0;
  var hit = 0;

  for (final line in content.split('\n').map((l) => l.trim())) {
    if (line.startsWith('SF:')) {
      path = line.substring(3).replaceAll(r'\', '/');
      found = 0;
      hit = 0;
    } else if (line.startsWith('LF:')) {
      found = int.parse(line.substring(3));
    } else if (line.startsWith('LH:')) {
      hit = int.parse(line.substring(3));
    } else if (line == 'end_of_record' && path != null) {
      files[path] = FileCoverage(linesFound: found, linesHit: hit);
      path = null;
    }
  }
  return files;
}

/// Compares the coverage of [files] with the thresholds.
CoverageResult checkCoverage(Map<String, FileCoverage> files) {
  final failures = <String>[];

  final overall = _percentage(files.values);
  if (overall == null) {
    failures.add('The coverage report has no lines.');
  } else if (overall < minOverallCoverage) {
    failures.add(
      'Coverage overall is ${_format(overall)}%, '
      'below the minimum of ${_format(minOverallCoverage)}%.',
    );
  }

  final domain = _percentage(
    files.entries.where((e) => e.key.contains('/domain/')).map((e) => e.value),
  );
  if (domain != null && domain < minDomainCoverage) {
    failures.add(
      'Coverage in domain/ is ${_format(domain)}%, '
      'below the minimum of ${_format(minDomainCoverage)}%.',
    );
  }

  return CoverageResult(
    overall: overall ?? 0,
    domain: domain,
    failures: failures,
  );
}

/// Percentage of lines hit, or `null` if there are no lines to cover.
double? _percentage(Iterable<FileCoverage> files) {
  var found = 0;
  var hit = 0;
  for (final file in files) {
    found += file.linesFound;
    hit += file.linesHit;
  }
  return found == 0 ? null : hit * 100 / found;
}

String _format(double value) => value.toStringAsFixed(1);

void main(List<String> args) {
  final file = File(args.isEmpty ? 'coverage/lcov.info' : args.first);
  if (!file.existsSync()) {
    stderr.writeln(
      '${file.path} not found. Run `flutter test --coverage` first.',
    );
    exit(1);
  }

  final result = checkCoverage(parseLcov(file.readAsStringSync()));
  final domain = result.domain;
  stdout
    ..writeln('Overall coverage: ${_format(result.overall)}%')
    ..writeln(
      domain == null
          ? 'Domain coverage: no domain/ code yet, threshold skipped'
          : 'Domain coverage: ${_format(domain)}%',
    );

  if (!result.passed) {
    result.failures.forEach(stderr.writeln);
    exit(1);
  }
}
