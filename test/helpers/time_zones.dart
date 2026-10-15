// Time zones for tests, so local days do not depend on the machine running
// them. Pass one to `FakeClock(…, utcOffset: madridOffset)`.

/// The offset of Madrid (Europe/Madrid) at the UTC instant [utc]: +2 h in
/// summer time, from 01:00 UTC on the last Sunday of March to 01:00 UTC on
/// the last Sunday of October, and +1 h the rest of the year.
Duration madridOffset(DateTime utc) {
  DateTime change(int month) {
    // Day 0 of the next month is the last day of this one.
    var day = DateTime.utc(utc.year, month + 1, 0);
    while (day.weekday != DateTime.sunday) {
      day = day.subtract(const Duration(days: 1));
    }
    return day.add(const Duration(hours: 1));
  }

  final isSummer = !utc.isBefore(change(3)) && utc.isBefore(change(10));
  return Duration(hours: isSummer ? 2 : 1);
}
