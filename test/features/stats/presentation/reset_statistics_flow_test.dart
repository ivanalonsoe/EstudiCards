import 'package:estudicards/app/router.dart';
import 'package:estudicards/core/clock.dart';
import 'package:estudicards/core/db/app_database.dart';
import 'package:estudicards/features/decks/data/decks_dao.dart';
import 'package:estudicards/features/decks/data/decks_repository.dart';
import 'package:estudicards/features/decks/domain/deck_input.dart';
import 'package:estudicards/features/projects/data/projects_dao.dart';
import 'package:estudicards/features/projects/data/projects_repository.dart';
import 'package:estudicards/features/projects/domain/project_input.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/test_app.dart';
import '../../../helpers/test_data.dart';

/// "Reiniciar estadísticas" from the deck menu (P03), the card editor (P06)
/// and the project form (P02), always after confirming.
void main() {
  late AppDatabase db;
  late FakeClock clock;
  late String projectId;
  late String deckId;
  late String cardId;
  late String otherDeckId;
  late String otherCardId;

  setUp(() async {
    db = createTestDatabase();
    clock = FakeClock(DateTime.utc(2026, 10, 6, 12));
    projectId = (await ProjectsRepository(ProjectsDao(db), clock).create(
      const ProjectInput(name: 'Inglés B2', color: 'blue', icon: 'globe'),
    )).id;
    final decks = DecksRepository(DecksDao(db), clock);
    deckId = (await decks.create(
      projectId,
      const DeckInput(name: 'Verbos'),
    )).id;
    otherDeckId = (await decks.create(
      projectId,
      const DeckInput(name: 'Phrasal verbs'),
    )).id;
    cardId = await addTestCard(db, deckId);
    otherCardId = await addTestCard(db, otherDeckId);
    for (final card in [cardId, otherCardId]) {
      await addTestAnswers(
        db,
        projectId: projectId,
        cardId: card,
        results: ['correct', 'wrong'],
      );
    }
  });

  Future<int> attemptsOf(String card) async => (await (db.select(
    db.attempts,
  )..where((a) => a.cardId.equals(card))).get()).length;

  Future<void> tapKey(WidgetTester tester, String key) async {
    await tester.tap(find.byKey(Key(key)));
    await tester.pumpAndSettle();
  }

  group('deck menu', () {
    Future<void> chooseReset(WidgetTester tester) async {
      await pumpTestApp(
        tester,
        size: mobile,
        db: db,
        clock: clock,
        location: AppRoutes.project(projectId),
      );
      expect(find.byKey(Key('deckTile.$deckId.errors')), findsOneWidget);
      await tapKey(tester, 'deckTile.$deckId.menu');
      await tester.tap(find.text('Reiniciar estadísticas'));
      await tester.pumpAndSettle();
    }

    testWidgets('resets the deck after confirming', (tester) async {
      await chooseReset(tester);
      expect(find.byKey(const Key('confirmDialog')), findsOneWidget);

      await tapKey(tester, 'confirmDialog.confirm');

      expect(await attemptsOf(cardId), 0);
      expect(await attemptsOf(otherCardId), 2);
      expect(find.byKey(Key('deckTile.$deckId.errors')), findsNothing);
      expect(find.byKey(Key('deckTile.$otherDeckId.errors')), findsOneWidget);
      expect(find.text('Estadísticas reiniciadas'), findsOneWidget);
    });

    testWidgets('"Cancelar" keeps the statistics', (tester) async {
      await chooseReset(tester);

      await tapKey(tester, 'confirmDialog.cancel');

      expect(await attemptsOf(cardId), 2);
      expect(find.byKey(Key('deckTile.$deckId.errors')), findsOneWidget);
    });
  });

  for (final (name, size) in [('mobile', mobile), ('desktop', desktop)]) {
    testWidgets('$name: the card editor resets the card after '
        'confirming', (tester) async {
      await pumpTestApp(
        tester,
        size: size,
        db: db,
        clock: clock,
        location: AppRoutes.editCard(projectId, deckId, cardId),
      );

      await tapKey(tester, 'cardEditor.resetStats');
      await tapKey(tester, 'confirmDialog.confirm');

      expect(await attemptsOf(cardId), 0);
      expect(await attemptsOf(otherCardId), 2);
      expect(find.text('Estadísticas reiniciadas'), findsOneWidget);
    });
  }

  testWidgets('a new card offers no reset', (tester) async {
    await pumpTestApp(
      tester,
      size: mobile,
      db: db,
      clock: clock,
      location: AppRoutes.newCard(projectId, deckId),
    );

    expect(find.byKey(const Key('cardEditor.resetStats')), findsNothing);
  });

  testWidgets('editing the project resets every deck of it after '
      'confirming', (tester) async {
    await pumpTestApp(
      tester,
      size: mobile,
      db: db,
      clock: clock,
      location: AppRoutes.project(projectId),
    );
    await tapKey(tester, 'projectScreen.menu');
    await tester.tap(find.text('Editar proyecto'));
    await tester.pumpAndSettle();

    final reset = find.byKey(const Key('projectForm.resetStats'));
    await tester.ensureVisible(reset);
    await tester.pumpAndSettle();
    await tester.tap(reset);
    await tester.pumpAndSettle();
    await tapKey(tester, 'confirmDialog.confirm');

    expect(await attemptsOf(cardId), 0);
    expect(await attemptsOf(otherCardId), 0);
  });

  testWidgets('a new project offers no reset', (tester) async {
    await pumpTestApp(tester, size: mobile, db: db, clock: clock);

    await tapKey(tester, 'dashboard.newProject');

    expect(find.byKey(const Key('projectForm.resetStats')), findsNothing);
  });
}
