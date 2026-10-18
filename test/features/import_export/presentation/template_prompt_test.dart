import 'package:estudicards/app/router.dart';
import 'package:estudicards/core/clock.dart';
import 'package:estudicards/core/db/app_database.dart';
import 'package:estudicards/features/decks/data/decks_dao.dart';
import 'package:estudicards/features/decks/data/decks_repository.dart';
import 'package:estudicards/features/decks/domain/deck.dart';
import 'package:estudicards/features/decks/domain/deck_input.dart';
import 'package:estudicards/features/import_export/domain/csv_template.dart';
import 'package:estudicards/features/projects/data/projects_dao.dart';
import 'package:estudicards/features/projects/data/projects_repository.dart';
import 'package:estudicards/features/projects/domain/project.dart';
import 'package:estudicards/features/projects/domain/project_input.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  });

  Future<FakeFileExporter> openDeck(WidgetTester tester, Size size) async {
    final exporter = FakeFileExporter();
    await pumpTestApp(
      tester,
      size: size,
      db: db,
      location: AppRoutes.deck(project.id, deck.id),
      fileExporter: exporter,
    );
    return exporter;
  }

  /// Records what the app copies to the clipboard.
  List<String> watchClipboard(WidgetTester tester) {
    final copied = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied.add((call.arguments as Map)['text'] as String);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    return copied;
  }

  for (final size in [mobile, desktop]) {
    testWidgets('"Plantilla" saves the template ($size)', (tester) async {
      final exporter = await openDeck(tester, size);

      await tapVisible(tester, _key('deckScreen.template'));
      await tester.pumpAndSettle();

      final file = exporter.exported.single;
      expect(file.name, 'estudicards_template.csv');
      expect(file.mimeType, 'text/csv');
      expect(file.bytes, csvTemplate());
    });

    testWidgets('"Prompt para IA" copies the prompt ($size)', (tester) async {
      final copied = watchClipboard(tester);
      await openDeck(tester, size);

      await tapVisible(tester, _key('deckScreen.aiPrompt'));
      await tester.pumpAndSettle();

      expect(copied, [aiPrompt]);
      expect(
        find.text(
          'Prompt copiado. Pégalo en tu IA y cambia lo que va entre '
          'corchetes.',
        ),
        findsOneWidget,
      );
    });
  }

  testWidgets('an empty deck offers "Descargar plantilla" (SPEC §5.3)', (
    tester,
  ) async {
    final exporter = await openDeck(tester, mobile);

    expect(find.text('Descargar plantilla'), findsOneWidget);
    await tapVisible(tester, _key('deckScreen.emptyTemplate'));
    await tester.pumpAndSettle();

    expect(exporter.exported.single.name, csvTemplateFileName);
  });
}
