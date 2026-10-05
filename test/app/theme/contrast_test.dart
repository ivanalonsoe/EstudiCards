import 'dart:ui';

import 'package:estudicards/app/theme/app_colors.dart';
import 'package:estudicards/app/theme/contrast.dart';
import 'package:flutter_test/flutter_test.dart';

/// WCAG AA minimum for normal text.
const aaNormalText = 4.5;

void main() {
  group('contrastRatio', () {
    test('is 21 between black and white, in either order', () {
      const black = Color(0xFF000000);
      const white = Color(0xFFFFFFFF);

      expect(contrastRatio(black, white), closeTo(21, 0.01));
      expect(contrastRatio(white, black), closeTo(21, 0.01));
    });

    test('is 1 between a colour and itself', () {
      expect(
        contrastRatio(AppColors.light.primary, AppColors.light.primary),
        1,
      );
    });
  });

  for (final (name, colors) in [
    ('light', AppColors.light),
    ('dark', AppColors.dark),
  ]) {
    group('$name theme', () {
      test('text on primary-strong is at least 4.5:1', () {
        expect(
          contrastRatio(colors.onPrimaryStrong, colors.primaryStrong),
          greaterThanOrEqualTo(aaNormalText),
        );
      });

      test('text on success and error buttons is at least 4.5:1', () {
        expect(
          contrastRatio(colors.onSuccess, colors.success),
          greaterThanOrEqualTo(aaNormalText),
        );
        expect(
          contrastRatio(colors.onError, colors.error),
          greaterThanOrEqualTo(aaNormalText),
        );
      });

      test('main and muted text are at least 4.5:1 on every surface', () {
        for (final surface in [
          colors.background,
          colors.surface,
          colors.surfaceVariant,
        ]) {
          expect(
            contrastRatio(colors.text, surface),
            greaterThanOrEqualTo(aaNormalText),
          );
          expect(
            contrastRatio(colors.textMuted, surface),
            greaterThanOrEqualTo(aaNormalText),
          );
        }
      });
    });
  }
}
