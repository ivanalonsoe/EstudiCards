import 'package:drift/drift.dart';
import 'package:estudicards/core/db/app_database.dart';
import 'package:estudicards/core/ids.dart';

/// Inserts a simple card into [deckId]. The cards repository arrives in
/// phase 2; until then tests that need cards insert them by hand.
Future<void> addTestCard(AppDatabase db, String deckId) {
  final now = DateTime.utc(2026, 10, 6);
  return db
      .into(db.cards)
      .insert(
        CardsCompanion.insert(
          id: newId(),
          deckId: deckId,
          type: 'simple',
          question: 'to bring',
          answer: const Value('traer'),
          createdAt: now,
          updatedAt: now,
        ),
      );
}
