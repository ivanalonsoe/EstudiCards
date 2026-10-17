import 'package:estudicards/app/router.dart';
import 'package:estudicards/core/clock.dart';
import 'package:estudicards/core/db/app_database.dart';
import 'package:estudicards/features/decks/data/decks_dao.dart';
import 'package:estudicards/features/decks/data/decks_repository.dart';
import 'package:estudicards/features/decks/domain/deck_input.dart';
import 'package:estudicards/features/projects/data/projects_dao.dart';
import 'package:estudicards/features/projects/data/projects_repository.dart';
import 'package:estudicards/features/projects/domain/project_input.dart';
import 'package:estudicards/features/study/presentation/review_errors_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/test_app.dart';
import '../../../helpers/test_data.dart';

/// P13: the global statistics.
void main() {
  late AppDatabase db;
  late FakeClock clock;
  late ProjectsRepository projects;
  late DecksRepository decks;

  setUp(() {
    db = createTestDatabase();
    clock = FakeClock(DateTime.utc(2026, 10, 6, 12));
    projects = ProjectsRepository(ProjectsDao(db), clock);
    decks = DecksRepository(DecksDao(db), clock);
  });

  /// A project with one deck and one card, answered with [results] on each
  /// of [days] (UTC dates, which are local days for this clock).
  Future<String> addProject(
    String name, {
    required Map<DateTime, List<String>> answers,
  }) async {
    final projectId = (await projects.create(
      ProjectInput(name: name, color: 'blue', icon: 'globe'),
    )).id;
    final deckId = (await decks.create(
      projectId,
      const DeckInput(name: 'Baraja'),
    )).id;
    final cardId = await addTestCard(db, deckId);
    for (final MapEntry(key: day, value: results) in answers.entries) {
      await addTestAnswers(
        db,
        projectId: projectId,
        cardId: cardId,
        results: results,
        at: day.add(const Duration(hours: 9)),
      );
    }
    return projectId;
  }

  Finder textIn(String key, String text) =>
      find.descendant(of: find.byKey(Key(key)), matching: find.text(text));

  Future<void> openStatistics(WidgetTester tester, {Size size = mobile}) =>
      pumpTestApp(
        tester,
        size: size,
        db: db,
        clock: clock,
        location: AppRoutes.statistics,
      );

  /// English: today, yesterday and 20 days ago. Biology (archived): 6, 7
  /// and 8 days ago, a 3-day run that is the best one.
  Future<(String, String)> addTwoProjects() async {
    final english = await addProject(
      'Inglés B2',
      answers: {
        DateTime.utc(2026, 10, 6): ['correct', 'correct', 'wrong'],
        DateTime.utc(2026, 10, 5): ['correct'],
        DateTime.utc(2026, 9, 16): ['correct', 'wrong'],
      },
    );
    final biology = await addProject(
      'Biología',
      answers: {
        DateTime.utc(2026, 9, 30): ['wrong'],
        DateTime.utc(2026, 9, 29): ['correct'],
        DateTime.utc(2026, 9, 28): ['correct', 'correct', 'correct'],
      },
    );
    await projects.setArchived(biology, isArchived: true);
    return (english, biology);
  }

  for (final (name, size) in [('mobile', mobile), ('desktop', desktop)]) {
    testWidgets('$name: shows streak, best streak, today / 7 / 30 days and a '
        'summary per project, with no review buttons', (tester) async {
      final (english, biology) = await addTwoProjects();

      await openStatistics(tester, size: size);

      expect(textIn('statistics.streak', '2 días'), findsOneWidget);
      expect(textIn('statistics.best', '3 días'), findsOneWidget);
      expect(textIn('statistics.today', '3'), findsOneWidget);
      // English today and yesterday, and Biology 6 days ago.
      expect(textIn('statistics.last7Days', '5'), findsOneWidget);
      expect(textIn('statistics.last30Days', '11'), findsOneWidget);
      expect(
        textIn('answersChart.legend.correct', 'Aciertos · 8'),
        findsOneWidget,
      );
      expect(textIn('answersChart.legend.wrong', 'Fallos · 3'), findsOneWidget);

      final englishRow = find.byKey(Key('statistics.project.$english'));
      await tester.scrollUntilVisible(
        englishRow,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(textIn('statistics.project.$english', 'Inglés B2'), findsOne);
      expect(textIn('statistics.project.$english', '67%'), findsOneWidget);
      // Archived projects count in the global statistics.
      expect(textIn('statistics.project.$biology', '80%'), findsOneWidget);
      // The project has pending errors, but P13 offers no review.
      expect(find.byType(ReviewErrorsButton), findsNothing);
    });
  }

  testWidgets('tapping a project opens it', (tester) async {
    final (english, _) = await addTwoProjects();
    await openStatistics(tester);
    final row = find.byKey(Key('statistics.project.$english'));
    await tester.scrollUntilVisible(
      row,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(row);
    await tester.pumpAndSettle();

    await tester.tap(row);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('screen.project')), findsOneWidget);
  });

  testWidgets('with nothing studied, shows the empty state', (tester) async {
    await addProject('Inglés B2', answers: const {});

    await openStatistics(tester);

    expect(find.byKey(const Key('statistics.empty')), findsOneWidget);
    expect(find.byKey(const Key('answersChart')), findsNothing);
  });
}
