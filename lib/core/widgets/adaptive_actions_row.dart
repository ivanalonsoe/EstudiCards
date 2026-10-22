import 'package:estudicards/app/theme/dimensions.dart';
import 'package:flutter/material.dart';

/// The bottom row of a Trash or Archived card: [leading] (a label) on the
/// left and [actions] on the right, on one row as in the design. When they
/// do not fit (e.g. with large system text) they go on two lines, aligned
/// right.
///
/// `OverflowBar` lays its children out in a row when they fit, and one
/// under the other when they do not.
class AdaptiveActionsRow extends StatelessWidget {
  const new({required this.leading, required this.actions, super.key});

  final Widget leading;
  final Widget actions;

  @override
  Widget build(BuildContext context) => OverflowBar(
    alignment: MainAxisAlignment.spaceBetween,
    overflowAlignment: OverflowBarAlignment.end,
    overflowSpacing: AppSpacing.sm,
    children: [leading, actions],
  );
}
