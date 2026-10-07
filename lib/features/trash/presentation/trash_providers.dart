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

/// The projects and decks in the trash, the most recently deleted first.
final trashItemsProvider = StreamProvider<List<TrashItem>>(
  (ref) => ref.watch(trashRepositoryProvider).watchTrash(),
);
