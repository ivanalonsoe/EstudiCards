import 'package:estudicards/core/providers.dart';
import 'package:estudicards/features/import_export/data/import_dao.dart';
import 'package:estudicards/features/import_export/data/import_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Previews and writes imports (see `ImportRepository`).
final importRepositoryProvider = Provider<ImportRepository>(
  (ref) => ImportRepository(
    ImportDao(ref.watch(databaseProvider)),
    ref.watch(clockProvider),
    ref.watch(imageFilesProvider),
  ),
);
