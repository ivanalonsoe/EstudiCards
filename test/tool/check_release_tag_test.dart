import 'package:flutter_test/flutter_test.dart';

import '../../tool/check_release_tag.dart';

/// A pubspec.yaml with [version] among other lines.
String pubspec(String version) =>
    'name: estudicards\n'
    'description: "Flashcards"\n'
    'version: $version\n'
    '\n'
    'environment:\n'
    '  sdk: ^3.9.0\n';

void main() {
  group('releaseFromTag', () {
    test('a tag "v" + the pubspec version is a final release', () {
      final release = releaseFromTag('v1.0.0', pubspec('1.0.0+1'));

      expect(release.version, '1.0.0');
      expect(release.prerelease, isFalse);
    });

    test('a suffix after "-" makes a pre-release of that version', () {
      final release = releaseFromTag('v1.0.0-rc.1', pubspec('1.0.0+1'));

      expect(release.version, '1.0.0-rc.1');
      expect(release.prerelease, isTrue);
    });

    test('a tag for another version is refused, naming both', () {
      expect(
        () => releaseFromTag('v1.0.1', pubspec('1.0.0+1')),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            allOf(contains('1.0.1'), contains('1.0.0')),
          ),
        ),
      );
    });

    test('a tag without the leading "v" is refused', () {
      expect(
        () => releaseFromTag('1.0.0', pubspec('1.0.0+1')),
        throwsFormatException,
      );
    });

    test('an empty suffix is refused', () {
      expect(
        () => releaseFromTag('v1.0.0-', pubspec('1.0.0+1')),
        throwsFormatException,
      );
    });

    test('a pubspec with no version is refused', () {
      expect(
        () => releaseFromTag('v1.0.0', 'name: estudicards\n'),
        throwsFormatException,
      );
    });
  });

  test('githubOutput writes the lines the workflow reads', () {
    expect(
      githubOutput((version: '1.0.0-rc.1', prerelease: true)),
      'version=1.0.0-rc.1\nprerelease=true\n',
    );
  });
}
