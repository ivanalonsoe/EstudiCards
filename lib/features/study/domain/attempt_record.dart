// One answer given in a study session, as the engine hands it over to be
// saved in `attempts` (SPEC §4.2).
import 'package:estudicards/features/study/domain/study_options.dart';

/// `correct` | `wrong` | `unanswered`.
enum AttemptResult { correct, wrong, unanswered }

/// How the result was reached (SPEC §4.2 `attempts.source`).
enum AttemptSource {
  /// "Acerté" or "Fallé" on a simple card.
  selfEval,

  /// "Comprobar" on a test card.
  testCheck,

  /// The per-question timer ran out (R 7.5).
  timeout,

  /// "Ver respuesta" (R 7.3).
  revealed,

  /// The session ended with the card still unresolved (R 7.3).
  sessionEnd,
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
