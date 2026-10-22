// Pieces shared by the project form (P02) and the deck form (P04).
import 'package:estudicards/app/l10n/generated/app_localizations.dart';
import 'package:estudicards/app/layout/breakpoints.dart';
import 'package:estudicards/app/theme/app_colors.dart';
import 'package:estudicards/app/theme/dimensions.dart';
import 'package:estudicards/app/theme/project_palette.dart';
import 'package:estudicards/features/projects/presentation/project_labels.dart';
import 'package:flutter/material.dart';

/// Shows [form] as a bottom sheet on mobile and as a dialog on tablet and
/// desktop. Returns what the form closes with (e.g. the saved item), or
/// null if the user cancelled.
Future<T?> showFormSheet<T>(BuildContext context, Widget form) {
  final isMobile =
      FormFactor.fromWidth(MediaQuery.sizeOf(context).width) ==
      FormFactor.mobile;
  return isMobile
      ? showModalBottomSheet<T>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          // Material's handle takes 48 px; this one leaves the title close
          // to it, as in `movil-claro/nuevo-proyecto.png`. The sheet can
          // still be dragged down to close it.
          builder: (context) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _SheetHandle(),
              Flexible(child: form),
            ],
          ),
        )
      : showDialog<T>(
          context: context,
          builder: (context) => Dialog(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: form,
            ),
          ),
        );
}

/// The small grey bar at the top of a bottom sheet.
class _SheetHandle extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: AppSpacing.md),
    child: Container(
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: AppColors.of(context).border,
        borderRadius: BorderRadius.circular(2),
      ),
    ),
  );
}

/// The frame of a form: title with a close button, the scrollable [fields],
/// and Cancel / Save at the bottom. Its parts get the keys `<keyPrefix>`,
/// `<keyPrefix>.close`, `<keyPrefix>.cancel` and `<keyPrefix>.save`.
class FormFrame extends StatelessWidget {
  const new({
    required this.keyPrefix,
    required this.title,
    required this.saveLabel,
    required this.onSave,
    required this.fields,
    super.key,
  });

  final String keyPrefix;
  final String title;
  final String saveLabel;

  /// Null disables the Save button.
  final VoidCallback? onSave;
  final List<Widget> fields;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      key: Key(keyPrefix),
      // Keeps the buttons above the on-screen keyboard.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.lg,
              AppSpacing.md,
              0,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                IconButton(
                  key: Key('$keyPrefix.close'),
                  tooltip: l10n.close,
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: fields,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: AppColors.of(context).border),
              ),
            ),
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    key: Key('$keyPrefix.cancel'),
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(l10n.cancel),
                  ),
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: FilledButton.icon(
                    key: Key('$keyPrefix.save'),
                    onPressed: onSave,
                    icon: const Icon(Icons.check_rounded),
                    label: Text(saveLabel, textAlign: TextAlign.center),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The bold label above each field, as in the design.
class FormLabel extends StatelessWidget {
  const new(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: Text(text, style: Theme.of(context).textTheme.titleSmall),
  );
}

/// The 12 colours of the project palette as circles; the chosen one has a
/// ✓ and a ring. Each circle has the key `<keyPrefix>.color.<colour key>`.
///
/// With an [inheritedColor] (the deck form), a first option "Del proyecto"
/// (key `<keyPrefix>.color.project`) stands for "no colour of its own":
/// choosing it sets the value to null.
class ColorPicker extends StatelessWidget {
  const new({
    required this.keyPrefix,
    required this.selected,
    required this.onChanged,
    this.inheritedColor,
    super.key,
  });

  final String keyPrefix;

  /// The chosen palette key; null means the inherited colour.
  final String? selected;
  final ValueChanged<String?> onChanged;
  final String? inheritedColor;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final brightness = Theme.of(context).brightness;
    final inherited = inheritedColor;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (inherited != null) ...[
          Semantics(
            label: l10n.projectColor,
            selected: selected == null,
            button: true,
            child: InkWell(
              key: Key('$keyPrefix.color.project'),
              onTap: () => onChanged(null),
              borderRadius: BorderRadius.circular(AppRadii.control),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ColorCircle(
                    color: ProjectColor.fromKey(inherited).resolve(brightness),
                    isSelected: selected == null,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  // The label is already read by the Semantics above.
                  ExcludeSemantics(
                    child: Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.md),
                      child: Text(l10n.projectColor),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        // At most 6 circles per row: two rows, as in the design.
        ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: minTouchTarget * 6 + AppSpacing.sm * 5,
          ),
          child: Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final color in ProjectColor.values)
                Semantics(
                  label: colorName(l10n, color),
                  selected: color.key == selected,
                  button: true,
                  child: InkResponse(
                    key: Key('$keyPrefix.color.${color.key}'),
                    onTap: () => onChanged(color.key),
                    child: _ColorCircle(
                      color: color.resolve(brightness),
                      isSelected: color.key == selected,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ColorCircle extends StatelessWidget {
  const new({required this.color, required this.isSelected});

  final Color color;
  final bool isSelected;

  @override
  Widget build(BuildContext context) => Container(
    width: minTouchTarget,
    height: minTouchTarget,
    padding: const EdgeInsets.all(AppSpacing.xs),
    decoration: isSelected
        ? BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 2),
          )
        : null,
    child: DecoratedBox(
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: isSelected
          ? Icon(
              Icons.check_rounded,
              // White in both themes, as in the design.
              color: AppColors.light.surface,
              size: 20,
            )
          : null,
    ),
  );
}
