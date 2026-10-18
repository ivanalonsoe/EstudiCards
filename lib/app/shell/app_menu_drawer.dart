import 'package:estudicards/app/l10n/generated/app_localizations.dart';
import 'package:estudicards/app/shell/brand_logo.dart';
import 'package:estudicards/app/shell/nav_destinations.dart';
import 'package:estudicards/app/theme/app_colors.dart';
import 'package:estudicards/app/theme/dimensions.dart';
import 'package:flutter/material.dart';

/// The general menu on mobile and tablet: a side drawer opened from the
/// dashboard's menu button (DESIGN_BRIEF.md §4).
class AppMenuDrawer extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
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
                  AppLocalizations.of(context).appTitle,
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            for (final destination in [importDestination, ...menuDestinations])
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
