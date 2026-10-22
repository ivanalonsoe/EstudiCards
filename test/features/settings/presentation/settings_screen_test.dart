import 'package:estudicards/app/router.dart';
import 'package:estudicards/core/clock.dart';
import 'package:estudicards/core/db/app_database.dart';
import 'package:estudicards/features/decks/data/decks_dao.dart';
import 'package:estudicards/features/decks/data/decks_repository.dart';
import 'package:estudicards/features/decks/domain/deck.dart';
import 'package:estudicards/features/decks/domain/deck_input.dart';
import 'package:estudicards/features/projects/data/projects_dao.dart';
import 'package:estudicards/features/projects/data/projects_repository.dart';
import 'package:estudicards/features/projects/domain/project_input.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_voice.dart';
import '../../../helpers/test_app.dart';
import '../../cards/presentation/card_editor_finders.dart';

Finder _key(String key) => find.byKey(Key(key));

/// The brightness of the theme the screens are drawn with.
Brightness _brightness(WidgetTester tester) =>
    Theme.of(tester.element(find.byType(Scaffold).first)).brightness;

void main() {
  late AppDatabase db;

  setUp(() => db = createTestDatabase());

  Future<void> openSettings(
    WidgetTester tester, {
    Size size = mobile,
    FakeVoice? voice,
  }) => pumpTestApp(
    tester,
    size: size,
    db: db,
    voice: voice,
    location: AppRoutes.settings,
  ).then((_) {});

  Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
    await tapVisible(tester, finder);
    await tester.pumpAndSettle();
  }

  Future<Map<String, String?>> stored() async => {
    for (final row in await db.select(db.settings).get()) row.key: row.value,
  };

  group('theme', () {
    testWidgets('follows the system until "Claro" or "Oscuro" is chosen', (
      tester,
    ) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      await openSettings(tester);

      expect(_brightness(tester), Brightness.light);

      await tapAndSettle(tester, _key('settings.theme.dark'));
      expect(_brightness(tester), Brightness.dark);
      expect((await stored())['theme_mode'], 'dark');

      await tapAndSettle(tester, _key('settings.theme.light'));
      expect(_brightness(tester), Brightness.light);

      // "Sistema" follows the device again.
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      await tapAndSettle(tester, _key('settings.theme.system'));
      expect(_brightness(tester), Brightness.dark);
      expect((await stored())['theme_mode'], 'system');
    });
  });

  group('card text size', () {
    testWidgets('starts at 100% and the slider goes up to 160%', (
      tester,
    ) async {
      await openSettings(tester);

      expect(find.text('Texto de las tarjetas'), findsOneWidget);
      expect(find.text('100%'), findsOneWidget);

      await tester.ensureVisible(_key('settings.cardTextScale'));
      await tester.drag(_key('settings.cardTextScale'), const Offset(800, 0));
      await tester.pumpAndSettle();

      expect(find.text('160%'), findsOneWidget);
      expect((await stored())['card_text_scale'], '1.6');
    });

    testWidgets('does not change the text of the rest of the app', (
      tester,
    ) async {
      await openSettings(tester);
      final before = tester.getSize(find.text('Texto de las tarjetas'));

      await tester.ensureVisible(_key('settings.cardTextScale'));
      await tester.drag(_key('settings.cardTextScale'), const Offset(800, 0));
      await tester.pumpAndSettle();

      expect(tester.getSize(find.text('Texto de las tarjetas')), before);
    });
  });

  group('daily goal', () {
    testWidgets('is on at 20 cards by default, and "+" and "−" change it by '
        '5', (tester) async {
      await openSettings(tester);

      expect(tester.widget<Switch>(_key('settings.dailyGoal')).value, isTrue);
      expect(find.text('Tarjetas al día'), findsOneWidget);
      expect(tester.widget<Text>(_key('settings.dailyGoal.value')).data, '20');

      await tapAndSettle(tester, _key('settings.dailyGoal.increase'));
      expect(tester.widget<Text>(_key('settings.dailyGoal.value')).data, '25');
      await tapAndSettle(tester, _key('settings.dailyGoal.decrease'));
      await tapAndSettle(tester, _key('settings.dailyGoal.decrease'));
      expect((await stored())['daily_goal'], '15');
    });

    testWidgets('turning it off stores the key with no value; turning it on '
        'again starts at 20', (tester) async {
      await openSettings(tester);

      await tapAndSettle(tester, _key('settings.dailyGoal'));
      expect(_key('settings.dailyGoal.value'), findsNothing);
      expect(await stored(), containsPair('daily_goal', null));

      await tapAndSettle(tester, _key('settings.dailyGoal'));
      expect(tester.widget<Text>(_key('settings.dailyGoal.value')).data, '20');
      expect((await stored())['daily_goal'], '20');
    });
  });

  group('voices', () {
    Future<void> addLanguageDecks() async {
      final clock = FakeClock(DateTime.utc(2026, 10, 6));
      final project = await ProjectsRepository(ProjectsDao(db), clock).create(
        const ProjectInput(name: 'Idiomas', color: 'blue', icon: 'globe'),
      );
      final decks = DecksRepository(DecksDao(db), clock);
      for (final source in ['en-GB', 'de-DE']) {
        await decks.create(
          project.id,
          DeckInput(
            name: source,
            type: DeckType.language,
            sourceLang: source,
            targetLang: 'es-ES',
          ),
        );
      }
    }

    testWidgets('says, for each language of the decks, whether the system '
        'has a voice', (tester) async {
      await addLanguageDecks();
      await openSettings(tester, voice: FakeVoice(missing: {'de-DE'}));

      Finder inRow(String code, String text) => find.descendant(
        of: _key('settings.voice.$code'),
        matching: find.text(text),
      );
      expect(inRow('en-GB', 'Inglés (R. U.)'), findsOneWidget);
      expect(inRow('en-GB', 'Instalada'), findsOneWidget);
      expect(inRow('es-ES', 'Instalada'), findsOneWidget);
      expect(inRow('de-DE', 'Alemán'), findsOneWidget);
      expect(inRow('de-DE', 'No instalada'), findsOneWidget);
      // With an icon too, not just colour.
      expect(
        find.descendant(
          of: _key('settings.voice.en-GB'),
          matching: find.byIcon(Icons.check_rounded),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: _key('settings.voice.de-DE'),
          matching: find.byIcon(Icons.error_outline_rounded),
        ),
        findsOneWidget,
      );
      // Only a missing voice offers the steps.
      expect(_key('settings.voice.en-GB.howTo'), findsNothing);
      expect(_key('settings.voice.de-DE.howTo'), findsOneWidget);
    });

    testWidgets(
      '"Cómo instalarla" explains the steps for this system',
      (tester) async {
        await addLanguageDecks();
        await openSettings(tester, voice: FakeVoice(missing: {'de-DE'}));

        await tapAndSettle(tester, _key('settings.voice.de-DE.howTo'));

        expect(find.text('No hay voz para Alemán'), findsOneWidget);
        expect(
          find.textContaining(switch (defaultTargetPlatform) {
            TargetPlatform.windows => 'Configuración › Hora e idioma › Voz',
            _ => 'Salida de texto a voz',
          }),
          findsOneWidget,
        );
      },
      // Runs once as if on Windows and once as if on Android.
      variant: const TargetPlatformVariant({
        TargetPlatform.windows,
        TargetPlatform.android,
      }),
    );

    testWidgets('without language decks, says that nothing needs a voice', (
      tester,
    ) async {
      await openSettings(tester);

      expect(_key('settings.voices.none'), findsOneWidget);
    });
  });

  testWidgets('the settings persist after restarting the app', (tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await openSettings(tester);
    await tapAndSettle(tester, _key('settings.theme.dark'));
    await tester.ensureVisible(_key('settings.cardTextScale'));
    await tester.drag(_key('settings.cardTextScale'), const Offset(800, 0));
    await tester.pumpAndSettle();
    await tapAndSettle(tester, _key('settings.dailyGoal'));

    // Close the app and start it again on the same database.
    await tester.pumpWidget(const SizedBox());
    await openSettings(tester);

    expect(_brightness(tester), Brightness.dark);
    expect(find.text('160%'), findsOneWidget);
    // Turned off, the goal stays off: it does not go back to 20.
    expect(tester.widget<Switch>(_key('settings.dailyGoal')).value, isFalse);
    expect(_key('settings.dailyGoal.value'), findsNothing);
  });
}
