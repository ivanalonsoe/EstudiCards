// Riverpod providers for the app-wide services.
//
// A provider is a global "recipe" that creates an object once and hands it
// to whoever asks for it (`ref.watch(databaseProvider)`). Widgets never
// build these objects themselves, so tests can swap them: the test helper
// overrides `databaseProvider` with an in-memory database and
// `clockProvider` with a `FakeClock`.
import 'package:estudicards/core/clock.dart';
import 'package:estudicards/core/db/app_database.dart';
import 'package:estudicards/core/files/image_files.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The app's database, opened once and closed when the app ends.
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

/// The current time (see `core/clock.dart`).
final clockProvider = Provider<Clock>((ref) => const SystemClock());

/// The card images on disk (see `core/files/image_files.dart`).
final imageFilesProvider = Provider<ImageFiles>((ref) => const NoImageFiles());
