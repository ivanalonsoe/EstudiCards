import 'dart:convert';
import 'dart:io';

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
import 'package:estudicards/features/import_export/domain/exchange_document.dart';
import 'package:estudicards/features/import_export/domain/exchange_json.dart';
import 'package:estudicards/features/projects/data/projects_dao.dart';
import 'package:estudicards/features/projects/data/projects_repository.dart';
import 'package:estudicards/features/projects/domain/project_input.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/test_images.dart';

void main() {
  late AppDatabase db;
  late Directory folder;
  late DiskImageFiles images;
  late CardsRepository cards;
  late ExchangeRepository repository;
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
    repository = ExchangeRepository(ExchangeDao(db), clock, images);
    final project = await ProjectsRepository(ProjectsDao(db), clock).create(
      const ProjectInput(name: 'Inglés B2', color: 'orange', icon: 'globe'),
    );
    deck = await DecksRepository(DecksDao(db), clock).create(
      project.id,
      const DeckInput(
        name: 'Verbos irregulares',
        description: 'Los más comunes',
        type: DeckType.language,
        sourceLang: 'en-GB',
        targetLang: 'es-ES',
      ),
    );
  });

  tearDown(() => db.close());

  File stored(String relativePath) => File('${folder.path}/$relativePath');

  /// The deck after a trip through a file.
  Future<ExchangeDeck> exportAndRead() async {
    final document = await repository.exportDeck(deck.id);
    return (decodeExchange(encodeExchange(document)) as DeckDocument).deck;
  }

  test(
    'exporting a deck and reading the file gives the same content',
    () async {
      final simple = await cards.create(
        deck.id,
        const CardInput(
          type: CardType.simple,
          question: 'to **bring**',
          answer: 'traer',
          example: 'Can you bring me some water?',
          notes: 'Irregular',
        ),
      );
      final test = await cards.create(
        deck.id,
        const CardInput(
          type: CardType.test,
          question: '¿Qué verbos son irregulares?',
          explanation: '*Walk* es regular.',
          allowMultiple: true,
          options: [
            CardOptionInput(text: 'go', isCorrect: true),
            CardOptionInput(text: 'walk'),
            CardOptionInput(text: 'eat', isCorrect: true),
          ],
        ),
      );

      final document = await repository.exportDeck(deck.id);
      final back = await exportAndRead();

      expect(document.exportedAt, now);
      expect(back.id, deck.id);
      expect(back.name, 'Verbos irregulares');
      expect(back.description, 'Los más comunes');
      // The deck has no colour of its own: it keeps inheriting.
      expect(back.color, isNull);
      expect(back.type, DeckType.language);
      expect(back.sourceLang, 'en-GB');
      expect(back.targetLang, 'es-ES');
      expect([for (final card in back.cards) card.id], [simple.id, test.id]);
      final [backSimple, backTest] = back.cards;
      expect(backSimple.question, 'to **bring**');
      expect(backSimple.answer, 'traer');
      expect(backSimple.example, 'Can you bring me some water?');
      expect(backSimple.notes, 'Irregular');
      expect(backTest.type, CardType.test);
      expect(backTest.explanation, '*Walk* es regular.');
      expect(backTest.allowMultiple, isTrue);
      expect(
        [for (final o in backTest.options) (o.id, o.text, o.isCorrect)],
        [for (final o in test.options) (o.id, o.text, o.isCorrect)],
      );
      // A shared deck carries no dates (SPEC §8.2).
      expect(backSimple.createdAt, isNull);
    },
  );

  test('a general deck keeps the languages it had', () async {
    final general = await DecksRepository(DecksDao(db), FakeClock(now)).update(
      deck.id,
      const DeckInput(
        name: 'Verbos irregulares',
        sourceLang: 'en-GB',
        targetLang: 'es-ES',
      ),
    );

    final back = await exportAndRead();

    expect(general.type, DeckType.general);
    expect(back.type, DeckType.general);
    expect((back.sourceLang, back.targetLang), ('en-GB', 'es-ES'));
  });

  test('images travel as base64 and are restored as new files', () async {
    final questionImage = await images.save(pngBytes(40, 30));
    final answerImage = await images.save(pngBytes(30, 40));
    await cards.create(
      deck.id,
      CardInput(
        type: CardType.simple,
        question: 'to bring',
        answer: 'traer',
        questionImage: questionImage,
        answerImage: answerImage,
      ),
    );

    final json = utf8.decode(
      encodeExchange(await repository.exportDeck(deck.id)),
    );
    final card = (await exportAndRead()).cards.single;

    // The file has the image itself, never its path on this device.
    expect(json, isNot(contains(questionImage)));
    expect(
      json,
      contains(base64Encode(stored(questionImage!).readAsBytesSync())),
    );
    final restored = await images.saveImported(card.questionImage!.bytes);
    expect(restored, isNot(questionImage));
    expect(restored, matches(RegExp(r'^[0-9a-f-]{36}\.jpg$')));
    expect(
      stored(restored!).readAsBytesSync(),
      stored(questionImage).readAsBytesSync(),
    );
    expect(card.answerImage!.bytes, stored(answerImage!).readAsBytesSync());
  });

  test(
    'an image file missing from the folder is exported as no image',
    () async {
      await cards.create(
        deck.id,
        const CardInput(
          type: CardType.simple,
          question: 'to bring',
          answer: 'traer',
          questionImage: 'lost.jpg',
        ),
      );

      final card = (await exportAndRead()).cards.single;

      expect(card.questionImage, isNull);
    },
  );

  test('exporting a deck that does not exist fails', () {
    expect(repository.exportDeck('missing'), throwsStateError);
  });
}
