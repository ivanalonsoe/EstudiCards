import 'package:estudicards/app/theme/app_colors.dart';
import 'package:estudicards/app/theme/dimensions.dart';
import 'package:estudicards/app/theme/motion.dart';
import 'package:flutter/material.dart';

/// One option of a [PillSelector]: its value, its label and, for tests, the
/// key of its label.
typedef PillOption<T> = ({T value, String label, Key? key});

/// Chooses one of a few options, as the design draws it (`movil-claro/
/// ajustes.png`, "Sistema / Claro / Oscuro"): a grey track with the chosen
/// option on a white "pill".
///
/// With [expand] the options share the width equally; without it each takes
/// what its label needs. A long label takes as many lines as it needs, so
/// none is cut with large text. Each option is at
/// least 48 dp high, so it is easy to tap (brief §9), and screen readers
/// hear it as a button, selected or not.
class PillSelector<T> extends StatelessWidget {
  const new({
    required this.options,
    required this.selected,
    required this.onChanged,
    this.expand = true,
    super.key,
  });

  final List<PillOption<T>> options;
  final T selected;
  final ValueChanged<T> onChanged;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final segments = [
      for (final option in options)
        _Segment(
          label: option.label,
          labelKey: option.key,
          isSelected: option.value == selected,
          // Options as wide as their labels are compact, as in the design.
          padding: expand ? AppSpacing.md : AppSpacing.sm,
          onTap: () => onChanged(option.value),
        ),
    ];
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(
        color: colors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppRadii.control),
      ),
      // `IntrinsicHeight` keeps every option as high as the tallest one,
      // e.g. when one label takes two lines.
      child: IntrinsicHeight(
        child: Row(
          mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Without [expand], an option still shrinks (and its label
            // wraps) when the selector does not fit, e.g. with large text.
            for (final segment in segments)
              if (expand)
                Expanded(child: segment)
              else
                Flexible(child: segment),
          ],
        ),
      ),
    );
  }
}

/// [label] with non-breaking spaces inside its parentheses, so a label that
/// takes two lines never splits "(R. U.)" or "(9)".
String _keepParenthesesTogether(String label) => label.replaceAllMapped(
  RegExp(r'\([^)]*\)'),
  (match) => match[0]!.replaceAll(' ', ' '),
);

class _Segment extends StatelessWidget {
  const new({
    required this.label,
    required this.labelKey,
    required this.isSelected,
    required this.padding,
    required this.onTap,
  });

  final String label;
  final Key? labelKey;
  final bool isSelected;

  /// Space at each side of the label.
  final double padding;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final radius = BorderRadius.circular(AppRadii.control - AppSpacing.xs);
    return Semantics(
      button: true,
      selected: isSelected,
      inMutuallyExclusiveGroup: true,
      child: AnimatedContainer(
        duration: AppMotion.fade,
        constraints: const BoxConstraints(minHeight: minTouchTarget),
        decoration: BoxDecoration(
          color: isSelected ? colors.surface : Colors.transparent,
          borderRadius: radius,
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: radius,
            onTap: onTap,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: padding,
                vertical: AppSpacing.xs,
              ),
              child: Center(
                child: Text(
                  _keepParenthesesTogether(label),
                  key: labelKey,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: isSelected ? colors.text : colors.textMuted,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
