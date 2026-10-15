// A clock that follows `fake_async`'s fake time: when a test calls
// `async.elapse(…)`, both the timers and this clock move forward together,
// so code that reads the clock inside a timer sees the right time.
import 'package:estudicards/core/clock.dart';
import 'package:fake_async/fake_async.dart';

class FakeAsyncClock implements Clock {
  new(this._async, this._start);

  final FakeAsync _async;
  final DateTime _start;

  @override
  DateTime now() => _start.add(_async.elapsed);

  /// UTC days, like a `FakeClock` without a time zone.
  @override
  DateTime localDay(DateTime time) =>
      DateTime.utc(time.year, time.month, time.day);
}
