import 'package:estudicards/app/router.dart';
import 'package:estudicards/core/clock.dart';
import 'package:estudicards/core/db/app_database.dart';
import 'package:estudicards/features/import_export/domain/exchange_document.dart';
import 'package:estudicards/features/import_export/domain/exchange_json.dart';
import 'package:estudicards/features/projects/data/projects_dao.dart';
import 'package:estudicards/features/projects/data/projects_repository.dart';
import 'package:estudicards/features/projects/domain/project_input.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_file_exporter.dart';
import '../../../helpers/test_app.dart';
import '../../cards/presentation/card_editor_finders.dart';

Finder _key(String key) => find.byKey(Key(key));

void main() {
  late AppDatabase db;

  setUp(() async {
    db = createTestDatabase();
    await ProjectsRepository(
      ProjectsDao(db),
      FakeClock(DateTime.utc(2026, 10, 6)),
    ).create(
      const ProjectInput(name: 'Inglés B2', color: 'blue', icon: 'globe'),
    );
  });

  Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
    await tapVisible(tester, finder);
    await tester.pumpAndSettle();
  }

  group('"Exportar todo" (US-24)', () {
    testWidgets('saves a full backup named after today', (tester) async {
      final exporter = FakeFileExporter();
      await pumpTestApp(
        tester,
        size: mobile,
        db: db,
        location: AppRoutes.settings,
        fileExporter: exporter,
      );

      expect(find.text('Copia de seguridad en JSON'), findsOneWidget);
      await tapAndSettle(tester, _key('settings.exportAll'));

      final file = exporter.exported.single;
      // The test clock is 6 October 2026 at 12:00 UTC.
      expect(file.name, 'estudicards-backup-2026-10-06.json');
      expect(file.mimeType, 'application/json');
      final backup = decodeExchange(file.bytes) as BackupDocument;
      expect(backup.projects.single.name, 'Inglés B2');
    });

    testWidgets('is in the mobile menu too (SPEC §5.1)', (tester) async {
      final exporter = FakeFileExporter();
      await pumpTestApp(tester, size: mobile, db: db, fileExporter: exporter);

      await tapAndSettle(tester, find.byTooltip('Abrir el menú de navegación'));
      await tapAndSettle(tester, _key('nav.exportAll'));

      expect(exporter.exported.single.name, endsWith('.json'));
    });

    testWidgets('on desktop it says where the backup was saved', (
      tester,
    ) async {
      await pumpTestApp(
        tester,
        size: desktop,
        db: db,
        location: AppRoutes.settings,
        fileExporter: FakeFileExporter(
          savesToDisk: true,
          savedPath: r'D:\copias\estudicards-backup-2026-10-06.json',
        ),
      );

      await tapAndSettle(tester, _key('settings.exportAll'));

      expect(
        find.text(r'Guardado en D:\copias\estudicards-backup-2026-10-06.json'),
        findsOneWidget,
      );
    });
  });

  group('a backup over the size limit (T5.10)', () {
    Future<FakeFileExporter> openWithLimit(WidgetTester tester) async {
      final exporter = FakeFileExporter();
      await pumpTestApp(
        tester,
        size: mobile,
        db: db,
        location: AppRoutes.settings,
        fileExporter: exporter,
        // Any backup is bigger than 10 bytes.
        backupLimit: 10,
      );
      await tapAndSettle(tester, _key('settings.exportAll'));
      return exporter;
    }

    testWidgets('offers to export without images', (tester) async {
      final exporter = await openWithLimit(tester);

      expect(find.text('La copia es demasiado grande'), findsOneWidget);
      expect(
        find.text('Copia completa con estadísticas, sin las imágenes'),
        findsOneWidget,
      );
      await tapAndSettle(tester, _key('backupTooLarge.withoutImages'));
      await tapAndSettle(tester, _key('backupTooLarge.continue'));

      final file = exporter.exported.single;
      expect(file.name, 'estudicards-backup-2026-10-06.json');
      final backup = decodeExchange(file.bytes) as BackupDocument;
      expect(backup.projects.single.name, 'Inglés B2');
    });

    testWidgets('or explains how to share the decks one by one', (
      tester,
    ) async {
      final exporter = await openWithLimit(tester);

      await tapAndSettle(tester, _key('backupTooLarge.deckByDeck'));
      await tapAndSettle(tester, _key('backupTooLarge.continue'));

      expect(exporter.exported, isEmpty);
      expect(
        find.text(
          'Abre cada baraja y usa «Compartir» › JSON: lleva sus imágenes, '
          'pero no las estadísticas.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('"Cancelar" exports nothing', (tester) async {
      final exporter = await openWithLimit(tester);

      await tapAndSettle(tester, _key('backupTooLarge.cancel'));

      expect(exporter.exported, isEmpty);
    });
  });

  testWidgets('shows the app version and the privacy note', (tester) async {
    await pumpTestApp(
      tester,
      size: mobile,
      db: db,
      location: AppRoutes.settings,
    );
    // The footer is at the bottom, below every section.
    await tester.drag(find.byType(ListView), const Offset(0, -2000));
    await tester.pumpAndSettle();

    expect(find.text('EstudiCards 1.0.0'), findsOneWidget);
    expect(
      find.text(
        'Sin cuentas ni conexión. Tus datos solo salen si los exportas.',
      ),
      findsOneWidget,
    );
  });
}
