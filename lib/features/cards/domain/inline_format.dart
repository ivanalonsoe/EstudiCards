// Bold and italic in card texts (US-08 AC3), stored as `**bold**` and
// `*italic*`.

/// The two styles of the formatting bar, with their marker.
enum InlineStyle {
  bold('**'),
  italic('*');

  new(this.marker);

  final String marker;
}

/// A piece of a card text with its style. Markers (`**`, `*`) are runs too,
/// so the editor can show them dimmed instead of hiding them.
///
/// It is a record: two runs with the same values are equal, which keeps
/// the tests short.
typedef FormattedRun = ({String text, bool bold, bool italic, bool isMarker});

/// A [FormattedRun]; plain text unless told otherwise.
FormattedRun formattedRun(
  String text, {
  bool bold = false,
  bool italic = false,
  bool isMarker = false,
}) => (text: text, bold: bold, italic: italic, isMarker: isMarker);

/// Splits [text] into runs with their style. `**` turns bold on and off and
/// `*` italic; `***` is both. A marker without its pair is plain text, so
/// "5 * 3" stays as typed. Joining the runs' text gives [text] back.
List<FormattedRun> parseInlineFormat(String text) {
  // 1. Split into markers and plain text. A run of asterisks is read as
  //    pairs (`**`) followed by one `*` if the count is odd.
  final tokens = <({String text, InlineStyle? style})>[];
  for (final match in RegExp(r'\*+|[^*]+').allMatches(text)) {
    final part = match[0]!;
    if (!part.startsWith('*')) {
      tokens.add((text: part, style: null));
      continue;
    }
    for (var i = 0; i < part.length ~/ 2; i++) {
      tokens.add((text: '**', style: InlineStyle.bold));
    }
    if (part.length.isOdd) tokens.add((text: '*', style: InlineStyle.italic));
  }

  // 2. Markers work in pairs: with an odd number of one kind, the last one
  //    has no pair and is plain text.
  final unpaired = <int>{};
  for (final style in InlineStyle.values) {
    final indexes = [
      for (final (i, token) in tokens.indexed)
        if (token.style == style) i,
    ];
    if (indexes.length.isOdd) unpaired.add(indexes.last);
  }

  // 3. Walk the tokens switching bold and italic on and off. Each marker
  //    keeps the style in force when it appears.
  var bold = false;
  var italic = false;
  final runs = <FormattedRun>[];
  void add(FormattedRun run) {
    final last = runs.lastOrNull;
    // Plain text next to plain text of the same style becomes one run.
    if (last != null &&
        !last.isMarker &&
        !run.isMarker &&
        last.bold == run.bold &&
        last.italic == run.italic) {
      runs.last = formattedRun(
        last.text + run.text,
        bold: run.bold,
        italic: run.italic,
      );
    } else {
      runs.add(run);
    }
  }

  for (final (i, token) in tokens.indexed) {
    final style = token.style;
    if (style == null || unpaired.contains(i)) {
      add(formattedRun(token.text, bold: bold, italic: italic));
      continue;
    }
    add(formattedRun(token.text, bold: bold, italic: italic, isMarker: true));
    switch (style) {
      case InlineStyle.bold:
        bold = !bold;
      case InlineStyle.italic:
        italic = !italic;
    }
  }
  return runs;
}

/// What the formatting bar's B and I buttons do: wraps the selection from
/// [start] to [end] in the [style]'s markers, or removes them if they are
/// already there. Returns the new text and the selection, which still
/// covers the same words. With nothing selected, the pair is inserted with
/// the cursor between them.
({String text, int start, int end}) toggleInlineStyle(
  String text, {
  required int start,
  required int end,
  required InlineStyle style,
}) {
  int countStars(Iterable<int> indexes) =>
      indexes.takeWhile((i) => text[i] == '*').length;
  final before = countStars([for (var i = start - 1; i >= 0; i--) i]);
  final after = countStars([for (var i = end; i < text.length; i++) i]);

  // `**` around the selection means bold, an odd number of `*` italic, and
  // `***` both.
  final hasStyle = switch (style) {
    InlineStyle.bold => before >= 2 && after >= 2,
    InlineStyle.italic => before.isOdd && after.isOdd,
  };
  final length = style.marker.length;
  if (hasStyle) {
    return (
      text:
          text.substring(0, start - length) +
          text.substring(start, end) +
          text.substring(end + length),
      start: start - length,
      end: end - length,
    );
  }
  return (
    text:
        text.substring(0, start) +
        style.marker +
        text.substring(start, end) +
        style.marker +
        text.substring(end),
    start: start + length,
    end: end + length,
  );
}
