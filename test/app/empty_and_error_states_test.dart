// T6.4 (SPEC §5.3): every empty state is shown with its text and action,
// with the same look (`EmptyState`, as in `docs/design/sistema/
// componentes.png`), and a screen whose data cannot be read says so and
// offers to try again instead of looking empty.
import 'package:estudicards/app/router.dart';
import 'package:estudicards/core/clock.dart';
import 'package:estudicards/core/db/app_database.dart';
import 'package:estudicards/core/widgets/empty_state.dart';
import 'package:estudicards/features/decks/data/decks_dao.dart';
import 'package:estudicards/features/decks/data/decks_repository.dart';
import 'package:estudicards/features/decks/domain/deck_input.dart';
import 'package:estudicards/features/projects/data/projects_dao.dart';
import 'package:estudicards/features/projects/data/projects_repository.dart';
import 'package:estudicards/features/projects/domain/project_input.dart';
import 'package:estudicards/features/projects/domain/project_summary.dart';
import 'package:estudicards/features/projects/presentation/project_providers.dart';
import 'package:estudicards/features/stats/domain/metrics.dart';
import 'package:estudicards/features/stats/presentation/stats_providers.dart';
import 'package:estudicards/features/trash/domain/trash_item.dart';
import 'package:estudicards/features/trash/presentation/trash_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_app.dart';
import '../helpers/test_data.dart';

/// [text] inside the shared empty state.
Finder inEmptyState(String text) =>
    find.descendant(of: find.byType(EmptyState), matching: find.text(text));

void main() {
  late AppDatabase db;
  late String projectId;
  late String deckId;

  /// A project "Inglés B2" with one empty deck "Verbos", or with no deck.
  Future<void> addProjectWithEmptyDeck({bool withDeck = true}) async {
    final clock = FakeClock(DateTime.utc(2026, 10, 6));
    projectId = (await ProjectsRepository(ProjectsDao(db), clock).create(
      const ProjectInput(name: 'Inglés B2', color: 'blue', icon: 'globe'),
    )).id;
    if (!withDeck) return;
    deckId = (await DecksRepository(
      DecksDao(db),
      clock,
    ).create(projectId, const DeckInput(name: 'Verbos'))).id;
  }

  setUp(() => db = createTestDatabase());

  group('empty states', () {
    for (final (form, size) in [('mobile', mobile), ('desktop', desktop)]) {
      testWidgets('dashboard with no projects: "Crea tu primer proyecto", '
          '"Nuevo proyecto" and "Importar un proyecto" ($form)', (
        tester,
      ) async {
        await pumpTestApp(tester, size: size, db: db);

        expect(inEmptyState('Crea tu primer proyecto'), findsOneWidget);
        expect(inEmptyState('Nuevo proyecto'), findsOneWidget);
        expect(inEmptyState('Importar un proyecto'), findsOneWidget);
      });

      testWidgets('project with no decks: "Crea una baraja para empezar a '
          'añadir tarjetas" and "Nueva baraja" ($form)', (tester) async {
        await addProjectWithEmptyDeck(withDeck: false);
        await pumpTestApp(
          tester,
          size: size,
          db: db,
          location: AppRoutes.project(projectId),
        );

        expect(
          inEmptyState('Crea una baraja para empezar a añadir tarjetas'),
          findsOneWidget,
        );
        // On mobile in the empty state; on desktop next to "Barajas".
        expect(find.text('Nueva baraja'), findsOneWidget);
        expect(
          inEmptyState('Nueva baraja'),
          size == mobile ? findsOneWidget : findsNothing,
        );
      });

      testWidgets('deck with no cards: "Añade tu primera tarjeta", "o '
          'importa desde CSV" and "Descargar plantilla" ($form)', (
        tester,
      ) async {
        await addProjectWithEmptyDeck();
        await pumpTestApp(
          tester,
          size: size,
          db: db,
          location: AppRoutes.deck(projectId, deckId),
        );

        expect(inEmptyState('Añade tu primera tarjeta'), findsOneWidget);
        expect(inEmptyState('o importa desde CSV'), findsOneWidget);
        expect(inEmptyState('Descargar plantilla'), findsOneWidget);
      });

      testWidgets('trash with nothing in it ($form)', (tester) async {
        await pumpTestApp(
          tester,
          size: size,
          db: db,
          location: AppRoutes.trash,
        );

        expect(inEmptyState('La papelera está vacía'), findsOneWidget);
      });

      testWidgets('no archived projects ($form)', (tester) async {
        await pumpTestApp(
          tester,
          size: size,
          db: db,
          location: AppRoutes.archived,
        );

        expect(inEmptyState('No hay proyectos archivados'), findsOneWidget);
      });

      testWidgets('global statistics with no answers ($form)', (tester) async {
        await pumpTestApp(
          tester,
          size: size,
          db: db,
          location: AppRoutes.statistics,
        );

        expect(inEmptyState('Aún no hay estadísticas'), findsOneWidget);
        expect(
          inEmptyState('Estudia un proyecto para verlas aquí.'),
          findsOneWidget,
        );
      });

      testWidgets('project statistics with no answers ($form)', (tester) async {
        await addProjectWithEmptyDeck();
        await pumpTestApp(
          tester,
          size: size,
          db: db,
          location: AppRoutes.projectStatistics(projectId),
        );

        expect(inEmptyState('Aún no hay estadísticas'), findsOneWidget);
      });
    }

    testWidgets('session setup with no available cards: the message and '
        '"Empezar" disabled', (tester) async {
      await addProjectWithEmptyDeck();
      await pumpTestApp(
        tester,
        size: mobile,
        db: db,
        location: AppRoutes.sessionSetup(projectId),
      );

      expect(find.text('No hay tarjetas disponibles'), findsWidgets);
      final start = tester.widget<ButtonStyleButton>(
        find.byKey(const Key('sessionSetup.start')),
      );
      expect(start.onPressed, isNull);
    });

    testWidgets('a project search with no results says so', (tester) async {
      await addProjectWithEmptyDeck();
      await pumpTestApp(tester, size: mobile, db: db);

      await tester.enterText(find.byKey(const Key('dashboard.search')), 'zzz');
      await tester.pumpAndSettle();

      expect(
        inEmptyState('Ningún proyecto coincide con «zzz»'),
        findsOneWidget,
      );
    });

    testWidgets('a card search with no results says so', (tester) async {
      await addProjectWithEmptyDeck();
      await addTestCard(db, deckId);
      await pumpTestApp(
        tester,
        size: mobile,
        db: db,
        location: AppRoutes.deck(projectId, deckId),
      );

      await tester.enterText(find.byType(TextField).first, 'zzz');
      await tester.pumpAndSettle();

      expect(
        inEmptyState('Ninguna tarjeta coincide con «zzz»'),
        findsOneWidget,
      );
    });
  });

  group('error states', () {
    /// Fails the first time it is read, and then gives [value].
    ///
    /// Riverpod tries a provider that fails with an `Exception` (such as a
    /// database error) again by itself, a few times, after a short wait. A
    /// `StateError` is not tried again, so the test sees the error until
    /// "Reintentar" is tapped.
    Stream<T> Function(Object? _) failOnce<T>(T value) {
      var reads = 0;
      return (_) => reads++ == 0
          ? Stream<T>.error(StateError('The database could not be read'))
          : Stream.value(value);
    }

    for (final (name, location, override, afterRetry) in [
      (
        'dashboard',
        AppRoutes.home,
        projectSummariesProvider.overrideWith(
          failOnce<List<ProjectSummary>>(const []),
        ),
        'Crea tu primer proyecto',
      ),
      (
        'archived',
        AppRoutes.archived,
        archivedProjectsProvider.overrideWith(
          failOnce<List<ProjectSummary>>(const []),
        ),
        'No hay proyectos archivados',
      ),
      (
        'trash',
        AppRoutes.trash,
        trashItemsProvider.overrideWith(failOnce<List<TrashItem>>(const [])),
        'La papelera está vacía',
      ),
      (
        'statistics',
        AppRoutes.statistics,
        statsOverviewProvider.overrideWith(
          failOnce(
            const StatsOverview(
              streak: Streak(current: 0, best: 0),
              answeredToday: 0,
              answeredLast7Days: 0,
            ),
          ),
        ),
        'Aún no hay estadísticas',
      ),
    ]) {
      testWidgets('$name: when the data cannot be read it says so, and '
          '"Reintentar" reads it again', (tester) async {
        await pumpTestApp(
          tester,
          size: mobile,
          db: db,
          location: location,
          overrides: [override],
        );

        expect(find.text('No se han podido cargar los datos'), findsOneWidget);
        expect(find.byType(EmptyState), findsNothing);

        await tester.tap(find.text('Reintentar'));
        await tester.pumpAndSettle();

        expect(find.text('No se han podido cargar los datos'), findsNothing);
        expect(inEmptyState(afterRetry), findsOneWidget);
      });
    }
  });
}
