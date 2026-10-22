import 'package:estudicards/app/theme/dimensions.dart';
import 'package:flutter/material.dart';

/// A heading with something at its right, e.g. "Últimos 30 días" and
/// "tarjetas por día", or "Opciones" and "3 de 6 · 2 correctas".
///
/// [trailing] takes the width it needs, up to half the row, and sits at the
/// right edge; [title] takes the rest. With large system text [trailing]
/// wraps instead of pushing the title out.
class HeadingRow extends StatelessWidget {
  const new({required this.title, this.trailing, super.key});

  final Widget title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final trailing = this.trailing;
    if (trailing == null) return title;
    return LayoutBuilder(
      builder: (context, constraints) => Row(
        children: [
          Expanded(child: title),
          const SizedBox(width: AppSpacing.md),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: constraints.maxWidth / 2),
            child: trailing,
          ),
        ],
      ),
    );
  }
}
