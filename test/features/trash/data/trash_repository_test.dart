import 'package:drift/drift.dart' show Table, TableInfo;
import 'package:drift/native.dart';
import 'package:estudicards/core/clock.dart';
import 'package:estudicards/core/db/app_database.dart';
import 'package:estudicards/core/files/image_files.dart';
import 'package:estudicards/features/decks/data/decks_dao.dart';
import 'package:estudicards/features/decks/data/decks_repository.dart';
import 'package:estudicards/features/decks/domain/deck.dart';
import 'package:estudicards/features/decks/domain/deck_input.dart';
import 'package:estudicards/features/projects/data/projects_dao.dart';
import 'package:estudicards/features/projects/data/projects_repository.dart';
import 'package:estudicards/features/projects/domain/project.dart';
import 'package:estudicards/features/projects/domain/project_input.dart';
import 'package:estudicards/features/trash/data/trash_dao.dart';
import 'package:estudicards/features/trash/data/trash_repository.dart';
import 'package:estudicards/features/trash/domain/trash_item.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/test_data.dart';

/// Records the image paths it is asked to delete.
class FakeImageFiles implements ImageFiles {
  final deleted = <String>[];

  @override
  Future<void> delete(Iterable<String> relativePaths) async =>
      deleted.addAll(relativePaths);
}

void main() {
  late AppDatabase db;
  late FakeClock clock;
  late FakeImageFiles images;
  late ProjectsRepository projects;
  late DecksRepository decks;
  late TrashRepository trash;
  final start = DateTime.utc(2026, 10, 1, 9);

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    clock = FakeClock(start);
    images = FakeImageFiles();
    projects = ProjectsRepository(ProjectsDao(db), clock);
    decks = DecksRepository(DecksDao(db), clock);
    trash = TrashRepository(TrashDao(db), clock, images);
  });

  tearDown(() => db.close());

  Future<Project> createProject(String name) =>
      projects.create(ProjectInput(name: name, color: 'blue', icon: 'globe'));

  Future<Deck> createDeck(Project project, String name, {int cards = 0}) async {
    final deck = await decks.create(project.id, DeckInput(name: name));
    for (var i = 0; i < cards; i++) {
      await addTestCard(db, deck.id);
    }
    return deck;
  }

  Future<List<String>> dashboardNames() async => [
    for (final s in await projects.watchProjects().first) s.project.name,
  ];

  Future<List<String>> deckNames(Project project) async => [
    for (final s in await decks.watchDecks(project.id).first) s.deck.name,
  ];

  Future<List<TrashItem>> trashItems() => trash.watchTrash().first;

  Future<int> rowCount(TableInfo<Table, Object?> table) =>
      db.select(table).get().then((rows) => rows.length);

  group('move to trash', () {
    test(
      'deleting a project hides it from the list and shows it in the trash',
      () async {
        final english = await createProject('Inglés B2');
        await createProject('Biología');

        await trash.moveProjectToTrash(english.id);

        expect(await dashboardNames(), ['Biología']);
        final [item] = await trashItems();
        expect(item.type, TrashItemType.project);
        expect(item.id, english.id);
        expect(item.name, 'Inglés B2');
        expect(item.deletedAt, start);
      },
    );

    test('deleting a deck hides it from its project', () async {
      final english = await createProject('Inglés B2');
      final verbs = await createDeck(english, 'Verbos');
      await createDeck(english, 'Phrasal verbs');

      await trash.moveDeckToTrash(verbs.id);

      expect(await deckNames(english), ['Phrasal verbs']);
      final [item] = await trashItems();
      expect(item.type, TrashItemType.deck);
      expect(item.name, 'Verbos');
      expect(item.projectName, 'Inglés B2');
    });

    test('items show their counts, the newest deleted first', () async {
      final english = await createProject('Inglés B2');
      final verbs = await createDeck(english, 'Verbos', cards: 2);
      await createDeck(english, 'Phrasal verbs', cards: 3);
      final law = await createProject('Oposiciones');
      final constitution = await createDeck(law, 'Constitución', cards: 4);

      await trash.moveDeckToTrash(verbs.id);
      clock.advance(const Duration(hours: 1));
      await trash.moveDeckToTrash(constitution.id);
      clock.advance(const Duration(hours: 1));
      await trash.moveProjectToTrash(english.id);

      final items = await trashItems();
      expect(items.map((i) => i.name), ['Inglés B2', 'Constitución', 'Verbos']);
      // The project counts the decks that are not in the trash themselves.
      expect((items[0].deckCount, items[0].cardCount), (1, 3));
      expect(items[1].cardCount, 4);
      expect(items[1].projectName, 'Oposiciones');
      expect(items[2].cardCount, 2);
    });
  });

  test('the trash list is emitted again when it changes', () async {
    final english = await createProject('Inglés B2');
    final counts = trash.watchTrash().map((items) => items.length).take(3);
    final emitted = counts.toList();
    await pumpEventQueue();

    await trash.moveProjectToTrash(english.id);
    await pumpEventQueue();
    await trash.restoreProject(english.id);

    expect(await emitted, [0, 1, 0]);
  });

  group('restore', () {
    test('restoring a project puts it back with its decks', () async {
      final english = await createProject('Inglés B2');
      await createDeck(english, 'Verbos', cards: 1);
      await trash.moveProjectToTrash(english.id);

      await trash.restoreProject(english.id);

      expect(await dashboardNames(), ['Inglés B2']);
      expect(await deckNames(english), ['Verbos']);
      expect(await trashItems(), isEmpty);
    });

    test('restoring a deck whose project is in the trash also restores the '
        'project', () async {
      final english = await createProject('Inglés B2');
      final verbs = await createDeck(english, 'Verbos');
      await trash.moveDeckToTrash(verbs.id);
      await trash.moveProjectToTrash(english.id);

      await trash.restoreDeck(verbs.id);

      expect(await dashboardNames(), ['Inglés B2']);
      expect(await deckNames(english), ['Verbos']);
      expect(await trashItems(), isEmpty);
    });

    test('restoring a deck leaves other trashed decks in the trash', () async {
      final english = await createProject('Inglés B2');
      final verbs = await createDeck(english, 'Verbos');
      final phrasal = await createDeck(english, 'Phrasal verbs');
      await trash.moveDeckToTrash(verbs.id);
      await trash.moveDeckToTrash(phrasal.id);

      await trash.restoreDeck(verbs.id);

      expect(await deckNames(english), ['Verbos']);
      expect((await trashItems()).single.name, 'Phrasal verbs');
    });
  });

  group('purge', () {
    test('at 14 days it is still in the trash; at 15 days the purge deletes it '
        'with its decks, cards, attempts and images', () async {
      final english = await createProject('Inglés B2');
      final verbs = await createDeck(english, 'Verbos');
      final cardId = await addTestCard(
        db,
        verbs.id,
        questionImage: 'images/q.jpg',
        answerImage: 'images/a.jpg',
      );
      await addTestCard(db, verbs.id);
      await addTestAttempt(db, projectId: english.id, cardId: cardId);
      await trash.moveProjectToTrash(english.id);

      clock.advance(const Duration(days: 14, hours: 23));
      expect(await trash.purgeExpired(), 0);
      expect(await trashItems(), hasLength(1));
      expect(images.deleted, isEmpty);

      clock.advance(const Duration(hours: 1));
      expect(await trash.purgeExpired(), 1);

      expect(await trashItems(), isEmpty);
      expect(await projects.getById(english.id), isNull);
      expect(await rowCount(db.decks), 0);
      expect(await rowCount(db.cards), 0);
      expect(await rowCount(db.attempts), 0);
      expect(await rowCount(db.studySessions), 0);
      expect(images.deleted, unorderedEquals(['images/q.jpg', 'images/a.jpg']));
    });

    test('purges an expired deck and keeps its active project', () async {
      final english = await createProject('Inglés B2');
      final verbs = await createDeck(english, 'Verbos', cards: 2);
      await createDeck(english, 'Phrasal verbs', cards: 1);
      await trash.moveDeckToTrash(verbs.id);

      clock.advance(const Duration(days: 15));
      await trash.purgeExpired();

      expect(await dashboardNames(), ['Inglés B2']);
      expect(await deckNames(english), ['Phrasal verbs']);
      expect(await rowCount(db.cards), 1);
    });
  });

  group('delete permanently', () {
    test('deletes one project with everything in it', () async {
      final english = await createProject('Inglés B2');
      await createDeck(english, 'Verbos', cards: 2);
      final law = await createProject('Oposiciones');
      await createDeck(law, 'Constitución', cards: 1);
      await trash.moveProjectToTrash(english.id);
      await trash.moveProjectToTrash(law.id);

      await trash.deleteProjectPermanently(english.id);

      expect((await trashItems()).single.name, 'Oposiciones');
      expect(await rowCount(db.cards), 1);
    });

    test('deletes one deck with its cards and images', () async {
      final english = await createProject('Inglés B2');
      final verbs = await createDeck(english, 'Verbos');
      await addTestCard(db, verbs.id, answerImage: 'images/a.jpg');
      await createDeck(english, 'Phrasal verbs', cards: 1);
      await trash.moveDeckToTrash(verbs.id);

      await trash.deleteDeckPermanently(verbs.id);

      expect(await trashItems(), isEmpty);
      expect(await deckNames(english), ['Phrasal verbs']);
      expect(await rowCount(db.cards), 1);
      expect(images.deleted, ['images/a.jpg']);
    });

    test('emptying the trash deletes every item in it', () async {
      final english = await createProject('Inglés B2');
      final law = await createProject('Oposiciones');
      final constitution = await createDeck(law, 'Constitución', cards: 2);
      await createDeck(law, 'Ley 39/2015', cards: 1);
      await trash.moveProjectToTrash(english.id);
      await trash.moveDeckToTrash(constitution.id);

      await trash.emptyTrash();

      expect(await trashItems(), isEmpty);
      expect(await dashboardNames(), ['Oposiciones']);
      expect(await deckNames(law), ['Ley 39/2015']);
      expect(await rowCount(db.cards), 1);
    });
  });
}
