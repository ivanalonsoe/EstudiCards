import 'package:estudicards/app/l10n/generated/app_localizations.dart';
import 'package:estudicards/app/theme/app_colors.dart';
import 'package:estudicards/app/theme/dimensions.dart';
import 'package:flutter/material.dart';

/// Asks the user to confirm an action (`docs/design/movil-claro/
/// dialogos.png`): an icon, a title, an explanation, "Cancelar" and the
/// [confirmLabel] button, red for destructive actions. Returns true if the
/// user confirmed.
///
/// Keys: `confirmDialog`, `confirmDialog.cancel`, `confirmDialog.confirm`.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String body,
  required String confirmLabel,
  IconData icon = Icons.delete_outline_rounded,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) {
      final colors = AppColors.of(context);
      final text = Theme.of(context).textTheme;
      return AlertDialog(
        key: const Key('confirmDialog'),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: colors.error.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadii.control),
              ),
              child: Icon(icon, color: colors.error),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(title, style: text.titleLarge),
          ],
        ),
        content: Text(
          body,
          style: text.bodyMedium?.copyWith(color: colors.textMuted),
        ),
        actions: [
          TextButton(
            key: const Key('confirmDialog.cancel'),
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(AppLocalizations.of(context).cancel),
          ),
          FilledButton(
            key: const Key('confirmDialog.confirm'),
            style: FilledButton.styleFrom(
              backgroundColor: colors.error,
              foregroundColor: colors.onError,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      );
    },
  );
  return confirmed ?? false;
}
