// T6.6: differences from the design (docs/design/) that were clearly bugs,
// each checked here so it does not come back.
import 'dart:io';

import 'package:estudicards/app/theme/app_colors.dart';
import 'package:estudicards/app/theme/dimensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fonts.dart';
import '../helpers/sample_screens.dart';
import '../helpers/test_app.dart';

SampleScreen _screen(String name) =>
    mainScreens.firstWhere((screen) => screen.name == name);

Finder _key(String key) => find.byKey(Key(key));

void main() {
  // Several checks depend on how wide the texts really are.
  setUpAll(loadAppFonts);

  for (final brightness in Brightness.values) {
    testWidgets('mobile: the top bar has the background colour, not the '
        "cards' (${brightness.name})", (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = brightness;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      await pumpSampleScreen(tester, _screen('settings'), size: mobile);

      final colors = brightness == Brightness.dark
          ? AppColors.dark
          : AppColors.light;
      final bar = tester.widget<Material>(
        find
            .descendant(
              of: find.byType(AppBar),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(bar.color, colors.background);
    });

    testWidgets("desktop: the session's top bar has the cards' colour "
        '(${brightness.name})', (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = brightness;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      await pumpSampleScreen(tester, _screen('study session'), size: desktop);

      final colors = brightness == Brightness.dark
          ? AppColors.dark
          : AppColors.light;
      final bar = tester.widget<DecoratedBox>(_key('session.topBar'));
      expect((bar.decoration as BoxDecoration).color, colors.surface);
    });
  }

  for (final (form, size) in [('mobile', mobile), ('desktop', desktop)]) {
    testWidgets('the caption of a statistics heading sits at its right '
        '($form)', (tester) async {
      await pumpSampleScreen(tester, _screen('project statistics'), size: size);

      final chart = find.ancestor(
        of: _key('answersChart'),
        matching: find.byType(Card),
      );
      final caption = find.descendant(
        of: chart,
        matching: find.text('tarjetas por día'),
      );
      expect(caption, findsOneWidget);
      expect(
        tester.getRect(caption).right,
        moreOrLessEquals(tester.getRect(chart).right - AppSpacing.lg),
      );
    });

    testWidgets('the options counter of the card editor sits at the right '
        '($form)', (tester) async {
      await pumpSampleScreen(tester, _screen('card editor'), size: size);

      final counter = find.text('3 de 6 · 2 correctas');
      final explanation = find.byKey(const Key('cardEditor.explanation'));
      expect(
        tester.getRect(counter).right,
        moreOrLessEquals(tester.getRect(explanation).right),
      );
    });

    testWidgets('the result tiles all have the same height ($form)', (
      tester,
    ) async {
      await pumpSampleScreen(tester, _screen('results'), size: size);

      final heights = {
        for (final key in [
          'results.correct',
          'results.wrong',
          'results.unanswered',
        ])
          tester.getSize(_key(key)).height,
      };
      expect(heights, hasLength(1));
    });
  }

  testWidgets('desktop dashboard: the goal and 7-day cards have a border', (
    tester,
  ) async {
    await pumpSampleScreen(tester, _screen('dashboard'), size: desktop);

    for (final key in ['dashboard.goal', 'dashboard.lastWeek']) {
      final card = tester.widget<Card>(_key(key));
      final shape =
          (card.shape ?? Theme.of(tester.element(_key(key))).cardTheme.shape)!
              as RoundedRectangleBorder;
      expect(shape.side.color, AppColors.light.border, reason: key);
    }
  });

  testWidgets('desktop project: "Estudiar" ends at the right edge', (
    tester,
  ) async {
    await pumpSampleScreen(tester, _screen('project'), size: desktop);

    // The content ends 40 px before the window's right edge.
    expect(
      tester.getRect(_key('projectScreen.study')).right,
      moreOrLessEquals(desktop.width - 40),
    );
  });

  testWidgets('desktop deck: "100%" fits on one line', (tester) async {
    await pumpSampleScreen(tester, _screen('deck'), size: desktop);

    expect(
      tester.getSize(find.text('100%')).height,
      tester.getSize(find.text('75%')).height,
    );
  });

  test('app_es.arb has no repeated key (the last one would win)', () {
    final keys = RegExp('^  "([^"@][^"]*)":', multiLine: true)
        .allMatches(File('lib/app/l10n/app_es.arb').readAsStringSync())
        .map((match) => match.group(1)!)
        .toList();
    final repeated = {
      for (final key in keys)
        if (keys.where((other) => other == key).length > 1) key,
    };
    expect(repeated, isEmpty);
  });
}
