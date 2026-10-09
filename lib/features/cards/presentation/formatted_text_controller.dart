import 'package:estudicards/app/theme/app_colors.dart';
import 'package:estudicards/features/cards/domain/inline_format.dart';
import 'package:flutter/material.dart';

/// The text of a card field with `**bold**` and `*italic*` (US-08 AC3).
///
/// A `TextEditingController` holds what a text field shows. Overriding
/// `buildTextSpan` changes how the text is drawn without changing the text
/// itself: the words between markers look bold or italic, and the markers
/// stay visible but dimmed, so the user can still delete them.
class FormattedTextController extends TextEditingController {
  new({super.text});

  /// Wraps the selection in [style]'s markers, or removes them (the B and I
  /// buttons).
  void toggle(InlineStyle style) {
    // With no cursor yet (the field was never tapped), act at the end.
    final selection = this.selection.isValid
        ? this.selection
        : TextSelection.collapsed(offset: text.length);
    final result = toggleInlineStyle(
      text,
      start: selection.start,
      end: selection.end,
      style: style,
    );
    value = TextEditingValue(
      text: result.text,
      selection: TextSelection(
        baseOffset: result.start,
        extentOffset: result.end,
      ),
    );
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    required bool withComposing,
    TextStyle? style,
  }) {
    // While the keyboard is composing a word (e.g. an accent on Android),
    // keep Flutter's own drawing, which underlines that word.
    if (withComposing && value.isComposingRangeValid) {
      return super.buildTextSpan(
        context: context,
        style: style,
        withComposing: withComposing,
      );
    }
    final muted = AppColors.of(context).textMuted;
    return TextSpan(
      style: style,
      children: [
        for (final run in parseInlineFormat(text))
          TextSpan(
            text: run.text,
            style: TextStyle(
              fontWeight: run.bold ? FontWeight.w700 : null,
              fontStyle: run.italic ? FontStyle.italic : null,
              color: run.isMarker ? muted : null,
            ),
          ),
      ],
    );
  }
}
