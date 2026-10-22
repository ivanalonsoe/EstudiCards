import 'package:estudicards/features/settings/domain/app_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('reading the stored settings (SPEC §4.2)', () {
    test('with nothing stored, the defaults: system theme, 100% and a '
        'daily goal of 20 cards', () {
      final settings = AppSettings.fromStored(const {});

      expect(settings.themeMode, AppThemeMode.system);
      expect(settings.cardTextScale, 1.0);
      expect(settings.dailyGoal, 20);
    });

    test('reads every stored value', () {
      final settings = AppSettings.fromStored(const {
        'theme_mode': 'dark',
        'card_text_scale': '1.4',
        'daily_goal': '30',
      });

      expect(settings.themeMode, AppThemeMode.dark);
      expect(settings.cardTextScale, 1.4);
      expect(settings.dailyGoal, 30);
    });

    test('unknown or damaged values fall back to the defaults', () {
      final settings = AppSettings.fromStored(const {
        'theme_mode': 'sepia',
        'card_text_scale': 'big',
        'daily_goal': 'many',
      });

      expect(settings.themeMode, AppThemeMode.system);
      expect(settings.cardTextScale, 1.0);
      expect(settings.dailyGoal, 20);
    });

    test('a goal turned off is stored with no value, and stays off', () {
      expect(AppSettings.fromStored(const {'daily_goal': '0'}).dailyGoal, null);
      expect(
        AppSettings.fromStored(const {'daily_goal': '-5'}).dailyGoal,
        null,
      );
      expect(
        AppSettings.fromStored(const {'daily_goal': null}).dailyGoal,
        null,
      );
    });

    test('the card text size stays between 80% and 160%, in steps of 10%', () {
      double scaleOf(String stored) =>
          AppSettings.fromStored({'card_text_scale': stored}).cardTextScale;

      expect(scaleOf('0.5'), 0.8);
      expect(scaleOf('2'), 1.6);
      expect(scaleOf('1.04'), 1.0);
      expect(scaleOf('1.26'), 1.3);
    });
  });

  group('what is stored', () {
    test('each value is stored as text under its key', () {
      expect(AppThemeMode.light.stored, 'light');
      expect(storedCardTextScale(1.2), '1.2');
      expect(storedCardTextScale(0.8), '0.8');
      expect(storedCardTextScale(1), '1.0');
    });

    test('a scale is stored rounded and within range', () {
      expect(storedCardTextScale(1.2000000001), '1.2');
      expect(storedCardTextScale(3), '1.6');
    });
  });

  group('daily goal steps', () {
    test('turning the goal on starts at 20 cards', () {
      expect(defaultDailyGoal, 20);
    });

    test('"+" and "−" change it by 5, between 5 and 200', () {
      expect(nextDailyGoal(20), 25);
      expect(previousDailyGoal(20), 15);
      expect(previousDailyGoal(5), 5);
      expect(nextDailyGoal(200), 200);
    });

    test('a goal off the steps moves to the nearest step', () {
      expect(nextDailyGoal(22), 25);
      expect(previousDailyGoal(22), 20);
    });
  });

  test('the languages to check are those of every language deck, once each, '
      'in the order they first appear', () {
    expect(
      deckLanguages([
        (source: 'en-GB', target: 'es-ES'),
        (source: 'de-DE', target: 'es-ES'),
        (source: 'en-GB', target: 'en-GB'),
        (source: null, target: null),
      ]),
      ['en-GB', 'es-ES', 'de-DE'],
    );
  });
}
