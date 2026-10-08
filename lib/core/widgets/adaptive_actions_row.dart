import 'package:estudicards/app/theme/dimensions.dart';
import 'package:flutter/material.dart';

/// The bottom row of a Trash or Archived card: [leading] (a label) on the
/// left and [actions] on the right. On a phone they do not fit on one line,
/// so [leading] goes above and [actions] below, aligned right.
///
/// `LayoutBuilder` tells how wide the card is before choosing the layout.
class AdaptiveActionsRow extends StatelessWidget {
  const new({required this.leading, required this.actions, super.key});

  final Widget leading;
  final Widget actions;

  /// Narrower than this, the actions go on their own line.
  static const double _oneLineWidth = 360;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxWidth < _oneLineWidth) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(alignment: Alignment.centerLeft, child: leading),
            const SizedBox(height: AppSpacing.sm),
            Align(alignment: Alignment.centerRight, child: actions),
          ],
        );
      }
      return Row(
        children: [
          Expanded(
            child: Align(alignment: Alignment.centerLeft, child: leading),
          ),
          actions,
        ],
      );
    },
  );
}
