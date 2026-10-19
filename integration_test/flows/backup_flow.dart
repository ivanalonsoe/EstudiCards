// Phase 5 wrap-up (TASKS.md T5.9): export everything from one database,
// restore it into a new, empty one and compare (SPEC §11: "exporting
// everything on one device and restoring on another leaves identical
// data"). Run from `integration_test/app_test.dart`.
//
// The two databases stand for two devices. The file goes from one to the
// other in memory: the system dialogs are tested by the E2E tests.
import 'package:drift/native.dart';
import 'package:estudicards/core/db/app_database.dart';
import 'package:estudicards/core/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../app_flow.dart';

void backupFlowTests() {
  testWidgets('export all, restore into a new database: identical data', (
    tester,
  ) async {
    // The first device: a project with a deck, two cards and a session.
    final first = AppDatabase(NativeDatabase.memory());
    addTearDown(first.close);
    final exporter = MemoryFileExporter();
    await tester.pumpWidget(
      appWithTestDatabase(
        db: first,
        overrides: [fileExporterProvider.overrideWithValue(exporter)],
      ),
    );
    await waitFor(tester, find.byKey(const Key('dashboard.empty')));
    await createProject(tester, 'Biología');
    await createDeck(tester, 'Célula');
    await tapText(tester, 'Célula');
    await waitFor(tester, find.byKey(const Key('screen.deck')));
    await addSimpleCard(tester, 'Mitocondria', 'Produce el ATP');
    await addTestCard(
      tester,
      '¿Qué orgánulo hace la fotosíntesis?',
      wrong: 'Ribosoma',
      correct: 'Cloroplasto',
    );
    await tapKey(tester, 'deckScreen.study');
    await startSession(tester);
    for (var i = 0; i < 2; i++) {
      await answerCorrectly(tester, correctOptions: {'Cloroplasto'});
    }
    await backFromResults(tester);

    await goTo(tester, 'settings');
    await tapKey(tester, 'settings.exportAll');
    final deadline = DateTime.now().add(const Duration(seconds: 15));
    while (exporter.files.isEmpty && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await tester.pump();
    }
    final MapEntry(key: name, value: backup) = exporter.files.entries.single;
    expect(name, startsWith('estudicards-backup-'));
    final exported = await backupData(tester);

    // The second device: empty, so the backup goes in without asking.
    final second = AppDatabase(NativeDatabase.memory());
    addTearDown(second.close);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      appWithTestDatabase(
        db: second,
        overrides: [
          documentPickerProvider.overrideWithValue(
            MemoryDocumentPicker(name, backup),
          ),
        ],
      ),
    );
    await waitFor(tester, find.byKey(const Key('dashboard.empty')));
    await goTo(tester, 'settings');
    await tapKey(tester, 'settings.restore');
    await expectSoon(tester, find.text('Copia restaurada.'));

    expect(await backupData(tester), exported);
    expect(exported['attempts'] as List, hasLength(2));
    await goTo(tester, 'home');
    // The sidebar shows it too on desktop.
    await waitFor(tester, find.text('Biología'));
    expect(find.text('Biología'), findsWidgets);
  });
}
