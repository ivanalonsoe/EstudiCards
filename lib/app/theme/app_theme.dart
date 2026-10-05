import 'package:estudicards/app/theme/app_colors.dart';
import 'package:estudicards/app/theme/dimensions.dart';
import 'package:flutter/material.dart';

/// Builds the light and dark `ThemeData` from the colour tokens.
///
/// `ThemeData` is the set of colours, fonts and shapes that every Material
/// widget reads by default. Mapping our tokens onto it means a plain
/// `FilledButton` already looks like the design.
abstract final class AppTheme {
  /// Family name declared in `pubspec.yaml` (fonts bundled in assets/fonts/).
  static const fontFamily = 'PlusJakartaSans';

  static ThemeData light() => _build(Brightness.light, AppColors.light);

  static ThemeData dark() => _build(Brightness.dark, AppColors.dark);

  static ThemeData _build(Brightness brightness, AppColors colors) {
    final scheme = ColorScheme(
      brightness: brightness,
      // Material fills buttons, switches and focused fields with `primary`,
      // which in the design is primary-strong (AA contrast with its text).
      primary: colors.primaryStrong,
      onPrimary: colors.onPrimaryStrong,
      primaryContainer: colors.primarySoft,
      onPrimaryContainer: colors.text,
      secondary: colors.primary,
      onSecondary: colors.onPrimaryStrong,
      error: colors.error,
      onError: colors.onError,
      surface: colors.surface,
      onSurface: colors.text,
      onSurfaceVariant: colors.textMuted,
      surfaceContainerHighest: colors.surfaceVariant,
      outline: colors.border,
      outlineVariant: colors.border,
      // No pink-ish tint on raised surfaces (a Material 3 default).
      surfaceTint: Colors.transparent,
    );

    final controlShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadii.control),
    );
    const buttonText = TextStyle(
      fontFamily: fontFamily,
      fontSize: 15,
      fontWeight: FontWeight.w700,
    );
    final buttonStyle = ButtonStyle(
      shape: WidgetStatePropertyAll(controlShape),
      minimumSize: const WidgetStatePropertyAll(Size(64, minTouchTarget)),
      textStyle: const WidgetStatePropertyAll(buttonText),
    );
    OutlineInputBorder fieldBorder(Color color, {double width = 1}) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.control),
          borderSide: BorderSide(color: color, width: width),
        );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: colors.background,
      fontFamily: fontFamily,
      textTheme: _textTheme(colors),
      dividerColor: colors.border,
      extensions: [colors],
      filledButtonTheme: FilledButtonThemeData(style: buttonStyle),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: buttonStyle.copyWith(
          foregroundColor: WidgetStatePropertyAll(colors.text),
          side: WidgetStatePropertyAll(BorderSide(color: colors.border)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(style: buttonStyle),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surfaceVariant,
        hintStyle: TextStyle(color: colors.textMuted),
        border: fieldBorder(Colors.transparent),
        enabledBorder: fieldBorder(Colors.transparent),
        focusedBorder: fieldBorder(colors.primaryStrong, width: 2),
        errorBorder: fieldBorder(colors.error, width: 2),
        focusedErrorBorder: fieldBorder(colors.error, width: 2),
      ),
      cardTheme: CardThemeData(
        color: colors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.listCard),
          side: BorderSide(color: colors.border),
        ),
      ),
    );
  }

  /// The type scale from the design (`docs/design/sistema/tokens.png`).
  static TextTheme _textTheme(AppColors colors) {
    TextStyle style(double size, FontWeight weight, {Color? color}) =>
        TextStyle(
          fontFamily: fontFamily,
          fontSize: size,
          fontWeight: weight,
          color: color ?? colors.text,
        );

    final body = style(15, FontWeight.w400);
    return TextTheme(
      displaySmall: style(32, FontWeight.w800), // Display
      headlineSmall: style(22, FontWeight.w700),
      titleLarge: style(22, FontWeight.w700), // Title
      titleMedium: style(17, FontWeight.w700), // Subtitle
      titleSmall: style(15, FontWeight.w700),
      bodyLarge: body,
      bodyMedium: body, // Body
      bodySmall: style(12, FontWeight.w500, color: colors.textMuted), // Caption
      labelLarge: style(15, FontWeight.w700),
      labelMedium: style(13, FontWeight.w600), // Label
      labelSmall: style(12, FontWeight.w500),
    );
  }
}
