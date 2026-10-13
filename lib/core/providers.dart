// Riverpod providers for the app-wide services.
//
// A provider is a global "recipe" that creates an object once and hands it
// to whoever asks for it (`ref.watch(databaseProvider)`). Widgets never
// build these objects themselves, so tests can swap them: the test helper
// overrides `databaseProvider` with an in-memory database and
// `clockProvider` with a `FakeClock`.
import 'dart:io';
import 'dart:math';

import 'package:estudicards/core/clock.dart';
import 'package:estudicards/core/db/app_database.dart';
import 'package:estudicards/core/files/image_files.dart';
import 'package:estudicards/core/files/image_source.dart';
import 'package:estudicards/core/random.dart';
import 'package:estudicards/core/voice/system_voice.dart';
import 'package:estudicards/core/voice/voice.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:path_provider/path_provider.dart';

/// The app's database, opened once and closed when the app ends.
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

/// The current time (see `core/clock.dart`).
final clockProvider = Provider<Clock>((ref) => const SystemClock());

/// Randomness for card selection and shuffling (see `core/random.dart`).
/// Tests override it with a seeded one.
final randomProvider = Provider<Random>((ref) => createRandom());

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

/// Reads cards aloud with the system voices (see `core/voice/voice.dart`).
final voiceProvider = Provider<Voice>((ref) => SystemVoice());

/// Whether the system has a voice for a language, asked once per language
/// (see `deckSummariesProvider` for `.family`).
final FutureProviderFamily<bool, String> voiceAvailableProvider =
    FutureProvider.family(
      (ref, language) => ref.watch(voiceProvider).isAvailable(language),
    );
