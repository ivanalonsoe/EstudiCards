// One answer given in a study session, as the engine hands it over to be
// saved in `attempts` (SPEC §4.2).
import 'package:estudicards/features/study/domain/study_options.dart';

/// `correct` | `wrong` | `unanswered`. The enum name is the stored value.
enum AttemptResult {
  correct,
  wrong,
  unanswered;

  /// The result for a stored value. Unknown values fall back to
  /// [unanswered], which changes no statistics.
  static AttemptResult fromStored(String value) =>
      values.asNameMap()[value] ?? unanswered;
}

/// How the result was reached (SPEC §4.2 `attempts.source`).
enum AttemptSource {
  /// "Acerté" or "Fallé" on a simple card.
  selfEval('self_eval'),

  /// "Comprobar" on a test card.
  testCheck('test_check'),

  /// The per-question timer ran out (R 7.5).
  timeout('timeout'),

  /// "Ver respuesta" (R 7.3).
  revealed('revealed'),

  /// The session ended with the card still unresolved (R 7.3).
  sessionEnd('session_end');

  // An enum can carry values: each case above passes its stored text.
  new(this.stored);

  /// The value saved in `attempts.source`.
  final String stored;

  /// The source for a stored value. Unknown values fall back to
  /// [sessionEnd].
  static AttemptSource fromStored(String value) => values.firstWhere(
    (source) => source.stored == value,
    orElse: () => sessionEnd,
  );
}

class AttemptRecord {
  const new({
    required this.cardId,
    required this.direction,
    required this.result,
    required this.source,
    required this.isFirstAttempt,
    required this.answeredAt,
    this.selectedOptionIds,
    this.responseTime,
  });

  final String cardId;

  /// The direction the card was studied in (see `directionFor`).
  final StudyDirection direction;
  final AttemptResult result;
  final AttemptSource source;

  /// False for the repeats of "Repetir falladas al final": they count
  /// neither in the statistics nor in the error list (R 7.3).
  final bool isFirstAttempt;

  /// The ticked options of a test card; null on a simple card.
  final Set<String>? selectedOptionIds;

  /// From when the card was shown until it was answered, pauses excluded.
  /// Null for an unanswered card.
  final Duration? responseTime;
  final DateTime answeredAt;
}
