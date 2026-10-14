// Everything chosen in the session setup (P08, US-14), as it is saved in
// `study_sessions` and remembered per project.
import 'dart:convert';

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

  /// The JSON text kept in `settings` as `last_session_config:<projectId>`
  /// (SPEC §4.2).
  String toJson() => jsonEncode({
    'deckIds': deckIds,
    'mode': mode.name,
    'direction': direction.name,
    'requestedCount': requestedCount,
    'prioritizeFailed': prioritizeFailed,
    'repeatFailed': repeatFailed,
    'timerType': timerType.stored,
    'timerSeconds': timerSeconds,
  });

  /// The configuration saved by [toJson], or null if [json] is not one
  /// (e.g. damaged): the setup then starts from its defaults.
  static SessionConfig? fromJson(String json) {
    try {
      final map = jsonDecode(json) as Map<String, dynamic>;
      return SessionConfig(
        deckIds: [for (final id in map['deckIds'] as List<dynamic>) '$id'],
        mode: StudyMode.fromStored(map['mode'] as String),
        direction: StudyDirection.fromStored(map['direction'] as String),
        requestedCount: map['requestedCount'] as int?,
        prioritizeFailed: map['prioritizeFailed'] as bool,
        repeatFailed: map['repeatFailed'] as bool,
        timerType: TimerType.fromStored(map['timerType'] as String),
        timerSeconds: map['timerSeconds'] as int?,
      );
      // A value of another type fails the `as` casts with a TypeError.
      // ignore: avoid_catching_errors
    } on TypeError {
      return null;
    } on FormatException {
      return null;
    }
  }
}
