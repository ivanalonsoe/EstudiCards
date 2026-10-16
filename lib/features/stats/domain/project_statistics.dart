// What the statistics of a project list besides the chart (P12): the most
// missed cards and the past sessions.
import 'package:estudicards/features/stats/domain/metrics.dart';
import 'package:estudicards/features/study/domain/session_state.dart';

/// A card of the "Más falladas" list.
class MissedCard {
  const new({
    required this.cardId,
    required this.deckId,
    required this.question,
    required this.wrongCount,
  });

  final String cardId;

  /// Where the card is, to open it in the editor.
  final String deckId;
  final String question;

  /// Wrong first attempts, both directions added up.
  final int wrongCount;
}

/// A finished session of the history.
class SessionSummary {
  const new({
    required this.id,
    required this.startedAt,
    required this.status,
    required this.deckNames,
    required this.answers,
    required this.unanswered,
    required this.activeDuration,
  });

  final String id;
  final DateTime startedAt;

  /// Completed, abandoned or out of time.
  final SessionStatus? status;
  final List<String> deckNames;

  /// Its first attempts, as on its results screen.
  final AnswerCounts answers;
  final int unanswered;

  /// Time studied, without the pauses.
  final Duration activeDuration;
}

/// A page of the history: the latest sessions, and whether older ones
/// remain ("Ver más").
class SessionHistory {
  const new({required this.sessions, required this.hasMore});

  final List<SessionSummary> sessions;
  final bool hasMore;
}
