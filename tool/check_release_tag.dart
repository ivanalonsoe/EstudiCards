// Checks that a release tag matches the app version before `release.yml`
// builds anything, so a release can never carry the wrong version number:
//
//   dart run tool/check_release_tag.dart v1.0.0-rc.1
//
// The tag is "v" + the version in pubspec.yaml without its build number
// (`1.0.0+1` → `v1.0.0`), optionally followed by "-" and a pre-release
// suffix (`v1.0.0-rc.1`). In GitHub Actions it adds the release version and
// whether it is a pre-release to the job's outputs; otherwise it only says
// what it would release. A tag that does not match fails with a message.
import 'dart:io';

/// The release a tag stands for: its version (`1.0.0-rc.1`) and whether it
/// is a pre-release (it has a suffix).
typedef Release = ({String version, bool prerelease});

/// The release of [tag] for a pubspec.yaml whose contents are [pubspec].
/// Throws a [FormatException] when the tag does not match its version.
Release releaseFromTag(String tag, String pubspec) {
  final match = RegExp(
    r'^version:\s*(\S+)',
    multiLine: true,
  ).firstMatch(pubspec);
  if (match == null) {
    throw const FormatException('pubspec.yaml has no "version:" line.');
  }
  // `1.0.0+1` → `1.0.0`: the part after "+" is Android's build number.
  final appVersion = match[1]!.split('+').first;

  final parts = RegExp(r'^v([^-]+)(?:-(.+))?$').firstMatch(tag);
  if (parts == null) {
    throw FormatException(
      'The tag "$tag" must be "v" + the version, e.g. v$appVersion or '
      'v$appVersion-rc.1.',
    );
  }
  if (parts[1] != appVersion) {
    throw FormatException(
      'The tag "$tag" is for version ${parts[1]}, but pubspec.yaml has '
      '$appVersion. Change one of them so they match.',
    );
  }
  return (version: tag.substring(1), prerelease: parts[2] != null);
}

/// [release] as `name=value` lines for `$GITHUB_OUTPUT`.
String githubOutput(Release release) =>
    'version=${release.version}\nprerelease=${release.prerelease}\n';

void main(List<String> args) {
  if (args.length != 1) {
    stderr.writeln('Usage: dart run tool/check_release_tag.dart <tag>');
    exit(2);
  }
  try {
    final release = releaseFromTag(
      args.single,
      File('pubspec.yaml').readAsStringSync(),
    );
    stdout.writeln(
      'Releasing ${release.version}'
      '${release.prerelease ? ' (pre-release)' : ''}.',
    );
    // In GitHub Actions, the job's outputs go to the file this variable
    // names. Written there rather than printed, since `dart run` prints its
    // own lines too.
    final outputs = Platform.environment['GITHUB_OUTPUT'];
    if (outputs != null) {
      File(outputs)
          .writeAsStringSync(githubOutput(release), mode: FileMode.append);
    }
  } on FormatException catch (error) {
    stderr.writeln(error.message);
    exit(1);
  }
}
