import 'package:estudicards/features/import_export/domain/export_names.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('joins the parts with "-" and adds the extension (SPEC §8.1)', () {
    expect(exportFileName(['Inglés B2'], 'json'), 'Inglés B2.json');
    expect(
      exportFileName(['Inglés B2', 'Verbos irregulares'], 'csv'),
      'Inglés B2-Verbos irregulares.csv',
    );
  });

  test('drops the characters a file name cannot have', () {
    expect(
      exportFileName(['Mates: 1/2 <"ESO">?', r'a\b|c*'], 'csv'),
      'Mates 12 ESO-abc.csv',
    );
  });

  test('trims spaces and dots that Windows refuses at the end', () {
    expect(
      exportFileName(['  Notas.. ', ' Tema   1 '], 'json'),
      'Notas-Tema 1.json',
    );
  });

  test('a name with nothing usable becomes "estudicards"', () {
    expect(exportFileName(['???', '///'], 'csv'), 'estudicards.csv');
  });

  test('a backup is named after the local day (SPEC §8.1)', () {
    expect(
      backupFileName(DateTime.utc(2026, 9, 3)),
      'estudicards-backup-2026-09-03.json',
    );
  });

  test('a very long name is cut', () {
    final name = exportFileName(['x' * 200], 'json');

    expect(name, '${'x' * 80}.json');
  });
}
