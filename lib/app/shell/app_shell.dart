import 'package:estudicards/app/layout/breakpoints.dart';
import 'package:estudicards/app/shell/app_sidebar.dart';
import 'package:flutter/material.dart';

/// The frame around the screens (SPEC §3.3).
///
/// - Desktop (≥ 840 dp): fixed sidebar on the left, the screen on the right.
/// - Mobile and tablet: only the screen; the menu is a drawer on the
///   dashboard (see DashboardScreen).
class AppShell extends StatelessWidget {
  const new({required this.location, required this.child, super.key});

  /// The current path, passed on to the sidebar.
  final String location;

  /// The current screen, given by the router.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (FormFactor.fromWidth(width) != FormFactor.desktop) return child;

    return Row(
      children: [
        AppSidebar(location: location),
        Expanded(child: child),
      ],
    );
  }
}
