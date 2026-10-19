// The user's settings (P16, SPEC §4.2), as plain values with the rules to
// read them from the `settings` table and to write them back. The table
// stores text under a key; anything missing or damaged falls back to its
// default, so a bad value never stops the app.

/// Light, dark, or whatever the device uses. The name is the stored value.
enum AppThemeMode {
  system,
  light,
  dark;

  String get stored => name;

  static AppThemeMode fromStored(String? value) =>
      values.asNameMap()[value] ?? system;
}

/// The keys of the `settings` table (SPEC §4.2).
abstract final class SettingKeys {
  static const themeMode = 'theme_mode';
  static const cardTextScale = 'card_text_scale';
  static const dailyGoal = 'daily_goal';
}

/// The card text size: from 80% to 160% (SPEC §9), in steps of 10%.
const minCardTextScale = 0.8;
const maxCardTextScale = 1.6;

/// The goal "Objetivo diario" starts at when turned on, and how "+" and
/// "−" move it (decided in T6.2).
const defaultDailyGoal = 20;
const dailyGoalStep = 5;
const minDailyGoal = 5;
const maxDailyGoal = 200;

class AppSettings {
  const new({
    this.themeMode = AppThemeMode.system,
    this.cardTextScale = 1.0,
    this.dailyGoal,
  });

  /// The settings stored under their keys; missing keys get the default.
  factory fromStored(Map<String, String?> stored) {
    final scale = double.tryParse(stored[SettingKeys.cardTextScale] ?? '');
    final goal = int.tryParse(stored[SettingKeys.dailyGoal] ?? '');
    return AppSettings(
      themeMode: AppThemeMode.fromStored(stored[SettingKeys.themeMode]),
      cardTextScale: scale == null ? 1.0 : roundCardTextScale(scale),
      dailyGoal: goal == null || goal <= 0 ? null : goal,
    );
  }

  final AppThemeMode themeMode;

  /// How much bigger (or smaller) the study card's text is: 1.0 is 100%.
  final double cardTextScale;

  /// Cards to answer each day, or null when the goal is off (the default).
  final int? dailyGoal;
}

/// [scale] within 80–160%, rounded to the nearest 10%.
double roundCardTextScale(double scale) =>
    (scale.clamp(minCardTextScale, maxCardTextScale) * 10).round() / 10;

/// [scale] as stored: rounded, e.g. `1.2`.
String storedCardTextScale(double scale) =>
    roundCardTextScale(scale).toStringAsFixed(1);

/// The goal after "+": the next step up, at most [maxDailyGoal].
int nextDailyGoal(int goal) => ((goal ~/ dailyGoalStep + 1) * dailyGoalStep)
    .clamp(minDailyGoal, maxDailyGoal);

/// The goal after "−": the next step down, at least [minDailyGoal].
int previousDailyGoal(int goal) =>
    (((goal - 1) ~/ dailyGoalStep) * dailyGoalStep).clamp(
      minDailyGoal,
      maxDailyGoal,
    );

/// The languages to check for a voice: the source and target of every
/// language deck in [decks], once each, in the order they first appear.
/// General decks have none (null).
List<String> deckLanguages(
  Iterable<({String? source, String? target})> decks,
) => {
  for (final deck in decks) ...[?deck.source, ?deck.target],
}.toList();
