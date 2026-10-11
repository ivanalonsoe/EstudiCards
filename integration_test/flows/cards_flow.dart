// Phase 2 wrap-up (TASKS.md T2.9): cards of both types are created,
// edited, moved and deleted. Run from `integration_test/app_test.dart`.
//
// The decks are general, so the system voice is never asked for: it
// depends on the voices installed on each machine.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../app_flow.dart';

/// The row of the card whose question is [question] in the deck screen.
Finder _cardRow(String question) => find.ancestor(
  of: find.text(question),
  matching: find.byWidgetPredicate(
    (widget) =>
        widget.key is ValueKey<String> &&
        RegExp(r'^cardRow\.[^.]+$')
            .hasMatch((widget.key! as ValueKey<String>).value),
  ),
);

/// Selects a card: with its checkbox on desktop, with a long press on a
/// phone.
Future<void> _selectCard(WidgetTester tester, String question) async {
  final row = _cardRow(question);
  await waitFor(tester, row);
  final checkbox = find.descendant(of: row, matching: find.byType(Checkbox));
  if (checkbox.evaluate().isNotEmpty) {
    await tester.tap(checkbox);
  } else {
    await tester.longPress(row);
  }
  await tester.pumpAndSettle();
}

void cardsFlowTests() {
  testWidgets('create cards of both types, edit, move and delete them', (
    tester,
  ) async {
    await tester.pumpWidget(appWithTestDatabase());
    await waitFor(tester, find.byKey(const Key('dashboard.empty')));
    await createProject(tester, 'Biología');
    await createDeck(tester, 'Repaso');
    await createDeck(tester, 'Célula');

    // A simple card, then a test card with "Guardar y añadir otra".
    await tapText(tester, 'Célula');
    await expectSoon(tester, find.byKey(const Key('deckScreen.empty')));
    await tapKey(tester, 'deckScreen.addCard');
    await enterTextInKey(tester, 'cardEditor.question', 'Mitocondria');
    await enterTextInKey(tester, 'cardEditor.answer', 'Produce el ATP');
    await tapKey(tester, 'cardEditor.saveAndAdd');
    await expectSoon(tester, find.text('Tarjeta guardada'));

    await tapKey(tester, 'cardEditor.testType');
    await enterTextInKey(
      tester,
      'cardEditor.question',
      '¿Qué orgánulo hace la fotosíntesis?',
    );
    await enterTextInKey(tester, 'cardEditor.option.0', 'Ribosoma');
    await enterTextInKey(tester, 'cardEditor.option.1', 'Cloroplasto');
    await tapKey(tester, 'cardEditor.option.1.correct');
    await tapKey(tester, 'cardEditor.save');

    // Both cards are in the deck.
    await expectSoon(tester, _cardRow('Mitocondria'));
    await expectSoon(tester, _cardRow('¿Qué orgánulo hace la fotosíntesis?'));

    // Edit the simple card.
    await tester.tap(_cardRow('Mitocondria'));
    await tester.pumpAndSettle();
    await enterTextInKey(
      tester,
      'cardEditor.answer',
      'Produce la mayor parte del ATP',
    );
    await tapKey(tester, 'cardEditor.save');
    await expectSoon(tester, _cardRow('Mitocondria'));

    // Move it to "Repaso" (also general, so no warning).
    await _selectCard(tester, 'Mitocondria');
    await expectSoon(tester, find.text('1 seleccionada'));
    await tapKey(tester, 'deckScreen.moveTo');
    await tapText(tester, 'Repaso');
    await expectSoon(tester, find.text('Tarjeta movida a «Repaso»'));
    expect(_cardRow('Mitocondria'), findsNothing);

    // Delete the test card; without "Deshacer" it is gone for good.
    await _selectCard(tester, '¿Qué orgánulo hace la fotosíntesis?');
    await tapKey(tester, 'deckScreen.deleteSelected');
    await tapKey(tester, 'confirmDialog.confirm');
    await expectSoon(tester, find.byKey(const Key('deckScreen.empty')));
    // The snackbar lasts 5 seconds (real time here); then the card is
    // deleted.
    await Future<void>.delayed(const Duration(seconds: 6));
    await tester.pumpAndSettle();

    // The moved card is in "Repaso", with the edited answer.
    await goTo(tester, 'home');
    await tapText(tester, 'Biología');
    // "Repaso" has the moved card and "Célula" none. (On desktop the
    // project header also says "1 tarjeta · — aciertos".)
    await waitFor(tester, find.text('0 tarjetas · — aciertos'));
    expect(find.text('0 tarjetas · — aciertos'), findsOneWidget);
    expect(find.text('1 tarjeta · — aciertos'), findsWidgets);
    await tapText(tester, 'Repaso');
    await expectSoon(tester, _cardRow('Mitocondria'));
    await tester.tap(_cardRow('Mitocondria'));
    await tester.pumpAndSettle();
    await expectSoon(tester, find.text('Produce la mayor parte del ATP'));
  });
}
