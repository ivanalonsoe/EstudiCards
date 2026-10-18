import 'package:estudicards/features/import_export/domain/auto_backups.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the name holds the UTC time it was made', () {
    final time = DateTime.utc(2026, 10, 18, 9, 30, 5);

    final name = autoBackupFileName(time);

    expect(name, 'estudicards-auto-20261018-093005.json');
    expect(autoBackupTime(name), time);
  });

  test('names the app did not write have no time', () {
    for (final name in [
      'estudicards-backup-2026-10-18.json',
      'estudicards-auto-2026.json',
      '../estudicards-auto-20261018-093005.json',
      'estudicards-auto-20261018-093005.json.txt',
    ]) {
      expect(autoBackupTime(name), isNull, reason: name);
    }
  });

  test('only the newest $maxAutoBackups are kept', () {
    final names = [
      for (var day = 1; day <= 8; day++)
        autoBackupFileName(DateTime.utc(2026, 10, day)),
    ]..shuffle();

    final deleted = autoBackupsToDelete([...names, 'notes.txt']);

    expect(deleted, [
      autoBackupFileName(DateTime.utc(2026, 10, 3)),
      autoBackupFileName(DateTime.utc(2026, 10, 2)),
      autoBackupFileName(DateTime.utc(2026, 10)),
    ]);
  });
}
