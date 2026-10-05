import 'package:estudicards/app/theme/app_theme.dart';
import 'package:estudicards/app/theme/theme_preview_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The root widget of the app.
class EstudiCardsApp extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'EstudiCards',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light(),
    darkTheme: AppTheme.dark(),
    // No `themeMode` given: it defaults to `ThemeMode.system`, so the app
    // follows the device's light/dark setting. Settings will let the user
    // override it later (SPEC §4.2, `theme_mode`).
    // Temporary home until the router arrives in T0.8.
    home: const ThemePreviewScreen(),
  );
}

/// Adds the Plus Jakarta Sans licence (SIL OFL) to the app's licence list.
/// The font is bundled with the app, and its licence requires shipping it.
void registerFontLicenses() {
  LicenseRegistry.addLicense(() async* {
    final text = await rootBundle.loadString('assets/fonts/OFL.txt');
    yield LicenseEntryWithLineBreaks(['Plus Jakarta Sans'], text);
  });
}
