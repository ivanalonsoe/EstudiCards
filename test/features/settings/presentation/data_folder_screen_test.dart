import 'dart:io';

import 'package:estudicards/app/l10n/generated/app_localizations.dart';
import 'package:estudicards/app/theme/app_theme.dart';
import 'package:estudicards/features/settings/data/data_folder_store.dart';
import 'package:estudicards/features/settings/presentation/data_folder_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/test_images.dart';

Finder _key(String key) => find.byKey(Key(key));

void main() {
  late Directory documents;
  late DataFolderStore store;
  Directory? ready;
  String? picked;

  setUp(() {
    documents = createTempFolder();
    store = DataFolderStore(createTempFolder());
    ready = null;
    picked = null;
  });

  Future<void> show(WidgetTester tester, {String? missingPath}) async {
    tester.view
      ..physicalSize = const Size(1280, 800)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('es'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: AppTheme.light(),
        home: DataFolderScreen(
          store: store,
          documents: documents,
          missingPath: missingPath,
          pickFolder: () async => picked,
          onReady: (folder) => ready = folder,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, String key) async {
    await tester.tap(_key(key));
    await tester.pumpAndSettle();
  }

  String path(Directory parent, String name) =>
      '${parent.path}${Platform.pathSeparator}$name';

  testWidgets(r'the first start offers Documents\EstudiCards', (tester) async {
    await show(tester);

    expect(find.text('¿Dónde guardamos tus datos?'), findsOneWidget);
    final folder = path(documents, 'EstudiCards');
    expect(find.text(folder), findsOneWidget);
    await tap(tester, 'dataFolder.continue');

    expect(ready!.path, folder);
    expect(Directory(folder).existsSync(), isTrue);
    expect((store.load() as ReadyDataFolder).folder.path, folder);
  });

  testWidgets('another folder gets an EstudiCards folder inside', (
    tester,
  ) async {
    final other = createTempFolder();
    picked = other.path;
    await show(tester);

    await tap(tester, 'dataFolder.change');
    expect(find.text(path(other, 'EstudiCards')), findsOneWidget);
    await tap(tester, 'dataFolder.continue');

    expect(ready!.path, path(other, 'EstudiCards'));
  });

  group('a folder that already has data', () {
    late Directory existing;

    setUp(() {
      final parent = createTempFolder();
      existing = Directory(path(parent, 'EstudiCards'))..createSync();
      File(path(existing, 'estudicards.sqlite')).writeAsStringSync('db');
      picked = existing.path;
    });

    testWidgets('can be loaded', (tester) async {
      await show(tester);

      await tap(tester, 'dataFolder.change');
      await tap(tester, 'dataFolder.continue');
      expect(find.text('Esta carpeta ya tiene datos'), findsOneWidget);
      await tap(tester, 'dataFolder.loadData');

      expect(ready!.path, existing.path);
      expect(
        File(path(existing, 'estudicards.sqlite')).readAsStringSync(),
        'db',
      );
    });

    testWidgets('or the user picks another one', (tester) async {
      await show(tester);

      await tap(tester, 'dataFolder.change');
      await tap(tester, 'dataFolder.continue');
      await tap(tester, 'dataFolder.chooseOther');

      expect(ready, isNull);
      expect(store.load(), isA<NoDataFolder>());
    });
  });

  group('data of an earlier version, loose in Documents', () {
    setUp(() {
      File(path(documents, 'estudicards.sqlite')).writeAsStringSync('old');
      Directory(path(documents, 'images')).createSync();
      File(path(documents, 'cv.pdf')).writeAsStringSync('pdf');
    });

    testWidgets('can be moved to the new folder', (tester) async {
      await show(tester);

      await tap(tester, 'dataFolder.continue');
      expect(find.text('Hemos encontrado tus datos'), findsOneWidget);
      await tap(tester, 'dataFolder.moveData');

      final folder = path(documents, 'EstudiCards');
      expect(ready!.path, folder);
      expect(
        File(path(Directory(folder), 'estudicards.sqlite')).readAsStringSync(),
        'old',
      );
      expect(Directory(path(Directory(folder), 'images')).existsSync(), isTrue);
      expect(File(path(documents, 'estudicards.sqlite')).existsSync(), isFalse);
      expect(File(path(documents, 'cv.pdf')).existsSync(), isTrue);
    });

    testWidgets('or left where they are', (tester) async {
      await show(tester);

      await tap(tester, 'dataFolder.continue');
      await tap(tester, 'dataFolder.startEmpty');

      expect(ready!.path, path(documents, 'EstudiCards'));
      expect(File(path(documents, 'estudicards.sqlite')).existsSync(), isTrue);
    });
  });

  testWidgets('a folder that is gone is reported and offered again', (
    tester,
  ) async {
    final gone = path(documents, 'EstudiCards');
    await show(tester, missingPath: gone);

    expect(
      find.text(
        'No encontramos la carpeta de tus datos. Si la has movido o '
        'cambiado de nombre, elígela de nuevo.',
      ),
      findsOneWidget,
    );
    expect(find.text(gone), findsOneWidget);
  });
}
