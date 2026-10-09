// Riverpod providers for the app-wide services.
//
// A provider is a global "recipe" that creates an object once and hands it
// to whoever asks for it (`ref.watch(databaseProvider)`). Widgets never
// build these objects themselves, so tests can swap them: the test helper
// overrides `databaseProvider` with an in-memory database and
// `clockProvider` with a `FakeClock`.
import 'dart:io';

import 'package:estudicards/core/clock.dart';
import 'package:estudicards/core/db/app_database.dart';
import 'package:estudicards/core/files/image_files.dart';
import 'package:estudicards/core/files/image_source.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

/// The app's database, opened once and closed when the app ends.
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

/// The current time (see `core/clock.dart`).
final clockProvider = Provider<Clock>((ref) => const SystemClock());

/// The folder with the card images: `<app documents>/images` (SPEC §3.4).
/// A `FutureProvider` because the system answers where the documents
/// folder is asynchronously. Tests use a temporary folder instead.
final imagesFolderProvider = FutureProvider<Directory>((ref) async {
  final documents = await getApplicationDocumentsDirectory();
  return Directory('${documents.path}/images');
});

/// The card images on disk (see `core/files/image_files.dart`). The trash
/// purge uses it too, so deleting a project for good deletes its images.
final imageFilesProvider = Provider<ImageFiles>(
  (ref) => DiskImageFiles(() => ref.read(imagesFolderProvider.future)),
);

/// Where the user picks images from (see `core/files/image_source.dart`).
final imageSourceProvider = Provider<ImageSource>(
  (ref) => const DeviceImageSource(),
);
