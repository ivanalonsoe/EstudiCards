import 'package:estudicards/app/l10n/generated/app_localizations.dart';
import 'package:estudicards/app/router.dart';
import 'package:estudicards/app/theme/app_theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

/// The root widget of the app.
///
/// It is a StatefulWidget so the router is created once and kept while the
/// app runs, instead of on every rebuild.
class EstudiCardsApp extends StatefulWidget {
  /// Tests can pass their own [router], e.g. one that starts on another
  /// screen.
  const new({this.router, super.key});

  final GoRouter? router;

  @override
  State<EstudiCardsApp> createState() => _EstudiCardsAppState();
}

class _EstudiCardsAppState extends State<EstudiCardsApp> {
  late final GoRouter _router = widget.router ?? createRouter();

  @override
  void dispose() {
    // Only dispose the router we created; a test disposes its own.
    if (widget.router == null) _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
    debugShowCheckedModeBanner: false,
    // The UI is only in Spanish in v1, whatever the device language.
    locale: const Locale('es'),
    // Delegates load the strings: ours (generated from app_es.arb) and
    // Flutter's own (dialog buttons, date pickers, tooltips…) in Spanish.
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: AppTheme.light(),
    darkTheme: AppTheme.dark(),
    // No `themeMode` given: it defaults to `ThemeMode.system`, so the app
    // follows the device's light/dark setting. Settings will let the user
    // override it later (SPEC §4.2, `theme_mode`).
    routerConfig: _router,
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
