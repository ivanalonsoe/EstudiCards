// Durations and curves of every animation (DESIGN_BRIEF.md §8), defined
// once here. Widgets use these instead of literal durations, so the whole
// app moves at the same pace.
import 'package:flutter/widgets.dart';

abstract final class AppMotion {
  /// Turning a card over: a 3D flip on the vertical axis.
  static const flip = Duration(milliseconds: 350);
  static const Curve flipCurve = Curves.easeInOut;

  /// The green or red border flash of an answer.
  static const flash = Duration(milliseconds: 450);

  /// The answered card leaving and the next one coming in.
  static const cardSwap = Duration(milliseconds: 300);
  static const Curve cardSwapCurve = Curves.easeOutCubic;

  /// One beat of the timer in its last seconds. Shorter than a second, so
  /// it ends before the next one starts.
  static const timerPulse = Duration(milliseconds: 600);

  /// The results ring filling up.
  static const ringFill = Duration(milliseconds: 900);
  static const Curve ringFillCurve = Curves.easeOutCubic;

  /// The confetti around the ring from 80%.
  static const confetti = Duration(milliseconds: 1100);
  static const Curve confettiCurve = Curves.easeOutBack;

  /// The fade that replaces movement when the system asks to reduce it.
  static const fade = Duration(milliseconds: 200);

  /// Whether the system asks to reduce motion (an accessibility setting).
  /// Then movements become fades (brief §8).
  static bool reduced(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context);
}
