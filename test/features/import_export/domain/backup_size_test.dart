import 'package:estudicards/features/import_export/domain/backup_size.dart';
import 'package:estudicards/features/import_export/domain/exchange_document.dart';
import 'package:estudicards/features/import_export/domain/import_limits.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a backup may be bigger than a shared file', () {
    expect(maxBackupFileBytes, 500 * 1024 * 1024);
    expect(maxBackupFileBytes, greaterThan(maxJsonFileBytes));
  });

  group('a file is too large', () {
    test('over the backup limit, whatever it is', () {
      expect(exchangeTooLarge(maxBackupFileBytes), isFalse);
      expect(exchangeTooLarge(maxBackupFileBytes + 1), isTrue);
    });

    test('a backup up to its own limit is read', () {
      expect(
        exchangeTooLarge(maxJsonFileBytes + 1, kind: ExchangeKind.backup),
        isFalse,
      );
    });

    test('a shared project or deck keeps the 100 MB limit', () {
      for (final kind in [ExchangeKind.project, ExchangeKind.deck]) {
        expect(exchangeTooLarge(maxJsonFileBytes, kind: kind), isFalse);
        expect(exchangeTooLarge(maxJsonFileBytes + 1, kind: kind), isTrue);
      }
    });
  });

  test('the estimated size adds the images as base64', () {
    // Base64 writes every 3 bytes as 4 characters, rounding up; each
    // image also has its `{"mime": …, "data": …}` around it.
    expect(
      estimatedBackupBytes(textBytes: 1000, imageSizes: [300, 301]),
      1000 + 400 + 404 + 2 * 40,
    );
    expect(estimatedBackupBytes(textBytes: 10, imageSizes: const []), 10);
  });
}
