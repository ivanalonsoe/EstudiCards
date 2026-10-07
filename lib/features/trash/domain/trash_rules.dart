/// How long projects and decks stay in the trash (SPEC §7.1).
const trashRetention = Duration(days: 15);

/// Days left before an item deleted at [deletedAt] is purged: 15 minus the
/// whole days elapsed, never below 0. Calculated when shown, not stored.
int daysLeft(DateTime deletedAt, {required DateTime now}) {
  final elapsed = now.difference(deletedAt).inDays;
  final left = trashRetention.inDays - elapsed;
  return left < 0 ? 0 : left;
}

/// Whether an item with [daysLeft] days left is flagged as urgent in the
/// trash (3 days or fewer, decided with the owner).
bool isUrgent(int daysLeft) => daysLeft <= 3;

/// Whether an item deleted at [deletedAt] has spent 15 days in the trash and
/// must be deleted permanently.
bool isExpired(DateTime deletedAt, {required DateTime now}) =>
    now.difference(deletedAt) >= trashRetention;
