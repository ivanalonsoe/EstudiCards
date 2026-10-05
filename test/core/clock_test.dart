import 'package:estudicards/core/clock.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SystemClock', () {
    test('returns the current time in UTC', () {
      final before = DateTime.timestamp();
      final now = const SystemClock().now();
      final after = DateTime.timestamp();

      expect(now.isUtc, isTrue);
      expect(now.isBefore(before), isFalse);
      expect(now.isAfter(after), isFalse);
    });
  });

  group('FakeClock', () {
    final start = DateTime.utc(2026, 10, 5, 9, 30);

    test('returns the time it was set to', () {
      final clock = FakeClock(start);

      expect(clock.now(), start);
      expect(clock.now(), start, reason: 'time does not move on its own');
    });

    test('can be advanced', () {
      final clock = FakeClock(start)..advance(const Duration(minutes: 90));

      expect(clock.now(), DateTime.utc(2026, 10, 5, 11));
    });

    test('can be set to another time', () {
      final later = DateTime.utc(2026, 10, 21);
      final clock = FakeClock(start)..set(later);

      expect(clock.now(), later);
    });

    test('rejects local times, because the app works in UTC', () {
      expect(() => FakeClock(DateTime(2026)), throwsArgumentError);
      expect(() => FakeClock(start).set(DateTime(2026)), throwsArgumentError);
    });
  });
}
