import 'package:estudicards/app/l10n/generated/app_localizations.dart';
import 'package:estudicards/app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Shows [child] alone, with the app's theme and Spanish strings, for
/// tests of a single component (the whole app is `pumpTestApp`).
Future<void> pumpComponent(
  WidgetTester tester,
  Widget child, {
  Brightness brightness = Brightness.light,
}) => tester.pumpWidget(
  MaterialApp(
    locale: const Locale('es'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: brightness == Brightness.dark ? AppTheme.dark() : AppTheme.light(),
    home: Scaffold(
      body: Center(child: SizedBox(width: 340, height: 520, child: child)),
    ),
  ),
);
