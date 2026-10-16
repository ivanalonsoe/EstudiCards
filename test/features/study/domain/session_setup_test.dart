import 'package:estudicards/features/cards/domain/flashcard.dart';
import 'package:estudicards/features/decks/domain/deck.dart';
import 'package:estudicards/features/study/domain/card_selection.dart';
import 'package:estudicards/features/study/domain/session_config.dart';
import 'package:estudicards/features/study/domain/session_setup.dart';
import 'package:estudicards/features/study/domain/session_state.dart';
import 'package:estudicards/features/study/domain/study_options.dart';
import 'package:flutter_test/flutter_test.dart';

final _start = DateTime.utc(2026, 10, 14);

Deck deck(
  String id, {
  DeckType type = DeckType.general,
  String? sourceLang,
  String? targetLang,
}) => Deck(
  id: id,
  projectId: 'project',
  name: 'Deck $id',
  color: 'blue',
  inheritsColor: true,
  type: type,
  sourceLang: sourceLang,
  targetLang: targetLang,
  createdAt: _start,
  updatedAt: _start,
);

Deck languageDeck(
  String id, [
  String source = 'en-GB',
  String target = 'es-ES',
]) => deck(id, type: DeckType.language, sourceLang: source, targetLang: target);

StudyCandidate candidate(String id, String deckId, {bool inErrors = false}) =>
    StudyCandidate(
      card: Flashcard(
        id: id,
        deckId: deckId,
        type: CardType.simple,
        question: 'Question $id',
        answer: 'Answer $id',
        allowMultiple: false,
        createdAt: _start,
        updatedAt: _start,
      ),
      isLanguageDeck: false,
      normalStats: DirectionStats(inErrorList: inErrors, studied: inErrors),
    );

void main() {
  final decks = [deck('a'), deck('b'), languageDeck('c')];

  group('initial form', () {
    test('without a last configuration, uses every deck and the defaults', () {
      final form = SetupForm.initial(decks: decks);

      expect(form.deckIds, ['a', 'b', 'c']);
      expect(form.count, 20);
      expect(form.customCount, isFalse);
      expect(form.mode, StudyMode.normal);
      expect(form.direction, StudyDirection.normal);
      expect(form.prioritizeFailed, isFalse);
      expect(form.repeatFailed, isFalse);
      expect(form.timerType, TimerType.none);
      expect(form.questionSeconds, 30);
      expect(form.sessionMinutes, 10);
    });

    test('loads the last configuration used in the project', () {
      final form = SetupForm.initial(
        decks: decks,
        last: const SessionConfig(
          deckIds: ['b', 'c'],
          mode: StudyMode.errors,
          direction: StudyDirection.reverse,
          requestedCount: 50,
          prioritizeFailed: true,
          repeatFailed: true,
          timerType: TimerType.perCard,
          timerSeconds: 45,
        ),
      );

      expect(form.deckIds, ['b', 'c']);
      expect(form.count, 50);
      expect(form.customCount, isFalse);
      expect(form.mode, StudyMode.errors);
      expect(form.direction, StudyDirection.reverse);
      expect(form.prioritizeFailed, isTrue);
      expect(form.repeatFailed, isTrue);
      expect(form.timerType, TimerType.perCard);
      expect(form.questionSeconds, 45);
      expect(form.sessionMinutes, 10);
    });

    test('a count that is not 10, 20, 50 or all is a custom one', () {
      final form = SetupForm.initial(
        decks: decks,
        last: const SessionConfig(deckIds: ['a'], requestedCount: 7),
      );

      expect(form.count, 7);
      expect(form.customCount, isTrue);
    });

    test('a global timer keeps its minutes', () {
      final form = SetupForm.initial(
        decks: decks,
        last: const SessionConfig(
          deckIds: ['a'],
          timerType: TimerType.global,
          timerSeconds: 25 * 60,
        ),
      );

      expect(form.sessionMinutes, 25);
      expect(form.questionSeconds, 30);
    });

    test('drops decks that no longer exist, or uses every deck if none '
        'is left', () {
      expect(
        SetupForm.initial(
          decks: decks,
          last: const SessionConfig(deckIds: ['a', 'gone']),
        ).deckIds,
        ['a'],
      );
      expect(
        SetupForm.initial(
          decks: decks,
          last: const SessionConfig(deckIds: ['gone']),
        ).deckIds,
        ['a', 'b', 'c'],
      );
    });

    test('opened from a deck, chooses only that deck and keeps the rest of '
        'the last configuration', () {
      final form = SetupForm.initial(
        decks: decks,
        deckId: 'c',
        last: const SessionConfig(deckIds: ['a', 'b'], requestedCount: 10),
      );

      expect(form.deckIds, ['c']);
      expect(form.count, 10);
    });
  });

  group('config', () {
    test('turns the form into the configuration to save', () {
      final form = SetupForm.initial(decks: decks).copyWith(
        deckIds: ['c'],
        direction: StudyDirection.reverse,
        timerType: TimerType.global,
        sessionMinutes: 15,
      );

      final config = form.toConfig(decks);

      expect(config.deckIds, ['c']);
      expect(config.requestedCount, 20);
      expect(config.direction, StudyDirection.reverse);
      expect(config.timerType, TimerType.global);
      expect(config.timerSeconds, 15 * 60);
    });

    test('"Todas" asks for every card and no timer has no seconds', () {
      final config = SetupForm.initial(decks: decks)
          .withCount(null)
          .toConfig(decks);

      expect(config.requestedCount, isNull);
      expect(config.timerSeconds, isNull);
    });

    test('keeps the decks in the project order', () {
      final config = SetupForm.initial(decks: decks)
          .copyWith(deckIds: ['c', 'a'])
          .toConfig(decks);

      expect(config.deckIds, ['a', 'c']);
    });

    test('without a language deck, the direction is normal', () {
      final config = SetupForm.initial(decks: decks)
          .copyWith(deckIds: ['a', 'b'], direction: StudyDirection.reverse)
          .toConfig(decks);

      expect(config.direction, StudyDirection.normal);
    });

    test('survives being saved as JSON', () {
      const config = SessionConfig(
        deckIds: ['a', 'c'],
        mode: StudyMode.errors,
        direction: StudyDirection.reverse,
        requestedCount: 12,
        prioritizeFailed: true,
        repeatFailed: true,
        timerType: TimerType.perCard,
        timerSeconds: 30,
      );

      final restored = SessionConfig.fromJson(config.toJson())!;

      expect(restored.deckIds, config.deckIds);
      expect(restored.mode, config.mode);
      expect(restored.direction, config.direction);
      expect(restored.requestedCount, config.requestedCount);
      expect(restored.prioritizeFailed, config.prioritizeFailed);
      expect(restored.repeatFailed, config.repeatFailed);
      expect(restored.timerType, config.timerType);
      expect(restored.timerSeconds, config.timerSeconds);
    });

    test('broken JSON gives no configuration', () {
      expect(SessionConfig.fromJson('not json'), isNull);
      expect(SessionConfig.fromJson('{"deckIds": 3}'), isNull);
    });
  });

  group('direction', () {
    test('is offered only when a chosen deck is a language deck', () {
      final form = SetupForm.initial(decks: decks);

      expect(form.copyWith(deckIds: ['a', 'b']).hasLanguageDeck(decks), false);
      expect(form.copyWith(deckIds: ['a', 'c']).hasLanguageDeck(decks), true);
    });

    test('names the pair when every chosen language deck shares it', () {
      final withPairs = [
        ...decks,
        languageDeck('d'),
        // French → Spanish, against the others' English → Spanish.
        languageDeck('e', 'fr-FR'),
      ];
      final form = SetupForm.initial(decks: withPairs);

      expect(form.copyWith(deckIds: ['a', 'c', 'd']).languagePair(withPairs), (
        source: 'en-GB',
        target: 'es-ES',
      ));
      expect(
        form.copyWith(deckIds: ['c', 'e']).languagePair(withPairs),
        isNull,
      );
    });
  });

  group('available cards', () {
    final candidates = [
      candidate('1', 'a'),
      candidate('2', 'a', inErrors: true),
      candidate('3', 'b'),
      candidate('4', 'c'),
    ];

    test('counts the cards of the chosen decks', () {
      final form = SetupForm.initial(decks: decks);

      expect(form.availableCount(candidates), 4);
      expect(form.copyWith(deckIds: ['a']).availableCount(candidates), 2);
      expect(form.copyWith(deckIds: []).availableCount(candidates), 0);
    });

    test('in "Solo errores", counts only the cards in errors', () {
      final form = SetupForm.initial(decks: decks)
          .copyWith(mode: StudyMode.errors);

      expect(form.availableCount(candidates), 1);
    });

    test('keeps only the candidates of the chosen decks', () {
      final form = SetupForm.initial(decks: decks).copyWith(deckIds: ['b']);

      expect([for (final c in form.candidatesOf(candidates)) c.card.id], ['3']);
    });
  });

  group('review errors (US-21)', () {
    /// A card of [deckId] in errors in the given directions.
    StudyCandidate inErrors(
      String id,
      String deckId, {
      bool language = true,
      bool test = false,
      bool normal = false,
      bool reverse = false,
    }) => StudyCandidate(
      card: Flashcard(
        id: id,
        deckId: deckId,
        type: test ? CardType.test : CardType.simple,
        question: 'Question $id',
        answer: test ? null : 'Answer $id',
        allowMultiple: false,
        createdAt: _start,
        updatedAt: _start,
      ),
      isLanguageDeck: language,
      normalStats: DirectionStats(inErrorList: normal, studied: true),
      reverseStats: DirectionStats(inErrorList: reverse, studied: true),
    );

    test('chooses "Solo errores" and keeps the rest of the '
        'configuration', () {
      final form = SetupForm.initial(
        decks: decks,
        last: const SessionConfig(
          deckIds: ['c'],
          requestedCount: 10,
          timerType: TimerType.perCard,
          timerSeconds: 15,
        ),
      );

      final review = form.forErrorReview([inErrors('1', 'c', normal: true)]);

      expect(review.mode, StudyMode.errors);
      expect(review.deckIds, ['c']);
      expect(review.count, 10);
      expect(review.timerType, TimerType.perCard);
      expect(review.questionSeconds, 15);
    });

    test('chooses the direction with more cards in errors', () {
      final form = SetupForm.initial(decks: decks);

      final review = form.forErrorReview([
        inErrors('1', 'c', normal: true),
        inErrors('2', 'c', reverse: true),
        inErrors('3', 'c', reverse: true),
      ]);

      expect(review.direction, StudyDirection.reverse);
      expect(
        review.availableCount([
          inErrors('1', 'c', normal: true),
          inErrors('2', 'c', reverse: true),
          inErrors('3', 'c', reverse: true),
        ]),
        2,
      );
    });

    test('counts the cards each direction would study: test cards and '
        'general decks go in the normal direction (R 7.3)', () {
      // Pairs in errors: 2 normal and 2 reverse. But a reverse session
      // would also study the test card, recorded in the normal direction:
      // 3 cards against 2.
      final candidates = [
        inErrors('1', 'c', normal: true),
        inErrors('2', 'c', reverse: true),
        inErrors('3', 'c', reverse: true),
        inErrors('4', 'c', test: true, normal: true),
      ];

      final review = SetupForm.initial(decks: decks).forErrorReview(candidates);

      expect(review.direction, StudyDirection.reverse);
      expect(review.availableCount(candidates), 3);
    });

    test('a tie keeps the direction of the last configuration', () {
      final form = SetupForm.initial(
        decks: decks,
        last: const SessionConfig(
          deckIds: ['c'],
          direction: StudyDirection.reverse,
        ),
      );

      final review = form.forErrorReview([
        inErrors('1', 'c', normal: true),
        inErrors('2', 'c', reverse: true),
      ]);

      expect(review.direction, StudyDirection.reverse);
    });

    test('only the chosen decks count', () {
      final form = SetupForm.initial(decks: decks).copyWith(deckIds: ['c']);

      final review = form.forErrorReview([
        inErrors('1', 'c', normal: true),
        inErrors('2', 'a', language: false, normal: true),
        inErrors('3', 'a', language: false, normal: true),
        inErrors('4', 'c', reverse: true),
        inErrors('5', 'c', reverse: true),
      ]);

      expect(review.direction, StudyDirection.reverse);
    });
  });

  group('timer values', () {
    test('per question: 5 to 120 seconds in steps of 5', () {
      expect(nextQuestionSeconds(30), 35);
      expect(previousQuestionSeconds(30), 25);
      expect(previousQuestionSeconds(5), 5);
      expect(nextQuestionSeconds(120), 120);
    });

    test('global: 1 minute, then 5 to 120 in steps of 5', () {
      expect(nextSessionMinutes(1), 5);
      expect(nextSessionMinutes(10), 15);
      expect(nextSessionMinutes(120), 120);
      expect(previousSessionMinutes(5), 1);
      expect(previousSessionMinutes(1), 1);
      expect(previousSessionMinutes(15), 10);
    });
  });
}
