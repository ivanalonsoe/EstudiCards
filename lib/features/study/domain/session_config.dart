// Everything chosen in the session setup (P08, US-14), as it is saved in
// `study_sessions` and remembered per project.
import 'package:estudicards/features/study/domain/session_state.dart';
import 'package:estudicards/features/study/domain/study_options.dart';

class SessionConfig {
  const new({
    required this.deckIds,
    this.mode = StudyMode.normal,
    this.direction = StudyDirection.normal,
    this.requestedCount,
    this.prioritizeFailed = false,
    this.repeatFailed = false,
    this.timerType = TimerType.none,
    this.timerSeconds,
  });

  final List<String> deckIds;
  final StudyMode mode;
  final StudyDirection direction;

  /// Null = all the available cards.
  final int? requestedCount;
  final bool prioritizeFailed;
  final bool repeatFailed;
  final TimerType timerType;

  /// Per question: 5–120. Global: 60–7200. Null without a timer.
  final int? timerSeconds;

  /// What the session engine needs from this configuration.
  SessionSettings get settings => SessionSettings(
    repeatFailed: repeatFailed,
    timerType: timerType,
    timerLimit: Duration(seconds: timerSeconds ?? 0),
  );
}
