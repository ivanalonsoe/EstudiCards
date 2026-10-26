import 'package:estudicards/app/l10n/generated/app_localizations.dart';
import 'package:estudicards/app/theme/app_colors.dart';
import 'package:flutter/material.dart';

/// What a card image shows when its file is missing: an icon and "Imagen no
/// disponible". It happens after Android restores its copy of the app,
/// which leaves the images out (T6.14), so the card still names a file
/// that is not in the images folder.
class MissingImage extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.broken_image_outlined,
              size: 20,
              color: colors.textMuted,
            ),
            const SizedBox(height: 2),
            // Flexible: in the editor's 64 px thumbnail the text wraps onto
            // two lines and is cut rather than overflowing.
            Flexible(
              child: Text(
                AppLocalizations.of(context).imageUnavailable,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall
                    ?.copyWith(color: colors.textMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
