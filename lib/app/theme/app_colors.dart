import 'package:flutter/material.dart';

/// The colour tokens from DESIGN_BRIEF.md §3.1, for the light and the dark
/// theme.
///
/// A `ThemeExtension` adds our own values to Flutter's `ThemeData`, next to
/// the built-in ones. Widgets read them with `AppColors.of(context)`, so they
/// never use literal colours and switch automatically with the theme.
class AppColors extends ThemeExtension<AppColors> {
  const new({
    required this.primary,
    required this.primaryStrong,
    required this.onPrimaryStrong,
    required this.primarySoft,
    required this.background,
    required this.surface,
    required this.surfaceVariant,
    required this.border,
    required this.text,
    required this.textMuted,
    required this.success,
    required this.onSuccess,
    required this.error,
    required this.onError,
    required this.warning,
    required this.chartCorrect,
    required this.chartWrong,
  });

  /// Accents, active icons, streak, daily goal ring.
  final Color primary;

  /// Primary button fill.
  final Color primaryStrong;

  /// Text and icons on [primaryStrong].
  final Color onPrimaryStrong;

  /// Selected chip and highlight backgrounds.
  final Color primarySoft;
  final Color background;

  /// Cards, sheets, dialogs.
  final Color surface;

  /// Text fields, alternate rows.
  final Color surfaceVariant;
  final Color border;
  final Color text;
  final Color textMuted;

  /// Correct answers. Always shown with a ✓ icon too.
  final Color success;
  final Color onSuccess;

  /// Wrong answers. Always shown with a ✗ icon too.
  final Color error;
  final Color onError;

  /// Timer about to run out.
  final Color warning;

  /// Chart colours: the wrong red is lighter than [error] so that people
  /// with red-green colour blindness can tell it from the green (brief §3.1).
  final Color chartCorrect;
  final Color chartWrong;

  static const light = AppColors(
    primary: Color(0xFFF97316),
    primaryStrong: Color(0xFFC2410C),
    onPrimaryStrong: Color(0xFFFFFFFF),
    primarySoft: Color(0xFFFFF1E6),
    background: Color(0xFFFAFAF9),
    surface: Color(0xFFFFFFFF),
    surfaceVariant: Color(0xFFF2F1EF),
    border: Color(0xFFE7E5E4),
    text: Color(0xFF1C1917),
    // Brief value #78716C darkened slightly: it gave 4.25:1 on surfaceVariant,
    // below WCAG AA (decided with the owner in T0.6).
    textMuted: Color(0xFF736C67),
    success: Color(0xFF15803D),
    onSuccess: Color(0xFFFFFFFF),
    error: Color(0xFFBE123C),
    onError: Color(0xFFFFFFFF),
    warning: Color(0xFFB45309),
    chartCorrect: Color(0xFF15803D),
    chartWrong: Color(0xFFFB7185),
  );

  static const dark = AppColors(
    primary: Color(0xFFFB923C),
    primaryStrong: Color(0xFFFDBA74),
    onPrimaryStrong: Color(0xFF1C1917),
    primarySoft: Color(0xFF3A2314),
    background: Color(0xFF0F0E0D),
    surface: Color(0xFF1C1A18),
    surfaceVariant: Color(0xFF282522),
    border: Color(0xFF35312D),
    text: Color(0xFFF5F5F4),
    textMuted: Color(0xFFA8A29E),
    success: Color(0xFF4ADE80),
    onSuccess: Color(0xFF1C1917),
    error: Color(0xFFFB7185),
    onError: Color(0xFF1C1917),
    warning: Color(0xFFFBBF24),
    chartCorrect: Color(0xFF16A34A),
    chartWrong: Color(0xFFFB7185),
  );

  /// The tokens of the current theme.
  static AppColors of(BuildContext context) =>
      Theme.of(context).extension<AppColors>()!;

  @override
  AppColors copyWith({
    Color? primary,
    Color? primaryStrong,
    Color? onPrimaryStrong,
    Color? primarySoft,
    Color? background,
    Color? surface,
    Color? surfaceVariant,
    Color? border,
    Color? text,
    Color? textMuted,
    Color? success,
    Color? onSuccess,
    Color? error,
    Color? onError,
    Color? warning,
    Color? chartCorrect,
    Color? chartWrong,
  }) => AppColors(
    primary: primary ?? this.primary,
    primaryStrong: primaryStrong ?? this.primaryStrong,
    onPrimaryStrong: onPrimaryStrong ?? this.onPrimaryStrong,
    primarySoft: primarySoft ?? this.primarySoft,
    background: background ?? this.background,
    surface: surface ?? this.surface,
    surfaceVariant: surfaceVariant ?? this.surfaceVariant,
    border: border ?? this.border,
    text: text ?? this.text,
    textMuted: textMuted ?? this.textMuted,
    success: success ?? this.success,
    onSuccess: onSuccess ?? this.onSuccess,
    error: error ?? this.error,
    onError: onError ?? this.onError,
    warning: warning ?? this.warning,
    chartCorrect: chartCorrect ?? this.chartCorrect,
    chartWrong: chartWrong ?? this.chartWrong,
  );

  /// Blends two sets of tokens. Flutter calls it to animate the change
  /// between the light and dark theme.
  @override
  AppColors lerp(AppColors? other, double t) {
    if (other == null) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppColors(
      primary: mix(primary, other.primary),
      primaryStrong: mix(primaryStrong, other.primaryStrong),
      onPrimaryStrong: mix(onPrimaryStrong, other.onPrimaryStrong),
      primarySoft: mix(primarySoft, other.primarySoft),
      background: mix(background, other.background),
      surface: mix(surface, other.surface),
      surfaceVariant: mix(surfaceVariant, other.surfaceVariant),
      border: mix(border, other.border),
      text: mix(text, other.text),
      textMuted: mix(textMuted, other.textMuted),
      success: mix(success, other.success),
      onSuccess: mix(onSuccess, other.onSuccess),
      error: mix(error, other.error),
      onError: mix(onError, other.onError),
      warning: mix(warning, other.warning),
      chartCorrect: mix(chartCorrect, other.chartCorrect),
      chartWrong: mix(chartWrong, other.chartWrong),
    );
  }
}
