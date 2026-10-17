import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:estudicards/core/clock.dart';
import 'package:estudicards/core/db/app_database.dart';
import 'package:estudicards/core/files/card_image.dart';
import 'package:estudicards/core/files/image_files.dart';
import 'package:estudicards/features/cards/data/cards_dao.dart';
import 'package:estudicards/features/cards/data/cards_repository.dart';
import 'package:estudicards/features/cards/domain/card_input.dart';
import 'package:estudicards/features/cards/domain/flashcard.dart';
import 'package:estudicards/features/decks/data/decks_dao.dart';
import 'package:estudicards/features/decks/data/decks_repository.dart';
import 'package:estudicards/features/decks/domain/deck.dart';
import 'package:estudicards/features/decks/domain/deck_input.dart';
import 'package:estudicards/features/import_export/data/exchange_dao.dart';
import 'package:estudicards/features/import_export/data/exchange_repository.dart';
import 'package:estudicards/features/import_export/data/import_dao.dart';
import 'package:estudicards/features/import_export/data/import_repository.dart';
import 'package:estudicards/features/import_export/domain/cards_csv.dart';
import 'package:estudicards/features/import_export/domain/exchange_document.dart';
import 'package:estudicards/features/import_export/domain/import_plan.dart';
import 'package:estudicards/features/projects/data/projects_dao.dart';
import 'package:estudicards/features/projects/data/projects_repository.dart';
import 'package:estudicards/features/projects/domain/project.dart';
import 'package:estudicards/features/projects/domain/project_input.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/test_images.dart';

const _imported = 'Importadas';

CsvSource _csvFixture(String name) =>
    CsvSource(parseCardsCsv(File('test/fixtures/$name').readAsBytesSync()));

void main() {
  late AppDatabase db;
  late Directory folder;
  late DiskImageFiles images;
  late CardsRepository cards;
  late ImportRepository repository;
  late Project project;
  late Deck deck;
  final now = DateTime.utc(2026, 10, 17, 9);

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    folder = createTempFolder();
    images = DiskImageFiles(
      () async => folder,
      prepare: (bytes) async => prepareCardImage(bytes),
    );
    final clock = FakeClock(now);
    cards = CardsRepository(CardsDao(db), clock, images);
    repository = ImportRepository(ImportDao(db), clock, images);
    project = await ProjectsRepository(ProjectsDao(db), clock).create(
      const ProjectInput(name: 'Inglés B2', color: 'blue', icon: 'globe'),
    );
    deck = await DecksRepository(
      DecksDao(db),
      clock,
    ).create(project.id, const DeckInput(name: 'Verbos irregulares'));
  });

  tearDown(() => db.close());

  Future<ImportResult> import(
    ImportSource source,
    ImportDestination destination,
  ) => repository
      .preview(source, destination, defaultDeckName: _imported)
      .then(repository.commit);

  Future<Flashcard> addSimple(String question, String answer) => cards.create(
    deck.id,
    CardInput(type: CardType.simple, question: question, answer: answer),
  );

  Future<List<CardRow>> cardsIn(String deckId) =>
      (db.select(db.cards)
            ..where((c) => c.deckId.equals(deckId))
            ..orderBy([(c) => OrderingTerm.asc(c.rowId)]))
          .get();

  Future<DeckDocument> exportedDeck() => ExchangeRepository(
    ExchangeDao(db),
    FakeClock(now),
    images,
  ).exportDeck(deck.id);

  group('as a new project or deck, every ID is new', () {
    test('a shared project imported twice gets new IDs each time', () async {
      await addSimple('to bring', 'traer');
      final file = (await exportedDeck()).deck;
      final shared = ExchangeProject(
        id: project.id,
        name: 'Inglés B2',
        color: 'blue',
        icon: 'globe',
        decks: [file],
      );

      final first = await import(
        ProjectFileSource(shared),
        const NewProjectDestination(name: 'Inglés B2 (copia)'),
      );
      final second = await import(
        ProjectFileSource(shared),
        const NewProjectDestination(name: 'Inglés B2 (otra)'),
      );

      final fileIds = {
        shared.id,
        file.id,
        for (final card in file.cards) card.id,
        for (final card in file.cards) ...card.options.map((o) => o.id),
      };
      for (final result in [first, second]) {
        expect(fileIds, isNot(contains(result.projectId)));
        final [deckId] = result.deckIds;
        expect(fileIds, isNot(contains(deckId)));
        final [card] = await cardsIn(deckId);
        expect(fileIds, isNot(contains(card.id)));
        expect(card.question, 'to bring');
      }
      expect(first.projectId, isNot(second.projectId));
      expect(await db.select(db.projects).get(), hasLength(3));
    });

    test('a deck imported as a new deck of its own project', () async {
      await cards.create(
        deck.id,
        const CardInput(
          type: CardType.test,
          question: '¿Irregular?',
          options: [
            CardOptionInput(text: 'go', isCorrect: true),
            CardOptionInput(text: 'walk'),
          ],
        ),
      );

      final result = await import(
        DeckFileSource((await exportedDeck()).deck),
        NewDeckDestination(projectId: project.id, name: 'Copia'),
      );

      final [copy] = await cardsIn(result.deckIds.single);
      final [original] = await cardsIn(deck.id);
      expect(copy.id, isNot(original.id));
      expect(copy.question, original.question);
      final options = await (db.select(
        db.cardOptions,
      )..where((o) => o.cardId.equals(copy.id))).get();
      expect(
        [for (final o in options) (o.optionText, o.isCorrect)],
        [('go', true), ('walk', false)],
      );
      expect(result.projectId, project.id);
    });
  });

  group('adding to a deck', () {
    test(
      'skips duplicates by ID or by normalised question and answer',
      () async {
        final bring = await addSimple('to bring', 'traer');
        await cards.create(
          deck.id,
          const CardInput(
            type: CardType.test,
            question: '¿Capital de Australia?',
            options: [
              CardOptionInput(text: 'Sídney'),
              CardOptionInput(text: 'Canberra', isCorrect: true),
            ],
          ),
        );
        final other = await DecksRepository(
          DecksDao(db),
          FakeClock(now),
        ).create(project.id, const DeckInput(name: 'Otra'));
        final elsewhere = await cards.create(
          other.id,
          const CardInput(type: CardType.simple, question: 'x', answer: 'y'),
        );
        const keptId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
        final file = ExchangeDeck(
          id: 'file-deck',
          name: 'Fichero',
          cards: [
            // The same ID as a card of the deck, even with other text.
            ExchangeCard(
              id: bring.id,
              type: CardType.simple,
              question: 'changed',
              answer: 'changed',
            ),
            // The same text, ignoring case and surrounding spaces.
            const ExchangeCard(
              id: 'c2',
              type: CardType.simple,
              question: '  TO BRING ',
              answer: 'Traer',
            ),
            const ExchangeCard(
              id: 'c3',
              type: CardType.test,
              question: '¿capital de australia?',
              options: [
                ExchangeOption(id: 'o1', text: 'sídney', isCorrect: false),
                ExchangeOption(id: 'o2', text: 'CANBERRA', isCorrect: true),
              ],
            ),
            // Same question, other answer: not a duplicate.
            const ExchangeCard(
              id: keptId,
              type: CardType.simple,
              question: 'to bring',
              answer: 'llevar',
            ),
            // Its ID is taken by a card of another deck: a new ID.
            ExchangeCard(
              id: elsewhere.id,
              type: CardType.simple,
              question: 'to seek',
              answer: 'buscar',
            ),
          ],
        );

        final plan = await repository.preview(
          DeckFileSource(file),
          ExistingDeckDestination(deck.id),
          defaultDeckName: _imported,
        );
        final result = await repository.commit(plan);

        expect(plan.duplicates.map((d) => d.question), [
          'changed',
          'TO BRING',
          '¿capital de australia?',
        ]);
        expect(result.added, 2);
        expect(result.duplicates, 3);
        final stored = await cardsIn(deck.id);
        expect(stored, hasLength(4));
        // The ID of the file is kept unless it already exists (rule 3).
        expect(stored[2].id, keptId);
        expect(stored[3].question, 'to seek');
        expect(stored[3].id, isNot(elsewhere.id));
      },
    );

    test("keeps the deck's type and still imports example and notes", () async {
      final file = (await exportedDeck()).deck;
      final languageFile = ExchangeDeck(
        id: file.id,
        name: 'Idioma',
        type: DeckType.language,
        sourceLang: 'en-GB',
        targetLang: 'es-ES',
        cards: const [
          ExchangeCard(
            id: 'c1',
            type: CardType.simple,
            question: 'to bring',
            answer: 'traer',
            example: 'Bring it.',
            notes: 'Irregular',
          ),
        ],
      );

      await import(
        DeckFileSource(languageFile),
        ExistingDeckDestination(deck.id),
      );

      final stored = await (db.select(
        db.decks,
      )..where((d) => d.id.equals(deck.id))).getSingle();
      expect(stored.type, 'general');
      expect(stored.sourceLang, isNull);
      final [card] = await cardsIn(deck.id);
      expect((card.example, card.notes), ('Bring it.', 'Irregular'));
    });

    test('marks the deck and its project as used', () async {
      await import(
        _csvFixture('excel_es.csv'),
        ExistingDeckDestination(deck.id),
      );

      final stored = await (db.select(
        db.projects,
      )..where((p) => p.id.equals(project.id))).getSingle();
      expect(stored.lastUsedAt, now);
    });
  });

  test('the summary counts added, duplicates and errors', () async {
    await addSimple('to bring', 'traer (brought, brought)');
    await addSimple('to seek', 'buscar (sought, sought)');
    await addSimple('to lend', 'prestar (lent, lent)');

    final plan = await repository.preview(
      _csvFixture('verbos_ia.csv'),
      ExistingDeckDestination(deck.id),
      defaultDeckName: _imported,
    );
    final result = await repository.commit(plan);

    expect(plan.newCards, 42);
    expect(plan.duplicates.map((d) => d.row), [3, 18, 31]);
    expect(plan.errors.map((e) => (e.row, e.problem)), [
      (7, ImportProblem.answerMissing),
    ]);
    expect((result.added, result.duplicates, result.errors), (42, 3, 1));
    expect(await cardsIn(deck.id), hasLength(45));
  });

  test('if it fails midway, nothing is imported', () async {
    // SQLite aborts the transaction when the second card is inserted, after
    // the project, the deck and the first card.
    await db.customStatement('''
      CREATE TRIGGER fail_midway BEFORE INSERT ON cards
      WHEN NEW.question = 'boom'
      BEGIN SELECT RAISE(ABORT, 'boom'); END
    ''');
    final file = ExchangeDeck(
      id: 'd',
      name: 'Con imagen',
      cards: [
        ExchangeCard(
          id: 'c1',
          type: CardType.simple,
          question: 'with image',
          answer: 'ok',
          questionImage: ExchangeImage(jpegBytes(20, 10)),
        ),
        const ExchangeCard(
          id: 'c2',
          type: CardType.simple,
          question: 'boom',
          answer: 'fails',
        ),
      ],
    );
    final plan = await repository.preview(
      DeckFileSource(file),
      const NewProjectDestination(name: 'Nuevo'),
      defaultDeckName: _imported,
    );

    await expectLater(repository.commit(plan), throwsA(isA<Exception>()));

    expect(await db.select(db.projects).get(), hasLength(1));
    expect(await db.select(db.decks).get(), hasLength(1));
    expect(await db.select(db.cards).get(), isEmpty);
    // The image stored before the transaction is deleted again.
    expect(
      folder.existsSync() ? folder.listSync() : <FileSystemEntity>[],
      isEmpty,
    );
  });

  group('a CSV as a new project', () {
    test(
      'gives every deck it creates the type and languages chosen once',
      () async {
        final result = await import(
          _csvFixture('google_sheets.csv'),
          const NewProjectDestination(
            name: 'Vocabulario',
            settings: DeckSettings(
              type: DeckType.language,
              sourceLang: 'en-GB',
              targetLang: 'es-ES',
            ),
          ),
        );

        final created = await (db.select(
          db.decks,
        )..where((d) => d.projectId.equals(result.projectId))).get();
        expect(
          {
            for (final d in created)
              d.name: (d.type, d.sourceLang, d.targetLang),
          },
          {
            'Verbos': ('language', 'en-GB', 'es-ES'),
            'Adjetivos': ('language', 'en-GB', 'es-ES'),
          },
        );
        final newProject = await (db.select(
          db.projects,
        )..where((p) => p.id.equals(result.projectId))).getSingle();
        expect(newProject.name, 'Vocabulario');
        expect((newProject.color, newProject.icon), ('orange', 'book'));
        expect(await cardsIn(result.deckIds.first), hasLength(2));
      },
    );

    test('rows without a "deck" column go to "Importadas"', () async {
      final result = await import(
        _csvFixture('excel_es.csv'),
        const NewProjectDestination(name: 'Excel'),
      );

      final [created] = await (db.select(
        db.decks,
      )..where((d) => d.projectId.equals(result.projectId))).get();
      expect(created.name, _imported);
      expect(created.type, 'general');
      expect(await cardsIn(created.id), hasLength(5));
    });
  });

  group('images', () {
    test('are stored as new files and linked to their card', () async {
      final jpeg = jpegBytes(30, 20);
      final file = ExchangeDeck(
        id: 'd',
        name: 'Imágenes',
        cards: [
          ExchangeCard(
            id: 'c',
            type: CardType.simple,
            question: 'q',
            answer: 'a',
            answerImage: ExchangeImage(jpeg),
          ),
        ],
      );

      final result = await import(
        DeckFileSource(file),
        ExistingDeckDestination(deck.id),
      );

      final [card] = await cardsIn(deck.id);
      expect(
        File('${folder.path}/${card.answerImage}').readAsBytesSync(),
        jpeg,
      );
      expect(result.imagesSkipped, 0);
    });

    test('a card whose image cannot be stored comes without it', () async {
      final file = ExchangeDeck(
        id: 'd',
        name: 'Imágenes',
        cards: [
          ExchangeCard(
            id: 'c',
            type: CardType.simple,
            question: 'q',
            answer: 'a',
            questionImage: ExchangeImage(
              Uint8List.fromList([0xFF, 0xD8, 0xFF, 0]),
            ),
          ),
        ],
      );

      final result = await import(
        DeckFileSource(file),
        ExistingDeckDestination(deck.id),
      );

      final [card] = await cardsIn(deck.id);
      expect(card.questionImage, isNull);
      expect(result.added, 1);
      expect(result.imagesSkipped, 1);
    });
  });
}
