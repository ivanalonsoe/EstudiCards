// Runs a study session in real time: it keeps the engine's current state,
// stamps every event with the clock's time and, when the session has a
// timer, sends a `Tick` every second so the timer can run out (R 7.5). The
// engine stays pure; this is the only piece with a running `Timer`. Plain
// Dart (`dart:async`), no Flutter.
import 'dart:async';

import 'package:estudicards/core/clock.dart';
import 'package:estudicards/features/study/domain/card_selection.dart';
import 'package:estudicards/features/study/domain/session_engine.dart';
import 'package:estudicards/features/study/domain/session_event.dart';
import 'package:estudicards/features/study/domain/session_state.dart';

class SessionRunner {
  /// Starts a session over [cards] now. `onStep` is called after every
  /// event with the new state and the answers to save.
  new({
    required this._engine,
    required this._clock,
    required List<SelectedCard> cards,
    required SessionSettings settings,
    this._onStep,
  }) {
    _take(_engine.start(cards: cards, settings: settings, at: _clock.now()));
    if (_state is! Finished && settings.timerType != TimerType.none) {
      // A `Timer.periodic` calls its function again and again, every
      // [interval], until it is cancelled.
      _ticker = Timer.periodic(
        const Duration(seconds: 1),
        (_) => send(const Tick()),
      );
    }
  }

  final SessionEngine _engine;
  final Clock _clock;
  final void Function(SessionStep step)? _onStep;
  late SessionState _state;
  Timer? _ticker;

  SessionState get state => _state;

  /// Applies [event] at the current time.
  void send(SessionEvent event) =>
      _take(_engine.apply(_state, event, at: _clock.now()));

  /// Stops the ticking, e.g. when the session screen closes. It also stops
  /// by itself when the session finishes.
  void dispose() {
    _ticker?.cancel();
    _ticker = null;
  }

  void _take(SessionStep step) {
    _state = step.state;
    _onStep?.call(step);
    if (_state is Finished) dispose();
  }
}
