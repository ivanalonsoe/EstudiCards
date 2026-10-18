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
import 'package:estudicards/features/import_export/data/auto_backup_files.dart';
import 'package:estudicards/features/import_export/data/backup_dao.dart';
import 'package:estudicards/features/import_export/data/backup_repository.dart';
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

final _now = DateTime.utc(2026, 10, 18, 9);

/// One database with its own images folder and the repositories on it.
class _Device {
  new(this.clock)
    : db = AppDatabase(NativeDatabase.memory()),
      images = createTempFolder(),
      backups = createTempFolder();

  final FakeClock clock;
  final AppDatabase db;
  final Directory images;
  final Directory backups;

  late final imageFiles = DiskImageFiles(
    () async => images,
    prepare: (bytes) async => prepareCardImage(bytes),
  );
  late final exchange = ExchangeRepository(ExchangeDao(db), clock, imageFiles);
  late final autoBackups = AutoBackupFiles(() async => backups);
  late final repository = BackupRepository(
    BackupDao(db),
    clock,
    imageFiles,
    exchange,
    autoBackups,
    encode: (backup) async => encodeExchange(backup),
  );
  late final projects = ProjectsRepository(ProjectsDao(db), clock);
  late final decks = DecksRepository(DecksDao(db), clock);
  late final cards = CardsRepository(CardsDao(db), clock, imageFiles);

  /// The backup of this device as a file, to compare two devices.
  Future<String> backupText() async =>
      String.fromCharCodes(encodeExchange(await exchange.exportBackup()));

  List<FileSystemEntity> imageFilesOnDisk() =>
      images.existsSync() ? images.listSync() : [];
}

/// Fills [device] with a bit of everything a backup carries.
Future<void> _seed(_Device device, {String name = 'Inglés B2'}) async {
  final db = device.db;
  final project = await device.projects.create(
    ProjectInput(name: name, color: 'blue', icon: 'globe'),
  );
  final archived = await device.projects.create(
    const ProjectInput(name: 'Archivado', color: 'green', icon: 'book'),
  );
  await device.projects.setArchived(archived.id, isArchived: true);
  final deck = await device.decks.create(
    project.id,
    const DeckInput(
      name: 'Verbos',
      type: DeckType.language,
      sourceLang: 'en-GB',
      targetLang: 'es-ES',
    ),
  );
  final trashed = await device.decks.create(
    project.id,
    const DeckInput(name: 'Borrada'),
  );
  await (db.update(db.decks)..where((d) => d.id.equals(trashed.id))).write(
    DecksCompanion(deletedAt: Value(_now)),
  );
  final image = await device.imageFiles.saveImported(jpegBytes(40, 30));
  final card = await device.cards.create(
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
    projectId: project.id,
    cardId: card.id,
    results: ['wrong', 'correct', 'correct'],
  );
  await db
      .into(db.settings)
      .insert(
        SettingsCompanion.insert(key: 'theme_mode', value: const Value('dark')),
      );
}

void main() {
  late _Device phone;
  late _Device laptop;

  setUp(() {
    phone = _Device(FakeClock(_now));
    laptop = _Device(FakeClock(_now));
  });

  tearDown(() async {
    await phone.db.close();
    await laptop.db.close();
  });

  test('with an empty database, restoring leaves the data identical to the '
      'export', () async {
    await _seed(phone);
    final backup = await phone.exchange.exportBackup();

    expect(await laptop.repository.isEmpty(), isTrue);
    final result = await laptop.repository.restore(
      backup,
      RestoreMode.replaceAll,
    );

    expect(await laptop.backupText(), await phone.backupText());
    expect(await laptop.repository.isEmpty(), isFalse);
    // Nothing to lose, so no automatic backup.
    expect(result.autoBackup, isNull);
    // The image is a new file in this device's folder.
    expect(laptop.imageFilesOnDisk(), hasLength(1));
  });

  test('"replace all" deletes the current data', () async {
    await _seed(phone, name: 'Del móvil');
    await _seed(laptop, name: 'Del portátil');
    final oldImages = [for (final f in laptop.imageFilesOnDisk()) f.path];
    final backup = await phone.exchange.exportBackup();

    await laptop.repository.restore(backup, RestoreMode.replaceAll);

    final names = [
      for (final p in await laptop.db.select(laptop.db.projects).get()) p.name,
    ];
    expect(names, unorderedEquals(['Del móvil', 'Archivado']));
    expect(await laptop.backupText(), await phone.backupText());
    // The images of the deleted cards are gone.
    for (final path in oldImages) {
      expect(File(path).existsSync(), isFalse);
    }
    expect(laptop.imageFilesOnDisk(), hasLength(1));
  });

  test('"replace all" first saves an automatic backup of the current '
      'data', () async {
    await _seed(laptop, name: 'Del portátil');
    final before = await laptop.backupText();

    final result = await laptop.repository.restore(
      BackupDocument(exportedAt: _now, appVersion: '1.0.0'),
      RestoreMode.replaceAll,
    );

    final autoBackup = result.autoBackup!;
    expect(autoBackup.time, _now);
    expect(autoBackup.path, startsWith(laptop.backups.path));
    final saved = decodeExchange(
      File(autoBackup.path).readAsBytesSync(),
    ) as BackupDocument;
    expect(saved.projects.map((p) => p.name), contains('Del portátil'));
    expect(String.fromCharCodes(encodeExchange(saved)), before);
    expect(await laptop.repository.isEmpty(), isTrue);
    expect(await laptop.autoBackups.list(), hasLength(1));
  });

  test('"merge" keeps the item with the most recent updated_at and '
      'recalculates card_stats', () async {
    // The phone and the laptop share a project and a card.
    await _seed(phone);
    await laptop.repository.restore(
      await phone.exchange.exportBackup(),
      RestoreMode.replaceAll,
    );
    final project = (await phone.db.select(phone.db.projects).get()).first;
    final card = (await phone.db.select(phone.db.cards).get()).single;

    // Later, the laptop renames the project; the phone edits the card and
    // answers it once more, and adds a card.
    laptop.clock.set(_now.add(const Duration(hours: 1)));
    await laptop.projects.update(
      project.id,
      const ProjectInput(name: 'Renombrado', color: 'blue', icon: 'globe'),
    );
    phone.clock.set(_now.add(const Duration(hours: 2)));
    await phone.cards.update(
      card.id,
      const CardInput(
        type: CardType.test,
        question: '¿Es irregular?',
        options: [
          CardOptionInput(text: 'go', isCorrect: true),
          CardOptionInput(text: 'play'),
        ],
      ),
    );
    final deck = (await phone.db.select(phone.db.decks).get()).first;
    final added = await phone.cards.create(
      deck.id,
      const CardInput(type: CardType.simple, question: 'new', answer: 'a'),
    );
    await addTestAnswers(
      phone.db,
      projectId: project.id,
      cardId: card.id,
      results: ['wrong'],
      at: _now.add(const Duration(hours: 3)),
    );

    final result = await laptop.repository.restore(
      await phone.exchange.exportBackup(),
      RestoreMode.merge,
    );

    expect(result.autoBackup, isNull);
    final db = laptop.db;
    final storedProject = await (db.select(
      db.projects,
    )..where((p) => p.id.equals(project.id))).getSingle();
    // The laptop's rename is newer than the phone's project.
    expect(storedProject.name, 'Renombrado');
    final storedCard = await (db.select(
      db.cards,
    )..where((c) => c.id.equals(card.id))).getSingle();
    // The phone's edit is newer than the laptop's card.
    expect(storedCard.question, '¿Es irregular?');
    final options = await (db.select(
      db.cardOptions,
    )..where((o) => o.cardId.equals(card.id))).get();
    expect([for (final o in options) o.optionText], ['go', 'play']);
    expect(
      await (db.select(db.cards)..where((c) => c.id.equals(added.id))).get(),
      hasLength(1),
    );
    // Attempts are merged by ID: the three shared ones and the new one.
    expect(await db.select(db.attempts).get(), hasLength(4));
    final stats = await (db.select(
      db.cardStats,
    )..where((s) => s.cardId.equals(card.id))).getSingle();
    expect((stats.correctCount, stats.wrongCount), (2, 2));
    expect(stats.inErrorList, isTrue);
    expect(stats.consecutiveCorrect, 0);
  });

  test('"merge" keeps the local settings and adds the missing ones', () async {
    await laptop.db
        .into(laptop.db.settings)
        .insert(
          SettingsCompanion.insert(
            key: 'theme_mode',
            value: const Value('light'),
          ),
        );

    await laptop.repository.restore(
      BackupDocument(
        exportedAt: _now,
        appVersion: '1.0.0',
        settings: const {'theme_mode': 'dark', 'daily_goal': '20'},
      ),
      RestoreMode.merge,
    );

    final settings = {
      for (final s in await laptop.db.select(laptop.db.settings).get())
        s.key: s.value,
    };
    expect(settings, {'theme_mode': 'light', 'daily_goal': '20'});
  });

  test('if it fails midway, nothing is restored', () async {
    await _seed(phone);
    await _seed(laptop, name: 'Del portátil');
    final before = await laptop.backupText();
    final imagesBefore = laptop.imageFilesOnDisk().length;
    await laptop.db.customStatement('''
      CREATE TRIGGER fail_midway BEFORE INSERT ON attempts
      BEGIN SELECT RAISE(ABORT, 'boom'); END
    ''');

    await expectLater(
      laptop.repository.restore(
        await phone.exchange.exportBackup(),
        RestoreMode.replaceAll,
      ),
      throwsA(isA<Exception>()),
    );

    expect(await laptop.backupText(), before);
    expect(laptop.imageFilesOnDisk(), hasLength(imagesBefore));
  });

  test('an attempt without its local day gets it from the clock', () async {
    await _seed(phone);
    final backup = await phone.exchange.exportBackup();
    final withoutDays = BackupDocument(
      exportedAt: backup.exportedAt,
      appVersion: backup.appVersion,
      projects: backup.projects,
      sessions: backup.sessions,
      sessionDecks: backup.sessionDecks,
      cardStats: backup.cardStats,
      attempts: [
        for (final a in backup.attempts)
          ExchangeAttempt(
            id: a.id,
            sessionId: a.sessionId,
            cardId: a.cardId,
            direction: a.direction,
            result: a.result,
            source: a.source,
            isFirstAttempt: a.isFirstAttempt,
            answeredAt: a.answeredAt,
          ),
      ],
    );
    final madrid = _Device(
      FakeClock(_now, utcOffset: (_) => const Duration(hours: 2)),
    );
    addTearDown(madrid.db.close);

    await madrid.repository.restore(withoutDays, RestoreMode.replaceAll);

    final days = {
      for (final a in await madrid.db.select(madrid.db.attempts).get())
        a.localDay,
    };
    expect(days, {'2026-10-06'});
  });

  group('automatic backups', () {
    test('only the newest five are kept, newest first', () async {
      for (var i = 0; i < 7; i++) {
        await laptop.autoBackups.save(
          encodeExchange(BackupDocument(exportedAt: _now, appVersion: '1')),
          _now.add(Duration(minutes: i)),
        );
      }

      final list = await laptop.autoBackups.list();

      expect(list, hasLength(5));
      expect(list.first.time, _now.add(const Duration(minutes: 6)));
      expect(list.last.time, _now.add(const Duration(minutes: 2)));
    });

    test('can be read and deleted', () async {
      final bytes = encodeExchange(
        BackupDocument(exportedAt: _now, appVersion: '1'),
      );
      final saved = await laptop.autoBackups.save(bytes, _now);

      expect(await laptop.autoBackups.read(saved), bytes);
      await laptop.autoBackups.delete(saved);
      expect(await laptop.autoBackups.list(), isEmpty);
    });

    test('files that are not automatic backups are ignored', () async {
      File('${laptop.backups.path}/notes.txt').writeAsStringSync('hi');

      expect(await laptop.autoBackups.list(), isEmpty);
    });
  });
}
