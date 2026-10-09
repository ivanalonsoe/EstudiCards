import 'package:estudicards/core/providers.dart';
import 'package:estudicards/features/decks/data/decks_dao.dart';
import 'package:estudicards/features/decks/data/decks_repository.dart';
import 'package:estudicards/features/decks/domain/deck.dart';
import 'package:estudicards/features/decks/domain/deck_summary.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';

final decksRepositoryProvider = Provider<DecksRepository>(
  (ref) => DecksRepository(
    DecksDao(ref.watch(databaseProvider)),
    ref.watch(clockProvider),
  ),
);

/// One deck, read once; null if it does not exist. `autoDispose` forgets it
/// when no screen uses it, so reopening a screen reads it again.
final FutureProviderFamily<Deck?, String> deckProvider = FutureProvider
    .autoDispose
    .family((ref, id) => ref.watch(decksRepositoryProvider).getById(id));

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
