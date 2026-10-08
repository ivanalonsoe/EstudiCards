import 'package:estudicards/core/providers.dart';
import 'package:estudicards/features/trash/data/trash_dao.dart';
import 'package:estudicards/features/trash/data/trash_repository.dart';
import 'package:estudicards/features/trash/domain/trash_item.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final trashRepositoryProvider = Provider<TrashRepository>(
  (ref) => TrashRepository(
    TrashDao(ref.watch(databaseProvider)),
    ref.watch(clockProvider),
    ref.watch(imageFilesProvider),
  ),
);

/// Purges the expired trash once, when the app starts (SPEC §7.1), and
/// gives how many items it deleted. A `FutureProvider` runs its function
/// the first time it is read and keeps the result, so tests can wait for it
/// with `container.read(startupPurgeProvider.future)`.
final startupPurgeProvider = FutureProvider<int>(
  (ref) => ref.read(trashRepositoryProvider).purgeExpired(),
);

/// The projects and decks in the trash, the most recently deleted first.
final trashItemsProvider = StreamProvider<List<TrashItem>>(
  (ref) => ref.watch(trashRepositoryProvider).watchTrash(),
);
