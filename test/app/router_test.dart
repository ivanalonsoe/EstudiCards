import 'package:estudicards/app/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../helpers/test_app.dart';

final Finder sidebar = find.byKey(const Key('shell.sidebar'));

/// Flutter's Spanish tooltip for the drawer menu button.
const openMenuTooltip = 'Abrir el menú de navegación';

/// Starts the app on a screen of [size], at [location].
Future<GoRouter> pumpApp(
  WidgetTester tester, {
  required Size size,
  String location = AppRoutes.home,
}) => pumpTestApp(tester, size: size, location: location);

/// The title shown by the screen on top.
Finder screenTitle(String title) =>
    find.descendant(of: find.byType(AppBar), matching: find.text(title));

void main() {
  group('responsive shell', () {
    testWidgets('at 390 px wide there is no sidebar, but a menu button', (
      tester,
    ) async {
      await pumpApp(tester, size: mobile);

      expect(sidebar, findsNothing);
      expect(find.byKey(const Key('screen.dashboard')), findsOneWidget);
      expect(find.byTooltip(openMenuTooltip), findsOneWidget);
    });

    testWidgets('a tablet (700 px) uses the mobile layout', (tester) async {
      await pumpApp(tester, size: tablet);

      expect(sidebar, findsNothing);
    });

    testWidgets('at 1440 px wide there is a sidebar with the menu', (
      tester,
    ) async {
      await pumpApp(tester, size: desktop);

      expect(sidebar, findsOneWidget);
      for (final label in [
        'Inicio',
        'Estadísticas',
        'Archivados',
        'Papelera',
        'Ajustes',
      ]) {
        expect(
          find.descendant(of: sidebar, matching: find.text(label)),
          findsOneWidget,
          reason: label,
        );
      }
      // The sidebar replaces the mobile menu button, and holds the logo.
      expect(find.byTooltip(openMenuTooltip), findsNothing);
      expect(find.byKey(const Key('screen.dashboard')), findsOneWidget);
    });

    testWidgets('on desktop the sidebar opens a screen and marks it', (
      tester,
    ) async {
      await pumpApp(tester, size: desktop);

      await tester.tap(find.byKey(const Key('nav.trash')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('screen.trash')), findsOneWidget);
      expect(sidebar, findsOneWidget);
      final item = tester.widget<ListTile>(find.byKey(const Key('nav.trash')));
      expect(item.selected, isTrue);
    });

    testWidgets('on mobile the side menu opens a screen with a back button', (
      tester,
    ) async {
      await pumpApp(tester, size: mobile);

      await tester.tap(find.byTooltip(openMenuTooltip));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('nav.trash')));
      await tester.pumpAndSettle();

      expect(screenTitle('Papelera'), findsOneWidget);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('screen.dashboard')), findsOneWidget);
    });
  });

  group('routes', () {
    testWidgets('navigating to /project/:id shows the project screen', (
      tester,
    ) async {
      final router = await pumpApp(tester, size: mobile);

      router.go(AppRoutes.project('p1'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('screen.project')), findsOneWidget);
      expect(screenTitle('Proyecto'), findsOneWidget);

      // Stack navigation: back returns to the dashboard.
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('screen.dashboard')), findsOneWidget);
    });

    testWidgets('every route shows its screen with its title', (tester) async {
      final router = await pumpApp(tester, size: mobile);

      final routes = {
        AppRoutes.home: 'EstudiCards',
        AppRoutes.project('p1'): 'Proyecto',
        AppRoutes.deck('p1', 'd1'): 'Baraja',
        AppRoutes.newCard('p1', 'd1'): 'Nueva tarjeta',
        AppRoutes.editCard('p1', 'd1', 'c1'): 'Editar tarjeta',
        AppRoutes.sessionSetup('p1'): 'Configurar sesión',
        AppRoutes.session('s1'): 'Sesión de estudio',
        AppRoutes.results('s1'): 'Resultados',
        AppRoutes.import: 'Importar',
        AppRoutes.statistics: 'Estadísticas',
        AppRoutes.archived: 'Archivados',
        AppRoutes.trash: 'Papelera',
        AppRoutes.settings: 'Ajustes',
      };

      for (final MapEntry(key: path, value: title) in routes.entries) {
        router.go(path);
        await tester.pumpAndSettle();

        expect(screenTitle(title), findsOneWidget, reason: path);
      }
    });

    testWidgets('the study session hides the sidebar on desktop', (
      tester,
    ) async {
      await pumpApp(tester, size: desktop, location: AppRoutes.session('s1'));

      expect(screenTitle('Sesión de estudio'), findsOneWidget);
      expect(sidebar, findsNothing);
    });

    testWidgets('an unknown route shows a not-found screen', (tester) async {
      await pumpApp(tester, size: mobile, location: '/nowhere');

      expect(find.text('No se ha encontrado la página'), findsOneWidget);

      await tester.tap(find.text('Volver al inicio'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('screen.dashboard')), findsOneWidget);
    });
  });
}
