import 'dart:ui';

import 'package:estudicards/app/theme/app_colors.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the light tokens have the values from the brief (§3.1)', () {
    const c = AppColors.light;

    expect(c.primary, const Color(0xFFF97316));
    expect(c.primaryStrong, const Color(0xFFC2410C));
    expect(c.onPrimaryStrong, const Color(0xFFFFFFFF));
    expect(c.primarySoft, const Color(0xFFFFF1E6));
    expect(c.background, const Color(0xFFFAFAF9));
    expect(c.surface, const Color(0xFFFFFFFF));
    expect(c.surfaceVariant, const Color(0xFFF2F1EF));
    expect(c.border, const Color(0xFFE7E5E4));
    expect(c.text, const Color(0xFF1C1917));
    expect(c.textMuted, const Color(0xFF736C67)); // adjusted for AA in T0.6
    expect(c.success, const Color(0xFF15803D));
    expect(c.onSuccess, const Color(0xFFFFFFFF));
    expect(c.error, const Color(0xFFBE123C));
    expect(c.onError, const Color(0xFFFFFFFF));
    expect(c.warning, const Color(0xFFB45309));
    expect(c.chartCorrect, const Color(0xFF15803D));
    expect(c.chartWrong, const Color(0xFFFB7185));
  });

  test('the dark tokens have the values from the brief (§3.1)', () {
    const c = AppColors.dark;

    expect(c.primary, const Color(0xFFFB923C));
    expect(c.primaryStrong, const Color(0xFFFDBA74));
    expect(c.onPrimaryStrong, const Color(0xFF1C1917));
    expect(c.primarySoft, const Color(0xFF3A2314));
    expect(c.background, const Color(0xFF0F0E0D));
    expect(c.surface, const Color(0xFF1C1A18));
    expect(c.surfaceVariant, const Color(0xFF282522));
    expect(c.border, const Color(0xFF35312D));
    expect(c.text, const Color(0xFFF5F5F4));
    expect(c.textMuted, const Color(0xFFA8A29E));
    expect(c.success, const Color(0xFF4ADE80));
    expect(c.onSuccess, const Color(0xFF1C1917));
    expect(c.error, const Color(0xFFFB7185));
    expect(c.onError, const Color(0xFF1C1917));
    expect(c.warning, const Color(0xFFFBBF24));
    expect(c.chartCorrect, const Color(0xFF16A34A));
    expect(c.chartWrong, const Color(0xFFFB7185));
  });

  test('lerp blends every token, so theme changes can animate', () {
    final middle = AppColors.light.lerp(AppColors.dark, 0.5);

    expect(
      middle.background,
      Color.lerp(AppColors.light.background, AppColors.dark.background, 0.5),
    );
    expect(AppColors.light.lerp(AppColors.dark, 1).text, AppColors.dark.text);
  });

  test('copyWith changes only the given tokens', () {
    final copy = AppColors.light.copyWith(primary: const Color(0xFF000000));

    expect(copy.primary, const Color(0xFF000000));
    expect(copy.surface, AppColors.light.surface);
  });
}
