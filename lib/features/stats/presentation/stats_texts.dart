// Texts for statistics shared by several screens.
import 'package:estudicards/app/l10n/generated/app_localizations.dart';
import 'package:estudicards/features/cards/domain/card_list.dart';

/// "92%", or "—" with no answers.
String rateText(AppLocalizations l10n, double? rate) =>
    rate == null ? '—' : l10n.percent((rate * 100).round());

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
