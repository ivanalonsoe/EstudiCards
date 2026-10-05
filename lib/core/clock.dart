// The app never calls `DateTime.now()` directly: it asks a `Clock`. In the
// app that is a `SystemClock` (the real time); in tests it is a `FakeClock`,
// which stays still until the test moves it. This makes timers, streaks and
// the 15-day trash testable without waiting (SPEC §10.3).
//
// All times are UTC (SPEC §4); screens convert them to local time to show
// them.

/// Something that tells the current time.
abstract interface class Clock {
  /// The current time, in UTC.
  DateTime now();
}

/// The real clock, used by the app.
class SystemClock implements Clock {
  const new();

  @override
  DateTime now() => DateTime.timestamp();
}

/// A clock for tests: it returns the time it was given until it is changed
/// with [set] or [advance].
class FakeClock implements Clock {
  new(DateTime start) : _now = _requireUtc(start);

  DateTime _now;

  @override
  DateTime now() => _now;

  void set(DateTime time) => _now = _requireUtc(time);

  void advance(Duration duration) => _now = _now.add(duration);

  static DateTime _requireUtc(DateTime time) {
    if (!time.isUtc) {
      throw ArgumentError.value(time, 'time', 'must be in UTC');
    }
    return time;
  }
}
