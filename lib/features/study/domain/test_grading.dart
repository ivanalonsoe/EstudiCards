// Grading of a test card after "Comprobar" (US-16).
import 'package:estudicards/features/cards/domain/flashcard.dart';

/// Whether ticking [selectedOptionIds] answers [card] correctly: the ticked
/// options must be exactly the correct ones (US-16 AC3). There is no partial
/// credit, so one missing or one extra option makes the answer wrong.
bool isTestAnswerCorrect(Flashcard card, Set<String> selectedOptionIds) {
  final correctIds = {
    for (final option in card.options)
      if (option.isCorrect) option.id,
  };
  return selectedOptionIds.length == correctIds.length &&
      selectedOptionIds.containsAll(correctIds);
}
