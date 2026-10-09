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
final Finder testTypeSwitch = find.byKey(const Key('cardEditor.testType'));
final Finder allowMultipleSwitch = find.byKey(
  const Key('cardEditor.allowMultiple'),
);
final Finder addOptionButton = find.byKey(const Key('cardEditor.addOption'));

/// The text field of the option at [index] (from 0).
Finder optionField(int index) => find.byKey(Key('cardEditor.option.$index'));

/// The "correct" selector of the option at [index].
Finder correctSelector(int index) =>
    find.byKey(Key('cardEditor.option.$index.correct'));

/// The ✕ that removes the option at [index].
Finder removeOptionButton(int index) =>
    find.byKey(Key('cardEditor.option.$index.remove'));

/// How many options the editor shows.
int optionCount() => find
    .byWidgetPredicate(
      (widget) =>
          widget.key is ValueKey<String> &&
          RegExp(r'^cardEditor\.option\.\d+$')
              .hasMatch((widget.key! as ValueKey<String>).value),
    )
    .evaluate()
    .length;

/// Whether the option at [index] is ticked as correct, as a screen reader
/// would announce it.
bool isTicked(WidgetTester tester, int index) =>
    isSemantics(isChecked: true)
        .matches(tester.getSemantics(correctSelector(index)), {});

/// Scrolls [finder] into view, lets the screen settle and taps it. The
/// editor is longer than the screen, so a widget can be out of sight.
Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
}

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
