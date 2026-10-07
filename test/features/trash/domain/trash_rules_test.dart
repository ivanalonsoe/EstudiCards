import 'package:estudicards/features/trash/domain/trash_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final deletedAt = DateTime.utc(2026, 10, 1, 9);
  DateTime after(Duration elapsed) => deletedAt.add(elapsed);

  group('daysLeft', () {
    test('is 15 right after deleting', () {
      expect(daysLeft(deletedAt, now: deletedAt), 15);
    });

    test('is 15 minus the whole days elapsed', () {
      expect(daysLeft(deletedAt, now: after(const Duration(days: 2))), 13);
      expect(daysLeft(deletedAt, now: after(const Duration(days: 14))), 1);
    });

    test('a day that has not finished does not count', () {
      expect(
        daysLeft(deletedAt, now: after(const Duration(days: 14, hours: 23))),
        1,
      );
    });

    test('is never negative', () {
      expect(daysLeft(deletedAt, now: after(const Duration(days: 20))), 0);
    });
  });

  group('isExpired', () {
    test('is false until 15 days have passed', () {
      expect(
        isExpired(
          deletedAt,
          now: after(const Duration(days: 14, hours: 23, minutes: 59)),
        ),
        isFalse,
      );
    });

    test('is true from 15 days on', () {
      expect(isExpired(deletedAt, now: after(trashRetention)), isTrue);
      expect(
        isExpired(deletedAt, now: after(const Duration(days: 30))),
        isTrue,
      );
    });
  });
}
