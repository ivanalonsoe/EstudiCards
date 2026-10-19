import 'package:estudicards/core/providers.dart';
import 'package:estudicards/features/settings/data/settings_dao.dart';
import 'package:estudicards/features/settings/data/settings_repository.dart';
import 'package:estudicards/features/settings/domain/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepository(SettingsDao(ref.watch(databaseProvider))),
);

/// The user's settings, updated as soon as one changes: the theme of the
/// whole app, the study card's text size and the daily goal.
final appSettingsProvider = StreamProvider<AppSettings>(
  (ref) => ref.watch(settingsRepositoryProvider).watch(),
);

/// The study card's text size; 100% while the settings load.
final cardTextScaleProvider = Provider<double>(
  (ref) => ref.watch(appSettingsProvider).value?.cardTextScale ?? 1.0,
);

/// The languages of the user's language decks, for the voice status in
/// Settings. `autoDispose`: it is read again each time Settings opens.
final FutureProvider<List<String>> deckLanguagesProvider =
    FutureProvider.autoDispose<List<String>>(
      (ref) => ref.watch(settingsRepositoryProvider).languagesOfDecks(),
    );

/// Flutter's [ThemeMode] for the setting.
ThemeMode themeModeOf(AppThemeMode mode) => switch (mode) {
  AppThemeMode.system => ThemeMode.system,
  AppThemeMode.light => ThemeMode.light,
  AppThemeMode.dark => ThemeMode.dark,
};
