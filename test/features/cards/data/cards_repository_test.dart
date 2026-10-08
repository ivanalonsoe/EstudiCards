import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:estudicards/core/clock.dart';
import 'package:estudicards/core/db/app_database.dart';
import 'package:estudicards/features/cards/data/cards_dao.dart';
import 'package:estudicards/features/cards/data/cards_repository.dart';
import 'package:estudicards/features/cards/domain/card_input.dart';
import 'package:estudicards/features/cards/domain/card_list.dart';
import 'package:estudicards/features/cards/domain/flashcard.dart';
import 'package:estudicards/features/decks/data/decks_dao.dart';
import 'package:estudicards/features/decks/data/decks_repository.dart';
import 'package:estudicards/features/decks/domain/deck.dart';
import 'package:estudicards/features/decks/domain/deck_input.dart';
import 'package:estudicards/features/projects/data/projects_dao.dart';
import 'package:estudicards/features/projects/data/projects_repository.dart';
import 'package:estudicards/features/projects/domain/project.dart';
import 'package:estudicards/features/projects/domain/project_input.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_image_files.dart';
import '../../../helpers/test_data.dart';

void main() {
  late AppDatabase db;
  late FakeClock clock;
  late FakeImageFiles images;
  late ProjectsRepository projects;
  late DecksRepository decks;
  late CardsRepository repository;
  late Project project;
  late Deck deck;
  final start = DateTime.utc(2026, 10, 6, 9);

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    clock = FakeClock(start);
    images = FakeImageFiles();
    projects = ProjectsRepository(ProjectsDao(db), clock);
    decks = DecksRepository(DecksDao(db), clock);
    repository = CardsRepository(CardsDao(db), clock, images);
    project = await projects.create(
      const ProjectInput(name: 'Biología', color: 'green', icon: 'flask'),
    );
    deck = await decks.create(project.id, const DeckInput(name: 'Célula'));
  });

  tearDown(() => db.close());

  const simple = CardInput(
    type: CardType.simple,
    question: 'to bring',
    answer: 'traer',
  );

  const atp = CardInput(
    type: CardType.test,
    question: '¿Qué orgánulo produce el ATP?',
    explanation: 'La mitocondria realiza la respiración celular.',
    options: [
      CardOptionInput(text: 'Ribosoma'),
      CardOptionInput(text: '  '),
      CardOptionInput(text: ' Mitocondria ', isCorrect: true),
      CardOptionInput(text: 'Aparato de Golgi'),
    ],
  );

  Matcher failsWith(CardInputError error) => throwsA(
    isA<InvalidCardException>().having((e) => e.errors, 'errors', [error]),
  );

  Future<List<CardOptionRow>> storedOptions(String cardId) =>
      (db.select(db.cardOptions)
            ..where((o) => o.cardId.equals(cardId))
            ..orderBy([(o) => OrderingTerm.asc(o.position)]))
          .get();

  Future<List<String>> listed({
    String query = '',
    CardSort sort = CardSort.newest,
  }) async => [
    for (final s
        in await repository.watchCards(deck.id, query: query, sort: sort).first)
      s.card.question,
  ];

  group('create', () {
    test('stores a simple card with a new ID and the clock time', () async {
      final card = await repository.create(
        deck.id,
        const CardInput(
          type: CardType.simple,
          question: ' to **bring** ',
          answer: ' traer ',
          questionImage: 'q.jpg',
          answerImage: 'a.jpg',
          example: ' Can you bring me some water? ',
          notes: '  ',
        ),
      );

      expect(card.id, hasLength(36));
      expect(card.deckId, deck.id);
      expect(card.type, CardType.simple);
      expect(card.question, 'to **bring**');
      expect(card.answer, 'traer');
      expect(card.questionImage, 'q.jpg');
      expect(card.answerImage, 'a.jpg');
      expect(card.example, 'Can you bring me some water?');
      expect(card.notes, isNull);
      expect(card.options, isEmpty);
      expect(card.createdAt, start);
      expect(card.updatedAt, start);
      expect((await repository.getById(card.id))!.answer, 'traer');
    });

    test('saving a test card saves its options with their position', () async {
      final card = await repository.create(deck.id, atp);

      final stored = await storedOptions(card.id);
      expect(stored.map((o) => o.optionText), [
        'Ribosoma',
        'Mitocondria',
        'Aparato de Golgi',
      ]);
      expect(stored.map((o) => o.position), [0, 1, 2]);
      expect(stored.map((o) => o.isCorrect), [false, true, false]);

      final read = (await repository.getById(card.id))!;
      expect(read.type, CardType.test);
      expect(
        read.explanation,
        'La mitocondria realiza la respiración celular.',
      );
      expect(read.options.map((o) => o.text), [
        'Ribosoma',
        'Mitocondria',
        'Aparato de Golgi',
      ]);
      expect(read.options.map((o) => o.position), [0, 1, 2]);
      expect(read.options.map((o) => o.id).toSet(), hasLength(3));
    });

    test('stores only the fields of its type', () async {
      final simpleCard = await repository.create(
        deck.id,
        const CardInput(
          type: CardType.simple,
          question: 'to bring',
          answer: 'traer',
          explanation: 'Not for simple cards',
          allowMultiple: true,
          options: [CardOptionInput(text: 'A', isCorrect: true)],
        ),
      );
      final testCard = await repository.create(
        deck.id,
        const CardInput(
          type: CardType.test,
          question: 'Q',
          answer: 'Not for test cards',
          options: [
            CardOptionInput(text: 'A', isCorrect: true),
            CardOptionInput(text: 'B'),
          ],
        ),
      );

      expect(simpleCard.explanation, isNull);
      expect(simpleCard.allowMultiple, isFalse);
      expect(await storedOptions(simpleCard.id), isEmpty);
      expect(testCard.answer, isNull);
    });

    test('fails with an invalid input and stores nothing', () async {
      expect(
        () => repository.create(
          deck.id,
          const CardInput(type: CardType.simple, question: 'to bring'),
        ),
        failsWith(.answerMissing),
      );
      expect(await listed(), isEmpty);
    });

    test('marks the deck and its project as used (R 7.7)', () async {
      clock.advance(const Duration(hours: 2));

      await repository.create(deck.id, simple);

      final later = start.add(const Duration(hours: 2));
      expect((await decks.getById(deck.id))!.lastUsedAt, later);
      expect((await projects.getById(project.id))!.lastUsedAt, later);
    });
  });

  group('update', () {
    test('changes the fields and the update time', () async {
      final card = await repository.create(deck.id, simple);
      clock.advance(const Duration(hours: 1));

      final updated = await repository.update(
        card.id,
        const CardInput(
          type: CardType.simple,
          question: 'to bring (irregular)',
          answer: 'traer',
          notes: 'brought · brought',
        ),
      );

      expect(updated.question, 'to bring (irregular)');
      expect(updated.notes, 'brought · brought');
      expect(updated.createdAt, start);
      expect(updated.updatedAt, start.add(const Duration(hours: 1)));
    });

    test('editing a card keeps its statistics', () async {
      final card = await repository.create(deck.id, simple);
      await addTestStats(db, card.id, correct: 3, wrong: 1);
      await addTestAttempt(db, projectId: project.id, cardId: card.id);

      await repository.update(
        card.id,
        const CardInput(
          type: CardType.simple,
          question: 'to bring',
          answer: 'traer, llevar',
        ),
      );

      final stats = await db.select(db.cardStats).getSingle();
      expect(stats.correctCount, 3);
      expect(stats.wrongCount, 1);
      expect(await db.select(db.attempts).get(), hasLength(1));
      final summary = (await repository.watchCards(deck.id).first).single;
      expect(summary.correctCount, 3);
      expect(summary.wrongCount, 1);
    });

    test('keeps the IDs of the options that stay, adds the new ones and '
        'removes the rest', () async {
      final card = await repository.create(deck.id, atp);
      final [ribosome, mitochondria, golgi] = card.options;

      final updated = await repository.update(
        card.id,
        CardInput(
          type: CardType.test,
          question: atp.question,
          options: [
            CardOptionInput(
              id: mitochondria.id,
              text: 'Mitocondria',
              isCorrect: true,
            ),
            const CardOptionInput(text: 'Lisosoma'),
            CardOptionInput(id: ribosome.id, text: 'Ribosomas'),
          ],
        ),
      );

      expect(updated.options.map((o) => o.text), [
        'Mitocondria',
        'Lisosoma',
        'Ribosomas',
      ]);
      expect(updated.options.map((o) => o.position), [0, 1, 2]);
      expect(updated.options[0].id, mitochondria.id);
      expect(updated.options[2].id, ribosome.id);
      expect(updated.options[1].id, isNot(anyOf(ribosome.id, golgi.id)));
      final storedIds = (await storedOptions(card.id)).map((o) => o.id);
      expect(storedIds, isNot(contains(golgi.id)));
      expect(storedIds, hasLength(3));
    });

    test('turning a test card into a simple one removes its options', () async {
      final card = await repository.create(deck.id, atp);

      final updated = await repository.update(card.id, simple);

      expect(updated.type, CardType.simple);
      expect(updated.options, isEmpty);
      expect(updated.explanation, isNull);
      expect(await storedOptions(card.id), isEmpty);
    });

    test('fails with an invalid input and keeps the stored card', () async {
      final card = await repository.create(deck.id, atp);

      expect(
        () => repository.update(
          card.id,
          const CardInput(
            type: CardType.test,
            question: 'Q',
            options: [CardOptionInput(text: 'A', isCorrect: true)],
          ),
        ),
        failsWith(.tooFewOptions),
      );
      final stored = (await repository.getById(card.id))!;
      expect(stored.question, atp.question);
      expect(stored.options, hasLength(3));
    });

    test('fails for an unknown ID', () async {
      expect(() => repository.update('missing', simple), throwsStateError);
    });
  });

  group('delete', () {
    test('deletes the card with its options, statistics and attempts, and '
        'then its images', () async {
      final card = await repository.create(
        deck.id,
        CardInput(
          type: CardType.test,
          question: atp.question,
          questionImage: 'question.jpg',
          answerImage: 'explanation.jpg',
          options: atp.options,
        ),
      );
      final kept = await repository.create(deck.id, simple);
      await addTestStats(db, card.id, wrong: 1);
      await addTestAttempt(db, projectId: project.id, cardId: card.id);

      await repository.delete(card.id);

      expect(await repository.getById(card.id), isNull);
      expect(await storedOptions(card.id), isEmpty);
      expect(await db.select(db.cardStats).get(), isEmpty);
      expect(await db.select(db.attempts).get(), isEmpty);
      expect(images.deleted, ['question.jpg', 'explanation.jpg']);
      expect(await repository.getById(kept.id), isNotNull);
    });
  });

  test('getById returns null for an unknown ID', () async {
    expect(await repository.getById('missing'), isNull);
  });

  group('watchCards', () {
    test("lists only the deck's cards, newest first by default", () async {
      final other = await decks.create(
        project.id,
        const DeckInput(name: 'Genética'),
      );
      await repository.create(deck.id, simple);
      clock.advance(const Duration(minutes: 1));
      await repository.create(deck.id, atp);
      await repository.create(
        other.id,
        const CardInput(type: CardType.simple, question: 'ADN', answer: 'DNA'),
      );

      expect(await listed(), [atp.question, 'to bring']);
    });

    test('search finds text in the question, answer and options', () async {
      await repository.create(deck.id, simple);
      await repository.create(deck.id, atp);
      await repository.create(
        deck.id,
        const CardInput(
          type: CardType.simple,
          question: 'to seek',
          answer: 'buscar',
        ),
      );

      expect(await listed(query: 'traer'), ['to bring']);
      expect(await listed(query: 'golgi'), [atp.question]);
      expect(await listed(query: 'ORGANULO'), [atp.question]);
      expect(await listed(query: 'busc'), ['to seek']);
      expect(await listed(query: 'nada'), isEmpty);
    });

    test('the three sort orders return the right order', () async {
      Future<String> addCard(String question) async {
        clock.advance(const Duration(minutes: 1));
        final card = await repository.create(
          deck.id,
          CardInput(type: CardType.simple, question: question, answer: 'x'),
        );
        return card.id;
      }

      final bear = await addCard('to bear');
      final forbid = await addCard('to forbid');
      await addCard('¿Qué verbos son irregulares?');
      final arise = await addCard('to arise');
      await addTestStats(db, bear, correct: 5, wrong: 6);
      await addTestStats(db, forbid, correct: 3, wrong: 4);
      await addTestStats(db, forbid, direction: 'reverse', wrong: 3);
      await addTestStats(db, arise, correct: 6);

      expect(await listed(), [
        'to arise',
        '¿Qué verbos son irregulares?',
        'to forbid',
        'to bear',
      ]);
      expect(await listed(sort: CardSort.alphabetical), [
        '¿Qué verbos son irregulares?',
        'to arise',
        'to bear',
        'to forbid',
      ]);
      // to forbid: 7 misses in both directions; to bear: 6.
      expect(await listed(sort: CardSort.mostMissed), [
        'to forbid',
        'to bear',
        'to arise',
        '¿Qué verbos son irregulares?',
      ]);
    });

    test('returns each card with its results in both directions', () async {
      final card = await repository.create(deck.id, simple);
      await addTestStats(db, card.id, correct: 3, wrong: 1);
      await addTestStats(db, card.id, direction: 'reverse', correct: 1);

      final summary = (await repository.watchCards(deck.id).first).single;

      expect(summary.correctCount, 4);
      expect(summary.wrongCount, 1);
      expect(summary.correctRate, 0.8);
    });

    test('emits again when the cards change', () async {
      final stream = repository.watchCards(deck.id);
      final names = stream.map(
        (cards) => [for (final s in cards) s.card.question],
      );

      final expectation = expectLater(
        names,
        emitsInOrder([
          isEmpty,
          ['to bring'],
          ['to bring (irregular)'],
          isEmpty,
        ]),
      );
      await pumpEventQueue();
      final card = await repository.create(deck.id, simple);
      await pumpEventQueue();
      await repository.update(
        card.id,
        const CardInput(
          type: CardType.simple,
          question: 'to bring (irregular)',
          answer: 'traer',
        ),
      );
      await pumpEventQueue();
      await repository.delete(card.id);

      await expectation;
    });
  });
}
