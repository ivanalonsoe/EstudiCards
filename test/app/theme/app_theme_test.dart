import 'package:estudicards/app/theme/app_colors.dart';
import 'package:estudicards/app/theme/app_theme.dart';
import 'package:estudicards/app/theme/dimensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final (brightness, theme, colors) in [
    (Brightness.light, AppTheme.light(), AppColors.light),
    (Brightness.dark, AppTheme.dark(), AppColors.dark),
  ]) {
    group('${brightness.name} theme', () {
      test('carries its colour tokens as an extension', () {
        expect(theme.brightness, brightness);
        expect(theme.extension<AppColors>(), colors);
      });

      test('maps the tokens onto the Material colour scheme', () {
        final scheme = theme.colorScheme;

        expect(theme.scaffoldBackgroundColor, colors.background);
        // Material's filled buttons use `primary`: the brief's primary-strong.
        expect(scheme.primary, colors.primaryStrong);
        expect(scheme.onPrimary, colors.onPrimaryStrong);
        expect(scheme.surface, colors.surface);
        expect(scheme.onSurface, colors.text);
        expect(scheme.onSurfaceVariant, colors.textMuted);
        expect(scheme.outline, colors.border);
        expect(scheme.error, colors.error);
      });

      test('uses Plus Jakarta Sans with the brief type scale', () {
        final text = theme.textTheme;

        expect(text.bodyMedium!.fontFamily, 'PlusJakartaSans');
        expect(
          [
            for (final style in [
              text.displaySmall,
              text.titleLarge,
              text.titleMedium,
              text.bodyMedium,
              text.labelMedium,
              text.bodySmall,
            ])
              (style!.fontSize, style.fontWeight),
          ],
          [
            (32.0, FontWeight.w800), // Display
            (22.0, FontWeight.w700), // Title
            (17.0, FontWeight.w700), // Subtitle
            (15.0, FontWeight.w400), // Body
            (13.0, FontWeight.w600), // Label
            (12.0, FontWeight.w500), // Caption
          ],
        );
        expect(text.bodyMedium!.color, colors.text);
      });

      test('buttons and fields have radius 12 and 48 px touch targets', () {
        final button = theme.filledButtonTheme.style!;
        final shape = button.shape!.resolve({})! as RoundedRectangleBorder;

        expect(shape.borderRadius, BorderRadius.circular(AppRadii.control));
        expect(button.minimumSize!.resolve({})!.height, 48);
        expect(
          (theme.inputDecorationTheme.border! as OutlineInputBorder)
              .borderRadius,
          BorderRadius.circular(AppRadii.control),
        );
      });
    });
  }

  test('spacing follows the 4 px grid and radii match the brief', () {
    expect(
      [
        AppSpacing.xs,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.xxl,
        AppSpacing.xxxl,
      ],
      [4, 8, 12, 16, 24, 32, 48],
    );
    expect(AppRadii.studyCard, 24);
    expect(AppRadii.listCard, 16);
    expect(AppRadii.control, 12);
    expect(AppRadii.chip, 999);
  });
}
