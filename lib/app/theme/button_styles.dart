import 'package:estudicards/app/theme/app_colors.dart';
import 'package:estudicards/app/theme/dimensions.dart';
import 'package:flutter/material.dart';

/// An icon button in a white box with a thin border, as the share, import
/// and ⋮ buttons of the desktop headers in the design
/// (`escritorio-claro/proyecto.png`).
ButtonStyle boxedIconButtonStyle(BuildContext context) {
  final colors = AppColors.of(context);
  return IconButton.styleFrom(
    backgroundColor: colors.surface,
    side: BorderSide(color: colors.border),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadii.control),
    ),
  );
}
