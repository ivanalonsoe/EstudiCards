import 'package:estudicards/app/app.dart';
import 'package:estudicards/app/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A test screen that shows strings read from `app_es.arb`.
class _StringsScreen extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        Text(l10n.trash),
        Text(l10n.cardCount(1)),
        Text(l10n.cardCount(84)),
        Text(l10n.reviewErrors(9)),
      ],
    );
  }
}

void main() {
  testWidgets('a test screen shows strings read from the ARB file', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('es'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: _StringsScreen(),
      ),
    );

    expect(find.text('Papelera'), findsOneWidget);
    expect(find.text('1 tarjeta'), findsOneWidget);
    expect(find.text('84 tarjetas'), findsOneWidget);
    expect(find.text('Repasar errores (9)'), findsOneWidget);
  });

  testWidgets('the app is in Spanish even on a device in another language', (
    tester,
  ) async {
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    tester.platformDispatcher.localesTestValue = [const Locale('en', 'US')];

    await tester.pumpWidget(const EstudiCardsApp());

    final context = tester.element(find.byType(Scaffold).first);
    expect(Localizations.localeOf(context), const Locale('es'));
    expect(AppLocalizations.of(context).appTitle, 'EstudiCards');
    // Flutter's own widgets (dialogs, date pickers…) are in Spanish too.
    expect(MaterialLocalizations.of(context).cancelButtonLabel, 'Cancelar');
  });
}
