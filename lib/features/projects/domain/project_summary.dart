import 'package:estudicards/features/projects/domain/project.dart';
import 'package:estudicards/features/stats/domain/metrics.dart';

/// A project with the numbers its card shows on the dashboard (P01).
class ProjectSummary {
  const new({
    required this.project,
    required this.deckCount,
    required this.cardCount,
    this.answers = const AnswerCounts(),
    this.errorCount = 0,
    this.lastStudiedAt,
  });

  final Project project;

  /// Decks not in the trash.
  final int deckCount;

  /// Cards in those decks.
  final int cardCount;

  /// First attempts of those cards, both directions (R 7.6).
  final AnswerCounts answers;

  /// Pending errors: (card, direction) pairs in the error list (R 7.6).
  final int errorCount;

  /// The last counted answer in the project; null if never studied.
  final DateTime? lastStudiedAt;
}
