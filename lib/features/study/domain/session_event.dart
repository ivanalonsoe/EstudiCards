// What can happen in a study session: the buttons the user taps and the
// pause, exit and timer events. The engine decides what each one does in
// each state (`session_engine.dart`).

sealed class SessionEvent {
  const new();
}

/// An event about the card on screen. [turn] is that card's
/// `CurrentCard.turn`; the engine ignores it if another card is showing.
sealed class CardEvent extends SessionEvent {
  const new({required this.turn});

  final int turn;
}

/// "¡Sé la respuesta!" or a tap on a simple card.
final class Flip extends CardEvent {
  const new({required super.turn});
}

/// A tap on an option of a test card.
final class ToggleOption extends CardEvent {
  const new({required super.turn, required this.optionId});

  final String optionId;
}

/// "Comprobar" on a test card.
final class Check extends CardEvent {
  const new({required super.turn});
}

/// "Acerté" ([correct] true) or "Fallé", with a button or a swipe.
final class SelfGrade extends CardEvent {
  const new({required super.turn, required this.correct});

  final bool correct;
}

/// "No sé la respuesta".
final class RevealAnswer extends CardEvent {
  const new({required super.turn});
}

/// "Dejar para el final".
final class LeaveForLater extends CardEvent {
  const new({required super.turn});
}

/// "Siguiente".
final class Next extends CardEvent {
  const new({required super.turn});
}

final class Pause extends SessionEvent {
  const new();
}

final class Resume extends SessionEvent {
  const new();
}

/// Sent every second while a session runs, so the engine can see a timer
/// run out (R 7.5).
final class Tick extends SessionEvent {
  const new();
}

/// "Salir", after confirming.
final class Exit extends SessionEvent {
  const new();
}
