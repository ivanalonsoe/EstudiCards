import 'package:estudicards/core/providers.dart';
import 'package:estudicards/features/decks/data/decks_dao.dart';
import 'package:estudicards/features/decks/data/decks_repository.dart';
import 'package:estudicards/features/decks/domain/deck_summary.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';

final decksRepositoryProvider = Provider<DecksRepository>(
  (ref) => DecksRepository(
    DecksDao(ref.watch(databaseProvider)),
    ref.watch(clockProvider),
  ),
);

/// A project's decks with their card counts.
///
/// `.family` makes one provider per argument: `deckSummariesProvider(id)`
/// is the deck list of the project with that ID, and each project's list is
/// kept and updated separately.
final StreamProviderFamily<List<DeckSummary>, String> deckSummariesProvider =
    StreamProvider.family(
      (ref, projectId) =>
          ref.watch(decksRepositoryProvider).watchDecks(projectId),
    );
