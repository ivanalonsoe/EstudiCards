// T5.11 (decided with the owner): on Windows the database, the images and
// the automatic backups live in a folder the user chooses, `Documents\
// EstudiCards` by default, instead of loose in Documents. This decides,
// before the app starts, whether to open it there or to ask for the folder
// first.
import 'dart:io';

import 'package:drift_flutter/drift_flutter.dart';
import 'package:estudicards/app/app.dart';
import 'package:estudicards/app/l10n/generated/app_localizations.dart';
import 'package:estudicards/app/theme/app_theme.dart';
import 'package:estudicards/core/db/app_database.dart';
import 'package:estudicards/core/providers.dart';
import 'package:estudicards/features/settings/data/data_folder_store.dart';
import 'package:estudicards/features/settings/domain/data_folder.dart';
import 'package:estudicards/features/settings/presentation/data_folder_screen.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

/// The first widget on Windows: the app in its data folder, or the screen
/// that asks for that folder (the first start, or a folder that is gone).
/// The choice is kept in the app's settings folder, under AppData.
///
/// It opens native dialogs and the real folders, so it is tried by hand;
/// `DataFolderScreen` and `DataFolderStore` have their own tests.
Future<Widget> windowsStartup() async {
  final store = DataFolderStore(await getApplicationSupportDirectory());
  final documents = await getApplicationDocumentsDirectory();
  Widget ask(String? missingPath) => MaterialApp(
    debugShowCheckedModeBanner: false,
    locale: const Locale('es'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: AppTheme.light(),
    darkTheme: AppTheme.dark(),
    home: DataFolderScreen(
      store: store,
      documents: documents,
      missingPath: missingPath,
      pickFolder: FilePicker.getDirectoryPath,
      // `runApp` again replaces this screen with the app.
      onReady: (folder) => runApp(appInDataFolder(folder)),
    ),
  );
  return switch (store.load()) {
    ReadyDataFolder(:final folder) => appInDataFolder(folder),
    NoDataFolder() => ask(null),
    MissingDataFolder(:final path) => ask(path),
  };
}

/// The app with its database, images and automatic backups in [folder].
Widget appInDataFolder(Directory folder) {
  String inFolder(String name) =>
      '${folder.path}${Platform.pathSeparator}$name';
  return ProviderScope(
    overrides: [
      databaseProvider.overrideWith((ref) {
        final db = AppDatabase(
          driftDatabase(
            name: 'estudicards',
            native: DriftNativeOptions(
              databasePath: () async => inFolder(databaseFileName),
            ),
          ),
        );
        ref.onDispose(db.close);
        return db;
      }),
      imagesFolderProvider.overrideWith((ref) => Directory(inFolder('images'))),
      backupsFolderProvider.overrideWith(
        (ref) => Directory(inFolder('backups')),
      ),
    ],
    child: const EstudiCardsApp(),
  );
}
