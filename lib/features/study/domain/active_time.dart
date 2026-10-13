// A stopwatch that can be paused, written as an immutable value: pausing or
// resuming gives a new `ActiveTime` instead of changing this one. It never
// reads the clock; whoever asks passes the current time.

class ActiveTime {
  /// A stopwatch running since [runningSince], or stopped (null) after
  /// counting [accumulated].
  const new({this.accumulated = Duration.zero, this.runningSince});

  /// Time counted before the last pause.
  final Duration accumulated;

  /// When it was last started or resumed; null while paused.
  final DateTime? runningSince;

  bool get isRunning => runningSince != null;

  /// The time counted up to [at], pauses excluded.
  Duration elapsedAt(DateTime at) {
    final since = runningSince;
    return since == null ? accumulated : accumulated + at.difference(since);
  }

  /// This stopwatch stopped at [at].
  ActiveTime pausedAt(DateTime at) =>
      isRunning ? ActiveTime(accumulated: elapsedAt(at)) : this;

  /// This stopwatch running again from [at].
  ActiveTime resumedAt(DateTime at) =>
      isRunning ? this : ActiveTime(accumulated: accumulated, runningSince: at);
}
