import 'package:estudicards/app/theme/app_colors.dart';
import 'package:estudicards/app/theme/dimensions.dart';
import 'package:estudicards/app/theme/project_palette.dart';
import 'package:flutter/material.dart';

/// A developer screen that shows the theme: type scale, colour tokens,
/// project palette and the main controls. It is the app's home until the
/// router arrives (T0.8).
///
/// Its labels are design token names, not UI copy, so they are not in the
/// ARB file.
class ThemePreviewScreen extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    final brightness = Theme.of(context).brightness;

    final tokens = {
      'primary': colors.primary,
      'primaryStrong': colors.primaryStrong,
      'primarySoft': colors.primarySoft,
      'background': colors.background,
      'surface': colors.surface,
      'surfaceVariant': colors.surfaceVariant,
      'border': colors.border,
      'text': colors.text,
      'textMuted': colors.textMuted,
      'success': colors.success,
      'error': colors.error,
      'warning': colors.warning,
    };

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          children: [
            Text('EstudiCards', style: text.displaySmall),
            const SizedBox(height: AppSpacing.sm),
            Text('Title 22/700', style: text.titleLarge),
            Text('Subtitle 17/700', style: text.titleMedium),
            Text('Body 15/400', style: text.bodyMedium),
            Text('Label 13/600', style: text.labelMedium),
            Text('Caption 12/500', style: text.bodySmall),
            const SizedBox(height: AppSpacing.xl),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                FilledButton(onPressed: () {}, child: const Text('primary')),
                OutlinedButton(
                  onPressed: () {},
                  child: const Text('secondary'),
                ),
                TextButton(onPressed: () {}, child: const Text('text')),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.success,
                    foregroundColor: colors.onSuccess,
                  ),
                  onPressed: () {},
                  icon: const Icon(Icons.check),
                  label: const Text('success'),
                ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.error,
                    foregroundColor: colors.onError,
                  ),
                  onPressed: () {},
                  icon: const Icon(Icons.close),
                  label: const Text('error'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            const TextField(decoration: InputDecoration(hintText: 'TextField')),
            const SizedBox(height: AppSpacing.xl),
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.md,
              children: [
                for (final MapEntry(key: name, value: color) in tokens.entries)
                  _Swatch(color: color, label: name),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.md,
              children: [
                for (final projectColor in ProjectColor.values)
                  _Swatch(
                    color: projectColor.resolve(brightness),
                    label: projectColor.key,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const new({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return SizedBox(
      width: 96,
      child: Column(
        children: [
          Container(
            height: 48,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(AppRadii.control),
              border: Border.all(color: colors.border),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
