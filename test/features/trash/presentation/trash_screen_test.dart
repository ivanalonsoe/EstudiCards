import 'package:estudicards/app/router.dart';
import 'package:estudicards/core/clock.dart';
import 'package:estudicards/core/db/app_database.dart';
import 'package:estudicards/core/files/image_files.dart';
import 'package:estudicards/features/decks/data/decks_dao.dart';
import 'package:estudicards/features/decks/data/decks_repository.dart';
import 'package:estudicards/features/decks/domain/deck.dart';
import 'package:estudicards/features/decks/domain/deck_input.dart';
import 'package:estudicards/features/projects/data/projects_dao.dart';
import 'package:estudicards/features/projects/data/projects_repository.dart';
import 'package:estudicards/features/projects/domain/project.dart';
import 'package:estudicards/features/projects/domain/project_input.dart';
import 'package:estudicards/features/trash/data/trash_dao.dart';
import 'package:estudicards/features/trash/data/trash_repository.dart';
import 'package:estudicards/features/trash/presentation/trash_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/test_app.dart';
import '../../../helpers/test_data.dart';

void main() {
  late AppDatabase db;
  late FakeClock clock;
  final today = DateTime.utc(2026, 10, 20, 12);

  setUp(() {
    db = createTestDatabase();
    clock = FakeClock(today);
  });

  /// A trash repository whose clock is [daysAgo] days before today, to move
  /// items to the trash in the past.
  TrashRepository trashDaysAgo(int daysAgo) => TrashRepository(
    TrashDao(db),
    FakeClock(today.subtract(Duration(days: daysAgo))),
    const NoImageFiles(),
  );

  /// The stored row, read with a plain query (see `test_app.dart`).
  Future<ProjectRow?> storedProject(String id) =>
      (db.select(db.projects)..where((p) => p.id.equals(id))).getSingleOrNull();

  Future<void> openTrash(WidgetTester tester) => pumpTestApp(
    tester,
    size: mobile,
    db: db,
    clock: clock,
    location: AppRoutes.trash,
  );

  Finder item(String id) => find.byKey(Key('trashItem.$id'));

  testWidgets('with nothing deleted, the empty state is shown', (tester) async {
    await openTrash(tester);

    expect(find.byKey(const Key('screen.trash')), findsOneWidget);
    expect(find.byKey(const Key('trash.emptyState')), findsOneWidget);
    expect(find.byKey(const Key('trash.empty')), findsNothing);
  });

  group('with items', () {
    late Project history;
    late Deck phrasal;

    setUp(() async {
      final projects = ProjectsRepository(ProjectsDao(db), clock);
      final decks = DecksRepository(DecksDao(db), clock);
      history = await projects.create(
        const ProjectInput(
          name: 'Historia 1º Bach.',
          color: 'violet',
          icon: 'book',
        ),
      );
      final ages = await decks.create(
        history.id,
        const DeckInput(name: 'Edad Media'),
      );
      await addTestCard(db, ages.id);
      await addTestCard(db, ages.id);
      final english = await projects.create(
        const ProjectInput(name: 'Inglés B2', color: 'blue', icon: 'globe'),
      );
      phrasal = await decks.create(
        english.id,
        const DeckInput(name: 'Phrasal verbs antiguos'),
      );
      await addTestCard(db, phrasal.id);

      // 12 days left for the project, 2 for the deck.
      await trashDaysAgo(3).moveProjectToTrash(history.id);
      await trashDaysAgo(13).moveDeckToTrash(phrasal.id);
    });

    testWidgets('lists projects and decks with their details', (tester) async {
      await openTrash(tester);

      expect(
        find.descendant(
          of: item(history.id),
          matching: find.text('Proyecto · 1 baraja · 2 tarjetas'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: item(phrasal.id),
          matching: find.text('Baraja de Inglés B2 · 1 tarjeta'),
        ),
        findsOneWidget,
      );
      expect(find.text('Se elimina en 12 días'), findsOneWidget);
      expect(find.text('Se elimina en 2 días'), findsOneWidget);
    });

    testWidgets('an item with 2 days left is flagged as urgent', (
      tester,
    ) async {
      await openTrash(tester);

      DaysLeftChip chip(String id) => tester.widget<DaysLeftChip>(
        find.byKey(Key('trashItem.$id.daysLeft')),
      );
      expect(chip(phrasal.id).urgent, isTrue);
      expect(chip(history.id).urgent, isFalse);
    });

    testWidgets('opening the trash purges the items that expired while the '
        'app was open', (tester) async {
      // The app starts today, when the deck still has 2 days left…
      final router = await pumpTestApp(
        tester,
        size: mobile,
        db: db,
        clock: clock,
      );
      // …and stays open for 3 more days.
      clock.advance(const Duration(days: 3));

      router.go(AppRoutes.trash);
      await tester.pumpAndSettle();

      expect(item(phrasal.id), findsNothing);
      expect(item(history.id), findsOneWidget);
      final deckRows = await db.select(db.decks).get();
      expect(deckRows.map((d) => d.id), isNot(contains(phrasal.id)));
    });

    testWidgets('restoring a project takes it out of the trash', (
      tester,
    ) async {
      await openTrash(tester);

      await tester.tap(find.byKey(Key('trashItem.${history.id}.restore')));
      await tester.pumpAndSettle();

      expect(item(history.id), findsNothing);
      expect((await storedProject(history.id))!.deletedAt, isNull);
    });

    testWidgets('deleting an item permanently asks first', (tester) async {
      await openTrash(tester);

      await tester.tap(find.byKey(Key('trashItem.${history.id}.delete')));
      await tester.pumpAndSettle();
      expect(
        find.text('¿Eliminar definitivamente «Historia 1º Bach.»?'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('confirmDialog.confirm')));
      await tester.pumpAndSettle();

      expect(item(history.id), findsNothing);
      expect(await storedProject(history.id), isNull);
    });

    testWidgets('emptying the trash asks first and deletes everything', (
      tester,
    ) async {
      await openTrash(tester);

      await tester.tap(find.byKey(const Key('trash.empty')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirmDialog.cancel')));
      await tester.pumpAndSettle();
      expect(item(history.id), findsOneWidget);

      await tester.tap(find.byKey(const Key('trash.empty')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirmDialog.confirm')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('trash.emptyState')), findsOneWidget);
      expect(await storedProject(history.id), isNull);
      // "Edad Media" went with its project; the trashed deck went too.
      expect(await db.select(db.decks).get(), isEmpty);
    });
  });
}
