import 'package:estudicards/features/projects/domain/project.dart';
import 'package:estudicards/features/projects/domain/project_input.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ProjectInput.validate', () {
    test('a general project with a name is valid', () {
      const input = ProjectInput(name: 'Historia', color: 'blue', icon: 'book');

      expect(input.validate(), isEmpty);
    });

    test('reports every error at once', () {
      final input = ProjectInput(
        name: ' ',
        description: 'a' * 301,
        color: 'blue',
        icon: 'globe',
        type: ProjectType.language,
        sourceLang: 'en-GB',
        targetLang: '  ',
      );

      expect(input.validate(), [
        ProjectInputError.nameMissing,
        ProjectInputError.descriptionTooLong,
        ProjectInputError.languagesMissing,
      ]);
    });

    test('counts the name and description without surrounding spaces', () {
      final input = ProjectInput(
        name: '  ${'a' * 60}  ',
        description: '  ${'a' * 300}  ',
        color: 'blue',
        icon: 'book',
      );

      expect(input.validate(), isEmpty);
      expect(input.trimmedName, 'a' * 60);
      expect(input.trimmedDescription, 'a' * 300);
    });

    test('a blank description becomes null', () {
      const input = ProjectInput(
        name: 'Historia',
        description: '   ',
        color: 'blue',
        icon: 'book',
      );

      expect(input.trimmedDescription, isNull);
    });
  });

  test('ProjectType.fromStored falls back to general for unknown values', () {
    expect(ProjectType.fromStored('language'), ProjectType.language);
    expect(ProjectType.fromStored('unknown'), ProjectType.general);
  });

  test('InvalidProjectException lists the errors in its message', () {
    expect(
      const InvalidProjectException([ProjectInputError.nameMissing]).toString(),
      'InvalidProjectException([ProjectInputError.nameMissing])',
    );
  });
}
