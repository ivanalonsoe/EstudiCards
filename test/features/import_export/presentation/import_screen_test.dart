import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:estudicards/app/router.dart';
import 'package:estudicards/core/clock.dart';
import 'package:estudicards/core/db/app_database.dart';
import 'package:estudicards/core/files/document_picker.dart';
import 'package:estudicards/core/files/image_files.dart';
import 'package:estudicards/features/cards/data/cards_dao.dart';
import 'package:estudicards/features/cards/data/cards_repository.dart';
import 'package:estudicards/features/cards/domain/card_input.dart';
import 'package:estudicards/features/cards/domain/flashcard.dart';
import 'package:estudicards/features/decks/data/decks_dao.dart';
import 'package:estudicards/features/decks/data/decks_repository.dart';
import 'package:estudicards/features/decks/domain/deck.dart';
import 'package:estudicards/features/decks/domain/deck_input.dart';
import 'package:estudicards/features/import_export/domain/exchange_document.dart';
import 'package:estudicards/features/import_export/domain/exchange_json.dart';
import 'package:estudicards/features/projects/data/projects_dao.dart';
import 'package:estudicards/features/projects/data/projects_repository.dart';
import 'package:estudicards/features/projects/domain/project.dart';
import 'package:estudicards/features/projects/domain/project_input.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../helpers/fake_document_picker.dart';
import '../../../helpers/test_app.dart';
import '../../cards/presentation/card_editor_finders.dart';

final _now = DateTime.utc(2026, 10, 6, 12);

Finder _key(String key) => find.byKey(Key(key));

/// A text anywhere, also inside a `Text.rich` with bold parts.
Finder _text(String text) => find.textContaining(text, findRichText: true);

String _location(GoRouter router) =>
    router.routerDelegate.currentConfiguration.uri.toString();

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
  });

  Future<void> addCards(Map<String, String> cards) async {
    final repository = CardsRepository(
      CardsDao(db),
      FakeClock(_now),
      const NoImageFiles(),
    );
    for (final MapEntry(key: question, value: answer) in cards.entries) {
      await repository.create(
        deck.id,
        CardInput(type: CardType.simple, question: question, answer: answer),
      );
    }
  }

  Future<List<CardRow>> cardsOf(String deckId) =>
      (db.select(db.cards)..where((c) => c.deckId.equals(deckId))).get();

  Future<GoRouter> openImport(
    WidgetTester tester, {
    required String location,
    PickedDocument? file,
    Size size = mobile,
  }) => pumpTestApp(
    tester,
    size: size,
    db: db,
    location: location,
    documentPicker: FakeDocumentPicker(file),
  );

  Future<void> chooseFile(WidgetTester tester) async {
    await tapVisible(tester, _key('import.chooseFile'));
    await tester.pumpAndSettle();
  }

  Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
    await tapVisible(tester, finder);
    await tester.pumpAndSettle();
  }

  Future<void> chooseLanguage(
    WidgetTester tester,
    String field,
    String name,
  ) async {
    await tapVisible(tester, _key(field));
    await tester.pumpAndSettle();
    await tester.tap(find.text(name).last);
    await tester.pumpAndSettle();
  }

  testWidgets('the preview shows "42 nuevas · 3 duplicadas · 1 con errores" '
      'for the matching fixture', (tester) async {
    await addCards({
      'to bring': 'traer (brought, brought)',
      'to seek': 'buscar (sought, sought)',
      'to lend': 'prestar (lent, lent)',
    });
    await openImport(
      tester,
      location: AppRoutes.importCards(projectId: project.id, deckId: deck.id),
      file: pickedFixture('verbos_ia.csv'),
    );

    await chooseFile(tester);

    // Adding to a deck has nothing to choose: straight to the review.
    expect(_text('verbos_ia.csv'), findsOneWidget);
    expect(_text('46 filas → añadir a Verbos irregulares'), findsOneWidget);
    expect(
      find.descendant(of: _key('import.new'), matching: find.text('42')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: _key('import.duplicates'), matching: find.text('3')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: _key('import.errors'), matching: find.text('1')),
      findsOneWidget,
    );
    expect(_text('Fila 7: falta la respuesta. Se omitirá.'), findsOneWidget);
    expect(_text('Fila 3: «to bring» ya existe en la baraja.'), findsOneWidget);
    expect(_text('Fila 18: «To Seek» ya existe en la baraja.'), findsOne);
    // The list only builds what is on screen.
    await tester.dragUntilVisible(
      _text('to arise'),
      _key('import.list'),
      const Offset(0, -300),
    );
    expect(_text('to arise'), findsOneWidget);
    expect(find.text('Importar 42 tarjetas'), findsOneWidget);

    await tapAndSettle(tester, _key('import.confirm'));

    expect(_key('screen.deck'), findsOneWidget);
    expect(
      find.text('42 añadidas, 3 omitidas por duplicadas, 1 con errores'),
      findsOneWidget,
    );
    expect(await cardsOf(deck.id), hasLength(45));
  });

  testWidgets('a CSV as a new project asks for the type once', (tester) async {
    final router = await openImport(
      tester,
      location: AppRoutes.importCards(),
      file: pickedFixture('google_sheets.csv'),
    );

    await chooseFile(tester);

    final name = tester.widget<TextField>(_key('import.name'));
    expect(name.controller!.text, 'google_sheets');
    // One type for every deck the "deck" column creates.
    expect(_key('import.type.language'), findsOneWidget);
    await tapAndSettle(tester, _key('import.type.language'));
    expect(
      tester.widget<FilledButton>(_key('import.continue')).onPressed,
      isNull,
    );
    await chooseLanguage(tester, 'import.sourceLang', 'Inglés (R. U.)');
    await chooseLanguage(tester, 'import.targetLang', 'Español');
    await tester.enterText(_key('import.name'), 'Vocabulario');
    await tapAndSettle(tester, _key('import.continue'));

    expect(_text('nuevo proyecto Vocabulario'), findsOneWidget);
    expect(find.text('Importar 3 tarjetas'), findsOneWidget);
    await tapAndSettle(tester, _key('import.confirm'));

    final created = await (db.select(
      db.projects,
    )..where((p) => p.name.equals('Vocabulario'))).getSingle();
    expect(_location(router), AppRoutes.project(created.id));
    final decks = await (db.select(
      db.decks,
    )..where((d) => d.projectId.equals(created.id))).get();
    expect(
      {for (final d in decks) d.name: (d.type, d.sourceLang, d.targetLang)},
      {
        'Verbos': ('language', 'en-GB', 'es-ES'),
        'Adjetivos': ('language', 'en-GB', 'es-ES'),
      },
    );
    expect(find.text('3 añadidas'), findsOneWidget);
  });

  testWidgets('a JSON deck as a new deck keeps its own type', (tester) async {
    final file = encodeExchange(
      DeckDocument(
        exportedAt: _now,
        appVersion: '1.0.0',
        deck: const ExchangeDeck(
          id: 'd',
          name: 'Phrasal verbs',
          type: DeckType.language,
          sourceLang: 'en-GB',
          targetLang: 'es-ES',
          cards: [
            ExchangeCard(
              id: 'c',
              type: CardType.simple,
              question: 'to give up',
              answer: 'rendirse',
            ),
          ],
        ),
      ),
    );
    final router = await openImport(
      tester,
      location: AppRoutes.importCards(projectId: project.id),
      file: pickedBytes('phrasal.json', file),
    );

    await chooseFile(tester);

    final name = tester.widget<TextField>(_key('import.name'));
    expect(name.controller!.text, 'Phrasal verbs');
    expect(_key('import.type.general'), findsNothing);
    expect(
      find.text('Cada baraja conserva el tipo y los idiomas del fichero.'),
      findsOneWidget,
    );
    await tapAndSettle(tester, _key('import.continue'));
    await tapAndSettle(tester, _key('import.confirm'));

    final created = await (db.select(
      db.decks,
    )..where((d) => d.name.equals('Phrasal verbs'))).getSingle();
    expect(created.type, 'language');
    expect(created.projectId, project.id);
    expect(_location(router), AppRoutes.deck(project.id, created.id));
    expect(await cardsOf(created.id), hasLength(1));
  });

  group('a file that cannot be imported shows why and stays on step 1', () {
    final cases = <String, (PickedDocument, String)>{
      'another type': (
        pickedBytes('notas.txt', utf8.encode('hola')),
        'Solo se pueden importar ficheros .csv o .json.',
      ),
      'too large, without reading it': (
        PickedDocument(
          name: 'enorme.csv',
          size: 6 * 1024 * 1024,
          read: () => throw StateError('must not be read'),
        ),
        'El fichero es demasiado grande (máximo 5 MB).',
      ),
      'not JSON': (
        pickedBytes('roto.json', utf8.encode('{nope')),
        'El fichero no es un JSON válido.',
      ),
      'a backup': (
        pickedBytes(
          'copia.json',
          encodeExchange(BackupDocument(exportedAt: _now, appVersion: '1')),
        ),
        'Es una copia de seguridad: restáurala desde Ajustes.',
      ),
      'a CSV without "question"': (
        pickedFixture('missing_question_column.csv'),
        'La primera fila debe tener una columna «question».',
      ),
      'a project into a deck': (
        pickedBytes(
          'p.json',
          encodeExchange(
            ProjectDocument(
              exportedAt: _now,
              appVersion: '1.0.0',
              project: const ExchangeProject(
                id: 'p',
                name: 'P',
                color: 'orange',
                icon: 'book',
              ),
            ),
          ),
        ),
        'Este fichero es un proyecto entero: impórtalo desde el inicio.',
      ),
    };
    for (final MapEntry(key: name, value: (file, message)) in cases.entries) {
      testWidgets(name, (tester) async {
        await openImport(
          tester,
          location: AppRoutes.importCards(
            projectId: project.id,
            deckId: deck.id,
          ),
          file: file,
        );

        await chooseFile(tester);

        expect(
          find.descendant(
            of: _key('import.error'),
            matching: find.text(message),
          ),
          findsOneWidget,
        );
        expect(_key('import.chooseFile'), findsOneWidget);
      });
    }
  });

  testWidgets('cancelling the picker changes nothing; ✕ goes back', (
    tester,
  ) async {
    final router = await openImport(
      tester,
      location: AppRoutes.importCards(projectId: project.id, deckId: deck.id),
    );

    await chooseFile(tester);
    expect(_key('import.chooseFile'), findsOneWidget);
    expect(_key('import.error'), findsNothing);

    await tapAndSettle(tester, _key('import.close'));
    expect(_location(router), AppRoutes.deck(project.id, deck.id));
  });

  testWidgets('works on desktop too', (tester) async {
    await openImport(
      tester,
      size: desktop,
      location: AppRoutes.importCards(projectId: project.id, deckId: deck.id),
      file: pickedFixture('excel_es.csv'),
    );

    await chooseFile(tester);
    await tapAndSettle(tester, _key('import.confirm'));

    expect(await cardsOf(deck.id), hasLength(5));
  });

  group('where it opens from', () {
    Future<String> openFrom(
      WidgetTester tester, {
      required Size size,
      required String location,
      required List<String> taps,
    }) async {
      final router = await openImport(tester, size: size, location: location);
      for (final key in taps) {
        // The drawer's button has no key: Flutter adds it with this tooltip.
        await tapAndSettle(
          tester,
          key == 'menu'
              ? find.byTooltip('Abrir el menú de navegación')
              : _key(key),
        );
      }
      return _location(router);
    }

    testWidgets('the dashboard imports a new project', (tester) async {
      expect(
        await openFrom(
          tester,
          size: desktop,
          location: AppRoutes.home,
          taps: ['dashboard.import'],
        ),
        AppRoutes.importCards(),
      );
    });

    testWidgets('the mobile menu imports a new project', (tester) async {
      expect(
        await openFrom(
          tester,
          size: mobile,
          location: AppRoutes.home,
          taps: ['menu', 'nav.import'],
        ),
        AppRoutes.importCards(),
      );
    });

    testWidgets('the empty dashboard offers "Importar un proyecto"', (
      tester,
    ) async {
      await db.delete(db.projects).go();
      expect(
        await openFrom(
          tester,
          size: mobile,
          location: AppRoutes.home,
          taps: ['dashboard.importEmpty'],
        ),
        AppRoutes.importCards(),
      );
    });

    for (final (size, taps) in [
      (mobile, ['projectScreen.menu', 'projectScreen.importDeck']),
      (desktop, ['projectScreen.importDeck']),
    ]) {
      testWidgets('a project imports a new deck ($size)', (tester) async {
        expect(
          await openFrom(
            tester,
            size: size,
            location: AppRoutes.project(project.id),
            taps: taps,
          ),
          AppRoutes.importCards(projectId: project.id),
        );
      });
    }

    for (final (size, key) in [
      (mobile, 'deckScreen.import'),
      (desktop, 'deckScreen.import'),
      (mobile, 'deckScreen.emptyImport'),
    ]) {
      testWidgets('a deck imports into itself ($key, $size)', (tester) async {
        expect(
          await openFrom(
            tester,
            size: size,
            location: AppRoutes.deck(project.id, deck.id),
            taps: [key],
          ),
          AppRoutes.importCards(projectId: project.id, deckId: deck.id),
        );
      });
    }
  });

  test('a picked file can be built from bytes', () {
    expect(pickedBytes('a.csv', Uint8List(3)).size, 3);
  });
}
