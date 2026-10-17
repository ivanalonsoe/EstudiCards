import 'package:estudicards/app/router.dart';
import 'package:estudicards/core/clock.dart';
import 'package:estudicards/core/db/app_database.dart';
import 'package:estudicards/features/decks/data/decks_dao.dart';
import 'package:estudicards/features/decks/data/decks_repository.dart';
import 'package:estudicards/features/decks/domain/deck_input.dart';
import 'package:estudicards/features/projects/data/projects_dao.dart';
import 'package:estudicards/features/projects/data/projects_repository.dart';
import 'package:estudicards/features/projects/domain/project_input.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/test_app.dart';
import '../../../helpers/test_data.dart';

/// P12: the statistics of a project, in the mobile tab and on the desktop
/// page and summary.
void main() {
  late AppDatabase db;
  late FakeClock clock;
  late String projectId;
  late String verbsId;
  late String phrasalId;

  setUp(() async {
    db = createTestDatabase();
    clock = FakeClock(DateTime.utc(2026, 10, 6, 12));
    projectId = (await ProjectsRepository(ProjectsDao(db), clock).create(
      const ProjectInput(name: 'Inglés B2', color: 'blue', icon: 'globe'),
    )).id;
    final decks = DecksRepository(DecksDao(db), clock);
    verbsId = (await decks.create(
      projectId,
      const DeckInput(name: 'Verbos irregulares'),
    )).id;
    phrasalId = (await decks.create(
      projectId,
      const DeckInput(name: 'Phrasal verbs'),
    )).id;
  });

  /// Today: 2 correct and 1 wrong in Verbos; 3 days ago, 1 wrong in
  /// Phrasal verbs.
  Future<void> addAnswers() async {
    await addTestAnswers(
      db,
      projectId: projectId,
      cardId: await addTestCard(db, verbsId),
      results: ['correct', 'wrong', 'correct'],
      at: DateTime.utc(2026, 10, 6, 9),
    );
    await addTestAnswers(
      db,
      projectId: projectId,
      cardId: await addTestCard(db, phrasalId),
      results: ['wrong'],
      at: DateTime.utc(2026, 10, 3, 9),
    );
  }

  Future<void> openStatisticsTab(WidgetTester tester) async {
    await pumpTestApp(
      tester,
      size: mobile,
      db: db,
      clock: clock,
      location: AppRoutes.project(projectId),
    );
    await tester.tap(find.byKey(const Key('projectScreen.tab.statistics')));
    await tester.pumpAndSettle();
  }

  /// Scrolls the project screen until [finder] is built and visible.
  Future<void> scrollTo(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }

  Finder textIn(String key, String text) =>
      find.descendant(of: find.byKey(Key(key)), matching: find.text(text));

  Finder iconIn(String key, IconData icon) =>
      find.descendant(of: find.byKey(Key(key)), matching: find.byIcon(icon));

  group('mobile tab', () {
    testWidgets('the legend shows the totals with ✓ and ✗', (tester) async {
      await addAnswers();
      await openStatisticsTab(tester);

      expect(find.byKey(const Key('answersChart')), findsOneWidget);
      expect(
        textIn('answersChart.legend.correct', 'Aciertos · 2'),
        findsOneWidget,
      );
      expect(
        iconIn('answersChart.legend.correct', Icons.check_rounded),
        findsOneWidget,
      );
      expect(textIn('answersChart.legend.wrong', 'Fallos · 2'), findsOneWidget);
      expect(
        iconIn('answersChart.legend.wrong', Icons.close_rounded),
        findsOneWidget,
      );
      expect(find.byKey(const Key('projectScreen.noStatistics')), findsNothing);
    });

    testWidgets('screen readers get the data of the chart', (tester) async {
      await addAnswers();
      await openStatisticsTab(tester);

      final label = tester
          .getSemantics(find.byKey(const Key('answersChart.data')))
          .label;
      expect(label, contains('2 aciertos y 2 fallos'));
      expect(label, contains('6 oct: 2 aciertos, 1 fallo'));
      expect(label, contains('3 oct: 0 aciertos, 1 fallo'));
    });

    testWidgets('shows % correct per deck', (tester) async {
      await addAnswers();
      await openStatisticsTab(tester);
      await scrollTo(tester, find.byKey(Key('projectStats.deck.$phrasalId')));

      expect(textIn('projectStats.deck.$verbsId', '67%'), findsOneWidget);
      expect(textIn('projectStats.deck.$phrasalId', '0%'), findsOneWidget);
    });

    testWidgets('shows the 3 most missed cards, and 10 after "Ver 10"', (
      tester,
    ) async {
      final cards = [
        for (var i = 1; i <= 12; i++) await addTestCard(db, verbsId),
      ];
      for (final (i, card) in cards.indexed) {
        await addTestStats(db, card, wrong: i + 1);
      }
      await openStatisticsTab(tester);
      await scrollTo(tester, find.byKey(const Key('projectStats.missed')));

      expect(find.byKey(Key('projectStats.missed.${cards[11]}')), findsOne);
      expect(
        textIn('projectStats.missed.${cards[11]}', '12 fallos'),
        findsOneWidget,
      );
      expect(find.byKey(Key('projectStats.missed.${cards[8]}')), findsNothing);

      await tester.tap(find.byKey(const Key('projectStats.missed.showAll')));
      await tester.pumpAndSettle();

      expect(find.byKey(Key('projectStats.missed.${cards[2]}')), findsOne);
      expect(find.byKey(Key('projectStats.missed.${cards[1]}')), findsNothing);
      expect(
        find.byKey(const Key('projectStats.missed.showAll')),
        findsNothing,
      );
    });

    testWidgets('tapping a missed card opens it', (tester) async {
      final card = await addTestCard(db, verbsId);
      await addTestStats(db, card, wrong: 2);
      await openStatisticsTab(tester);
      await scrollTo(tester, find.byKey(Key('projectStats.missed.$card')));

      await tester.tap(find.byKey(Key('projectStats.missed.$card')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('screen.editCard')), findsOneWidget);
    });

    testWidgets('shows the last 10 sessions; "Ver más" shows older ones', (
      tester,
    ) async {
      final sessions = [
        for (var day = 1; day <= 12; day++)
          await addTestSession(
            db,
            projectId: projectId,
            deckIds: [verbsId],
            startedAt: DateTime.utc(2026, 9, day, 18),
            correct: 4,
            wrong: 1,
            activeDuration: const Duration(minutes: 6),
          ),
      ];
      await openStatisticsTab(tester);
      final latest = find.byKey(Key('projectStats.session.${sessions.last}'));
      await scrollTo(tester, latest);

      expect(
        textIn('projectStats.session.${sessions.last}', 'Verbos irregulares'),
        findsOneWidget,
      );
      expect(
        textIn('projectStats.session.${sessions.last}', '12 sept · 6 min'),
        findsOneWidget,
      );
      expect(
        textIn('projectStats.session.${sessions.last}', '80%'),
        findsOneWidget,
      );
      expect(
        find.byKey(Key('projectStats.session.${sessions[1]}')),
        findsNothing,
      );

      final more = find.byKey(const Key('projectStats.sessions.more'));
      await scrollTo(tester, more);
      await tester.tap(more);
      await tester.pumpAndSettle();
      await scrollTo(
        tester,
        find.byKey(Key('projectStats.session.${sessions.first}')),
      );

      expect(find.byKey(Key('projectStats.session.${sessions[1]}')), findsOne);
      expect(more, findsNothing);
    });

    testWidgets('tapping a session opens its results', (tester) async {
      final session = await addTestSession(
        db,
        projectId: projectId,
        deckIds: [verbsId],
        startedAt: DateTime.utc(2026, 10, 5, 18),
        correct: 1,
      );
      await openStatisticsTab(tester);
      final row = find.byKey(Key('projectStats.session.$session'));
      await scrollTo(tester, row);

      await tester.tap(row);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('screen.results')), findsOneWidget);
    });
  });

  group('desktop', () {
    testWidgets('the summary shows the chart and the most missed cards', (
      tester,
    ) async {
      await addAnswers();
      await pumpTestApp(
        tester,
        size: desktop,
        db: db,
        clock: clock,
        location: AppRoutes.project(projectId),
      );

      expect(
        find.descendant(
          of: find.byKey(const Key('projectScreen.summary')),
          matching: find.byKey(const Key('answersChart')),
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('projectStats.missed')), findsOneWidget);
      expect(find.byKey(const Key('projectScreen.noStatistics')), findsNothing);
    });

    testWidgets('"Ver estadísticas" opens the statistics page', (tester) async {
      await addAnswers();
      await pumpTestApp(
        tester,
        size: desktop,
        db: db,
        clock: clock,
        location: AppRoutes.project(projectId),
      );

      await tester.tap(find.byKey(const Key('projectScreen.seeStatistics')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('screen.projectStatistics')), findsOneWidget);
      expect(find.byKey(Key('projectStats.deck.$verbsId')), findsOneWidget);
      expect(find.byKey(const Key('projectStats.sessions')), findsOneWidget);
    });
  });
}
