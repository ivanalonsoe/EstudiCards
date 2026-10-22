// The daily goal on the dashboard and the sidebar (US-23 AC2,
// `docs/design/movil-claro/dashboard.png`, `escritorio-claro/dashboard.png`).
import 'package:drift/drift.dart' show Value;
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

Finder _key(String key) => find.byKey(Key(key));

void main() {
  late AppDatabase db;

  /// A project with one card answered [answered] times today (the test
  /// clock's day, 6 October 2026) and, if given, a daily [goal]. With
  /// [goalOff] the goal was turned off in Settings (stored with no value).
  Future<void> prepare({
    required int answered,
    int? goal,
    bool goalOff = false,
  }) async {
    db = createTestDatabase();
    final clock = FakeClock(DateTime.utc(2026, 10, 6, 12));
    final project = await ProjectsRepository(ProjectsDao(db), clock).create(
      const ProjectInput(name: 'Inglés B2', color: 'blue', icon: 'globe'),
    );
    final deck = await DecksRepository(
      DecksDao(db),
      clock,
    ).create(project.id, const DeckInput(name: 'Verbos'));
    final card = await addTestCard(db, deck.id);
    await addTestAnswers(
      db,
      projectId: project.id,
      cardId: card,
      results: List.filled(answered, 'correct'),
    );
    if (goal != null) {
      await db
          .into(db.settings)
          .insert(
            SettingsCompanion.insert(key: 'daily_goal', value: Value('$goal')),
          );
    }
    if (goalOff) {
      await db
          .into(db.settings)
          .insert(SettingsCompanion.insert(key: 'daily_goal'));
    }
  }

  testWidgets('a new install shows a goal of 20 cards', (tester) async {
    await prepare(answered: 3);

    await pumpTestApp(tester, size: mobile, db: db);
    expect(
      find.descendant(of: _key('dashboard.goal'), matching: find.text('de 20')),
      findsOneWidget,
    );

    await pumpTestApp(tester, size: desktop, db: db);
    expect(
      find.descendant(
        of: _key('sidebar.goal'),
        matching: find.text('3 de 20 hoy'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('with the goal turned off, there is no goal ring or card', (
    tester,
  ) async {
    await prepare(answered: 3, goalOff: true);

    await pumpTestApp(tester, size: mobile, db: db);
    expect(_key('dashboard.goal'), findsNothing);

    await pumpTestApp(tester, size: desktop, db: db);
    expect(_key('dashboard.goal'), findsNothing);
    expect(_key('sidebar.goal'), findsNothing);
  });

  testWidgets('mobile: the greeting card shows the ring and the cards left', (
    tester,
  ) async {
    await prepare(answered: 14, goal: 20);

    await pumpTestApp(tester, size: mobile, db: db);

    final goal = _key('dashboard.goal');
    expect(goal, findsOneWidget);
    expect(
      find.descendant(of: goal, matching: find.text('14')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: goal, matching: find.text('de 20')),
      findsOneWidget,
    );
    expect(
      find.text('Te quedan 6 tarjetas para tu objetivo de hoy'),
      findsOneWidget,
    );
  });

  testWidgets('desktop: the goal card, the line under the greeting and the '
      'sidebar card', (tester) async {
    await prepare(answered: 14, goal: 20);

    await pumpTestApp(tester, size: desktop, db: db);

    final goal = _key('dashboard.goal');
    expect(
      find.descendant(of: goal, matching: find.text('Objetivo diario')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: goal, matching: find.text('70% completado')),
      findsOneWidget,
    );
    expect(
      find.text('Te quedan 6 tarjetas para tu objetivo de hoy.'),
      findsOneWidget,
    );
    final sidebar = _key('sidebar.goal');
    expect(
      find.descendant(of: sidebar, matching: find.text('14 de 20 hoy')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: sidebar, matching: find.text('1 día de racha')),
      findsOneWidget,
    );
  });

  testWidgets('a reached goal says so', (tester) async {
    await prepare(answered: 6, goal: 5);

    await pumpTestApp(tester, size: mobile, db: db);

    expect(find.text('¡Objetivo de hoy cumplido!'), findsOneWidget);
  });
}
