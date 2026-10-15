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
import 'package:estudicards/features/decks/domain/deck.dart';
import 'package:estudicards/features/decks/domain/deck_input.dart';
import 'package:estudicards/features/projects/data/projects_dao.dart';
import 'package:estudicards/features/projects/data/projects_repository.dart';
import 'package:estudicards/features/projects/domain/project_input.dart';
import 'package:estudicards/features/study/data/study_dao.dart';
import 'package:estudicards/features/study/data/study_repository.dart';
import 'package:estudicards/features/study/domain/card_selection.dart';
import 'package:estudicards/features/study/domain/session_config.dart';
import 'package:estudicards/features/study/domain/session_state.dart';
import 'package:estudicards/features/study/domain/study_options.dart';
import 'package:estudicards/features/study/presentation/session_launch.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../helpers/fake_image_files.dart';
import '../../../helpers/test_app.dart';

final _clock = FakeClock(DateTime.utc(2026, 10, 15, 9));

/// A session ready on screen: its ID, the router and the database.
typedef OpenSession = ({String id, GoRouter router, AppDatabase db});

/// Saves a session over [cards] (in that order) in a project "Inglés B2"
/// with one deck, leaves its queue in memory as "Empezar" does and opens
/// the session screen.
Future<OpenSession> openSession(
  WidgetTester tester, {
  required List<CardInput> cards,
  Size size = mobile,
  bool languageDeck = false,
  StudyDirection direction = StudyDirection.normal,
  bool repeatFailed = false,
  TimerType timerType = TimerType.none,
  int? timerSeconds,
}) async {
  final db = createTestDatabase();
  final project = await ProjectsRepository(
    ProjectsDao(db),
    _clock,
  ).create(const ProjectInput(name: 'Inglés B2', color: 'blue', icon: 'globe'));
  final deck = await DecksRepository(DecksDao(db), _clock).create(
    project.id,
    DeckInput(
      name: 'Verbos',
      type: languageDeck ? DeckType.language : DeckType.general,
      sourceLang: languageDeck ? 'en-GB' : null,
      targetLang: languageDeck ? 'es-ES' : null,
    ),
  );
  final repository = CardsRepository(CardsDao(db), _clock, FakeImageFiles());
  final flashcards = [
    for (final input in cards) await repository.create(deck.id, input),
  ];
  final config = SessionConfig(
    deckIds: [deck.id],
    direction: direction,
    repeatFailed: repeatFailed,
    timerType: timerType,
    timerSeconds: timerSeconds,
  );
  final sessionId = await StudyRepository(
    StudyDao(db),
    _clock,
  ).startSession(project.id, config);

  final router = await pumpTestApp(
    tester,
    size: size,
    db: db,
    location: AppRoutes.project(project.id),
  );
  ProviderScope.containerOf(tester.element(find.byType(EstudiCardsApp)))
      .read(launchedSessionsProvider.notifier)
      .add(
        sessionId,
        SessionLaunch(
          projectId: project.id,
          cards: [
            for (final card in flashcards)
              SelectedCard(
                card: card,
                direction: card.type == CardType.simple
                    ? direction
                    : StudyDirection.normal,
              ),
          ],
          settings: config.settings,
        ),
      );
  router.go(AppRoutes.session(sessionId));
  await tester.pumpAndSettle();
  return (id: sessionId, router: router, db: db);
}

CardInput simple(String question, String answer) =>
    CardInput(type: CardType.simple, question: question, answer: answer);

/// "¿Cuál es la capital de Francia?" with "París" correct.
const capitalQuestion = CardInput(
  type: CardType.test,
  question: '¿Cuál es la capital de Francia?',
  options: [
    CardOptionInput(text: 'París', isCorrect: true),
    CardOptionInput(text: 'Roma'),
    CardOptionInput(text: 'Lisboa'),
  ],
);

Finder byKey(String key) => find.byKey(Key(key));

Future<void> tapKey(WidgetTester tester, String key) async {
  await tester.ensureVisible(byKey(key));
  await tester.pumpAndSettle();
  await tester.tap(byKey(key));
  await tester.pumpAndSettle();
}

String textOf(WidgetTester tester, String key) =>
    tester.widget<Text>(byKey(key)).data!;

bool enabled(WidgetTester tester, String key) =>
    tester.widget<ButtonStyleButton>(byKey(key)).onPressed != null;

Future<List<AttemptRow>> attempts(AppDatabase db) =>
    db.select(db.attempts).get();

void main() {
  for (final (name, size) in [('mobile', mobile), ('desktop', desktop)]) {
    testWidgets('unflipped shows "Girar", "Ver respuesta" and "Dejar para el '
        'final"; flipped shows "Acerté" and "Fallé" ($name)', (tester) async {
      await openSession(
        tester,
        size: size,
        cards: [simple('to bring', 'traer')],
      );

      expect(find.text('to bring'), findsOneWidget);
      for (final key in ['session.flip', 'session.reveal', 'session.leave']) {
        expect(byKey(key), findsOneWidget);
      }
      expect(byKey('session.correct'), findsNothing);
      expect(byKey('session.wrong'), findsNothing);

      await tapKey(tester, 'session.flip');

      expect(find.text('traer'), findsOneWidget);
      expect(byKey('session.correct'), findsOneWidget);
      expect(byKey('session.wrong'), findsOneWidget);
      for (final key in ['session.flip', 'session.reveal', 'session.leave']) {
        expect(byKey(key), findsNothing);
      }
    });
  }

  testWidgets('tapping a simple card flips it', (tester) async {
    await openSession(tester, cards: [simple('to bring', 'traer')]);

    await tester.tap(byKey('studyCard'));
    await tester.pumpAndSettle();

    expect(byKey('session.correct'), findsOneWidget);
  });

  testWidgets('in a test card, "Comprobar" is disabled with no selection; '
      'after checking, ✓ and ✗ and "Siguiente" are shown', (tester) async {
    final session = await openSession(tester, cards: [capitalQuestion]);

    expect(enabled(tester, 'session.check'), isFalse);
    await tester.tap(find.text('Roma'));
    await tester.pumpAndSettle();
    expect(enabled(tester, 'session.check'), isTrue);

    await tapKey(tester, 'session.check');

    expect(find.text('Incorrecto'), findsOneWidget);
    expect(find.byIcon(Icons.cancel_rounded), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    expect(byKey('session.next'), findsOneWidget);
    expect(byKey('session.check'), findsNothing);
    final attempt = (await attempts(session.db)).single;
    expect(attempt.result, 'wrong');
    expect(attempt.source, 'test_check');
  });

  testWidgets('swiping right records a correct answer and left a wrong one, '
      'with haptics', (tester) async {
    final haptics = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'HapticFeedback.vibrate') {
          haptics.add('${call.arguments}');
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    final session = await openSession(
      tester,
      cards: [simple('to bring', 'traer'), simple('to seek', 'buscar')],
    );

    await tapKey(tester, 'session.flip');
    await tester.drag(byKey('studyCard'), const Offset(300, 0));
    await tester.pumpAndSettle();
    await tapKey(tester, 'session.flip');
    await tester.drag(byKey('studyCard'), const Offset(-300, 0));
    await tester.pumpAndSettle();

    expect((await attempts(session.db)).map((a) => a.result), [
      'correct',
      'wrong',
    ]);
    expect(haptics, hasLength(2));
  });

  testWidgets('a short drag does not answer', (tester) async {
    final session = await openSession(
      tester,
      cards: [simple('to bring', 'traer')],
    );

    await tapKey(tester, 'session.flip');
    await tester.drag(byKey('studyCard'), const Offset(40, 0));
    await tester.pumpAndSettle();

    expect(await attempts(session.db), isEmpty);
    expect(byKey('session.correct'), findsOneWidget);
  });

  testWidgets('the "n / total" progress, the counters and "+N repasos" '
      'update', (tester) async {
    await openSession(
      tester,
      repeatFailed: true,
      cards: [simple('to bring', 'traer'), simple('to seek', 'buscar')],
    );

    expect(textOf(tester, 'session.progress'), '0 / 2');
    expect(byKey('session.repeats'), findsNothing);

    await tapKey(tester, 'session.flip');
    await tapKey(tester, 'session.wrong');

    expect(textOf(tester, 'session.progress'), '1 / 2');
    expect(textOf(tester, 'session.repeats'), '+1 repaso');
    expect(textOf(tester, 'session.correctCount'), '0');
    expect(textOf(tester, 'session.wrongCount'), '1');

    await tapKey(tester, 'session.flip');
    await tapKey(tester, 'session.correct');

    expect(textOf(tester, 'session.progress'), '2 / 2');
    expect(textOf(tester, 'session.correctCount'), '1');
    // The repeat of the first card is on screen now.
    expect(find.text('to bring'), findsOneWidget);
    expect(textOf(tester, 'session.repeats'), '+1 repaso');
  });

  testWidgets('"Ver respuesta" shows the solution and waits for '
      '"Siguiente"', (tester) async {
    final session = await openSession(
      tester,
      cards: [simple('to bring', 'traer'), simple('to seek', 'buscar')],
    );

    await tapKey(tester, 'session.reveal');

    expect(find.text('traer'), findsOneWidget);
    expect(byKey('session.correct'), findsNothing);
    final attempt = (await attempts(session.db)).single;
    expect((attempt.result, attempt.source), ('wrong', 'revealed'));

    await tapKey(tester, 'session.next');
    expect(find.text('to seek'), findsOneWidget);
  });

  testWidgets('"Dejar para el final" moves the card to the end', (
    tester,
  ) async {
    final session = await openSession(
      tester,
      cards: [simple('to bring', 'traer'), simple('to seek', 'buscar')],
    );

    await tapKey(tester, 'session.leave');

    expect(find.text('to seek'), findsOneWidget);
    expect(await attempts(session.db), isEmpty);
  });

  testWidgets('in reverse, a language card shows its answer first', (
    tester,
  ) async {
    await openSession(
      tester,
      languageDeck: true,
      direction: StudyDirection.reverse,
      cards: [simple('to bring', 'traer')],
    );

    expect(find.text('traer'), findsOneWidget);
    expect(find.text('to bring'), findsNothing);
  });

  testWidgets('a per-question timer shows its time', (tester) async {
    await openSession(
      tester,
      timerType: TimerType.perCard,
      timerSeconds: 30,
      cards: [simple('to bring', 'traer')],
    );

    expect(textOf(tester, 'session.timer'), '0:30');
  });

  testWidgets('answering the last card goes to the results', (tester) async {
    final session = await openSession(
      tester,
      cards: [simple('to bring', 'traer')],
    );

    await tapKey(tester, 'session.flip');
    await tapKey(tester, 'session.correct');

    expect(
      session.router.routerDelegate.currentConfiguration.uri.path,
      AppRoutes.results(session.id),
    );
    final stored = await session.db
        .select(session.db.studySessions)
        .getSingle();
    expect(stored.status, 'completed');
    expect(stored.correctTotal, 1);
  });

  for (final (name, size) in [('mobile', mobile), ('desktop', desktop)]) {
    testWidgets('"Salir" asks for confirmation and goes to the results '
        '($name)', (tester) async {
      final session = await openSession(
        tester,
        size: size,
        cards: [simple('to bring', 'traer'), simple('to seek', 'buscar')],
      );

      await tapKey(tester, 'session.exit');
      expect(find.text('Se guardarán tus respuestas.'), findsOneWidget);
      await tapKey(tester, 'confirmDialog.cancel');
      expect(find.text('to bring'), findsOneWidget);

      await tapKey(tester, 'session.exit');
      await tapKey(tester, 'confirmDialog.confirm');

      expect(
        session.router.routerDelegate.currentConfiguration.uri.path,
        AppRoutes.results(session.id),
      );
      final stored = await session.db
          .select(session.db.studySessions)
          .getSingle();
      expect(stored.status, 'abandoned');
      expect(stored.unansweredTotal, 2);
    });
  }

  group('pause', () {
    for (final (name, size) in [('mobile', mobile), ('desktop', desktop)]) {
      testWidgets('while paused, the card is not visible ($name)', (
        tester,
      ) async {
        await openSession(
          tester,
          size: size,
          cards: [simple('to bring', 'traer')],
        );

        await tapKey(tester, 'session.pause');

        expect(byKey('session.paused'), findsOneWidget);
        expect(find.text('En pausa'), findsOneWidget);
        expect(byKey('studyCard'), findsNothing);
        expect(find.text('to bring'), findsNothing);
        expect(byKey('session.flip'), findsNothing);
        expect(byKey('session.pause'), findsNothing);

        await tapKey(tester, 'session.resume');

        expect(byKey('session.paused'), findsNothing);
        expect(find.text('to bring'), findsOneWidget);
      });
    }

    testWidgets('the pause shows the time studied so far', (tester) async {
      await openSession(tester, cards: [simple('to bring', 'traer')]);

      await tapKey(tester, 'session.pause');

      expect(
        find.text('La tarjeta está oculta.\nTiempo de sesión: 0:00'),
        findsOneWidget,
      );
    });

    testWidgets('sending the app to the background pauses it', (tester) async {
      await openSession(tester, cards: [simple('to bring', 'traer')]);
      // Registered after opening the session, so it runs before the app is
      // removed (tear-downs run last-in, first-out): a hidden app draws no
      // frames, and removing it would wait for ever.
      addTearDown(
        () => tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        ),
      );

      tester.binding
        ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
        ..handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      await tester.pump();
      // A hidden app draws nothing, so the pause shows on coming back,
      // and it stays until "Continuar".
      tester.binding
        ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
        ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(byKey('session.paused'), findsOneWidget);
      expect(find.text('to bring'), findsNothing);
    });

    testWidgets('"Salir de la sesión" asks for confirmation and goes to the '
        'results', (tester) async {
      final session = await openSession(
        tester,
        cards: [simple('to bring', 'traer')],
      );
      await tapKey(tester, 'session.pause');

      await tapKey(tester, 'session.pauseExit');
      expect(find.text('Se guardarán tus respuestas.'), findsOneWidget);
      await tapKey(tester, 'confirmDialog.confirm');

      expect(
        session.router.routerDelegate.currentConfiguration.uri.path,
        AppRoutes.results(session.id),
      );
      final stored = await session.db
          .select(session.db.studySessions)
          .getSingle();
      expect(stored.status, 'abandoned');
    });
  });

  testWidgets('a session that is not in memory any more says so', (
    tester,
  ) async {
    await pumpTestApp(
      tester,
      size: mobile,
      location: AppRoutes.session('missing'),
    );

    expect(find.text('Esta sesión ya no existe'), findsOneWidget);
  });
}
