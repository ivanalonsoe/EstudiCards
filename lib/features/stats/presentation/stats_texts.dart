// Texts for statistics shared by several screens.
import 'package:estudicards/app/l10n/generated/app_localizations.dart';
import 'package:estudicards/features/cards/domain/card_list.dart';

/// "92%", or "—" with no answers.
String rateText(AppLocalizations l10n, double? rate) =>
    rate == null ? '—' : l10n.percent((rate * 100).round());

/// "Verbos irregulares y Phrasal verbs"; empty with no names.
String joinNames(AppLocalizations l10n, List<String> names) {
  if (names.length <= 1) return names.join();
  return l10n.listAnd(
    names.sublist(0, names.length - 1).join(', '),
    names.last,
  );
}

/// "45 s" under a minute, "6 min" from a minute (rounded).
String shortDuration(AppLocalizations l10n, Duration duration) {
  final seconds = (duration.inMilliseconds / 1000).round();
  return seconds < 60
      ? l10n.secondsShort(seconds)
      : l10n.minutesShort((seconds / 60).round());
}

/// "Hoy", "Ayer", "Hace 3 días" or "Nunca", in local calendar days.
String reviewedText(
  AppLocalizations l10n,
  DateTime? reviewedAt,
  DateTime now,
) => switch (daysSinceReview(reviewedAt, now)) {
  null => l10n.reviewedNever,
  <= 0 => l10n.reviewedToday,
  1 => l10n.reviewedYesterday,
  final days => l10n.reviewedDaysAgo(days),
};
