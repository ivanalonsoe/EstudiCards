import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:estudicards/core/clock.dart';
import 'package:estudicards/core/db/app_database.dart';
import 'package:estudicards/features/decks/data/decks_dao.dart';
import 'package:estudicards/features/decks/data/decks_repository.dart';
import 'package:estudicards/features/decks/domain/deck.dart';
import 'package:estudicards/features/decks/domain/deck_input.dart';
import 'package:estudicards/features/projects/data/projects_dao.dart';
import 'package:estudicards/features/projects/data/projects_repository.dart';
import 'package:estudicards/features/projects/domain/project.dart';
import 'package:estudicards/features/projects/domain/project_input.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/test_data.dart';

void main() {
  late AppDatabase db;
  late FakeClock clock;
  late ProjectsRepository projects;
  late DecksRepository repository;
  late Project project;
  final start = DateTime.utc(2026, 10, 6, 9);

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    clock = FakeClock(start);
    projects = ProjectsRepository(ProjectsDao(db), clock);
    repository = DecksRepository(DecksDao(db), clock);
    project = await projects.create(
      const ProjectInput(name: 'Inglés B2', color: 'blue', icon: 'globe'),
    );
  });

  tearDown(() => db.close());

  Matcher failsWith(DeckInputError error) => throwsA(
    isA<InvalidDeckException>().having((e) => e.errors, 'errors', [error]),
  );

  Future<List<String>> listedNames([String? projectId]) async =>
      (await repository.watchDecks(projectId ?? project.id).first)
          .map((s) => s.deck.name)
          .toList();

  group('create', () {
    test('stores the deck with a new ID and the clock time', () async {
      final deck = await repository.create(
        project.id,
        const DeckInput(
          name: '  Verbos irregulares ',
          description: ' Los 100 más comunes ',
          color: 'teal',
        ),
      );

      expect(deck.id, hasLength(36));
      expect(deck.projectId, project.id);
      expect(deck.name, 'Verbos irregulares');
      expect(deck.description, 'Los 100 más comunes');
      expect(deck.color, 'teal');
      expect(deck.inheritsColor, isFalse);
      expect(deck.lastUsedAt, isNull);
      expect(deck.createdAt, start);
      expect(deck.updatedAt, start);
      expect((await repository.getById(deck.id))!.name, 'Verbos irregulares');
    });

    test('fails with no name', () async {
      expect(
        () => repository.create(project.id, const DeckInput(name: ' ')),
        failsWith(.nameMissing),
      );
      expect(await listedNames(), isEmpty);
    });

    test('fails with 61 characters and accepts 60', () async {
      expect(
        () => repository.create(project.id, DeckInput(name: 'a' * 61)),
        failsWith(.nameTooLong),
      );

      await repository.create(project.id, DeckInput(name: 'a' * 60));
      expect(await listedNames(), ['a' * 60]);
    });
  });

  group('type and languages', () {
    const english = DeckInput(
      name: 'Verbos irregulares',
      type: DeckType.language,
      sourceLang: 'en-GB',
      targetLang: 'es-ES',
    );

    test('a new deck is general and has no languages', () async {
      final deck = await repository.create(
        project.id,
        const DeckInput(name: 'Célula'),
      );

      expect(deck.type, DeckType.general);
      expect(deck.isLanguage, isFalse);
      expect(deck.sourceLang, isNull);
      expect(deck.targetLang, isNull);
    });

    test('a language deck stores its type and languages', () async {
      final deck = await repository.create(project.id, english);

      expect(deck.type, DeckType.language);
      expect(deck.isLanguage, isTrue);
      expect(deck.sourceLang, 'en-GB');
      expect(deck.targetLang, 'es-ES');
      final listed = (await repository.watchDecks(project.id).first).single;
      expect(listed.deck.type, DeckType.language);
      expect(listed.deck.sourceLang, 'en-GB');
    });

    test('a language deck without a source language fails', () {
      expect(
        () => repository.create(
          project.id,
          const DeckInput(
            name: 'Verbos',
            type: DeckType.language,
            targetLang: 'es-ES',
          ),
        ),
        failsWith(.languagesMissing),
      );
    });

    test('a language deck without a target language fails', () {
      expect(
        () => repository.create(
          project.id,
          const DeckInput(
            name: 'Verbos',
            type: DeckType.language,
            sourceLang: 'en-GB',
          ),
        ),
        failsWith(.languagesMissing),
      );
    });

    test('a project can hold decks of both types', () async {
      // The list goes oldest first.
      await repository.create(project.id, english);
      clock.advance(const Duration(minutes: 1));
      await repository.create(
        project.id,
        const DeckInput(
          name: 'Definitions',
          type: DeckType.language,
          sourceLang: 'en-GB',
          targetLang: 'en-GB',
        ),
      );
      clock.advance(const Duration(minutes: 1));
      await repository.create(project.id, const DeckInput(name: 'Notas'));

      final decks = [
        for (final s in await repository.watchDecks(project.id).first)
          (s.deck.type, s.deck.sourceLang, s.deck.targetLang),
      ];

      expect(decks, [
        (DeckType.language, 'en-GB', 'es-ES'),
        (DeckType.language, 'en-GB', 'en-GB'),
        (DeckType.general, null, null),
      ]);
    });

    test(
      'switching from language to general does not delete the languages',
      () async {
        final deck = await repository.create(project.id, english);

        final updated = await repository.update(
          deck.id,
          const DeckInput(name: 'Verbos irregulares'),
        );

        expect(updated.type, DeckType.general);
        expect(updated.sourceLang, 'en-GB');
        expect(updated.targetLang, 'es-ES');
      },
    );
  });

  group('colour', () {
    test("a deck without a colour returns the project's colour", () async {
      final deck = await repository.create(
        project.id,
        const DeckInput(name: 'Phrasal verbs'),
      );

      expect(deck.color, 'blue');
      expect(deck.inheritsColor, isTrue);
      expect((await repository.getById(deck.id))!.color, 'blue');
      expect(
        (await repository.watchDecks(project.id).first).single.deck.color,
        'blue',
      );
    });

    test("follows the project's colour when the project changes", () async {
      final deck = await repository.create(
        project.id,
        const DeckInput(name: 'Phrasal verbs'),
      );

      await projects.update(
        project.id,
        const ProjectInput(name: 'Inglés B2', color: 'violet', icon: 'globe'),
      );

      expect((await repository.getById(deck.id))!.color, 'violet');
    });

    test('removing its own colour makes the deck inherit again', () async {
      final deck = await repository.create(
        project.id,
        const DeckInput(name: 'Phrasal verbs', color: 'pink'),
      );

      final updated = await repository.update(
        deck.id,
        const DeckInput(name: 'Phrasal verbs'),
      );

      expect(updated.color, 'blue');
      expect(updated.inheritsColor, isTrue);
    });
  });

  group('update', () {
    test('changes the fields and the update time', () async {
      final deck = await repository.create(
        project.id,
        const DeckInput(name: 'Verbos'),
      );
      clock.advance(const Duration(hours: 1));

      final updated = await repository.update(
        deck.id,
        const DeckInput(
          name: 'Verbos irregulares',
          description: 'Lista B',
          color: 'teal',
        ),
      );

      expect(updated.name, 'Verbos irregulares');
      expect(updated.description, 'Lista B');
      expect(updated.color, 'teal');
      expect(updated.createdAt, start);
      expect(updated.updatedAt, start.add(const Duration(hours: 1)));
    });

    test('fails with an invalid input and keeps the stored data', () async {
      final deck = await repository.create(
        project.id,
        const DeckInput(name: 'Verbos'),
      );

      expect(
        () => repository.update(deck.id, const DeckInput(name: '')),
        failsWith(.nameMissing),
      );
      expect((await repository.getById(deck.id))!.name, 'Verbos');
    });
  });

  group('list', () {
    test('excludes deleted decks', () async {
      await repository.create(project.id, const DeckInput(name: 'Kept'));
      final deleted = await repository.create(
        project.id,
        const DeckInput(name: 'Deleted'),
      );
      // Moving to the trash arrives with T1.7; mark it by hand for now.
      await (db.update(db.decks)..where((d) => d.id.equals(deleted.id))).write(
        DecksCompanion(deletedAt: Value(clock.now())),
      );

      expect(await listedNames(), ['Kept']);
    });

    test("only returns the given project's decks, oldest first", () async {
      final other = await projects.create(
        const ProjectInput(name: 'Biología', color: 'green', icon: 'flask'),
      );
      await repository.create(project.id, const DeckInput(name: 'First'));
      await repository.create(other.id, const DeckInput(name: 'Other'));
      clock.advance(const Duration(minutes: 1));
      await repository.create(project.id, const DeckInput(name: 'Second'));

      expect(await listedNames(), ['First', 'Second']);
      expect(await listedNames(other.id), ['Other']);
    });

    test('returns each deck with its number of cards', () async {
      final verbs = await repository.create(
        project.id,
        const DeckInput(name: 'Verbos'),
      );
      final empty = await repository.create(
        project.id,
        const DeckInput(name: 'Vacía'),
      );
      await addTestCard(db, verbs.id);
      await addTestCard(db, verbs.id);

      final counts = {
        for (final s in await repository.watchDecks(project.id).first)
          s.deck.id: s.cardCount,
      };

      expect(counts, {verbs.id: 2, empty.id: 0});
    });

    test('returns each deck with its answers and pending errors, both '
        'directions added up (R 7.6)', () async {
      final verbs = await repository.create(
        project.id,
        const DeckInput(name: 'Verbos'),
      );
      final empty = await repository.create(
        project.id,
        const DeckInput(name: 'Vacía'),
      );
      final bring = await addTestCard(db, verbs.id);
      final seek = await addTestCard(db, verbs.id);
      await addTestAnswers(
        db,
        projectId: project.id,
        cardId: bring,
        results: ['correct', 'wrong'],
      );
      await addTestAnswers(
        db,
        projectId: project.id,
        cardId: bring,
        direction: 'reverse',
        results: ['wrong'],
      );
      await addTestAnswers(
        db,
        projectId: project.id,
        cardId: seek,
        results: ['correct', 'correct'],
      );

      final summaries = {
        for (final s in await repository.watchDecks(project.id).first)
          s.deck.id: s,
      };

      final listed = summaries[verbs.id]!;
      expect((listed.answers.correct, listed.answers.wrong), (3, 2));
      // `to bring` is in errors in both directions: two pairs.
      expect(listed.errorCount, 2);
      expect(summaries[empty.id]!.answers.total, 0);
      expect(summaries[empty.id]!.errorCount, 0);
    });
  });

  test('markUsed stores the clock time as the last use', () async {
    final deck = await repository.create(
      project.id,
      const DeckInput(name: 'Verbos'),
    );
    clock.advance(const Duration(days: 1));

    await repository.markUsed(deck.id);

    final stored = await repository.getById(deck.id);
    expect(stored!.lastUsedAt, start.add(const Duration(days: 1)));
  });

  test('getById returns null for an unknown ID', () async {
    expect(await repository.getById('missing'), isNull);
  });
}
