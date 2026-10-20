import 'dart:io';
import 'dart:typed_data';

import 'package:estudicards/app/router.dart';
import 'package:estudicards/core/clock.dart';
import 'package:estudicards/core/db/app_database.dart';
import 'package:estudicards/core/files/document_picker.dart';
import 'package:estudicards/features/cards/domain/flashcard.dart';
import 'package:estudicards/features/import_export/data/auto_backup_files.dart';
import 'package:estudicards/features/import_export/domain/exchange_document.dart';
import 'package:estudicards/features/import_export/domain/exchange_json.dart';
import 'package:estudicards/features/projects/data/projects_dao.dart';
import 'package:estudicards/features/projects/data/projects_repository.dart';
import 'package:estudicards/features/projects/domain/project_input.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_document_picker.dart';
import '../../../helpers/test_app.dart';
import '../../../helpers/test_images.dart';
import '../../cards/presentation/card_editor_finders.dart';

final _then = DateTime.utc(2026, 9, 30, 10);

Finder _key(String key) => find.byKey(Key(key));

/// A backup from another device with one project, one deck and one card.
Uint8List _backupFile({String name = 'Del móvil'}) => encodeExchange(
  BackupDocument(
    exportedAt: _then,
    appVersion: '1.0.0',
    projects: [
      ExchangeProject(
        id: 'p-phone',
        name: name,
        color: 'green',
        icon: 'book',
        createdAt: _then,
        updatedAt: _then,
        decks: [
          ExchangeDeck(
            id: 'd-phone',
            name: 'Verbos',
            createdAt: _then,
            updatedAt: _then,
            cards: [
              ExchangeCard(
                id: 'c-phone',
                type: CardType.simple,
                question: 'to bring',
                answer: 'traer',
                createdAt: _then,
                updatedAt: _then,
              ),
            ],
          ),
        ],
      ),
    ],
  ),
);

void main() {
  late AppDatabase db;
  late Directory backups;

  setUp(() {
    db = createTestDatabase();
    backups = createTempFolder();
  });

  Future<void> addLocalProject() =>
      ProjectsRepository(ProjectsDao(db), FakeClock(_then)).create(
        const ProjectInput(name: 'Del portátil', color: 'blue', icon: 'globe'),
      );

  Future<List<String>> projectNames() async => [
    for (final p in await db.select(db.projects).get()) p.name,
  ];

  /// Opens Settings and scrolls down to "Datos", below the other sections.
  Future<void> openSettings(WidgetTester tester, {PickedDocument? file}) async {
    await pumpTestApp(
      tester,
      size: mobile,
      db: db,
      location: AppRoutes.settings,
      documentPicker: FakeDocumentPicker(file),
      backupsFolder: backups,
    );
    await tester.drag(find.byType(ListView), const Offset(0, -2000));
    await tester.pumpAndSettle();
  }

  Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
    await tapVisible(tester, finder);
    await tester.pumpAndSettle();
  }

  testWidgets('with no data, the backup is restored without asking', (
    tester,
  ) async {
    await openSettings(
      tester,
      file: pickedBytes('estudicards-backup-2026-09-30.json', _backupFile()),
    );

    await tapAndSettle(tester, _key('settings.restore'));

    expect(_key('restoreDialog'), findsNothing);
    expect(await projectNames(), ['Del móvil']);
    expect(find.text('Copia restaurada.'), findsOneWidget);
  });

  testWidgets('with data it asks, and "Fusionar" keeps both', (tester) async {
    await addLocalProject();
    await openSettings(
      tester,
      file: pickedBytes('estudicards-backup-2026-09-30.json', _backupFile()),
    );

    await tapAndSettle(tester, _key('settings.restore'));

    expect(find.text('Ya tienes datos aquí'), findsOneWidget);
    expect(
      find.text(
        '¿Qué hacemos con la copia «estudicards-backup-2026-09-30.json»?',
      ),
      findsOneWidget,
    );
    expect(find.text('Añade lo nuevo y conserva lo más reciente'), findsOne);
    expect(find.text('Borra lo actual y deja solo la copia'), findsOne);
    await tapAndSettle(tester, _key('restoreDialog.continue'));

    expect(
      await projectNames(),
      unorderedEquals(['Del portátil', 'Del móvil']),
    );
    expect(find.text('Copia restaurada.'), findsOneWidget);
    // Synchronous: asynchronous file calls never finish in widget tests.
    expect(backups.listSync(), isEmpty);
  });

  testWidgets(
    '"Reemplazar todo" asks again, saves an automatic backup and lists it',
    (tester) async {
      await addLocalProject();
      await openSettings(
        tester,
        file: pickedBytes('copia.json', _backupFile()),
      );

      await tapAndSettle(tester, _key('settings.restore'));
      await tapAndSettle(tester, _key('restoreDialog.replace'));
      await tapAndSettle(tester, _key('restoreDialog.continue'));
      expect(find.text('¿Reemplazar todos tus datos?'), findsOneWidget);
      await tapAndSettle(tester, _key('confirmDialog.confirm'));

      expect(await projectNames(), ['Del móvil']);
      expect(
        find.text(
          'Copia restaurada. Tus datos anteriores están en «Copias '
          'automáticas».',
        ),
        findsOneWidget,
      );
      final [saved] = await AutoBackupFiles(() async => backups).list();
      expect(_key('autoBackup.${saved.name}'), findsOneWidget);
      final previous =
          decodeExchange(File(saved.path).readAsBytesSync()) as BackupDocument;
      expect(previous.projects.single.name, 'Del portátil');
    },
  );

  testWidgets('"Cancelar" leaves everything as it was', (tester) async {
    await addLocalProject();
    await openSettings(tester, file: pickedBytes('copia.json', _backupFile()));

    await tapAndSettle(tester, _key('settings.restore'));
    await tapAndSettle(tester, _key('restoreDialog.cancel'));

    expect(await projectNames(), ['Del portátil']);
  });

  testWidgets('a file that is not a backup says so', (tester) async {
    final deck = encodeExchange(
      DeckDocument(
        exportedAt: _then,
        appVersion: '1.0.0',
        deck: const ExchangeDeck(id: 'd', name: 'Verbos'),
      ),
    );
    await openSettings(tester, file: pickedBytes('verbos.json', deck));

    await tapAndSettle(tester, _key('settings.restore'));

    expect(
      find.text(
        'Este fichero no es una copia de seguridad. Para añadir un proyecto '
        'o una baraja, usa «Importar».',
      ),
      findsOneWidget,
    );
    expect(await projectNames(), isEmpty);
  });

  group('automatic backups', () {
    Future<AutoBackup> saveAutoBackup() =>
        AutoBackupFiles(() async => backups)
            .save(_backupFile(name: 'Copia automática'), _then);

    testWidgets('can be restored from Settings', (tester) async {
      final saved = await saveAutoBackup();
      await addLocalProject();
      await openSettings(tester);

      expect(find.text('COPIAS AUTOMÁTICAS'), findsOneWidget);
      await tapAndSettle(tester, _key('autoBackup.${saved.name}.restore'));
      await tapAndSettle(tester, _key('restoreDialog.continue'));

      expect(
        await projectNames(),
        unorderedEquals(['Del portátil', 'Copia automática']),
      );
    });

    testWidgets('can be deleted after confirming', (tester) async {
      final saved = await saveAutoBackup();
      await openSettings(tester);

      await tapAndSettle(tester, _key('autoBackup.${saved.name}.delete'));
      expect(find.text('¿Eliminar esta copia automática?'), findsOneWidget);
      await tapAndSettle(tester, _key('confirmDialog.confirm'));

      expect(File(saved.path).existsSync(), isFalse);
      expect(_key('autoBackup.${saved.name}'), findsNothing);
      expect(find.text('COPIAS AUTOMÁTICAS'), findsNothing);
    });

    testWidgets('deleting asks first: "Cancelar" keeps it', (tester) async {
      final saved = await saveAutoBackup();
      await openSettings(tester);

      await tapAndSettle(tester, _key('autoBackup.${saved.name}.delete'));
      await tapAndSettle(tester, _key('confirmDialog.cancel'));

      expect(File(saved.path).existsSync(), isTrue);
    });
  });
}
