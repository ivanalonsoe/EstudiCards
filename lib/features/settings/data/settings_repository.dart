// The entry point the app uses to read and change the settings (see
// `ProjectsRepository` for what a repository does). They live in the
// `settings` table, so "Exportar todo" takes them with the rest of the data
// (SPEC §8.2).
import 'package:estudicards/features/settings/data/settings_dao.dart';
import 'package:estudicards/features/settings/domain/app_settings.dart';

class SettingsRepository {
  new(this._dao);

  final SettingsDao _dao;

  Future<AppSettings> read() async =>
      AppSettings.fromStored(await _dao.readAll());

  /// The settings now and again after every change.
  Stream<AppSettings> watch() => _dao.watchAll().map(AppSettings.fromStored);

  Future<void> setThemeMode(AppThemeMode mode) =>
      _dao.write(SettingKeys.themeMode, mode.stored);

  Future<void> setCardTextScale(double scale) =>
      _dao.write(SettingKeys.cardTextScale, storedCardTextScale(scale));

  /// Null turns the goal off.
  Future<void> setDailyGoal(int? goal) =>
      _dao.write(SettingKeys.dailyGoal, goal?.toString());

  /// The languages of the user's language decks, to check their voices.
  Future<List<String>> languagesOfDecks() async =>
      deckLanguages(await _dao.languageDecks());
}
