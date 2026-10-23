// Timers (R 7.5) through `SessionRunner`, with `fake_async`: inside
// `fakeAsync`, `async.elapse(…)` moves the timers and the clock forward at
// once, so no test waits for real.
import 'package:estudicards/core/random.dart';
import 'package:estudicards/features/study/domain/attempt_record.dart';
import 'package:estudicards/features/study/domain/session_engine.dart';
import 'package:estudicards/features/study/domain/session_event.dart';
import 'package:estudicards/features/study/domain/session_runner.dart';
import 'package:estudicards/features/study/domain/session_state.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_async_clock.dart';
import 'session_harness.dart';

const seconds = Duration(seconds: 1);

SessionSettings perQuestion(int limitSeconds) => SessionSettings(
  timerType: TimerType.perCard,
  timerLimit: Duration(seconds: limitSeconds),
);

SessionSettings global(Duration limit) =>
    SessionSettings(timerType: TimerType.global, timerLimit: limit);

/// A running session plus every answer it handed over.
class Run {
  new(FakeAsync async, List<String> cardIds, SessionSettings settings)
    : clock = FakeAsyncClock(async, sessionStart) {
    runner = SessionRunner(
      engine: SessionEngine(random: createRandom(seed: 1)),
      clock: clock,
      cards: queueOf([
        for (final id in cardIds)
          if (id.startsWith('test')) testCard(id) else simpleCard(id),
      ]),
      settings: settings,
      onStep: (step) => attempts.addAll(step.attempts),
    );
  }

  final FakeAsyncClock clock;
  late final SessionRunner runner;
  final attempts = <AttemptRecord>[];

  SessionState get state => runner.state;
  InProgress get session => switch (state) {
    final InProgress session => session,
    Paused(:final session) => session,
    _ => throw StateError('The session has finished'),
  };
  CurrentCard get current => session.current;
  int get turn => current.turn;
  Duration? get questionTimeLeft => session.questionTimeLeft(clock.now());
  Duration? get sessionTimeLeft => session.sessionTimeLeft(clock.now());
  bool get isTimeRunningOut => session.isTimeRunningOut(clock.now());

  void send(SessionEvent event) => runner.send(event);
}

void main() {
  group('per question', () {
    test('reaching 0 records a wrong answer with source timeout', () {
      fakeAsync((async) {
        final run = Run(async, ['one', 'two'], perQuestion(10));

        async.elapse(seconds * 9);
        expect(run.attempts, isEmpty);
        expect(run.questionTimeLeft, seconds);

        async.elapse(seconds);
        final attempt = run.attempts.single;
        expect(attempt.cardId, 'one');
        expect(attempt.result, AttemptResult.wrong);
        expect(attempt.source, AttemptSource.timeout);
        expect(attempt.responseTime, seconds * 10);
        expect(attempt.answeredAt, sessionStart.add(seconds * 10));
        // The card shows its back and waits for "Siguiente".
        expect(run.current.step, isA<Resolved>());
        expect(run.questionTimeLeft, Duration.zero);

        run.runner.dispose();
      });
    });

    test('a test card that runs out records the options ticked so far', () {
      fakeAsync((async) {
        final run = Run(async, ['test'], perQuestion(5))
          ..send(const Flip(turn: 1)) // ignored: test cards do not flip
          ..send(const ToggleOption(turn: 1, optionId: 'test-c'));

        async.elapse(seconds * 5);

        expect(run.attempts.single.source, AttemptSource.timeout);
        expect(run.attempts.single.selectedOptionIds, {'test-c'});
        run.runner.dispose();
      });
    });

    test('"leave for later" restarts its time when the card comes back', () {
      fakeAsync((async) {
        final run = Run(async, ['one', 'two'], perQuestion(10));

        async.elapse(seconds * 8);
        run.send(LeaveForLater(turn: run.turn));
        async.elapse(seconds * 3);
        run
          ..send(Flip(turn: run.turn))
          ..send(SelfGrade(turn: run.turn, correct: true));

        expect(run.current.card.id, 'one');
        expect(run.questionTimeLeft, seconds * 10);

        async.elapse(seconds * 9);
        expect(run.attempts.map((a) => a.cardId), ['two']);

        async.elapse(seconds);
        expect(run.attempts.last.source, AttemptSource.timeout);
        run.runner.dispose();
      });
    });

    test('stops when a simple card is flipped; the response time keeps '
        'counting until "Acerté" or "Fallé"', () {
      fakeAsync((async) {
        final run = Run(async, ['one', 'two'], perQuestion(10));

        async.elapse(seconds * 8);
        run.send(Flip(turn: run.turn));
        async.elapse(seconds * 30);

        expect(run.attempts, isEmpty);
        expect(run.questionTimeLeft, seconds * 2);

        run.send(SelfGrade(turn: run.turn, correct: true));

        expect(run.attempts.single.result, AttemptResult.correct);
        expect(run.attempts.single.source, AttemptSource.selfEval);
        expect(run.attempts.single.responseTime, seconds * 38);
        run.runner.dispose();
      });
    });

    test('stops on "Comprobar" and on "No sé la respuesta"', () {
      fakeAsync((async) {
        final run = Run(async, ['test', 'simple'], perQuestion(10));

        async.elapse(seconds * 4);
        run
          ..send(ToggleOption(turn: run.turn, optionId: 'test-a'))
          ..send(Check(turn: run.turn));
        async.elapse(seconds * 20);

        expect(run.attempts.single.source, AttemptSource.testCheck);
        expect(run.questionTimeLeft, seconds * 6);

        run.send(Next(turn: run.turn));
        async.elapse(seconds * 7);
        run.send(RevealAnswer(turn: run.turn));
        async.elapse(seconds * 20);

        expect(run.attempts.map((a) => a.source), [
          AttemptSource.testCheck,
          AttemptSource.revealed,
        ]);
        expect(run.questionTimeLeft, seconds * 3);
        run.runner.dispose();
      });
    });
  });

  group('global', () {
    test('reaching 0 ends the session with status time_up and pending cards '
        'as unanswered', () {
      fakeAsync((async) {
        final run = Run(async, [
          'one',
          'two',
          'three',
        ], global(const Duration(minutes: 1)));

        async.elapse(seconds * 20);
        run
          ..send(Flip(turn: run.turn))
          ..send(SelfGrade(turn: run.turn, correct: true));
        async.elapse(seconds * 39);
        expect(run.state, isA<InProgress>());
        expect(run.sessionTimeLeft, seconds);

        async.elapse(seconds);

        final finished = run.state as Finished;
        expect(finished.status, SessionStatus.timeUp);
        expect(finished.activeDuration, const Duration(minutes: 1));
        expect(finished.unansweredCount, 2);
        final unanswered = run.attempts.skip(1);
        expect(unanswered.map((a) => (a.cardId, a.result)), [
          ('two', AttemptResult.unanswered),
          ('three', AttemptResult.unanswered),
        ]);
        expect(
          unanswered.every(
            (a) => a.answeredAt == sessionStart.add(const Duration(minutes: 1)),
          ),
          isTrue,
        );
        // The runner stops ticking once the session is over.
        expect(async.pendingTimers, isEmpty);
      });
    });

    test('there is no per-question time limit', () {
      fakeAsync((async) {
        final run = Run(async, ['one'], global(const Duration(minutes: 5)));

        async.elapse(const Duration(minutes: 4));

        expect(run.attempts, isEmpty);
        expect(run.questionTimeLeft, isNull);
        run.runner.dispose();
      });
    });
  });

  group('time does not advance while paused', () {
    test('per question', () {
      fakeAsync((async) {
        final run = Run(async, ['one'], perQuestion(10));

        async.elapse(seconds * 4);
        run.send(const Pause());
        async.elapse(const Duration(hours: 1));

        expect(run.attempts, isEmpty);
        expect(run.questionTimeLeft, seconds * 6);

        run.send(const Resume());
        async.elapse(seconds * 5);
        expect(run.attempts, isEmpty);

        async.elapse(seconds);
        expect(run.attempts.single.source, AttemptSource.timeout);
        expect(run.attempts.single.responseTime, seconds * 10);
        run.runner.dispose();
      });
    });

    test('global', () {
      fakeAsync((async) {
        final run = Run(async, ['one'], global(const Duration(minutes: 1)));

        async.elapse(seconds * 30);
        run.send(const Pause());
        async.elapse(const Duration(hours: 1));

        expect(run.state, isA<Paused>());
        expect(run.sessionTimeLeft, seconds * 30);

        run.send(const Resume());
        async.elapse(seconds * 30);

        expect((run.state as Finished).status, SessionStatus.timeUp);
      });
    });
  });

  group('the warning turns on', () {
    test('in the last 5 s of the per-question timer', () {
      fakeAsync((async) {
        final run = Run(async, ['one'], perQuestion(30));

        async.elapse(seconds * 24);
        expect(run.isTimeRunningOut, isFalse);

        async.elapse(seconds);
        expect(run.isTimeRunningOut, isTrue);
        run.runner.dispose();
      });
    });

    test('in the last minute of the global timer', () {
      fakeAsync((async) {
        final run = Run(async, ['one'], global(const Duration(minutes: 5)));

        async.elapse(const Duration(minutes: 3, seconds: 59));
        expect(run.isTimeRunningOut, isFalse);

        async.elapse(seconds);
        expect(run.isTimeRunningOut, isTrue);
        run.runner.dispose();
      });
    });

    test('a tick without a timer changes nothing', () {
      final h = SessionHarness(queueOf([simpleCard('one')]))
        ..wait(const Duration(hours: 3))
        ..send(const Tick());

      expect(h.current.step, isA<Answering>());
      expect(h.attempts, isEmpty);
    });

    test('never without a timer', () {
      fakeAsync((async) {
        final run = Run(async, ['one'], const SessionSettings());

        async.elapse(const Duration(hours: 3));

        expect(run.isTimeRunningOut, isFalse);
        expect(run.questionTimeLeft, isNull);
        expect(run.sessionTimeLeft, isNull);
        expect(run.attempts, isEmpty);
        run.runner.dispose();
        expect(async.pendingTimers, isEmpty);
      });
    });
  });
}
