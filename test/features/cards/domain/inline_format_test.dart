import 'package:estudicards/features/cards/domain/inline_format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseInlineFormat', () {
    test('plain text is one plain run', () {
      expect(parseInlineFormat('to bring'), [formattedRun('to bring')]);
      expect(parseInlineFormat(''), isEmpty);
    });

    test('finds bold and italic, keeping the markers as runs', () {
      expect(parseInlineFormat('Can you **bring** me *some* water?'), [
        formattedRun('Can you '),
        formattedRun('**', isMarker: true),
        formattedRun('bring', bold: true),
        formattedRun('**', bold: true, isMarker: true),
        formattedRun(' me '),
        formattedRun('*', isMarker: true),
        formattedRun('some', italic: true),
        formattedRun('*', italic: true, isMarker: true),
        formattedRun(' water?'),
      ]);
    });

    test('bold and italic can be nested', () {
      expect(parseInlineFormat('**a *b* c**'), [
        formattedRun('**', isMarker: true),
        formattedRun('a ', bold: true),
        formattedRun('*', bold: true, isMarker: true),
        formattedRun('b', bold: true, italic: true),
        formattedRun('*', bold: true, italic: true, isMarker: true),
        formattedRun(' c', bold: true),
        formattedRun('**', bold: true, isMarker: true),
      ]);
    });

    test('three markers make bold italic text', () {
      final runs = parseInlineFormat('***both***');

      expect(runs.where((r) => !r.isMarker), [
        formattedRun('both', bold: true, italic: true),
      ]);
      expect(runs.map((r) => r.text).join(), '***both***');
    });

    test('a marker without its pair is plain text', () {
      expect(parseInlineFormat('5 * 3'), [formattedRun('5 * 3')]);
      expect(parseInlineFormat('**open'), [formattedRun('**open')]);
    });

    test('joining the runs gives back the text', () {
      const text = 'a **b** *c* ***d*** **e *f***  *';
      expect(parseInlineFormat(text).map((r) => r.text).join(), text);
    });
  });

  group('toggleInlineStyle', () {
    test('wraps the selection and keeps it selected', () {
      final result = toggleInlineStyle(
        'Can you bring me',
        start: 8,
        end: 13,
        style: InlineStyle.bold,
      );

      expect(result.text, 'Can you **bring** me');
      expect(result.text.substring(result.start, result.end), 'bring');
    });

    test('italic uses a single marker', () {
      final result = toggleInlineStyle(
        'some water',
        start: 0,
        end: 4,
        style: InlineStyle.italic,
      );

      expect(result.text, '*some* water');
      expect((result.start, result.end), (1, 5));
    });

    test('with nothing selected, inserts the pair with the cursor inside', () {
      final result = toggleInlineStyle(
        'ab',
        start: 1,
        end: 1,
        style: InlineStyle.bold,
      );

      expect(result.text, 'a****b');
      expect((result.start, result.end), (3, 3));
    });

    test('removes the style when the selection already has it', () {
      final result = toggleInlineStyle(
        'Can you **bring** me',
        start: 10,
        end: 15,
        style: InlineStyle.bold,
      );

      expect(result.text, 'Can you bring me');
      expect(result.text.substring(result.start, result.end), 'bring');
    });

    test('italic inside bold adds italic instead of breaking the bold', () {
      final result = toggleInlineStyle(
        '**bring**',
        start: 2,
        end: 7,
        style: InlineStyle.italic,
      );

      expect(result.text, '***bring***');
      expect(result.text.substring(result.start, result.end), 'bring');
    });

    test('removes italic from bold italic text and keeps the bold', () {
      final result = toggleInlineStyle(
        '***bring***',
        start: 3,
        end: 8,
        style: InlineStyle.italic,
      );

      expect(result.text, '**bring**');
      expect(result.text.substring(result.start, result.end), 'bring');
    });
  });
}
