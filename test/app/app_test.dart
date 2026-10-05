import 'package:estudicards/app/app.dart';
import 'package:estudicards/app/theme/app_colors.dart';
import 'package:estudicards/app/theme/app_theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Paints a box with the current theme's background token.
class _ThemedBox extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) => ColoredBox(
    key: const Key('test.themedBox'),
    color: AppColors.of(context).background,
  );
}

Color boxColor(WidgetTester tester) =>
    tester.widget<ColoredBox>(find.byKey(const Key('test.themedBox'))).color;

Color scaffoldColor(WidgetTester tester) =>
    Theme.of(tester.element(find.byType(Scaffold).first))
        .scaffoldBackgroundColor;

void main() {
  testWidgets('a widget changes colours when the theme changes', (
    tester,
  ) async {
    Widget app(ThemeMode mode) => MaterialApp(
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: mode,
      home: const _ThemedBox(),
    );

    await tester.pumpWidget(app(ThemeMode.light));
    expect(boxColor(tester), AppColors.light.background);

    await tester.pumpWidget(app(ThemeMode.dark));
    await tester.pumpAndSettle(); // the theme change is animated
    expect(boxColor(tester), AppColors.dark.background);
  });

  testWidgets('the app follows the system theme by default', (tester) async {
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    await tester.pumpWidget(const EstudiCardsApp());
    expect(scaffoldColor(tester), AppColors.light.background);

    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    await tester.pumpAndSettle();
    expect(scaffoldColor(tester), AppColors.dark.background);
  });

  test('the Plus Jakarta Sans licence is registered', () async {
    registerFontLicenses();

    final packages = await LicenseRegistry.licenses
        .expand((license) => license.packages)
        .toList();
    expect(packages, contains('Plus Jakarta Sans'));
  });
}
