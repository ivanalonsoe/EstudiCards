import 'package:estudicards/core/random.dart';
import 'package:estudicards/features/cards/domain/flashcard.dart';
import 'package:estudicards/features/study/domain/attempt_record.dart';
import 'package:estudicards/features/study/domain/card_selection.dart';
import 'package:estudicards/features/study/domain/session_event.dart';
import 'package:estudicards/features/study/domain/session_state.dart';
import 'package:estudicards/features/study/domain/study_options.dart';
import 'package:flutter_test/flutter_test.dart';

import 'session_harness.dart';

const repeatFailed = SessionSettings(repeatFailed: true);

void main() {
  group('answering', () {
    test('answering correctly or wrongly moves to the next card and updates '
        'the counters', () {
      final h =
          SessionHarness(
              queueOf([
                simpleCard('one'),
                simpleCard('two'),
                simpleCard('three'),
              ]),
            )
            ..flip()
            ..grade(correct: true);

      expect(h.cardId, 'two');
      expect(h.session.correctCount, 1);
      expect(h.session.wrongCount, 0);

      h
        ..flip()
        ..grade(correct: false);

      expect(h.cardId, 'three');
      expect(h.session.correctCount, 1);
      expect(h.session.wrongCount, 1);
      expect(h.attempts.map((a) => (a.cardId, a.result, a.source)), [
        ('one', AttemptResult.correct, AttemptSource.selfEval),
        ('two', AttemptResult.wrong, AttemptSource.selfEval),
      ]);
      expect(h.attempts.every((a) => a.isFirstAttempt), isTrue);
    });

    test('a test card is graded on "Comprobar", shows the solution and moves '
        'on with "Siguiente"', () {
      final h =
          SessionHarness(
              queueOf([
                testCard('right'),
                testCard('wrong'),
                simpleCard('last'),
              ]),
            )
            ..mark('a')
            ..check();

      expect(h.cardId, 'right');
      expect(h.current.step, isA<Resolved>());
      expect(h.session.correctCount, 1);
      expect(h.attempts.single.source, AttemptSource.testCheck);
      expect(h.attempts.single.selectedOptionIds, {'right-a'});

      h
        ..next()
        ..mark('b')
        ..check();

      expect(h.attempts.last.result, AttemptResult.wrong);
      expect(h.attempts.last.selectedOptionIds, {'wrong-b'});
      expect(h.session.wrongCount, 1);

      h.next();

      expect(h.cardId, 'last');
    });

    test('"Comprobar" does nothing while no option is ticked', () {
      final h = SessionHarness(queueOf([testCard('card')]))..check();

      expect(h.current.step, isA<Answering>());
      expect(h.attempts, isEmpty);
    });

    test('without "allow multiple", ticking an option unticks the previous '
        'one; with it, each tap ticks or unticks', () {
      final single = SessionHarness(queueOf([testCard('single')]))
        ..mark('a')
        ..mark('b');

      expect((single.current.step as Answering).selectedOptionIds, {
        'single-b',
      });

      final multiple =
          SessionHarness(
              queueOf([
                testCard('multi', correct: {'a', 'c'}),
              ]),
            )
            ..mark('a')
            ..mark('b')
            ..mark('c')
            ..mark('b');

      expect((multiple.current.step as Answering).selectedOptionIds, {
        'multi-a',
        'multi-c',
      });
    });

    test('the session completes when no cards remain', () {
      final h = SessionHarness(queueOf([simpleCard('one'), testCard('two')]))
        ..wait(const Duration(seconds: 4))
        ..flip()
        ..grade(correct: true)
        ..wait(const Duration(seconds: 6))
        ..mark('b')
        ..check()
        ..next();

      final finished = h.state as Finished;
      expect(finished.status, SessionStatus.completed);
      expect(finished.correctCount, 1);
      expect(finished.wrongCount, 1);
      expect(finished.unansweredCount, 0);
      expect(finished.activeDuration, const Duration(seconds: 10));
    });

    test('a session with no cards is complete from the start', () {
      final h = SessionHarness(const []);

      expect((h.state as Finished).status, SessionStatus.completed);
    });
  });

  test('"show answer" records a wrong answer with source revealed', () {
    final h = SessionHarness(
      queueOf([simpleCard('simple'), testCard('test'), simpleCard('last')]),
    )..reveal();

    expect(h.current.step, isA<Resolved>());
    expect(h.session.wrongCount, 1);

    h
      ..next()
      ..mark('a')
      ..reveal();

    expect(h.attempts.map((a) => (a.cardId, a.result, a.source)), [
      ('simple', AttemptResult.wrong, AttemptSource.revealed),
      ('test', AttemptResult.wrong, AttemptSource.revealed),
    ]);
    expect(h.session.wrongCount, 2);

    h.next();

    expect(h.cardId, 'last');
  });

  test('"leave for later" moves the card to the end without recording '
      'anything and can be repeated', () {
    final h = SessionHarness(
      queueOf([simpleCard('one'), simpleCard('two'), simpleCard('three')]),
    );
    final shown = <String>[h.cardId];

    h.leaveForLater();
    shown.add(h.cardId);
    h.leaveForLater();
    shown.add(h.cardId);
    h
      ..flip()
      ..grade(correct: true);
    shown.add(h.cardId);
    h.leaveForLater();
    shown.add(h.cardId);

    expect(shown, ['one', 'two', 'three', 'one', 'two']);
    expect(h.attempts.map((a) => a.cardId), ['three']);
  });

  group('"repeat missed"', () {
    test('a missed card comes back at the end until answered correctly, and '
        'the repeat has is_first_attempt = false', () {
      final h =
          SessionHarness(
              queueOf([simpleCard('missed'), simpleCard('known')]),
              settings: repeatFailed,
            )
            ..flip()
            ..grade(correct: false) // missed, first attempt
            ..flip()
            ..grade(correct: true); // known

      expect(h.cardId, 'missed');
      expect(h.current.entry.isRepeat, isTrue);

      h
        ..flip()
        ..grade(correct: false); // missed again: comes back once more

      expect(h.cardId, 'missed');

      h
        ..flip()
        ..grade(correct: true);

      expect(h.state, isA<Finished>());
      expect(h.attempts.map((a) => (a.cardId, a.result, a.isFirstAttempt)), [
        ('missed', AttemptResult.wrong, true),
        ('known', AttemptResult.correct, true),
        ('missed', AttemptResult.wrong, false),
        ('missed', AttemptResult.correct, false),
      ]);
    });

    test('"show answer" also counts as missed', () {
      final h =
          SessionHarness(queueOf([testCard('test')]), settings: repeatFailed)
            ..reveal()
            ..next();

      expect(h.cardId, 'test');
      expect(h.current.entry.isRepeat, isTrue);
    });

    test('without it, a missed card does not come back', () {
      final h = SessionHarness(queueOf([simpleCard('missed')]))
        ..flip()
        ..grade(correct: false);

      expect(h.state, isA<Finished>());
    });
  });

  test('the ✓ and ✗ counters count only first attempts, and the repeats '
      'still to answer show as "+N repasos"', () {
    final h = SessionHarness(
      queueOf([simpleCard('one'), simpleCard('two'), simpleCard('three')]),
      settings: repeatFailed,
    );
    expect(h.session.pendingRepeats, 0);

    h
      ..flip()
      ..grade(correct: false)
      ..flip()
      ..grade(correct: false);

    expect(h.session.pendingRepeats, 2);

    h
      ..flip()
      ..grade(correct: true) // three
      ..flip()
      ..grade(correct: true); // repeat of one

    expect((h.session.correctCount, h.session.wrongCount), (1, 2));
    expect(h.session.pendingRepeats, 1);

    h
      ..flip()
      ..grade(correct: false); // repeat of two, missed again

    expect((h.session.correctCount, h.session.wrongCount), (1, 2));
    expect(h.session.pendingRepeats, 1);
  });

  test('progress counts the original cards answered, not the ones left for '
      'later', () {
    final h = SessionHarness(
      queueOf([simpleCard('one'), simpleCard('two'), simpleCard('three')]),
      settings: repeatFailed,
    );
    expect((h.session.answeredCount, h.session.totalCards), (0, 3));

    h.leaveForLater();
    expect(h.session.answeredCount, 0);

    h
      ..flip()
      ..grade(correct: false)
      ..reveal();
    expect(h.session.answeredCount, 2);

    h
      ..next()
      ..flip()
      ..grade(correct: true) // one
      ..flip()
      ..grade(correct: true); // repeat of two
    expect(h.session.answeredCount, 3);
  });

  group('exit', () {
    test('on exit, pending cards are recorded as unanswered', () {
      final h =
          SessionHarness(
              queueOf([
                simpleCard('answered'),
                simpleCard('left'),
                simpleCard('flipped'),
                testCard('waiting'),
              ]),
            )
            ..flip()
            ..grade(correct: true)
            ..leaveForLater()
            ..flip()
            ..exit();

      final unanswered = h.attempts.skip(1);
      expect(unanswered.map((a) => a.cardId), ['flipped', 'waiting', 'left']);
      for (final attempt in unanswered) {
        expect(attempt.result, AttemptResult.unanswered);
        expect(attempt.source, AttemptSource.sessionEnd);
        expect(attempt.isFirstAttempt, isTrue);
        expect(attempt.responseTime, isNull);
      }
      final finished = h.state as Finished;
      expect(finished.status, SessionStatus.abandoned);
      expect(
        (finished.correctCount, finished.wrongCount, finished.unansweredCount),
        (1, 0, 3),
      );
    });

    test('pending repeats are not recorded: only original cards end up '
        'unanswered', () {
      final h =
          SessionHarness(
              queueOf([simpleCard('missed'), simpleCard('pending')]),
              settings: repeatFailed,
            )
            ..flip()
            ..grade(correct: false)
            ..exit();

      expect(h.attempts.map((a) => (a.cardId, a.result)), [
        ('missed', AttemptResult.wrong),
        ('pending', AttemptResult.unanswered),
      ]);
      expect((h.state as Finished).unansweredCount, 1);
    });

    test('a repeat on screen is not recorded either', () {
      final h =
          SessionHarness(
              queueOf([simpleCard('missed')]),
              settings: repeatFailed,
            )
            ..flip()
            ..grade(correct: false)
            ..exit();

      expect(h.attempts, hasLength(1));
      expect((h.state as Finished).unansweredCount, 0);
    });

    test('a card already answered on screen is not recorded again', () {
      final h = SessionHarness(queueOf([testCard('test')]))
        ..mark('a')
        ..check()
        ..exit();

      expect(h.attempts.single.source, AttemptSource.testCheck);
    });

    test('works from the pause too', () {
      final h = SessionHarness(queueOf([simpleCard('one')]))
        ..pause()
        ..exit();

      expect((h.state as Finished).status, SessionStatus.abandoned);
      expect(h.attempts.single.result, AttemptResult.unanswered);
    });
  });

  test('in reverse direction, test cards and the cards of general decks are '
      'recorded as normal; simple cards of language decks as reverse', () {
    final cards = selectCards(
      [
        StudyCandidate(
          card: simpleCard('language simple'),
          isLanguageDeck: true,
        ),
        StudyCandidate(card: testCard('language test'), isLanguageDeck: true),
        StudyCandidate(
          card: simpleCard('general simple'),
          isLanguageDeck: false,
        ),
      ],
      mode: StudyMode.normal,
      direction: StudyDirection.reverse,
      random: createRandom(seed: 1),
    );
    final h = SessionHarness(cards);

    while (h.state is InProgress) {
      if (h.current.card.type == CardType.test) {
        h
          ..reveal()
          ..next();
      } else {
        h
          ..flip()
          ..grade(correct: true);
      }
    }

    expect(
      {for (final a in h.attempts) a.cardId: a.direction},
      {
        'language simple': StudyDirection.reverse,
        'language test': StudyDirection.normal,
        'general simple': StudyDirection.normal,
      },
    );
  });

  group('pause', () {
    test('the response time runs from when the card is shown and excludes '
        'pauses', () {
      final h = SessionHarness(queueOf([simpleCard('one')]))
        ..wait(const Duration(seconds: 5))
        ..pause()
        ..wait(const Duration(minutes: 1))
        ..resume()
        ..wait(const Duration(seconds: 3))
        ..flip()
        ..wait(const Duration(seconds: 2))
        ..grade(correct: true);

      expect(h.attempts.single.responseTime, const Duration(seconds: 10));
      expect((h.state as Finished).activeDuration, const Duration(seconds: 10));
    });

    test('resuming goes back to the card exactly as it was', () {
      final h = SessionHarness(queueOf([simpleCard('one'), simpleCard('two')]))
        ..flip()
        ..pause();

      expect(h.state, isA<Paused>());

      h.resume();

      expect(h.cardId, 'one');
      expect(h.current.step, isA<Flipped>());
    });

    test('card events are ignored while paused', () {
      final h = SessionHarness(queueOf([simpleCard('one')]));
      final turn = h.turn;
      h
        ..pause()
        ..send(Flip(turn: turn))
        ..send(RevealAnswer(turn: turn));

      expect(h.state, isA<Paused>());
      expect(h.attempts, isEmpty);
    });
  });

  group('events that do not apply', () {
    test('are ignored and change nothing', () {
      final h =
          SessionHarness(queueOf([simpleCard('simple'), testCard('test')]))
            ..grade(correct: true) // not flipped yet
            ..next(); // nothing to move on from

      expect(h.cardId, 'simple');
      expect(h.current.step, isA<Answering>());
      expect(h.attempts, isEmpty);

      h
        ..flip()
        ..grade(correct: true)
        ..flip(); // a test card does not flip

      expect(h.current.step, isA<Answering>());
    });

    test('a late double tap does not act on the next card', () {
      final h = SessionHarness(
        queueOf([simpleCard('one'), simpleCard('two'), simpleCard('three')]),
      );
      final firstTurn = h.turn;

      h
        ..send(LeaveForLater(turn: firstTurn))
        ..send(LeaveForLater(turn: firstTurn));

      expect(h.cardId, 'two');
    });
  });

  test('test options are shuffled each time the card is shown', () {
    final h = SessionHarness(queueOf([testCard('test')]));
    final orders = <String>{};

    for (var i = 0; i < 20; i++) {
      expect(
        h.current.options.map((o) => o.id),
        unorderedEquals(['test-a', 'test-b', 'test-c', 'test-d']),
      );
      orders.add(h.current.options.map((o) => o.id).join(','));
      h.leaveForLater();
    }

    expect(orders.length, greaterThan(1));
    expect(h.current.card.options.first.id, 'test-a');
  });
}
