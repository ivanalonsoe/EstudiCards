import 'package:estudicards/app/router.dart';
import 'package:estudicards/core/clock.dart';
import 'package:estudicards/core/db/app_database.dart';
import 'package:estudicards/features/decks/data/decks_dao.dart';
import 'package:estudicards/features/decks/data/decks_repository.dart';
import 'package:estudicards/features/decks/domain/deck.dart';
import 'package:estudicards/features/decks/domain/deck_input.dart';
import 'package:estudicards/features/projects/data/projects_dao.dart';
import 'package:estudicards/features/projects/data/projects_repository.dart';
import 'package:estudicards/features/projects/domain/project.dart';
import 'package:estudicards/features/projects/domain/project_input.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/test_app.dart';
import '../../../helpers/test_data.dart';

void main() {
  late AppDatabase db;
  late FakeClock clock;
  late ProjectsRepository projects;
  late DecksRepository decks;
  late Project english;
  late Deck verbs;

  setUp(() async {
    db = createTestDatabase();
    clock = FakeClock(DateTime.utc(2026, 10, 6, 12));
    projects = ProjectsRepository(ProjectsDao(db), clock);
    decks = DecksRepository(DecksDao(db), clock);
    english = await projects.create(
      const ProjectInput(name: 'Inglés B2', color: 'blue', icon: 'globe'),
    );
    verbs = await decks.create(english.id, const DeckInput(name: 'Verbos'));
    await addTestCard(db, verbs.id);
    await addTestCard(db, verbs.id);
    final phrasal = await decks.create(
      english.id,
      const DeckInput(name: 'Phrasal verbs'),
    );
    await addTestCard(db, phrasal.id);
  });

  Finder cardOf(Project p) => find.byKey(Key('projectCard.${p.id}'));
  final confirm = find.byKey(const Key('confirmDialog.confirm'));

  Future<void> chooseInMenu(WidgetTester tester, Key menu, String item) async {
    await tester.tap(find.byKey(menu));
    await tester.pumpAndSettle();
    await tester.tap(find.text(item));
    await tester.pumpAndSettle();
  }

  Future<DateTime?> storedDeletedAt(String projectId) async =>
      (await (db.select(
        db.projects,
      )..where((p) => p.id.equals(projectId))).getSingle()).deletedAt;

  group('project from the dashboard', () {
    Future<void> openDeleteDialog(WidgetTester tester) async {
      await pumpTestApp(tester, size: mobile, db: db, clock: clock);
      await chooseInMenu(
        tester,
        Key('projectCard.${english.id}.menu'),
        'Eliminar',
      );
    }

    testWidgets('the dialog states how many decks and cards will be moved', (
      tester,
    ) async {
      await openDeleteDialog(tester);

      expect(find.text('¿Eliminar «Inglés B2»?'), findsOneWidget);
      expect(
        find.text(
          'Se moverán a la papelera 2 barajas y 3 tarjetas. '
          'Podrás recuperarlo durante 15 días.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('cancelling keeps the project', (tester) async {
      await openDeleteDialog(tester);

      await tester.tap(find.byKey(const Key('confirmDialog.cancel')));
      await tester.pumpAndSettle();

      expect(cardOf(english), findsOneWidget);
      expect(await storedDeletedAt(english.id), isNull);
    });

    testWidgets('tapping "Deshacer" within 5 s leaves the project where it '
        'was', (tester) async {
      await openDeleteDialog(tester);

      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(cardOf(english), findsNothing);
      expect(
        find.text('«Inglés B2» se ha movido a la papelera'),
        findsOneWidget,
      );

      await tester.pump(const Duration(seconds: 4));
      await tester.tap(find.text('Deshacer'));
      await tester.pumpAndSettle();

      expect(cardOf(english), findsOneWidget);
      expect(await storedDeletedAt(english.id), isNull);
    });

    testWidgets('without "Deshacer" the message goes after 5 s and the '
        'project stays in the trash', (tester) async {
      await openDeleteDialog(tester);

      await tester.tap(confirm);
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      expect(find.text('Deshacer'), findsNothing);
      expect(cardOf(english), findsNothing);
      expect(await storedDeletedAt(english.id), clock.now());
    });
  });

  testWidgets('a project deleted from its own screen goes back to the '
      'dashboard with "Deshacer"', (tester) async {
    await pumpTestApp(
      tester,
      size: mobile,
      db: db,
      clock: clock,
      location: AppRoutes.project(english.id),
    );

    await chooseInMenu(
      tester,
      const Key('projectScreen.menu'),
      'Eliminar proyecto',
    );
    await tester.tap(confirm);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('screen.dashboard')), findsOneWidget);
    expect(find.text('Deshacer'), findsOneWidget);

    await tester.tap(find.text('Deshacer'));
    await tester.pumpAndSettle();
    expect(cardOf(english), findsOneWidget);
  });

  testWidgets('a deck is deleted from its menu, and "Deshacer" brings it '
      'back', (tester) async {
    await pumpTestApp(
      tester,
      size: mobile,
      db: db,
      clock: clock,
      location: AppRoutes.project(english.id),
    );
    final tile = find.byKey(Key('deckTile.${verbs.id}'));

    await chooseInMenu(tester, Key('deckTile.${verbs.id}.menu'), 'Eliminar');
    expect(
      find.text(
        'Se moverán a la papelera 2 tarjetas. '
        'Podrás recuperarla durante 15 días.',
      ),
      findsOneWidget,
    );
    await tester.tap(confirm);
    await tester.pumpAndSettle();

    expect(tile, findsNothing);
    expect(find.text('«Verbos» se ha movido a la papelera'), findsOneWidget);

    await tester.tap(find.text('Deshacer'));
    await tester.pumpAndSettle();
    expect(tile, findsOneWidget);
  });
}
