// T6.6: the differences from the design (docs/design/) that the owner
// decided to follow (SPEC §13.2, assumption 68).
import 'dart:io';

import 'package:estudicards/app/shell/brand_logo.dart';
import 'package:estudicards/app/theme/app_colors.dart';
import 'package:estudicards/app/theme/app_theme.dart';
import 'package:estudicards/app/theme/ring_slider_thumb.dart';
import 'package:estudicards/core/widgets/pill_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fonts.dart';
import '../helpers/sample_screens.dart';
import '../helpers/test_app.dart';

SampleScreen _screen(String name) =>
    mainScreens.firstWhere((screen) => screen.name == name);

Finder _key(String key) => find.byKey(Key(key));

/// The widget whose key ends with [suffix], e.g. `.unarchive`.
Finder _keyEndingWith(String suffix) => find.byWidgetPredicate(
  (widget) =>
      widget.key is ValueKey<String> &&
      (widget.key! as ValueKey<String>).value.endsWith(suffix),
);

/// The font size of the root of a `Text` or `Text.rich` found by [finder].
double _fontSize(WidgetTester tester, Finder finder) => tester
    .widget<RichText>(
      find
          .descendant(
            of: finder,
            matching: find.byType(RichText),
            matchRoot: true,
          )
          .first,
    )
    .text
    .style!
    .fontSize!;

void main() {
  setUpAll(loadAppFonts);

  testWidgets('1. the back button is a "‹" chevron', (tester) async {
    await pumpSampleScreen(tester, _screen('settings'), size: mobile);

    expect(
      find.descendant(
        of: find.byType(BackButton),
        matching: find.byIcon(Icons.chevron_left_rounded),
      ),
      findsOneWidget,
    );
  });

  test('2. icons use their outlined versions, as the design', () {
    const filled = [
      'upload_rounded',
      'download_rounded',
      'play_arrow_rounded',
      'pause_rounded',
      'ios_share_rounded',
      'volume_up_rounded',
      'volume_off_rounded',
      'folder_open_rounded',
      'style_rounded',
      'copy_rounded',
      'bar_chart_rounded',
      'language_rounded',
      'balance_rounded',
      'schedule_rounded',
    ];
    final used = {
      for (final file in Directory('lib').listSync(recursive: true))
        if (file is File && file.path.endsWith('.dart'))
          for (final icon in filled)
            if (RegExp('Icons\\.$icon\\b').hasMatch(file.readAsStringSync()))
              '${file.path}: $icon',
    };
    expect(used, isEmpty);
  });

  test('sharing uses the usual share icon (three joined dots), easier to '
      'recognise than the iOS box with an arrow', () {
    final used = {
      for (final file in Directory('lib').listSync(recursive: true))
        if (file is File && file.path.endsWith('.dart'))
          if (RegExp(r'Icons\.ios_share').hasMatch(file.readAsStringSync()))
            file.path,
    };
    expect(used, isEmpty);
  });

  for (final (name, size) in [('project', desktop), ('deck', desktop)]) {
    testWidgets('the $name share button shows the share icon', (tester) async {
      await pumpSampleScreen(tester, _screen(name), size: size);

      expect(find.byIcon(Icons.share_outlined), findsOneWidget);
    });
  }

  for (final (name, form, size) in [
    ('settings', 'mobile', mobile),
    ('session setup', 'mobile', mobile),
    ('deck', 'desktop', desktop),
    ('card editor', 'desktop', desktop),
  ]) {
    testWidgets('3. $name ($form) chooses with the pill selector of the '
        'design', (tester) async {
      await pumpSampleScreen(tester, _screen(name), size: size);

      expect(find.byType(SegmentedButton<Object>), findsNothing);
      expect(
        find.byWidgetPredicate((widget) => widget is PillSelector),
        findsWidgets,
      );
    });
  }

  testWidgets('5. a short question is large, and still fits the card', (
    tester,
  ) async {
    await pumpSampleScreen(tester, _screen('study session'), size: mobile);

    final question = find.text('to bring', findRichText: true);
    expect(_fontSize(tester, question), greaterThanOrEqualTo(36));
    expect(
      tester.getSize(question).width,
      lessThanOrEqualTo(
        tester.getSize(find.byKey(const Key('studyCard'))).width,
      ),
    );
  });

  testWidgets('6. mobile results: "Repetir sesión" and "Volver" share a row', (
    tester,
  ) async {
    await pumpSampleScreen(tester, _screen('results'), size: mobile);

    expect(
      tester.getCenter(_key('results.repeatSession')).dy,
      tester.getCenter(_key('results.back')).dy,
    );
  });

  // The days left of the trash are longer than the archive date: they fit
  // on one row from about 395 px, as on most Android phones (412 px); on a
  // narrower phone they go on two lines (the design does not fit either).
  for (final (name, leading, action, size) in [
    ('archived', '.unarchive', '.unarchive', mobile),
    ('trash', '.daysLeft', '.restore', const Size(412, 915)),
  ]) {
    testWidgets('7. mobile $name: the date and the buttons fit on one row', (
      tester,
    ) async {
      await pumpSampleScreen(tester, _screen(name), size: size);

      final button = _keyEndingWith(action);
      final label = name == 'archived'
          ? find.textContaining('Archivado el')
          : _keyEndingWith(leading);
      expect(
        tester.getCenter(label).dy,
        moreOrLessEquals(tester.getCenter(button).dy, epsilon: 1),
      );
    });
  }

  testWidgets('8. dialog titles are 17 points', (tester) async {
    await pumpSampleScreen(tester, _screen('study session'), size: mobile);
    await tester.tap(_key('session.exit').first);
    await tester.pumpAndSettle();

    expect(_fontSize(tester, find.text('¿Salir de la sesión?')), 17);
  });

  group('9. details', () {
    testWidgets('the logo is as large as in the design', (tester) async {
      await pumpSampleScreen(tester, _screen('dashboard'), size: mobile);
      expect(tester.getSize(find.byType(BrandLogo)).height, 32);

      await pumpSampleScreen(tester, _screen('dashboard'), size: desktop);
      expect(tester.getSize(find.byType(BrandLogo).first).height, 36);
    });

    testWidgets('the desktop project header has boxed icon buttons', (
      tester,
    ) async {
      await pumpSampleScreen(tester, _screen('project'), size: desktop);

      final button = find.descendant(
        of: _key('projectScreen.importDeck'),
        matching: find.byType(Material),
      );
      final shape = tester.widget<Material>(button.first).shape;
      expect(shape, isA<OutlinedBorder>());
      expect((shape! as OutlinedBorder).side, isNot(BorderSide.none));
    });

    testWidgets('the desktop deck search shows its whole hint', (tester) async {
      await pumpSampleScreen(tester, _screen('deck'), size: desktop);

      expect(
        tester.getSize(_key('deckScreen.search')).width,
        greaterThanOrEqualTo(320),
      );
    });

    test("a focused field turns white (the cards' colour)", () {
      for (final (theme, colors) in [
        (AppTheme.light(), AppColors.light),
        (AppTheme.dark(), AppColors.dark),
      ]) {
        final fill = theme.inputDecorationTheme.fillColor;
        expect(
          WidgetStateProperty.resolveAs(fill, {WidgetState.focused}),
          colors.surface,
        );
        expect(WidgetStateProperty.resolveAs(fill, {}), colors.surfaceVariant);
      }
    });

    test('a switch that is off is a grey track with a white thumb', () {
      final theme = AppTheme.light();
      const colors = AppColors.light;
      final switches = theme.switchTheme;
      expect(switches.trackColor!.resolve({}), colors.border);
      expect(switches.thumbColor!.resolve({}), colors.surface);
      expect(switches.trackOutlineColor!.resolve({}), Colors.transparent);
    });

    test('the slider thumb is white with an orange ring', () {
      final theme = AppTheme.light();
      expect(theme.sliderTheme.thumbShape, isA<RingSliderThumbShape>());
    });

    testWidgets('the form sheet title sits close to its handle', (
      tester,
    ) async {
      await pumpSampleScreen(tester, _screen('dashboard'), size: mobile);
      await tester.tap(_key('dashboard.newProject'));
      await tester.pumpAndSettle();

      final sheetTop = tester.getRect(find.byType(BottomSheet)).top;
      expect(
        tester.getRect(find.text('Nuevo proyecto').last).top - sheetTop,
        lessThanOrEqualTo(48),
      );
    });
  });
}
