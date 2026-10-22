import 'dart:async';

import 'package:estudicards/app/l10n/generated/app_localizations.dart';
import 'package:estudicards/app/shell/brand_logo.dart';
import 'package:estudicards/app/shell/nav_destinations.dart';
import 'package:estudicards/app/theme/app_colors.dart';
import 'package:estudicards/app/theme/dimensions.dart';
import 'package:estudicards/features/import_export/presentation/backup.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The general menu on mobile and tablet: a side drawer opened from the
/// dashboard's menu button (DESIGN_BRIEF.md §4). Besides the screens, it
/// has "Exportar todo" (SPEC §5.1).
class AppMenuDrawer extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context);
    return Drawer(
      key: const Key('shell.drawer'),
      backgroundColor: colors.surface,
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Row(
              children: [
                const BrandLogo(),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  l10n.appTitle,
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            NavTile(
              destination: importDestination,
              selected: false,
              onNavigate: () => Navigator.of(context).pop(),
            ),
            ListTile(
              key: const Key('nav.exportAll'),
              leading: const Icon(Icons.file_download_outlined),
              title: Text(l10n.exportAll),
              iconColor: colors.text,
              textColor: colors.text,
              titleTextStyle: Theme.of(context).textTheme.titleSmall,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadii.control),
              ),
              onTap: () {
                // The drawer's context goes away when it closes; the
                // dashboard's stays.
                final screenContext = Navigator.of(context).context;
                Navigator.of(context).pop();
                unawaited(exportAll(screenContext, ref));
              },
            ),
            for (final destination in menuDestinations)
              NavTile(
                destination: destination,
                selected: false,
                // Close the drawer before opening the new screen.
                onNavigate: () => Navigator.of(context).pop(),
              ),
          ],
        ),
      ),
    );
  }
}
