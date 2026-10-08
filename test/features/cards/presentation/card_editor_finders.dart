// Finders and helpers shared by the card editor tests.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final Finder questionField = find.byKey(const Key('cardEditor.question'));
final Finder answerField = find.byKey(const Key('cardEditor.answer'));
final Finder exampleField = find.byKey(const Key('cardEditor.example'));
final Finder notesField = find.byKey(const Key('cardEditor.notes'));
final Finder explanationField = find.byKey(const Key('cardEditor.explanation'));
final Finder saveButton = find.byKey(const Key('cardEditor.save'));
final Finder saveAndAddButton = find.byKey(const Key('cardEditor.saveAndAdd'));
final Finder cancelButton = find.byKey(const Key('cardEditor.cancel'));
final Finder closeButton = find.byKey(const Key('cardEditor.close'));

/// Whether the button found by [finder] can be tapped.
bool isEnabled(WidgetTester tester, Finder finder) =>
    tester.widget<ButtonStyleButton>(finder).onPressed != null;

EditableText _editable(WidgetTester tester, Finder field) =>
    tester.widget<EditableText>(
      find.descendant(of: field, matching: find.byType(EditableText)),
    );

/// The text in the field found by [field].
String fieldText(WidgetTester tester, Finder field) =>
    _editable(tester, field).controller.text;

bool hasFocus(WidgetTester tester, Finder field) =>
    _editable(tester, field).focusNode.hasFocus;

/// Selects the characters from [start] to [end] in [field], as a user
/// dragging over them would.
void setSelection(WidgetTester tester, Finder field, int start, int end) {
  _editable(tester, field).controller.selection = TextSelection(
    baseOffset: start,
    extentOffset: end,
  );
}
