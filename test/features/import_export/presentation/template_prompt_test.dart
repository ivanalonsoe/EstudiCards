import 'package:estudicards/app/router.dart';
import 'package:estudicards/app/theme/dimensions.dart';
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
import 'package:flutter/rendering.dart';
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

    testWidgets('"Prompt para IA" opens a window that starts on "A partir de '
        'datos" and copies the prompt in English ($size)', (tester) async {
      final copied = watchClipboard(tester);
      await openDeck(tester, size);

      await tapVisible(tester, _key('deckScreen.aiPrompt'));
      await tester.pumpAndSettle();

      final dialog = _key('aiPromptDialog');
      expect(
        find.descendant(of: dialog, matching: find.text('Prompt para IA')),
        findsOneWidget,
      );
      expect(find.text('A partir de datos'), findsOneWidget);
      expect(find.text('Con nueva información'), findsOneWidget);
      expect(_key('aiPromptDialog.fromDataHint'), findsOneWidget);
      expect(copied, isEmpty);

      await tester.tap(_key('aiPromptDialog.english'));
      await tester.pumpAndSettle();

      expect(dialog, findsNothing);
      expect(copied, [
        aiPrompt(
          mode: AiPromptMode.fromData,
          language: AiPromptLanguage.english,
          deckName: 'Verbos irregulares',
        ),
      ]);
      expect(
        find.text(
          'Prompt copiado. Pégalo en tu IA y cambia lo que va entre '
          'corchetes.',
        ),
        findsOneWidget,
      );
    });
  }

  testWidgets('"Con nueva información" explains its prompt and copies it in '
      'Spanish', (tester) async {
    final copied = watchClipboard(tester);
    await openDeck(tester, mobile);
    await tapVisible(tester, _key('deckScreen.aiPrompt'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Con nueva información'));
    await tester.pumpAndSettle();
    expect(_key('aiPromptDialog.newContentHint'), findsOneWidget);
    expect(_key('aiPromptDialog.fromDataHint'), findsNothing);

    await tester.tap(_key('aiPromptDialog.spanish'));
    await tester.pumpAndSettle();

    expect(copied, [
      aiPrompt(
        mode: AiPromptMode.newContent,
        language: AiPromptLanguage.spanish,
        deckName: 'Verbos irregulares',
      ),
    ]);
  });

  testWidgets('with text at 200% on a phone, no label of the window is cut', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await openDeck(tester, mobile);
    await tapVisible(tester, _key('deckScreen.aiPrompt'));
    await tester.pumpAndSettle();

    for (final label in ['A partir de datos', 'Con nueva información']) {
      final paragraph = tester.renderObject<RenderParagraph>(find.text(label));
      expect(paragraph.didExceedMaxLines, isFalse, reason: label);
    }
  });

  testWidgets('on a phone the window leaves 16 px at each side, and the '
      'export buttons, one above the other, have space between them', (
    tester,
  ) async {
    await openDeck(tester, mobile);
    await tapVisible(tester, _key('deckScreen.aiPrompt'));
    await tester.pumpAndSettle();

    final box = find
        .descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(Material),
        )
        .first;
    expect(tester.getSize(box).width, mobile.width - 2 * AppSpacing.lg);

    final spanish = tester.getRect(_key('aiPromptDialog.spanish'));
    final english = tester.getRect(_key('aiPromptDialog.english'));
    final (upper, lower) = spanish.top < english.top
        ? (spanish, english)
        : (english, spanish);
    expect(lower.top - upper.bottom, greaterThanOrEqualTo(AppSpacing.sm));
  });

  testWidgets('on desktop the window is not wider than 480 px', (tester) async {
    await openDeck(tester, desktop);
    await tapVisible(tester, _key('deckScreen.aiPrompt'));
    await tester.pumpAndSettle();

    // The white box: the dialog's first Material.
    final box = find
        .descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(Material),
        )
        .first;
    expect(tester.getSize(box).width, lessThanOrEqualTo(480));
  });

  testWidgets('the prompt of a language deck has its languages', (
    tester,
  ) async {
    final copied = watchClipboard(tester);
    final languageDeck = await DecksRepository(DecksDao(db), FakeClock(_now))
        .create(
          project.id,
          const DeckInput(
            name: 'Vocabulary 01',
            type: DeckType.language,
            sourceLang: 'en-GB',
            targetLang: 'es-ES',
          ),
        );
    await pumpTestApp(
      tester,
      size: mobile,
      db: db,
      location: AppRoutes.deck(project.id, languageDeck.id),
    );
    await tapVisible(tester, _key('deckScreen.aiPrompt'));
    await tester.pumpAndSettle();

    await tester.tap(_key('aiPromptDialog.english'));
    await tester.pumpAndSettle();

    expect(copied, [
      aiPrompt(
        mode: AiPromptMode.fromData,
        language: AiPromptLanguage.english,
        deckName: 'Vocabulary 01',
        deckLanguages: (source: 'en-GB', target: 'es-ES'),
      ),
    ]);
  });

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
