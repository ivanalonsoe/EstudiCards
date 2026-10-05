import 'package:estudicards/app/l10n/generated/app_localizations.dart';
import 'package:estudicards/app/router.dart';
import 'package:estudicards/app/theme/app_colors.dart';
import 'package:estudicards/app/theme/dimensions.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// One entry of the general menu (sidebar on desktop, drawer on mobile).
class NavDestination {
  const new({
    required this.id,
    required this.path,
    required this.icon,
    required this.label,
  });

  /// Used for the tile's key: `nav.<id>`.
  final String id;
  final String path;
  final IconData icon;
  final String Function(AppLocalizations l10n) label;
}

final homeDestination = NavDestination(
  id: 'home',
  path: AppRoutes.home,
  icon: Icons.home_outlined,
  label: (l10n) => l10n.home,
);

/// The links at the bottom of the sidebar, in the design's order.
final menuDestinations = [
  NavDestination(
    id: 'statistics',
    path: AppRoutes.statistics,
    icon: Icons.bar_chart_rounded,
    label: (l10n) => l10n.statistics,
  ),
  NavDestination(
    id: 'archived',
    path: AppRoutes.archived,
    icon: Icons.inventory_2_outlined,
    label: (l10n) => l10n.archived,
  ),
  NavDestination(
    id: 'trash',
    path: AppRoutes.trash,
    icon: Icons.delete_outline_rounded,
    label: (l10n) => l10n.trash,
  ),
  NavDestination(
    id: 'settings',
    path: AppRoutes.settings,
    icon: Icons.tune_rounded,
    label: (l10n) => l10n.settings,
  ),
];

/// A menu row. Highlighted with the soft orange when [selected].
class NavTile extends StatelessWidget {
  const new({
    required this.destination,
    required this.selected,
    this.onNavigate,
    super.key,
  });

  final NavDestination destination;
  final bool selected;

  /// Called before navigating, e.g. to close the drawer.
  final VoidCallback? onNavigate;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return ListTile(
      key: Key('nav.${destination.id}'),
      selected: selected,
      leading: Icon(destination.icon),
      title: Text(destination.label(AppLocalizations.of(context))),
      iconColor: colors.text,
      textColor: colors.text,
      selectedColor: colors.primaryStrong,
      selectedTileColor: colors.primarySoft,
      titleTextStyle: Theme.of(context).textTheme.titleSmall,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.control),
      ),
      onTap: () {
        onNavigate?.call();
        // `go` replaces the current screen stack with the one the path
        // describes (see router.dart).
        context.go(destination.path);
      },
    );
  }
}
