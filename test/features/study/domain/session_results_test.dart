import 'package:estudicards/core/random.dart';
import 'package:estudicards/features/cards/domain/flashcard.dart';
import 'package:estudicards/features/study/domain/attempt_record.dart';
import 'package:estudicards/features/study/domain/session_config.dart';
import 'package:estudicards/features/study/domain/session_results.dart';
import 'package:estudicards/features/study/domain/session_state.dart';
import 'package:estudicards/features/study/domain/study_options.dart';
import 'package:flutter_test/flutter_test.dart';

import 'session_harness.dart';

AttemptRecord attempt(
  String cardId,
  AttemptResult result, {
  bool isFirstAttempt = true,
  int? seconds,
  StudyDirection direction = StudyDirection.normal,
}) => AttemptRecord(
  cardId: cardId,
  direction: direction,
  result: result,
  source: result == AttemptResult.unanswered
      ? AttemptSource.sessionEnd
      : AttemptSource.selfEval,
  isFirstAttempt: isFirstAttempt,
  responseTime: seconds == null ? null : Duration(seconds: seconds),
  answeredAt: sessionStart,
);

SessionResults results({
  int correct = 0,
  int wrong = 0,
  int unanswered = 0,
  SessionStatus status = SessionStatus.completed,
  List<AttemptRecord> attempts = const [],
  List<Flashcard> cards = const [],
  SessionConfig config = const SessionConfig(deckIds: ['deck']),
}) => SessionResults(
  sessionId: 'session',
  projectId: 'project',
  projectName: 'Inglés B2',
  deckNames: const ['Verbos irregulares'],
  config: config,
  status: status,
  correctCount: correct,
  wrongCount: wrong,
  unansweredCount: unanswered,
  activeDuration: const Duration(minutes: 6, seconds: 12),
  attempts: attempts,
  cards: {for (final card in cards) card.id: card},
);

void main() {
  group('% correct and celebration', () {
    test('rounds the % as it is shown and counts the total of cards', () {
      final shown = results(correct: 15, wrong: 4, unanswered: 1);

      expect(shown.correctPercent, 79);
      expect(shown.totalCards, 20);
    });

    test('celebrates from 80%: 79% gives "Sesión terminada"', () {
      final eighty = results(correct: 4, wrong: 1);
      final seventyNine = results(correct: 15, wrong: 4);

      expect(eighty.celebrates, isTrue);
      expect(eighty.headline, ResultsHeadline.goodJob);
      expect(seventyNine.celebrates, isFalse);
      expect(seventyNine.headline, ResultsHeadline.finished);
    });

    test('with no answers there is no % and no celebration', () {
      final empty = results(unanswered: 3);

      expect(empty.correctPercent, isNull);
      expect(empty.celebrates, isFalse);
      expect(empty.headline, ResultsHeadline.finished);
    });

    test('a session that ran out of time says so, whatever the %', () {
      final timeUp = results(
        correct: 9,
        wrong: 1,
        unanswered: 5,
        status: SessionStatus.timeUp,
      );

      expect(timeUp.headline, ResultsHeadline.timeUp);
      expect(timeUp.celebrates, isTrue);
    });
  });

  test('the average time counts the answered first attempts only', () {
    final shown = results(
      attempts: [
        attempt('a', AttemptResult.correct, seconds: 10),
        attempt('b', AttemptResult.wrong, seconds: 20),
        attempt('b', AttemptResult.correct, seconds: 90, isFirstAttempt: false),
        attempt('c', AttemptResult.unanswered),
      ],
    );

    expect(shown.averageResponseTime, const Duration(seconds: 15));
    expect(results().averageResponseTime, isNull);
  });

  test('lists the missed and the unanswered cards, in the order they were '
      'answered and in their direction, leaving out deleted cards', () {
    final shown = results(
      cards: [
        simpleCard('one'),
        simpleCard('two'),
        simpleCard('three'),
        simpleCard('four'),
      ],
      attempts: [
        attempt('two', AttemptResult.wrong, direction: StudyDirection.reverse),
        attempt('one', AttemptResult.correct),
        attempt('four', AttemptResult.wrong),
        attempt('two', AttemptResult.wrong, isFirstAttempt: false),
        attempt('deleted', AttemptResult.wrong),
        attempt('three', AttemptResult.unanswered),
      ],
    );

    expect(shown.missed.map((m) => (m.card.id, m.direction)), [
      ('two', StudyDirection.reverse),
      ('four', StudyDirection.normal),
    ]);
    expect(shown.unanswered.map((u) => u.card.id), ['three']);
  });

  group('"Repasar falladas ahora"', () {
    test('keeps the decks, the direction, the timer and "repeat missed"; '
        'asks for exactly the missed cards', () {
      final shown = results(
        config: const SessionConfig(
          deckIds: ['deck', 'other'],
          mode: StudyMode.errors,
          direction: StudyDirection.reverse,
          requestedCount: 50,
          prioritizeFailed: true,
          repeatFailed: true,
          timerType: TimerType.perCard,
          timerSeconds: 30,
        ),
        cards: [simpleCard('one'), simpleCard('two')],
        attempts: [
          attempt('one', AttemptResult.wrong),
          attempt('two', AttemptResult.wrong),
        ],
      );

      final config = shown.reviewConfig;
      expect(config.deckIds, ['deck', 'other']);
      expect(config.mode, StudyMode.normal);
      expect(config.direction, StudyDirection.reverse);
      expect(config.requestedCount, 2);
      expect(config.prioritizeFailed, isFalse);
      expect(config.repeatFailed, isTrue);
      expect(config.timerType, TimerType.perCard);
      expect(config.timerSeconds, 30);
    });

    test('reviews only the missed cards, shuffled', () {
      final ids = [for (var i = 0; i < 10; i++) 'card-$i'];
      final shown = results(
        cards: [for (final id in ids) simpleCard(id)],
        attempts: [
          for (final id in ids) attempt(id, AttemptResult.wrong),
          attempt('extra', AttemptResult.correct),
        ],
      );

      final queue = shown.reviewQueue(createRandom(seed: 1));

      expect(queue.map((c) => c.card.id), unorderedEquals(ids));
      expect(queue.map((c) => c.card.id), isNot(ids));
    });
  });
}
