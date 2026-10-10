import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:estudicards/core/clock.dart';
import 'package:estudicards/core/db/app_database.dart';
import 'package:estudicards/core/ids.dart';
import 'package:estudicards/features/decks/data/decks_dao.dart';
import 'package:estudicards/features/decks/data/decks_repository.dart';
import 'package:estudicards/features/decks/domain/deck_input.dart';
import 'package:estudicards/features/projects/data/projects_dao.dart';
import 'package:estudicards/features/projects/data/projects_repository.dart';
import 'package:estudicards/features/projects/domain/project_input.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/test_data.dart';

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

  Matcher failsWith(ProjectInputError error) => throwsA(
    isA<InvalidProjectException>().having(
      (e) => e.errors,
      'errors',
      contains(error),
    ),
  );

  Future<List<String>> listedNames() async =>
      (await repository.watchProjects().first)
          .map((s) => s.project.name)
          .toList();

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
        (summaries) => summaries.map((s) => s.project.name).toList(),
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

  test(
    'counts the decks and cards of each project, ignoring decks in the trash',
    () async {
      final english = await repository.create(general('Inglés B2'));
      final empty = await repository.create(general('Biología'));
      final decks = DecksRepository(DecksDao(db), clock);
      final verbs = await decks.create(
        english.id,
        const DeckInput(name: 'Verbos'),
      );
      final phrasal = await decks.create(
        english.id,
        const DeckInput(name: 'Phrasal verbs'),
      );
      final deleted = await decks.create(
        english.id,
        const DeckInput(name: 'Antiguos'),
      );
      // Cards and the trash arrive in later tasks; insert them by hand.
      Future<void> addCard(String deckId) => db
          .into(db.cards)
          .insert(
            CardsCompanion.insert(
              id: newId(),
              deckId: deckId,
              type: 'simple',
              question: 'to bring',
              answer: const Value('traer'),
              createdAt: start,
              updatedAt: start,
            ),
          );
      await addCard(verbs.id);
      await addCard(verbs.id);
      await addCard(phrasal.id);
      await addCard(deleted.id);
      await (db.update(db.decks)..where((d) => d.id.equals(deleted.id))).write(
        DecksCompanion(deletedAt: Value(start)),
      );

      final summaries = {
        for (final s in await repository.watchProjects().first) s.project.id: s,
      };

      expect(summaries[english.id]!.deckCount, 2);
      expect(summaries[english.id]!.cardCount, 3);
      expect(summaries[empty.id]!.deckCount, 0);
      expect(summaries[empty.id]!.cardCount, 0);
    },
  );

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

  group('archive', () {
    test('archiving stores the time; unarchiving clears it', () async {
      final project = await repository.create(general('Alemán A1'));
      clock.advance(const Duration(days: 2));

      await repository.setArchived(project.id, isArchived: true);
      final archived = (await repository.getById(project.id))!;
      expect(archived.isArchived, isTrue);
      expect(archived.archivedAt, clock.now());

      await repository.setArchived(project.id, isArchived: false);
      final back = (await repository.getById(project.id))!;
      expect(back.isArchived, isFalse);
      expect(back.archivedAt, isNull);
    });

    test('the archived list has the archived projects not in the trash, the '
        'most recently archived first, with their counts', () async {
      final german = await repository.create(general('Alemán A1'));
      final chemistry = await repository.create(general('Química'));
      final deleted = await repository.create(general('Deleted'));
      await repository.create(general('Active'));
      final decks = DecksRepository(DecksDao(db), clock);
      final deck = await decks.create(
        german.id,
        const DeckInput(name: 'Saludos'),
      );
      await addTestCard(db, deck.id);

      await repository.setArchived(german.id, isArchived: true);
      clock.advance(const Duration(days: 1));
      await repository.setArchived(chemistry.id, isArchived: true);
      await repository.setArchived(deleted.id, isArchived: true);
      await (db.update(db.projects)..where((p) => p.id.equals(deleted.id)))
          .write(ProjectsCompanion(deletedAt: Value(clock.now())));

      final archived = await repository.watchArchived().first;

      expect(archived.map((s) => s.project.name), ['Química', 'Alemán A1']);
      expect((archived[1].deckCount, archived[1].cardCount), (1, 1));
    });
  });

  group('watchProject', () {
    test('emits the project again after it is edited', () async {
      final project = await repository.create(general('Química'));
      final names = repository
          .watchProject(project.id)
          .map((p) => p?.name)
          .take(2)
          .toList();
      // Wait for the first value before editing.
      await pumpEventQueue();

      await repository.update(project.id, general('Química orgánica'));

      expect(await names, ['Química', 'Química orgánica']);
    });

    test('emits null for an unknown ID', () async {
      expect(await repository.watchProject('missing').first, isNull);
    });
  });
}
