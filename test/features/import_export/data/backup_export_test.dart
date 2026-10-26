import 'dart:convert';
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
import 'package:estudicards/features/import_export/domain/exchange_document.dart';
import 'package:estudicards/features/import_export/domain/exchange_json.dart';
import 'package:estudicards/features/projects/data/projects_dao.dart';
import 'package:estudicards/features/projects/data/projects_repository.dart';
import 'package:estudicards/features/projects/domain/project_input.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/test_data.dart';
import '../../../helpers/test_images.dart';

void main() {
  late AppDatabase db;
  late Directory folder;
  late DiskImageFiles images;
  late ExchangeRepository repository;
  final now = DateTime.utc(2026, 10, 18, 9);

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    folder = createTempFolder();
    images = DiskImageFiles(
      () async => folder,
      prepare: (bytes) async => prepareCardImage(bytes),
    );
    repository = ExchangeRepository(ExchangeDao(db), FakeClock(now), images);
  });

  tearDown(() => db.close());

  test('the backup includes archived projects and projects in the trash, '
      'sessions, attempts and settings', () async {
    final clock = FakeClock(now);
    final projects = ProjectsRepository(ProjectsDao(db), clock);
    final decks = DecksRepository(DecksDao(db), clock);
    final cards = CardsRepository(CardsDao(db), clock, images);
    final active = await projects.create(
      const ProjectInput(name: 'Inglés B2', color: 'blue', icon: 'globe'),
    );
    final archived = await projects.create(
      const ProjectInput(name: 'Archivado', color: 'green', icon: 'book'),
    );
    await projects.setArchived(archived.id, isArchived: true);
    final trashed = await projects.create(
      const ProjectInput(name: 'En la papelera', color: 'red', icon: 'book'),
    );
    await (db.update(db.projects)..where((p) => p.id.equals(trashed.id))).write(
      ProjectsCompanion(deletedAt: Value(now)),
    );
    final deck = await decks.create(
      active.id,
      const DeckInput(
        name: 'Verbos',
        type: DeckType.language,
        sourceLang: 'en-GB',
        targetLang: 'es-ES',
      ),
    );
    final trashedDeck = await decks.create(
      active.id,
      const DeckInput(name: 'Borrada'),
    );
    await (db.update(db.decks)..where((d) => d.id.equals(trashedDeck.id)))
        .write(DecksCompanion(deletedAt: Value(now)));
    final image = await images.save(pngBytes(20, 10));
    final test = await cards.create(
      deck.id,
      CardInput(
        type: CardType.test,
        question: '¿Irregular?',
        questionImage: image,
        options: const [
          CardOptionInput(text: 'go', isCorrect: true),
          CardOptionInput(text: 'walk'),
        ],
      ),
    );
    await addTestAnswers(
      db,
      projectId: active.id,
      cardId: test.id,
      results: ['wrong', 'correct'],
    );
    final sessionId = await addTestSession(
      db,
      projectId: active.id,
      deckIds: [deck.id],
      startedAt: now,
      correct: 1,
    );
    await db
        .into(db.settings)
        .insert(
          SettingsCompanion.insert(
            key: 'theme_mode',
            value: const Value('dark'),
          ),
        );

    final document = await repository.exportBackup();
    final back = decodeExchange(encodeExchange(document)) as BackupDocument;

    expect(document.exportedAt, now);
    expect(
      {for (final p in back.projects) p.name: (p.isArchived, p.deletedAt)},
      {
        'Inglés B2': (false, null),
        'Archivado': (true, null),
        'En la papelera': (false, now),
      },
    );
    final english = back.projects.firstWhere((p) => p.id == active.id);
    expect(
      [for (final d in english.decks) (d.name, d.deletedAt)],
      [('Verbos', null), ('Borrada', now)],
    );
    final card = english.decks.first.cards.single;
    expect(card.id, test.id);
    expect(card.createdAt, now);
    expect(
      card.questionImage!.bytes,
      File('${folder.path}/$image').readAsBytesSync(),
    );
    // Options keep their IDs: attempts point at them.
    expect(
      [for (final o in card.options) o.id],
      [for (final o in test.options) o.id],
    );
    expect(back.sessions.map((s) => s.id), contains(sessionId));
    expect(back.sessionDecks.map((s) => s.sessionId), contains(sessionId));
    expect(back.attempts, hasLength(2));
    expect(back.attempts.first.localDay, '2026-10-06');
    expect(back.attempts.first.result, 'wrong');
    expect(back.cardStats.single.cardId, test.id);
    expect(back.cardStats.single.correctCount, 1);
    expect(back.settings, {'theme_mode': 'dark'});
  });

  test('the ticked options of an attempt travel as a list', () async {
    final clock = FakeClock(now);
    final project = await ProjectsRepository(
      ProjectsDao(db),
      clock,
    ).create(const ProjectInput(name: 'P', color: 'blue', icon: 'book'));
    final deck = await DecksRepository(
      DecksDao(db),
      clock,
    ).create(project.id, const DeckInput(name: 'D'));
    final cardId = await addTestCard(db, deck.id);
    final sessionId = await addTestSession(
      db,
      projectId: project.id,
      deckIds: [deck.id],
      startedAt: now,
    );
    await db
        .into(db.attempts)
        .insert(
          AttemptsCompanion.insert(
            id: 'a1',
            sessionId: sessionId,
            cardId: cardId,
            direction: 'normal',
            result: 'wrong',
            source: 'test_check',
            isFirstAttempt: true,
            answeredAt: now,
            selectedOptionIds: Value(jsonEncode(['o1', 'o2'])),
          ),
        );

    final attempt = (await repository.exportBackup()).attempts.single;

    expect(attempt.selectedOptionIds, ['o1', 'o2']);
    expect(attempt.localDay, isNull);
  });

  group('the size of a backup (T5.10)', () {
    Future<String> cardWithImage() async {
      final clock = FakeClock(now);
      final project = await ProjectsRepository(
        ProjectsDao(db),
        clock,
      ).create(const ProjectInput(name: 'P', color: 'blue', icon: 'book'));
      final deck = await DecksRepository(
        DecksDao(db),
        clock,
      ).create(project.id, const DeckInput(name: 'D'));
      final image = await images.saveImported(jpegBytes(40, 30));
      await CardsRepository(CardsDao(db), clock, images).create(
        deck.id,
        CardInput(
          type: CardType.simple,
          question: 'q',
          answer: 'a',
          questionImage: image,
          answerImage: image,
        ),
      );
      return image!;
    }

    test('a backup can leave the images out', () async {
      await cardWithImage();

      final backup = await repository.exportBackup(withImages: false);

      final card = backup.projects.single.decks.single.cards.single;
      expect(card.questionImage, isNull);
      expect(card.answerImage, isNull);
    });

    test('lists the size of every image a backup would carry', () async {
      final image = await cardWithImage();
      final size = File('${folder.path}/$image').lengthSync();

      // The same file twice: once as the question, once as the answer.
      expect(await repository.backupImageSizes(), [size, size]);
    });
  });

  test(
    'a card whose image file is missing is backed up without that image',
    () async {
      // As after Android restores its copy of the app, which leaves the
      // images out: the card still names a file that is not in the folder.
      final clock = FakeClock(now);
      final project = await ProjectsRepository(
        ProjectsDao(db),
        clock,
      ).create(const ProjectInput(name: 'P', color: 'blue', icon: 'book'));
      final deck = await DecksRepository(
        DecksDao(db),
        clock,
      ).create(project.id, const DeckInput(name: 'D'));
      final kept = await images.saveImported(jpegBytes(40, 30));
      await CardsRepository(CardsDao(db), clock, images).create(
        deck.id,
        CardInput(
          type: CardType.simple,
          question: 'q',
          answer: 'a',
          questionImage: 'lost.jpg',
          answerImage: kept,
        ),
      );

      final sizes = await repository.backupImageSizes();
      final document = await repository.exportBackup();
      final back = decodeExchange(encodeExchange(document)) as BackupDocument;

      expect(sizes, [File('${folder.path}/$kept').lengthSync()]);
      final card = back.projects.single.decks.single.cards.single;
      expect(card.question, 'q');
      expect(card.questionImage, isNull);
      expect(
        card.answerImage!.bytes,
        File('${folder.path}/$kept').readAsBytesSync(),
      );
    },
  );

  test('an empty database gives an empty backup', () async {
    final backup = await repository.exportBackup();

    expect(backup.projects, isEmpty);
    expect(backup.attempts, isEmpty);
    expect(backup.settings, isEmpty);
  });
}
