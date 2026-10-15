// The app never calls `DateTime.now()` directly: it asks a `Clock`. In the
// app that is a `SystemClock` (the real time); in tests it is a `FakeClock`,
// which stays still until the test moves it. This makes timers, streaks and
// the 15-day trash testable without waiting (SPEC §10.3).
//
// All times are UTC (SPEC §4); screens convert them to local time to show
// them. The clock also says which calendar day an instant falls on for the
// user (streaks and "per day" statistics), so tests can pick a time zone.

/// Something that tells the current time and the user's calendar day.
abstract interface class Clock {
  /// The current time, in UTC.
  DateTime now();

  /// The calendar day, in the user's local time, of the UTC instant
  /// [time]. It is returned as midnight UTC of that date (e.g. 15 October
  /// → `2026-10-15 00:00Z`), so days can be compared and counted without
  /// summer time changing their length.
  DateTime localDay(DateTime time);
}

/// The real clock, used by the app. Local days follow the device's time
/// zone.
class SystemClock implements Clock {
  const new();

  @override
  DateTime now() => DateTime.timestamp();

  @override
  DateTime localDay(DateTime time) => _dateOf(time.toLocal());
}

/// A clock for tests: it returns the time it was given until it is changed
/// with [set] or [advance].
///
/// Its local days follow `utcOffset`, the offset from UTC at each instant
/// (e.g. +2 h in Madrid in summer). Without one, local days are UTC days, so
/// tests never depend on the machine's time zone.
class FakeClock implements Clock {
  new(DateTime start, {Duration Function(DateTime utc)? utcOffset})
    : _now = _requireUtc(start),
      _utcOffset = utcOffset ?? _noOffset;

  DateTime _now;
  final Duration Function(DateTime utc) _utcOffset;

  @override
  DateTime now() => _now;

  @override
  DateTime localDay(DateTime time) => _dateOf(time.add(_utcOffset(time)));

  void set(DateTime time) => _now = _requireUtc(time);

  void advance(Duration duration) => _now = _now.add(duration);

  static Duration _noOffset(DateTime utc) => Duration.zero;

  static DateTime _requireUtc(DateTime time) {
    if (!time.isUtc) {
      throw ArgumentError.value(time, 'time', 'must be in UTC');
    }
    return time;
  }
}

/// The date of [time] (its year, month and day) as midnight UTC.
DateTime _dateOf(DateTime time) =>
    DateTime.utc(time.year, time.month, time.day);

/// [day] as stored in the database: `YYYY-MM-DD` text, e.g. `2026-03-09`.
String dayKey(DateTime day) =>
    '${day.year.toString().padLeft(4, '0')}-'
    '${day.month.toString().padLeft(2, '0')}-'
    '${day.day.toString().padLeft(2, '0')}';

/// The day stored as [key] (`YYYY-MM-DD`), as midnight UTC.
DateTime parseDayKey(String key) => DateTime.parse('${key}T00:00:00Z');
