// What the user chooses in the session setup (P08, US-14), before it
// becomes a `SessionConfig`. Pure Dart, so the rules of the screen (the
// last configuration, which decks count, the timer steps) are unit-tested.
import 'package:estudicards/features/decks/domain/deck.dart';
import 'package:estudicards/features/study/domain/card_selection.dart';
import 'package:estudicards/features/study/domain/session_config.dart';
import 'package:estudicards/features/study/domain/session_state.dart';
import 'package:estudicards/features/study/domain/study_options.dart';

/// The fixed choices of "Número de tarjetas", besides "Todas" and "Otro".
const presetCounts = [10, 20, 50];

/// The values a timer starts with when it is chosen (design: 30 s).
const defaultQuestionSeconds = 30;
const defaultSessionMinutes = 10;

class SetupForm {
  const new({
    required this.deckIds,
    this.count = 20,
    this.customCount = false,
    this.mode = StudyMode.normal,
    this.direction = StudyDirection.normal,
    this.prioritizeFailed = false,
    this.repeatFailed = false,
    this.timerType = TimerType.none,
    this.questionSeconds = defaultQuestionSeconds,
    this.sessionMinutes = defaultSessionMinutes,
  });

  /// The form P08 opens with: the project's last configuration
  /// ([last], US-14 AC1) or the defaults, with every deck. Decks that no
  /// longer exist are dropped; if none is left, every deck is chosen.
  /// Opened from a deck ([deckId]), only that deck is chosen and the rest
  /// comes from [last] (decided with the owner).
  ///
  /// A `factory` constructor works out the values before creating the form.
  factory initial({
    required List<Deck> decks,
    SessionConfig? last,
    String? deckId,
  }) {
    final allIds = [for (final deck in decks) deck.id];
    final lastIds = [
      for (final id in last?.deckIds ?? const <String>[])
        if (allIds.contains(id)) id,
    ];
    final deckIds = deckId != null && allIds.contains(deckId)
        ? [deckId]
        : lastIds.isEmpty
        ? allIds
        : lastIds;
    if (last == null) return SetupForm(deckIds: deckIds);

    final count = last.requestedCount;
    final seconds = last.timerSeconds;
    return SetupForm(
      deckIds: deckIds,
      count: count,
      customCount: count != null && !presetCounts.contains(count),
      mode: last.mode,
      direction: last.direction,
      prioritizeFailed: last.prioritizeFailed,
      repeatFailed: last.repeatFailed,
      timerType: last.timerType,
      questionSeconds: last.timerType == TimerType.perCard && seconds != null
          ? seconds
          : defaultQuestionSeconds,
      sessionMinutes: last.timerType == TimerType.global && seconds != null
          ? seconds ~/ 60
          : defaultSessionMinutes,
    );
  }

  final List<String> deckIds;

  /// How many cards to ask for; null = "Todas".
  final int? count;

  /// True when the count was chosen with "Otro" (its − / + row).
  final bool customCount;
  final StudyMode mode;
  final StudyDirection direction;
  final bool prioritizeFailed;
  final bool repeatFailed;
  final TimerType timerType;

  /// The values of each timer, kept while another one is chosen.
  final int questionSeconds;
  final int sessionMinutes;

  SetupForm copyWith({
    List<String>? deckIds,
    StudyMode? mode,
    StudyDirection? direction,
    bool? prioritizeFailed,
    bool? repeatFailed,
    TimerType? timerType,
    int? questionSeconds,
    int? sessionMinutes,
  }) => SetupForm(
    deckIds: deckIds ?? this.deckIds,
    count: count,
    customCount: customCount,
    mode: mode ?? this.mode,
    direction: direction ?? this.direction,
    prioritizeFailed: prioritizeFailed ?? this.prioritizeFailed,
    repeatFailed: repeatFailed ?? this.repeatFailed,
    timerType: timerType ?? this.timerType,
    questionSeconds: questionSeconds ?? this.questionSeconds,
    sessionMinutes: sessionMinutes ?? this.sessionMinutes,
  );

  /// The same form asking for [count] cards (null = "Todas"). `copyWith`
  /// cannot set a value back to null, hence this method.
  SetupForm withCount(int? count, {bool custom = false}) => SetupForm(
    deckIds: deckIds,
    count: count,
    customCount: custom,
    mode: mode,
    direction: direction,
    prioritizeFailed: prioritizeFailed,
    repeatFailed: repeatFailed,
    timerType: timerType,
    questionSeconds: questionSeconds,
    sessionMinutes: sessionMinutes,
  );

  List<Deck> _chosen(List<Deck> decks) => [
    for (final deck in decks)
      if (deckIds.contains(deck.id)) deck,
  ];

  /// "Sentido" is offered when a chosen deck is a language deck (R 7.3).
  bool hasLanguageDeck(List<Deck> decks) =>
      _chosen(decks).any((deck) => deck.isLanguage);

  /// The pair "Sentido" names (e.g. Inglés → Español) when every chosen
  /// language deck has the same one; null when they differ, and the
  /// options are then "Normal" and "Inverso" (decided with the owner).
  ({String source, String target})? languagePair(List<Deck> decks) {
    final pairs = {
      for (final deck in _chosen(decks))
        if (deck.isLanguage &&
            deck.sourceLang != null &&
            deck.targetLang != null)
          (source: deck.sourceLang!, target: deck.targetLang!),
    };
    return pairs.length == 1 ? pairs.single : null;
  }

  /// The candidates from the chosen decks.
  List<StudyCandidate> candidatesOf(List<StudyCandidate> candidates) => [
    for (final candidate in candidates)
      if (deckIds.contains(candidate.card.deckId)) candidate,
  ];

  /// How many cards the session can use (US-14 AC2).
  int availableCount(List<StudyCandidate> candidates) => availableCards(
    candidatesOf(candidates),
    mode: mode,
    direction: direction,
  ).length;

  /// The configuration to save and start. The decks keep the project's
  /// order, and without a language deck the direction is normal.
  SessionConfig toConfig(List<Deck> decks) => SessionConfig(
    deckIds: [for (final deck in _chosen(decks)) deck.id],
    mode: mode,
    direction: hasLanguageDeck(decks) ? direction : StudyDirection.normal,
    requestedCount: count,
    prioritizeFailed: prioritizeFailed,
    repeatFailed: repeatFailed,
    timerType: timerType,
    timerSeconds: switch (timerType) {
      TimerType.none => null,
      TimerType.perCard => questionSeconds,
      TimerType.global => sessionMinutes * 60,
    },
  );
}

/// The per-question timer goes from 5 to 120 seconds in steps of 5 (R 7.5).
int nextQuestionSeconds(int seconds) => seconds >= 120 ? 120 : seconds + 5;

int previousQuestionSeconds(int seconds) => seconds <= 5 ? 5 : seconds - 5;

/// The global timer goes from 1 to 120 minutes (R 7.5): 1, then 5 to 120 in
/// steps of 5, so long sessions do not take dozens of taps.
int nextSessionMinutes(int minutes) =>
    minutes >= 120 ? 120 : (minutes ~/ 5 + 1) * 5;

int previousSessionMinutes(int minutes) => minutes <= 5 ? 1 : minutes - 5;
