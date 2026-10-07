import 'package:estudicards/core/providers.dart';
import 'package:estudicards/features/trash/data/trash_dao.dart';
import 'package:estudicards/features/trash/data/trash_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final trashRepositoryProvider = Provider<TrashRepository>(
  (ref) => TrashRepository(
    TrashDao(ref.watch(databaseProvider)),
    ref.watch(clockProvider),
    ref.watch(imageFilesProvider),
  ),
);
