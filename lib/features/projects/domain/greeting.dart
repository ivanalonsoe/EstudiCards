/// The greeting at the top of the dashboard, by time of day.
enum Greeting {
  /// "Buenos días": 6:00 to 13:59.
  morning,

  /// "Buenas tardes": 14:00 to 20:59.
  afternoon,

  /// "Buenas noches": 21:00 to 5:59.
  evening;

  /// The greeting for a [localTime] (the device's time, not UTC).
  static Greeting at(DateTime localTime) => switch (localTime.hour) {
    >= 6 && < 14 => morning,
    >= 14 && < 21 => afternoon,
    _ => evening,
  };
}
