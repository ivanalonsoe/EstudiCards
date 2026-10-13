import 'package:estudicards/app/app.dart';
import 'package:estudicards/app/router.dart';
import 'package:estudicards/core/clock.dart';
import 'package:estudicards/core/db/app_database.dart';
import 'package:estudicards/features/cards/data/cards_dao.dart';
import 'package:estudicards/features/cards/data/cards_repository.dart';
import 'package:estudicards/features/cards/domain/card_input.dart';
import 'package:estudicards/features/cards/domain/flashcard.dart';
import 'package:estudicards/features/decks/data/decks_dao.dart';
import 'package:estudicards/features/decks/data/decks_repository.dart';
import 'package:estudicards/features/decks/domain/deck_input.dart';
import 'package:estudicards/features/projects/data/projects_dao.dart';
import 'package:estudicards/features/projects/data/projects_repository.dart';
import 'package:estudicards/features/projects/domain/project_input.dart';
import 'package:estudicards/features/study/data/study_dao.dart';
import 'package:estudicards/features/study/data/study_repository.dart';
import 'package:estudicards/features/study/domain/attempt_record.dart';
import 'package:estudicards/features/study/domain/session_config.dart';
import 'package:estudicards/features/study/domain/session_engine.dart';
import 'package:estudicards/features/study/domain/session_state.dart';
import 'package:estudicards/features/study/domain/study_options.dart';
import 'package:estudicards/features/study/presentation/session_launch.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_image_files.dart';
import '../../../helpers/test_app.dart';

final _now = DateTime.utc(2026, 10, 6, 12);

/// A session saved as the engine would leave it: [correct] cards answered
/// right, [wrong] missed and [unanswered] left, in that order. Every answer
/// took [answerTime]. Card N asks "Pregunta N" and answers "Respuesta N".
Future<({String sessionId, String projectId, List<String> cardIds})>
saveFinishedSession(
  AppDatabase db, {
  int correct = 0,
  int wrong = 0,
  int unanswered = 0,
  SessionStatus status = SessionStatus.completed,
  Duration answerTime = const Duration(seconds: 18),
  Duration activeDuration = const Duration(minutes: 6, seconds: 12),
  SessionConfig Function(String deckId)? config,
}) async {
  final clock = FakeClock(_now);
  final project = await ProjectsRepository(
    ProjectsDao(db),
    clock,
  ).create(const ProjectInput(name: 'Inglés B2', color: 'blue', icon: 'globe'));
  final deck = await DecksRepository(
    DecksDao(db),
    clock,
  ).create(project.id, const DeckInput(name: 'Verbos irregulares'));
  final cards = CardsRepository(CardsDao(db), clock, FakeImageFiles());
  final results = [
    ...List.filled(correct, AttemptResult.correct),
    ...List.filled(wrong, AttemptResult.wrong),
    ...List.filled(unanswered, AttemptResult.unanswered),
  ];
  final cardIds = <String>[];
  for (var i = 1; i <= results.length; i++) {
    final card = await cards.create(
      deck.id,
      CardInput(
        type: CardType.simple,
        question: 'Pregunta $i',
        answer: 'Respuesta $i',
      ),
    );
    cardIds.add(card.id);
  }

  final repository = StudyRepository(StudyDao(db), clock);
  final sessionId = await repository.startSession(
    project.id,
    config?.call(deck.id) ?? SessionConfig(deckIds: [deck.id]),
  );
  await repository.record(
    sessionId,
    SessionStep(
      Finished(
        status: status,
        activeDuration: activeDuration,
        correctCount: correct,
        wrongCount: wrong,
        unansweredCount: unanswered,
      ),
      [
        for (final (index, result) in results.indexed)
          AttemptRecord(
            cardId: cardIds[index],
            direction: StudyDirection.normal,
            result: result,
            source: result == AttemptResult.unanswered
                ? AttemptSource.sessionEnd
                : AttemptSource.selfEval,
            isFirstAttempt: true,
            responseTime: result == AttemptResult.unanswered
                ? null
                : answerTime,
            answeredAt: _now,
          ),
      ],
    ),
  );
  return (sessionId: sessionId, projectId: project.id, cardIds: cardIds);
}

void main() {
  for (final (name, size) in [('mobile', mobile), ('desktop', desktop)]) {
    testWidgets('shows %, correct, wrong, unanswered, total and average time '
        '($name)', (tester) async {
      final db = createTestDatabase();
      final saved = await saveFinishedSession(
        db,
        correct: 15,
        wrong: 4,
        unanswered: 1,
      );

      await pumpTestApp(
        tester,
        size: size,
        db: db,
        location: AppRoutes.results(saved.sessionId),
      );

      expect(find.text('79%'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('results.correct')),
          matching: find.text('15'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('results.wrong')),
          matching: find.text('4'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('results.unanswered')),
          matching: find.text('1'),
        ),
        findsOneWidget,
      );
      expect(find.textContaining('20 tarjetas'), findsOneWidget);
      expect(find.textContaining('6:12'), findsOneWidget);
      expect(find.textContaining('18 s'), findsOneWidget);
    });
  }

  testWidgets('lists the missed cards (question and correct answer) and the '
      'unanswered ones', (tester) async {
    final db = createTestDatabase();
    final saved = await saveFinishedSession(
      db,
      correct: 1,
      wrong: 2,
      unanswered: 1,
    );

    await pumpTestApp(
      tester,
      size: desktop,
      db: db,
      location: AppRoutes.results(saved.sessionId),
    );

    expect(find.text('Falladas (2)'), findsOneWidget);
    expect(find.text('No respondidas (1)'), findsOneWidget);
    for (final n in [2, 3, 4]) {
      expect(find.text('Pregunta $n'), findsOneWidget);
      expect(find.text('Respuesta $n'), findsOneWidget);
    }
    expect(find.text('Pregunta 1'), findsNothing);
  });

  group('celebration', () {
    Future<void> showResults(
      WidgetTester tester, {
      required int correct,
      required int wrong,
      SessionStatus status = SessionStatus.completed,
    }) async {
      final db = createTestDatabase();
      final saved = await saveFinishedSession(
        db,
        correct: correct,
        wrong: wrong,
        status: status,
      );
      await pumpTestApp(
        tester,
        size: mobile,
        db: db,
        location: AppRoutes.results(saved.sessionId),
      );
    }

    testWidgets('at ≥ 80% the celebration is shown', (tester) async {
      await showResults(tester, correct: 4, wrong: 1);

      expect(find.text('80%'), findsOneWidget);
      expect(find.text('¡Buen trabajo!'), findsOneWidget);
      expect(find.byKey(const Key('results.celebration')), findsOneWidget);
    });

    testWidgets('at 79% it is not', (tester) async {
      await showResults(tester, correct: 15, wrong: 4);

      expect(find.text('79%'), findsOneWidget);
      expect(find.text('Sesión terminada'), findsOneWidget);
      expect(find.byKey(const Key('results.celebration')), findsNothing);
    });

    testWidgets('when the time ran out, the title says so', (tester) async {
      await showResults(
        tester,
        correct: 1,
        wrong: 3,
        status: SessionStatus.timeUp,
      );

      expect(find.text('¡Se acabó el tiempo!'), findsOneWidget);
    });
  });

  group('"Repasar falladas ahora"', () {
    testWidgets('starts a session with only the missed cards', (tester) async {
      final db = createTestDatabase();
      final saved = await saveFinishedSession(
        db,
        correct: 2,
        wrong: 3,
        unanswered: 1,
        config: (deckId) => SessionConfig(
          deckIds: [deckId],
          direction: StudyDirection.reverse,
          timerType: TimerType.perCard,
          timerSeconds: 30,
        ),
      );
      final router = await pumpTestApp(
        tester,
        size: mobile,
        db: db,
        location: AppRoutes.results(saved.sessionId),
      );

      // The button is at the end of the list, below the missed cards.
      final review = find.byKey(const Key('results.reviewMissed'));
      await tester.scrollUntilVisible(review, 200);
      await tester.tap(review);
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(EstudiCardsApp)),
      );
      final launched = container.read(launchedSessionsProvider);
      final newId = launched.keys.single;
      expect(newId, isNot(saved.sessionId));
      expect(
        launched[newId]!.cards.map((c) => c.card.id),
        unorderedEquals(saved.cardIds.sublist(2, 5)),
      );
      expect(launched[newId]!.settings.timerType, TimerType.perCard);
      expect(launched[newId]!.settings.timerLimit, const Duration(seconds: 30));
      final stored = await (db.select(
        db.studySessions,
      )..where((s) => s.id.equals(newId))).getSingle();
      expect(stored.direction, 'reverse');
      expect(stored.requestedCount, 3);
      expect(
        router.routerDelegate.currentConfiguration.uri.path,
        AppRoutes.session(newId),
      );
    });

    testWidgets('is not shown when nothing was missed', (tester) async {
      final db = createTestDatabase();
      final saved = await saveFinishedSession(db, correct: 3, unanswered: 1);

      // On desktop the whole screen fits, so a missing button is really
      // missing and not just scrolled out of view.
      await pumpTestApp(
        tester,
        size: desktop,
        db: db,
        location: AppRoutes.results(saved.sessionId),
      );

      expect(find.byKey(const Key('results.reviewMissed')), findsNothing);
    });
  });

  for (final (name, size, key) in [
    ('mobile', mobile, 'results.close'),
    ('desktop', desktop, 'results.backToProject'),
  ]) {
    testWidgets('goes back to the project ($name)', (tester) async {
      final db = createTestDatabase();
      final saved = await saveFinishedSession(db, correct: 1);
      final router = await pumpTestApp(
        tester,
        size: size,
        db: db,
        location: AppRoutes.results(saved.sessionId),
      );

      await tester.tap(find.byKey(Key(key)));
      await tester.pumpAndSettle();

      expect(
        router.routerDelegate.currentConfiguration.uri.path,
        AppRoutes.project(saved.projectId),
      );
    });
  }

  testWidgets('an unknown session says it no longer exists', (tester) async {
    await pumpTestApp(
      tester,
      size: mobile,
      location: AppRoutes.results('missing'),
    );

    expect(find.text('Esta sesión ya no existe'), findsOneWidget);
  });
}
