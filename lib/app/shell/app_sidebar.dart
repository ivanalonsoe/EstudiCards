import 'package:estudicards/app/l10n/generated/app_localizations.dart';
import 'package:estudicards/app/shell/brand_logo.dart';
import 'package:estudicards/app/shell/nav_destinations.dart';
import 'package:estudicards/app/theme/app_colors.dart';
import 'package:estudicards/app/theme/dimensions.dart';
import 'package:flutter/material.dart';

/// The fixed left sidebar on desktop (`docs/design/escritorio-claro/`).
///
/// The project list, search and the daily goal card are filled in by the
/// phase 1 and phase 4 tasks; for now the sidebar has the frame and menu.
class AppSidebar extends StatelessWidget {
  const new({required this.location, super.key});

  static const double width = 280;

  /// The current path, to highlight the matching menu entry.
  final String location;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;

    return Material(
      key: const Key('shell.sidebar'),
      color: colors.surface,
      child: Container(
        width: width,
        decoration: BoxDecoration(
          border: Border(right: BorderSide(color: colors.border)),
        ),
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const BrandLogo(),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  l10n.appTitle,
                  style: text.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            // Not wired yet: project search arrives with the project list.
            TextField(
              decoration: InputDecoration(
                hintText: l10n.searchProjects,
                prefixIcon: const Icon(Icons.search_rounded),
                isDense: true,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            NavTile(
              destination: homeDestination,
              selected: location == homeDestination.path,
            ),
            const SizedBox(height: AppSpacing.lg),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Text(
                l10n.projects.toUpperCase(),
                style: text.labelSmall?.copyWith(
                  color: colors.textMuted,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            // The project list goes here (phase 1).
            const Spacer(),
            for (final destination in menuDestinations)
              NavTile(
                destination: destination,
                selected: location == destination.path,
              ),
          ],
        ),
      ),
    );
  }
}
