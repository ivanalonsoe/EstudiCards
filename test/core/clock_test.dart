import 'package:estudicards/core/clock.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/time_zones.dart';

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

    test('without a time zone, local days are UTC days', () {
      final clock = FakeClock(start);

      expect(
        clock.localDay(DateTime.utc(2026, 10, 15, 23, 59)),
        DateTime.utc(2026, 10, 15),
      );
    });
  });

  group('local days in Madrid', () {
    final clock = FakeClock(
      DateTime.utc(2026, 10, 15),
      utcOffset: madridOffset,
    );

    test('a day starts at local midnight', () {
      // Summer time (+2): 21:59 UTC is 23:59 and 22:00 UTC is 00:00.
      expect(
        clock.localDay(DateTime.utc(2026, 10, 15, 21, 59)),
        DateTime.utc(2026, 10, 15),
      );
      expect(
        clock.localDay(DateTime.utc(2026, 10, 15, 22)),
        DateTime.utc(2026, 10, 16),
      );
      // Winter time (+1): 23:00 UTC is midnight.
      expect(
        clock.localDay(DateTime.utc(2026, 12, 2, 22, 59)),
        DateTime.utc(2026, 12, 2),
      );
      expect(
        clock.localDay(DateTime.utc(2026, 12, 2, 23)),
        DateTime.utc(2026, 12, 3),
      );
    });

    test('the day clocks go back has 25 hours', () {
      // 25 October 2026: 03:00 summer time becomes 02:00 winter time.
      expect(
        clock.localDay(DateTime.utc(2026, 10, 24, 22)),
        DateTime.utc(2026, 10, 25),
      );
      expect(
        clock.localDay(DateTime.utc(2026, 10, 25, 22, 59)),
        DateTime.utc(2026, 10, 25),
      );
      expect(
        clock.localDay(DateTime.utc(2026, 10, 25, 23)),
        DateTime.utc(2026, 10, 26),
      );
    });

    test('the day clocks go forward has 23 hours', () {
      // 29 March 2026: 02:00 winter time becomes 03:00 summer time.
      expect(
        clock.localDay(DateTime.utc(2026, 3, 28, 23)),
        DateTime.utc(2026, 3, 29),
      );
      expect(
        clock.localDay(DateTime.utc(2026, 3, 29, 21, 59)),
        DateTime.utc(2026, 3, 29),
      );
      expect(
        clock.localDay(DateTime.utc(2026, 3, 29, 22)),
        DateTime.utc(2026, 3, 30),
      );
    });
  });

  test('the system clock gives the local date of an instant', () {
    final instant = DateTime.utc(2026, 7, 1, 12);
    final local = instant.toLocal();

    expect(
      const SystemClock().localDay(instant),
      DateTime.utc(local.year, local.month, local.day),
    );
  });

  test('a day is stored as YYYY-MM-DD text and read back', () {
    final day = DateTime.utc(2026, 3, 9);

    expect(dayKey(day), '2026-03-09');
    expect(parseDayKey('2026-03-09'), day);
  });
}
