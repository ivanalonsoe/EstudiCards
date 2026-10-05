/// Spacing on a 4 px grid (DESIGN_BRIEF.md §3.3). Use these instead of
/// literal numbers for paddings and gaps.
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;
}

/// Corner radii (DESIGN_BRIEF.md §3.3).
abstract final class AppRadii {
  static const double studyCard = 24;
  static const double listCard = 16;

  /// Buttons and text fields.
  static const double control = 12;

  /// Fully rounded ("pill") chips.
  static const double chip = 999;
}

/// Minimum size of anything the user taps (DESIGN_BRIEF.md §9).
const double minTouchTarget = 48;
