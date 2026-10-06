import 'package:estudicards/features/projects/domain/project.dart';

/// A project with the numbers its card shows on the dashboard (P01).
class ProjectSummary {
  const new({
    required this.project,
    required this.deckCount,
    required this.cardCount,
  });

  final Project project;

  /// Decks not in the trash.
  final int deckCount;

  /// Cards in those decks.
  final int cardCount;
}
