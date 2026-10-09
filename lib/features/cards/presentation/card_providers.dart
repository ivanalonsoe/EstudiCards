import 'package:estudicards/core/providers.dart';
import 'package:estudicards/features/cards/data/cards_dao.dart';
import 'package:estudicards/features/cards/data/cards_repository.dart';
import 'package:estudicards/features/cards/domain/flashcard.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';

final cardsRepositoryProvider = Provider<CardsRepository>(
  (ref) => CardsRepository(
    CardsDao(ref.watch(databaseProvider)),
    ref.watch(clockProvider),
    ref.watch(imageFilesProvider),
  ),
);

/// One card, read once when the editor opens; null if it does not exist
/// (see `deckProvider` for `autoDispose`).
final FutureProviderFamily<Flashcard?, String> cardProvider = FutureProvider
    .autoDispose
    .family((ref, id) => ref.watch(cardsRepositoryProvider).getById(id));
