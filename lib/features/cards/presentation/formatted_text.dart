import 'package:estudicards/features/cards/domain/inline_format.dart';
import 'package:flutter/material.dart';

/// A card text with its `**bold**` and `*italic*` applied and the markers
/// hidden, as it is shown when studying.
class FormattedText extends StatelessWidget {
  const new(this.text, {this.style, this.textAlign, super.key});

  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) => Text.rich(
    TextSpan(
      children: [
        for (final run in parseInlineFormat(text))
          if (!run.isMarker)
            TextSpan(
              text: run.text,
              style: TextStyle(
                fontWeight: run.bold ? FontWeight.w800 : null,
                fontStyle: run.italic ? FontStyle.italic : null,
              ),
            ),
      ],
    ),
    style: style,
    textAlign: textAlign,
  );
}
