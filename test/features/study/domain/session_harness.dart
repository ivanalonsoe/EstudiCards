// Drives a `SessionEngine` in tests the way the session screen will: it keeps
// the current state and a fake current time, and collects every answer the
// engine hands over to be saved.
import 'package:estudicards/core/random.dart';
import 'package:estudicards/features/cards/domain/flashcard.dart';
import 'package:estudicards/features/study/domain/attempt_record.dart';
import 'package:estudicards/features/study/domain/card_selection.dart';
import 'package:estudicards/features/study/domain/session_engine.dart';
import 'package:estudicards/features/study/domain/session_event.dart';
import 'package:estudicards/features/study/domain/session_state.dart';
import 'package:estudicards/features/study/domain/study_options.dart';

final sessionStart = DateTime.utc(2026, 10, 12, 9);

/// A simple card with ID [id].
Flashcard simpleCard(String id) => Flashcard(
  id: id,
  deckId: 'deck',
  type: CardType.simple,
  question: 'Question $id',
  answer: 'Answer $id',
  allowMultiple: false,
  createdAt: sessionStart,
  updatedAt: sessionStart,
);

/// A test card with ID [id] and options `<id>-a` to `<id>-d`; the letters in
/// [correct] are the correct ones.
Flashcard testCard(String id, {Set<String> correct = const {'a'}}) => Flashcard(
  id: id,
  deckId: 'deck',
  type: CardType.test,
  question: 'Question $id',
  allowMultiple: correct.length > 1,
  options: [
    for (final (index, letter) in ['a', 'b', 'c', 'd'].indexed)
      CardOption(
        id: '$id-$letter',
        text: 'Option $letter',
        isCorrect: correct.contains(letter),
        position: index,
      ),
  ],
  createdAt: sessionStart,
  updatedAt: sessionStart,
);

/// [cards] as a session queue, all in the normal direction.
List<SelectedCard> queueOf(List<Flashcard> cards) => [
  for (final card in cards)
    SelectedCard(card: card, direction: StudyDirection.normal),
];

class SessionHarness {
  new(
    List<SelectedCard> cards, {
    SessionSettings settings = const SessionSettings(),
    int seed = 1,
  }) : engine = SessionEngine(random: createRandom(seed: seed)) {
    _take(engine.start(cards: cards, settings: settings, at: now));
  }

  final SessionEngine engine;
  DateTime now = sessionStart;
  late SessionState state;

  /// Every answer the engine handed over, in order.
  final attempts = <AttemptRecord>[];

  InProgress get session => state as InProgress;
  CurrentCard get current => session.current;
  String get cardId => current.card.id;
  int get turn => current.turn;

  void wait(Duration duration) => now = now.add(duration);

  void send(SessionEvent event) => _take(engine.apply(state, event, at: now));

  void flip() => send(Flip(turn: turn));
  void grade({required bool correct}) =>
      send(SelfGrade(turn: turn, correct: correct));
  void mark(String letter) =>
      send(ToggleOption(turn: turn, optionId: '$cardId-$letter'));
  void check() => send(Check(turn: turn));
  void reveal() => send(RevealAnswer(turn: turn));
  void leaveForLater() => send(LeaveForLater(turn: turn));
  void next() => send(Next(turn: turn));
  void pause() => send(const Pause());
  void resume() => send(const Resume());
  void exit() => send(const Exit());

  void _take(SessionStep step) {
    state = step.state;
    attempts.addAll(step.attempts);
  }
}
