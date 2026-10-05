import 'package:estudicards/app/l10n/generated/app_localizations.dart';
import 'package:estudicards/app/layout/breakpoints.dart';
import 'package:estudicards/app/shell/app_menu_drawer.dart';
import 'package:estudicards/app/shell/brand_logo.dart';
import 'package:estudicards/app/theme/dimensions.dart';
import 'package:flutter/material.dart';

/// An empty screen with only its title. Every route uses one until the
/// task that builds the real screen replaces it.
class PlaceholderScreen extends StatelessWidget {
  const new({this.title, this.isHome = false, super.key})
    : assert(title != null || isHome, 'only the home screen has no title');

  final String? title;

  /// The dashboard: shows the logo and, on mobile, the menu drawer.
  final bool isHome;

  @override
  Widget build(BuildContext context) {
    final isDesktop =
        FormFactor.fromWidth(MediaQuery.sizeOf(context).width) ==
        FormFactor.desktop;

    return Scaffold(
      appBar: AppBar(
        // On desktop the logo is already in the sidebar.
        title: isHome && !isDesktop
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const BrandLogo(),
                  const SizedBox(width: AppSpacing.sm),
                  Text(AppLocalizations.of(context).appTitle),
                ],
              )
            : Text(title ?? AppLocalizations.of(context).home),
      ),
      // On desktop the sidebar already shows the menu.
      drawer: isHome && !isDesktop ? const AppMenuDrawer() : null,
    );
  }
}
