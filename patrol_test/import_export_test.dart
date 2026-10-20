// Phase 5 E2E tests (SPEC §10.2):
//
// - E2E-04: import a CSV with the native file picker → preview with
//   duplicates and errors → import.
// - E2E-05: export all → delete the data → restore the backup → the data is
//   identical.
// - E2E-07: share a deck: the native share sheet opens (Android).
//
//   adb push test/fixtures/verbos_ia.csv /sdcard/Download/verbos_ia.csv
//   patrol test --target patrol_test/import_export_test.dart
//
// E2E-04 picks `verbos_ia.csv` from the device's Downloads folder, so it has
// to be copied there first (CI does it before running Patrol).
import 'dart:typed_data';

import 'package:estudicards/core/files/document_picker.dart';
import 'package:estudicards/core/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import '../integration_test/app_flow.dart';

/// Picks the last file the [exporter] received: the backup goes from
/// "Exportar todo" to "Restaurar copia" in memory (E2E-05).
class _PickExported implements DocumentPicker {
  new(this.exporter);

  final MemoryFileExporter exporter;

  @override
  Future<PickedDocument?> pick(List<String> extensions) async {
    final MapEntry(key: name, value: bytes) = exporter.files.entries.last;
    return PickedDocument(
      name: name,
      size: bytes.length,
      read: () async => Uint8List.fromList(bytes),
    );
  }
}

/// A project "Inglés B2" with a general deck "Verbos irregulares", left open
/// on the deck screen.
Future<void> _createDeck(WidgetTester tester) async {
  await waitFor(tester, find.byKey(const Key('dashboard.empty')));
  await createProject(tester, 'Inglés B2');
  await createDeck(tester, 'Verbos irregulares');
  await tapText(tester, 'Verbos irregulares');
  await waitFor(tester, find.byKey(const Key('screen.deck')));
}

void main() {
  patrolTest('E2E-04: import a CSV with the native file picker, with '
      'duplicates and errors', ($) async {
    final tester = $.tester;
    await $.pumpWidgetAndSettle(appWithTestDatabase());
    await _createDeck(tester);
    // The three cards that `verbos_ia.csv` repeats.
    await addSimpleCard(tester, 'to bring', 'traer (brought, brought)');
    await addSimpleCard(tester, 'to seek', 'buscar (sought, sought)');
    await addSimpleCard(tester, 'to lend', 'prestar (lent, lent)');

    await tapKey(tester, 'deckScreen.import');
    await tapKey(tester, 'import.chooseFile');
    // The system file picker: Downloads, then the file.
    await $.platform.mobile.tap(Selector(contentDescription: 'Show roots'));
    await $.platform.mobile.tap(Selector(text: 'Downloads'));
    await $.platform.mobile.tap(Selector(text: 'verbos_ia.csv'));

    await $(const Key('import.new')).$('42').waitUntilVisible();
    expect($(const Key('import.duplicates')).$('3'), findsOneWidget);
    expect($(const Key('import.errors')).$('1'), findsOneWidget);
    await tapKey(tester, 'import.confirm');
    await $('42 añadidas, 3 omitidas por duplicadas, 1 con errores')
        .waitUntilVisible();
    await $(find.textContaining('45 tarjetas')).waitUntilVisible();
  });

  patrolTest('E2E-05: export all, delete the data, restore the backup: the '
      'data is identical', ($) async {
    final tester = $.tester;
    final exporter = MemoryFileExporter();
    await $.pumpWidgetAndSettle(
      appWithTestDatabase(
        overrides: [
          fileExporterProvider.overrideWithValue(exporter),
          documentPickerProvider.overrideWithValue(_PickExported(exporter)),
        ],
      ),
    );
    await _createDeck(tester);
    await addSimpleCard(tester, 'to bring', 'traer');
    final before = await backupData(tester);

    await goTo(tester, 'settings');
    await tapKeyInSettings(tester, 'settings.exportAll');
    await waitFor(tester, find.byKey(const Key('settings.restore')));
    expect(exporter.files, hasLength(1));

    // Delete everything: the project, and then the trash.
    await goTo(tester, 'home');
    await chooseInProjectCardMenu(tester, 'Eliminar');
    await tapKey(tester, 'confirmDialog.confirm');
    await goTo(tester, 'trash');
    await tapKey(tester, 'trash.empty');
    await tapKey(tester, 'confirmDialog.confirm');
    await $(const Key('trash.emptyState')).waitUntilVisible();

    // With nothing left, the backup goes in without asking.
    await goTo(tester, 'settings');
    await tapKeyInSettings(tester, 'settings.restore');
    await $('Copia restaurada.').waitUntilVisible();
    expect(await backupData(tester), before);
    await goTo(tester, 'home');
    await $('Inglés B2').waitUntilVisible();
  });

  patrolTest('E2E-07: sharing a deck opens the native share sheet', ($) async {
    final tester = $.tester;
    await $.pumpWidgetAndSettle(appWithTestDatabase());
    await _createDeck(tester);
    await addSimpleCard(tester, 'to bring', 'traer');

    await tapKey(tester, 'deckScreen.menu');
    await tapKey(tester, 'deckScreen.share');
    await tapKey(tester, 'shareDialog.confirm');
    // Android's share sheet names the shared file.
    await $.platform.mobile.waitUntilVisible(
      Selector(textContains: 'Verbos irregulares'),
      timeout: const Duration(seconds: 20),
    );
    await $.platform.android.pressBack();
    await $(const Key('screen.deck')).waitUntilVisible();
  });
}
