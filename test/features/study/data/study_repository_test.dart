import 'dart:convert';

import 'package:drift/native.dart';
import 'package:estudicards/core/clock.dart';
import 'package:estudicards/core/db/app_database.dart';
import 'package:estudicards/core/random.dart';
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
import 'package:estudicards/features/projects/domain/project.dart';
import 'package:estudicards/features/projects/domain/project_input.dart';
import 'package:estudicards/features/study/data/study_dao.dart';
import 'package:estudicards/features/study/data/study_repository.dart';
import 'package:estudicards/features/study/domain/attempt_record.dart';
import 'package:estudicards/features/study/domain/card_selection.dart';
import 'package:estudicards/features/study/domain/session_config.dart';
import 'package:estudicards/features/study/domain/session_engine.dart';
import 'package:estudicards/features/study/domain/session_event.dart';
import 'package:estudicards/features/study/domain/session_state.dart';
import 'package:estudicards/features/study/domain/study_options.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_image_files.dart';

/// A session being played: its ID, a way to send events and the turn of
/// the card on screen.
typedef PlayedSession = ({
  String id,
  Future<void> Function(SessionEvent event) send,
  int Function() turn,
});

void main() {
  late AppDatabase db;
  late FakeClock clock;
  late StudyRepository repository;
  late Project project;
  late Deck deck;
  late Deck otherDeck;
  late List<Flashcard> cards;
  final start = DateTime.utc(2026, 10, 13, 9);

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    clock = FakeClock(start);
    repository = StudyRepository(StudyDao(db), clock);
    project = await ProjectsRepository(ProjectsDao(db), clock).create(
      const ProjectInput(name: 'Inglés B2', color: 'blue', icon: 'globe'),
    );
    final decks = DecksRepository(DecksDao(db), clock);
    deck = await decks.create(project.id, const DeckInput(name: 'Verbos'));
    otherDeck = await decks.create(project.id, const DeckInput(name: 'Viajes'));
    final cardsRepository = CardsRepository(
      CardsDao(db),
      clock,
      FakeImageFiles(),
    );
    cards = [
      for (final word in ['to bring', 'to seek', 'to bear'])
        await cardsRepository.create(
          deck.id,
          CardInput(type: CardType.simple, question: word, answer: 'x'),
        ),
      await cardsRepository.create(
        deck.id,
        const CardInput(
          type: CardType.test,
          question: '¿Cuál es correcta?',
          options: [
            CardOptionInput(text: 'A', isCorrect: true),
            CardOptionInput(text: 'B'),
          ],
        ),
      ),
    ];
  });

  tearDown(() => db.close());

  /// Plays a session the way the session screen will: each event is
  /// applied at the clock's time and its step is saved at once.
  Future<PlayedSession> startPlaying(
    List<Flashcard> queue,
    SessionConfig config,
  ) async {
    final engine = SessionEngine(random: createRandom(seed: 1));
    final id = await repository.startSession(project.id, config);
    var state = engine
        .start(
          cards: [
            for (final card in queue)
              SelectedCard(card: card, direction: StudyDirection.normal),
          ],
          settings: config.settings,
          at: clock.now(),
        )
        .state;
    Future<void> send(SessionEvent event) async {
      final step = engine.apply(state, event, at: clock.now());
      state = step.state;
      await repository.record(id, step);
    }

    return (id: id, send: send, turn: () => (state as InProgress).current.turn);
  }

  Future<List<AttemptRow>> storedAttempts() => db.select(db.attempts).get();

  Future<StudySessionRow> storedSession(String id) =>
      (db.select(db.studySessions)..where((s) => s.id.equals(id))).getSingle();

  test('starting a session saves it in progress with its configuration and '
      'decks, and marks the project and the decks as used', () async {
    clock.advance(const Duration(hours: 1));

    final id = await repository.startSession(
      project.id,
      SessionConfig(
        deckIds: [deck.id, otherDeck.id],
        mode: StudyMode.errors,
        direction: StudyDirection.reverse,
        requestedCount: 20,
        prioritizeFailed: true,
        repeatFailed: true,
        timerType: TimerType.perCard,
        timerSeconds: 30,
      ),
    );

    final session = await storedSession(id);
    expect(session.projectId, project.id);
    expect(session.status, 'in_progress');
    expect(session.mode, 'errors');
    expect(session.direction, 'reverse');
    expect(session.requestedCount, 20);
    expect(session.prioritizeFailed, isTrue);
    expect(session.repeatFailed, isTrue);
    expect(session.timerType, 'per_card');
    expect(session.timerSeconds, 30);
    expect(session.startedAt, clock.now());
    expect(session.endedAt, isNull);
    final sessionDecks = await db.select(db.sessionDecks).get();
    expect(
      sessionDecks.map((d) => d.deckId),
      unorderedEquals([deck.id, otherDeck.id]),
    );
    final projectRow = await db.select(db.projects).getSingle();
    expect(projectRow.lastUsedAt, clock.now());
    final deckRows = await db.select(db.decks).get();
    expect(deckRows.every((d) => d.lastUsedAt == clock.now()), isTrue);
  });

  test('answering saves an attempt with the response time, excluding '
      'pauses', () async {
    final session = await startPlaying([
      cards[0],
      cards[3],
    ], SessionConfig(deckIds: [deck.id]));

    clock.advance(const Duration(seconds: 5));
    await session.send(const Pause());
    clock.advance(const Duration(minutes: 10));
    await session.send(const Resume());
    clock.advance(const Duration(seconds: 3));
    await session.send(Flip(turn: session.turn()));
    clock.advance(const Duration(seconds: 2));
    await session.send(SelfGrade(turn: session.turn(), correct: true));

    final attempt = (await storedAttempts()).single;
    expect(attempt.sessionId, session.id);
    expect(attempt.cardId, cards[0].id);
    expect(attempt.direction, 'normal');
    expect(attempt.result, 'correct');
    expect(attempt.source, 'self_eval');
    expect(attempt.isFirstAttempt, isTrue);
    expect(attempt.responseTimeMs, 10000);
    expect(attempt.answeredAt, clock.now());
    expect(attempt.selectedOptionIds, isNull);

    final optionA = cards[3].options.first.id;
    await session.send(ToggleOption(turn: session.turn(), optionId: optionA));
    await session.send(Check(turn: session.turn()));

    final testAttempt = (await storedAttempts()).last;
    expect(testAttempt.source, 'test_check');
    expect(jsonDecode(testAttempt.selectedOptionIds!), [optionA]);
  });

  test('if the app "closes" midway (the engine is discarded), the answered '
      'attempts are in the database', () async {
    final session = await startPlaying(
      cards.take(3).toList(),
      SessionConfig(deckIds: [deck.id]),
    );
    await session.send(RevealAnswer(turn: session.turn()));
    await session.send(Next(turn: session.turn()));
    await session.send(Flip(turn: session.turn()));
    await session.send(SelfGrade(turn: session.turn(), correct: true));
    // The engine is dropped here: no exit, no end of session.

    final attempts = await storedAttempts();
    expect(attempts.map((a) => (a.cardId, a.result, a.source)), [
      (cards[0].id, 'wrong', 'revealed'),
      (cards[1].id, 'correct', 'self_eval'),
    ]);
    final stored = await storedSession(session.id);
    expect(stored.status, 'in_progress');
    expect(stored.endedAt, isNull);
  });

  test('session totals only count first attempts', () async {
    final session = await startPlaying(
      cards.take(3).toList(),
      SessionConfig(deckIds: [deck.id], repeatFailed: true),
    );

    clock.advance(const Duration(seconds: 4));
    await session.send(Flip(turn: session.turn()));
    await session.send(SelfGrade(turn: session.turn(), correct: false));
    clock.advance(const Duration(seconds: 4));
    await session.send(Flip(turn: session.turn()));
    await session.send(SelfGrade(turn: session.turn(), correct: true));
    // The third card is left for later: next comes the repeat of the first.
    await session.send(LeaveForLater(turn: session.turn()));
    clock.advance(const Duration(seconds: 2));
    await session.send(Flip(turn: session.turn()));
    await session.send(SelfGrade(turn: session.turn(), correct: true));
    await session.send(const Exit());

    final stored = await storedSession(session.id);
    expect(stored.status, 'abandoned');
    expect(stored.correctTotal, 1);
    expect(stored.wrongTotal, 1);
    expect(stored.unansweredTotal, 1);
    expect(stored.endedAt, clock.now());
    expect(stored.activeDurationMs, 10000);
    expect(await storedAttempts(), hasLength(4));
  });

  group('results', () {
    test('reads the session with its project, decks, configuration, totals, '
        'attempts and cards', () async {
      final session = await startPlaying(
        [cards[3], cards[0], cards[1]],
        SessionConfig(
          deckIds: [otherDeck.id, deck.id],
          direction: StudyDirection.reverse,
          requestedCount: 3,
          repeatFailed: true,
          timerType: TimerType.perCard,
          timerSeconds: 30,
        ),
      );
      clock.advance(const Duration(seconds: 6));
      await session.send(RevealAnswer(turn: session.turn()));
      await session.send(Next(turn: session.turn()));
      clock.advance(const Duration(seconds: 4));
      await session.send(Flip(turn: session.turn()));
      await session.send(SelfGrade(turn: session.turn(), correct: true));
      await session.send(const Exit());

      final results = (await repository.results(session.id))!;

      expect(results.projectId, project.id);
      expect(results.projectName, 'Inglés B2');
      expect(results.deckNames, ['Verbos', 'Viajes']);
      expect(results.config.deckIds, unorderedEquals([deck.id, otherDeck.id]));
      expect(results.config.direction, StudyDirection.reverse);
      expect(results.config.mode, StudyMode.normal);
      expect(results.config.requestedCount, 3);
      expect(results.config.repeatFailed, isTrue);
      expect(results.config.timerType, TimerType.perCard);
      expect(results.config.timerSeconds, 30);
      expect(results.status, SessionStatus.abandoned);
      expect(
        (results.correctCount, results.wrongCount, results.unansweredCount),
        (1, 1, 1),
      );
      expect(results.activeDuration, const Duration(seconds: 10));
      expect(results.attempts.map((a) => (a.cardId, a.result, a.source)), [
        (cards[3].id, AttemptResult.wrong, AttemptSource.revealed),
        (cards[0].id, AttemptResult.correct, AttemptSource.selfEval),
        (cards[1].id, AttemptResult.unanswered, AttemptSource.sessionEnd),
      ]);
      expect(results.attempts.first.responseTime, const Duration(seconds: 6));
      expect(results.attempts.first.selectedOptionIds, isEmpty);
      expect(results.missed.single.card.options, hasLength(2));
      expect(results.unanswered.single.card.question, 'to seek');
    });

    test('a session still in progress has no status yet', () async {
      final session = await startPlaying(
        cards.take(1).toList(),
        SessionConfig(deckIds: [deck.id]),
      );

      expect((await repository.results(session.id))!.status, isNull);
    });

    test('an unknown session has no results', () async {
      expect(await repository.results('missing'), isNull);
    });
  });

  test('a session that runs out of time is saved as time_up', () async {
    final session = await startPlaying(
      cards.take(2).toList(),
      SessionConfig(
        deckIds: [deck.id],
        timerType: TimerType.global,
        timerSeconds: 60,
      ),
    );

    clock.advance(const Duration(minutes: 1));
    await session.send(const Tick());

    final stored = await storedSession(session.id);
    expect(stored.status, 'time_up');
    expect(stored.unansweredTotal, 2);
  });
}
