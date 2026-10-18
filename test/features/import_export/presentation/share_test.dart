import 'package:estudicards/app/router.dart';
import 'package:estudicards/core/clock.dart';
import 'package:estudicards/core/db/app_database.dart';
import 'package:estudicards/core/files/image_files.dart';
import 'package:estudicards/features/cards/data/cards_dao.dart';
import 'package:estudicards/features/cards/data/cards_repository.dart';
import 'package:estudicards/features/cards/domain/card_input.dart';
import 'package:estudicards/features/cards/domain/flashcard.dart';
import 'package:estudicards/features/decks/data/decks_dao.dart';
import 'package:estudicards/features/decks/data/decks_repository.dart';
import 'package:estudicards/features/decks/domain/deck.dart';
import 'package:estudicards/features/decks/domain/deck_input.dart';
import 'package:estudicards/features/import_export/domain/cards_csv.dart';
import 'package:estudicards/features/import_export/domain/exchange_document.dart';
import 'package:estudicards/features/import_export/domain/exchange_json.dart';
import 'package:estudicards/features/projects/data/projects_dao.dart';
import 'package:estudicards/features/projects/data/projects_repository.dart';
import 'package:estudicards/features/projects/domain/project.dart';
import 'package:estudicards/features/projects/domain/project_input.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_file_exporter.dart';
import '../../../helpers/test_app.dart';
import '../../cards/presentation/card_editor_finders.dart';

final _now = DateTime.utc(2026, 10, 6, 12);

Finder _key(String key) => find.byKey(Key(key));

void main() {
  late AppDatabase db;
  late Project project;
  late Deck deck;

  setUp(() async {
    db = createTestDatabase();
    final clock = FakeClock(_now);
    project = await ProjectsRepository(ProjectsDao(db), clock).create(
      const ProjectInput(name: 'Inglés B2', color: 'blue', icon: 'globe'),
    );
    deck = await DecksRepository(
      DecksDao(db),
      clock,
    ).create(project.id, const DeckInput(name: 'Verbos irregulares'));
    await CardsRepository(CardsDao(db), clock, const NoImageFiles()).create(
      deck.id,
      const CardInput(
        type: CardType.simple,
        question: 'to bring',
        answer: 'traer',
      ),
    );
  });

  Future<FakeFileExporter> open(
    WidgetTester tester, {
    required String location,
    Size size = mobile,
    FakeFileExporter? exporter,
  }) async {
    final fake = exporter ?? FakeFileExporter();
    await pumpTestApp(
      tester,
      size: size,
      db: db,
      location: location,
      fileExporter: fake,
    );
    return fake;
  }

  Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
    await tapVisible(tester, finder);
    await tester.pumpAndSettle();
  }

  testWidgets('a project is shared as JSON by default, with no statistics', (
    tester,
  ) async {
    final exporter = await open(
      tester,
      location: AppRoutes.project(project.id),
    );

    await tapAndSettle(tester, _key('projectScreen.share'));

    expect(find.text('Compartir «Inglés B2»'), findsOneWidget);
    expect(
      find.text('No incluye tus estadísticas, solo preguntas y respuestas.'),
      findsOneWidget,
    );
    expect(find.text('Para abrir en EstudiCards'), findsOneWidget);
    expect(find.text('Para Excel o Google Sheets'), findsOneWidget);
    await tapAndSettle(tester, _key('shareDialog.confirm'));

    final file = exporter.exported.single;
    expect(file.name, 'Inglés B2.json');
    expect(file.mimeType, 'application/json');
    final document = decodeExchange(file.bytes) as ProjectDocument;
    expect(document.project.decks.single.cards.single.question, 'to bring');
    expect(_key('shareDialog'), findsNothing);
  });

  testWidgets('a deck is shared as CSV, with ";" and a BOM', (tester) async {
    final exporter = await open(
      tester,
      location: AppRoutes.deck(project.id, deck.id),
    );

    await tapAndSettle(tester, _key('deckScreen.menu'));
    await tapAndSettle(tester, _key('deckScreen.share'));
    expect(find.text('Compartir «Verbos irregulares»'), findsOneWidget);
    await tapAndSettle(tester, _key('shareDialog.csv'));
    await tapAndSettle(tester, _key('shareDialog.confirm'));

    final file = exporter.exported.single;
    expect(file.name, 'Inglés B2-Verbos irregulares.csv');
    expect(file.mimeType, 'text/csv');
    expect(file.bytes.sublist(0, 3), [0xEF, 0xBB, 0xBF]);
    final csv = parseCardsCsv(file.bytes);
    expect(csv.separator, ';');
    expect(csv.cards.single.input.answer, 'traer');
  });

  testWidgets('"Cancelar" shares nothing', (tester) async {
    final exporter = await open(
      tester,
      location: AppRoutes.project(project.id),
    );

    await tapAndSettle(tester, _key('projectScreen.share'));
    await tapAndSettle(tester, _key('shareDialog.cancel'));

    expect(exporter.exported, isEmpty);
  });

  testWidgets('on desktop it says where the file was saved', (tester) async {
    await open(
      tester,
      size: desktop,
      location: AppRoutes.deck(project.id, deck.id),
      exporter: FakeFileExporter(
        savesToDisk: true,
        savedPath: r'C:\Users\ana\Documents\Inglés B2-Verbos irregulares.json',
      ),
    );

    await tapAndSettle(tester, _key('deckScreen.share'));
    await tapAndSettle(tester, _key('shareDialog.confirm'));

    expect(
      find.text(
        r'Guardado en C:\Users\ana\Documents\Inglés B2-Verbos irregulares.json',
      ),
      findsOneWidget,
    );
  });

  group('where it opens from', () {
    Future<void> expectDialog(
      WidgetTester tester, {
      required Size size,
      required String location,
      required List<String> taps,
    }) async {
      await open(tester, size: size, location: location);
      for (final key in taps) {
        await tapAndSettle(tester, _key(key));
      }
      expect(_key('shareDialog'), findsOneWidget);
    }

    testWidgets('the ⋮ menu of a dashboard project', (tester) async {
      await expectDialog(
        tester,
        size: mobile,
        location: AppRoutes.home,
        taps: ['projectCard.${project.id}.menu', 'projectCard.share'],
      );
    });

    testWidgets('the project header on desktop', (tester) async {
      await expectDialog(
        tester,
        size: desktop,
        location: AppRoutes.project(project.id),
        taps: ['projectScreen.share'],
      );
    });

    testWidgets('the ⋮ menu of a deck in its project', (tester) async {
      await expectDialog(
        tester,
        size: mobile,
        location: AppRoutes.project(project.id),
        taps: ['deckTile.${deck.id}.menu', 'deckTile.share'],
      );
    });
  });
}
