import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:estudicards/core/clock.dart';
import 'package:estudicards/core/db/app_database.dart';
import 'package:estudicards/features/projects/data/projects_dao.dart';
import 'package:estudicards/features/projects/data/projects_repository.dart';
import 'package:estudicards/features/projects/domain/project.dart';
import 'package:estudicards/features/projects/domain/project_input.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late FakeClock clock;
  late ProjectsRepository repository;
  final start = DateTime.utc(2026, 10, 6, 9);

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    clock = FakeClock(start);
    repository = ProjectsRepository(ProjectsDao(db), clock);
  });

  tearDown(() => db.close());

  ProjectInput general(String name) =>
      ProjectInput(name: name, color: 'blue', icon: 'globe');

  ProjectInput language({String? sourceLang, String? targetLang}) =>
      ProjectInput(
        name: 'Inglés B2',
        color: 'blue',
        icon: 'globe',
        type: ProjectType.language,
        sourceLang: sourceLang,
        targetLang: targetLang,
      );

  Matcher failsWith(ProjectInputError error) => throwsA(
    isA<InvalidProjectException>().having(
      (e) => e.errors,
      'errors',
      contains(error),
    ),
  );

  Future<List<String>> listedNames() async =>
      (await repository.watchProjects().first).map((p) => p.name).toList();

  group('create', () {
    test('stores the project with a new ID and the clock time', () async {
      final project = await repository.create(
        const ProjectInput(
          name: '  Biología 2º Bach.  ',
          description: 'Temas 1 a 5',
          color: 'green',
          icon: 'flask',
        ),
      );

      expect(project.id, hasLength(36));
      expect(project.name, 'Biología 2º Bach.');
      expect(project.description, 'Temas 1 a 5');
      expect(project.color, 'green');
      expect(project.icon, 'flask');
      expect(project.type, ProjectType.general);
      expect(project.isFavorite, isFalse);
      expect(project.isArchived, isFalse);
      expect(project.createdAt, start);
      expect(project.updatedAt, start);

      final stored = (await repository.getById(project.id))!;
      expect(stored.name, 'Biología 2º Bach.');
      expect(stored.description, 'Temas 1 a 5');
      expect(stored.createdAt, start);
    });

    test('fails with no name', () async {
      expect(() => repository.create(general('')), failsWith(.nameMissing));
      expect(() => repository.create(general('   ')), failsWith(.nameMissing));
      expect(await listedNames(), isEmpty);
    });

    test('fails with 61 characters and accepts 60', () async {
      expect(
        () => repository.create(general('a' * 61)),
        failsWith(.nameTooLong),
      );

      await repository.create(general('a' * 60));
      expect(await listedNames(), ['a' * 60]);
    });

    test('fails with a description longer than 300 characters', () {
      expect(
        () => repository.create(
          ProjectInput(
            name: 'Historia',
            description: 'a' * 301,
            color: 'blue',
            icon: 'book',
          ),
        ),
        failsWith(.descriptionTooLong),
      );
    });

    test('a language project without a source language fails', () {
      expect(
        () => repository.create(language(targetLang: 'es-ES')),
        failsWith(.languagesMissing),
      );
    });

    test('a language project without a target language fails', () {
      expect(
        () => repository.create(language(sourceLang: 'en-GB')),
        failsWith(.languagesMissing),
      );
    });

    test('a language project with both languages is stored', () async {
      final project = await repository.create(
        language(sourceLang: 'en-GB', targetLang: 'es-ES'),
      );

      expect(project.type, ProjectType.language);
      expect(project.sourceLang, 'en-GB');
      expect(project.targetLang, 'es-ES');
    });
  });

  group('update', () {
    test('changes every field and the update time', () async {
      final project = await repository.create(general('Historia'));
      clock.advance(const Duration(hours: 1));

      final updated = await repository.update(
        project.id,
        const ProjectInput(
          name: 'Historia 1º Bach.',
          description: 'Edad Moderna',
          color: 'violet',
          icon: 'book',
        ),
      );

      expect(updated.name, 'Historia 1º Bach.');
      expect(updated.description, 'Edad Moderna');
      expect(updated.color, 'violet');
      expect(updated.icon, 'book');
      expect(updated.createdAt, start);
      expect(updated.updatedAt, start.add(const Duration(hours: 1)));
    });

    test('fails with an invalid input and keeps the stored data', () async {
      final project = await repository.create(general('Historia'));

      expect(
        () => repository.update(project.id, general('')),
        failsWith(.nameMissing),
      );
      expect((await repository.getById(project.id))!.name, 'Historia');
    });

    test(
      'switching from language to general does not delete the languages',
      () async {
        final project = await repository.create(
          language(sourceLang: 'en-GB', targetLang: 'es-ES'),
        );

        final updated = await repository.update(
          project.id,
          const ProjectInput(name: 'Inglés B2', color: 'blue', icon: 'globe'),
        );

        expect(updated.type, ProjectType.general);
        expect(updated.sourceLang, 'en-GB');
        expect(updated.targetLang, 'es-ES');
      },
    );
  });

  group('list', () {
    test('returns favourites first, then by last use, and excludes archived '
        'and deleted projects', () async {
      final old = await repository.create(general('Old'));
      clock.advance(const Duration(minutes: 1));
      final recent = await repository.create(general('Recent'));
      clock.advance(const Duration(minutes: 1));
      final favourite = await repository.create(general('Favourite'));
      final archived = await repository.create(general('Archived'));
      final deleted = await repository.create(general('Deleted'));

      clock.advance(const Duration(hours: 1));
      await repository.markUsed(old.id);
      clock.advance(const Duration(hours: 1));
      await repository.markUsed(recent.id);
      await repository.setFavorite(favourite.id, isFavorite: true);
      await repository.setArchived(archived.id, isArchived: true);
      // Moving to the trash arrives with T1.7; mark it by hand for now.
      await (db.update(db.projects)..where((p) => p.id.equals(deleted.id)))
          .write(ProjectsCompanion(deletedAt: Value(clock.now())));

      expect(await listedNames(), ['Favourite', 'Recent', 'Old']);
    });

    test('a project never used is sorted by its creation time', () async {
      final used = await repository.create(general('Used'));
      clock.advance(const Duration(hours: 1));
      await repository.markUsed(used.id);
      clock.advance(const Duration(hours: 1));
      await repository.create(general('New'));

      expect(await listedNames(), ['New', 'Used']);
    });

    test('unarchiving brings a project back to the list', () async {
      final project = await repository.create(general('Química'));

      await repository.setArchived(project.id, isArchived: true);
      expect(await listedNames(), isEmpty);

      await repository.setArchived(project.id, isArchived: false);
      expect(await listedNames(), ['Química']);
    });

    test('emits a new list when a project changes', () async {
      final lists = repository.watchProjects().map(
        (projects) => projects.map((p) => p.name).toList(),
      );

      final expectation = expectLater(
        lists,
        emitsInOrder([
          <String>[],
          ['Química'],
        ]),
      );
      await Future<void>.delayed(Duration.zero);
      await repository.create(general('Química'));
      await expectation;
    });
  });

  test('markUsed stores the clock time as the last use', () async {
    final project = await repository.create(general('Química'));
    expect(project.lastUsedAt, isNull);
    clock.advance(const Duration(days: 1));

    await repository.markUsed(project.id);

    final stored = await repository.getById(project.id);
    expect(stored!.lastUsedAt, start.add(const Duration(days: 1)));
  });

  test('setFavorite marks and unmarks a project as favourite', () async {
    final project = await repository.create(general('Química'));

    await repository.setFavorite(project.id, isFavorite: true);
    expect((await repository.getById(project.id))!.isFavorite, isTrue);

    await repository.setFavorite(project.id, isFavorite: false);
    expect((await repository.getById(project.id))!.isFavorite, isFalse);
  });

  test('getById returns null for an unknown ID', () async {
    expect(await repository.getById('missing'), isNull);
  });
}
