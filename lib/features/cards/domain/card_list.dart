// Search and sorting of a deck's card list (P05, US-12). Plain functions,
// so they are tested without a database; the repository applies them to
// the cards it reads.
import 'package:estudicards/core/text_search.dart';
import 'package:estudicards/features/cards/domain/flashcard.dart';

/// The orders of the card list (US-12 AC2).
enum CardSort {
  /// Creation date, newest first (the default).
  newest,

  /// By question, ignoring case, accents, bold and italic marks and opening
  /// marks such as "¿".
  alphabetical,

  /// Most misses first (decided with the owner).
  mostMissed,
}

/// A card with its results, for the deck's card list.
class CardSummary {
  const new({
    required this.card,
    this.correctCount = 0,
    this.wrongCount = 0,
    this.lastReviewedAt,
  });

  final Flashcard card;

  /// First attempts, both directions added up (R 7.6).
  final int correctCount;
  final int wrongCount;

  /// The last answer in either direction; null if never studied.
  final DateTime? lastReviewedAt;

  /// % correct as a fraction: correct / (correct + wrong) (R 7.6). Null
  /// with no answers, which the list shows as "—".
  double? get correctRate {
    final total = correctCount + wrongCount;
    return total == 0 ? null : correctCount / total;
  }
}

/// How good a % correct is, for the colour of its bar: green, amber or red
/// (thresholds taken from the deck screen design).
enum RateLevel {
  good,
  fair,
  poor;

  static RateLevel of(double rate) => switch (rate) {
    >= 0.7 => good,
    >= 0.4 => fair,
    _ => poor,
  };
}

/// The % correct of several cards together, as a fraction; null with no
/// answers (R 7.6).
double? combinedCorrectRate(Iterable<CardSummary> cards) {
  var correct = 0;
  var wrong = 0;
  for (final card in cards) {
    correct += card.correctCount;
    wrong += card.wrongCount;
  }
  final total = correct + wrong;
  return total == 0 ? null : correct / total;
}

/// Calendar days, in local time, from [reviewedAt] to [now]: 0 = today,
/// 1 = yesterday. Null if the card was never reviewed.
int? daysSinceReview(DateTime? reviewedAt, DateTime now) {
  if (reviewedAt == null) return null;
  // Compare the local dates at midnight UTC, so a daylight saving change
  // does not leave a day with 23 or 25 hours.
  DateTime day(DateTime time) {
    final local = time.toLocal();
    return DateTime.utc(local.year, local.month, local.day);
  }

  return day(now).difference(day(reviewedAt)).inDays;
}

/// Whether [card] matches what the user typed in the search box (US-12
/// AC1): the text can be in the question, the answer or an option. Case,
/// accents and bold or italic marks are ignored.
bool matchesCardSearch(Flashcard card, String query) {
  final normalizedQuery = normalizeForSearch(query.trim());
  if (normalizedQuery.isEmpty) return true;
  final texts = [
    card.question,
    ?card.answer,
    for (final option in card.options) option.text,
  ];
  return texts.any((text) => _plain(text).contains(normalizedQuery));
}

/// [cards] in the given [sort] order (US-12 AC2). Ties go newest first.
List<CardSummary> sortCards(Iterable<CardSummary> cards, CardSort sort) {
  int newestFirst(CardSummary a, CardSummary b) =>
      b.card.createdAt.compareTo(a.card.createdAt);

  final compare = switch (sort) {
    CardSort.newest => newestFirst,
    CardSort.alphabetical => (CardSummary a, CardSummary b) {
      final byQuestion = _sortKey(a.card.question)
          .compareTo(_sortKey(b.card.question));
      return byQuestion != 0 ? byQuestion : newestFirst(a, b);
    },
    // Most misses first; with the same misses, the lower % correct first.
    // Cards never missed all have 0 misses, so they go last, newest first.
    CardSort.mostMissed => (CardSummary a, CardSummary b) {
      final byMisses = b.wrongCount.compareTo(a.wrongCount);
      if (byMisses != 0) return byMisses;
      if (a.wrongCount > 0) {
        final byRate = a.correctRate!.compareTo(b.correctRate!);
        if (byRate != 0) return byRate;
      }
      return newestFirst(a, b);
    },
  };
  return cards.toList()..sort(compare);
}

/// [text] without bold and italic marks (`**`, `*`), lower case and without
/// accents.
String _plain(String text) => normalizeForSearch(text.replaceAll('*', ''));

/// Leading characters that are not letters or digits, such as "¿", "¡" or
/// quotes.
final _leadingMarks = RegExp(r'^[^\p{L}\p{N}]+', unicode: true);

/// What the alphabetical order compares: "¿Qué…?" sorts under Q.
String _sortKey(String question) =>
    _plain(question).replaceFirst(_leadingMarks, '');
