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

void main() {
  late AppDatabase db;
  late FakeClock clock;
  late DecksRepository decks;
  late Project project;

  setUp(() async {
    db = createTestDatabase();
    clock = FakeClock(DateTime.utc(2026, 10, 6, 12));
    decks = DecksRepository(DecksDao(db), clock);
    project = await ProjectsRepository(ProjectsDao(db), clock).create(
      const ProjectInput(name: 'Inglés B2', color: 'blue', icon: 'globe'),
    );
  });

  Future<void> openProject(WidgetTester tester, {Size size = mobile}) =>
      pumpTestApp(
        tester,
        size: size,
        db: db,
        clock: clock,
        location: AppRoutes.project(project.id),
      );

  /// The decks in the database, read with a plain query (see
  /// `test/helpers/test_app.dart`).
  Future<List<Deck>> storedDecks() async {
    final rows = await db.select(db.decks).get();
    return [for (final row in rows) (await decks.getById(row.id))!];
  }

  final save = find.byKey(const Key('deckForm.save'));
  bool saveEnabled(WidgetTester tester) =>
      tester.widget<ButtonStyleButton>(save).onPressed != null;

  Future<void> openNewDeckForm(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('projectScreen.newDeck')));
    await tester.pumpAndSettle();
  }

  testWidgets('cannot save without a name', (tester) async {
    await openProject(tester);
    await openNewDeckForm(tester);

    expect(find.byKey(const Key('deckForm')), findsOneWidget);
    expect(saveEnabled(tester), isFalse);

    await tester.enterText(find.byKey(const Key('deckForm.name')), '   ');
    await tester.pump();
    expect(saveEnabled(tester), isFalse);

    await tester.enterText(find.byKey(const Key('deckForm.name')), 'Verbos');
    await tester.pump();
    expect(saveEnabled(tester), isTrue);
  });

  testWidgets('the new deck appears in the list', (tester) async {
    await openProject(tester);
    expect(find.byKey(const Key('projectScreen.empty')), findsOneWidget);

    await openNewDeckForm(tester);
    await tester.enterText(
      find.byKey(const Key('deckForm.name')),
      'Verbos irregulares',
    );
    // Rebuild so the Save button is enabled before tapping it.
    await tester.pump();
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('deckForm')), findsNothing);
    final [deck] = await storedDecks();
    expect(deck.name, 'Verbos irregulares');
    expect(find.byKey(Key('deckTile.${deck.id}')), findsOneWidget);
    expect(find.text('0 tarjetas · — aciertos'), findsOneWidget);
    // It stays on the project screen.
    expect(find.byKey(const Key('screen.project')), findsOneWidget);
  });

  testWidgets("a new deck uses the project's colour unless one is chosen", (
    tester,
  ) async {
    await openProject(tester);
    await openNewDeckForm(tester);

    expect(
      tester.getSemantics(find.byKey(const Key('deckForm.color.project'))),
      isSemantics(isSelected: true, label: 'Del proyecto'),
    );

    await tester.enterText(find.byKey(const Key('deckForm.name')), 'Viajes');
    await tester.tap(find.byKey(const Key('deckForm.color.teal')));
    await tester.pump();
    await tester.tap(save);
    await tester.pumpAndSettle();

    final [deck] = await storedDecks();
    expect(deck.color, 'teal');
    expect(deck.inheritsColor, isFalse);
  });

  testWidgets('"Editar" in the deck menu changes the deck', (tester) async {
    final deck = await decks.create(
      project.id,
      const DeckInput(name: 'Verbos', color: 'pink'),
    );
    await openProject(tester);

    await tester.tap(find.byKey(Key('deckTile.${deck.id}.menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Editar'));
    await tester.pumpAndSettle();

    expect(find.text('Editar baraja'), findsOneWidget);
    final name = find.byKey(const Key('deckForm.name'));
    expect(tester.widget<TextField>(name).controller!.text, 'Verbos');

    await tester.enterText(name, 'Verbos irregulares');
    // Back to the project's colour.
    await tester.tap(find.byKey(const Key('deckForm.color.project')));
    await tester.tap(save);
    await tester.pumpAndSettle();

    final stored = (await decks.getById(deck.id))!;
    expect(stored.name, 'Verbos irregulares');
    expect(stored.inheritsColor, isTrue);
    expect(find.text('Verbos irregulares'), findsOneWidget);
  });

  testWidgets('cancelling does not create a deck', (tester) async {
    await openProject(tester);
    await openNewDeckForm(tester);
    await tester.enterText(find.byKey(const Key('deckForm.name')), 'Verbos');

    await tester.tap(find.byKey(const Key('deckForm.cancel')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('deckForm')), findsNothing);
    expect(await storedDecks(), isEmpty);
  });

  testWidgets('on desktop the form opens in a dialog', (tester) async {
    await openProject(tester, size: desktop);
    await openNewDeckForm(tester);

    expect(
      find.ancestor(
        of: find.byKey(const Key('deckForm')),
        matching: find.byType(Dialog),
      ),
      findsOneWidget,
    );
  });
}
