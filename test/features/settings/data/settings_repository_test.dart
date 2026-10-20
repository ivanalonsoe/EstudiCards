import 'package:estudicards/core/clock.dart';
import 'package:estudicards/core/db/app_database.dart';
import 'package:estudicards/features/decks/data/decks_dao.dart';
import 'package:estudicards/features/decks/data/decks_repository.dart';
import 'package:estudicards/features/decks/domain/deck.dart';
import 'package:estudicards/features/decks/domain/deck_input.dart';
import 'package:estudicards/features/projects/data/projects_dao.dart';
import 'package:estudicards/features/projects/data/projects_repository.dart';
import 'package:estudicards/features/projects/domain/project_input.dart';
import 'package:estudicards/features/settings/data/settings_dao.dart';
import 'package:estudicards/features/settings/data/settings_repository.dart';
import 'package:estudicards/features/settings/domain/app_settings.dart';
import 'package:estudicards/features/trash/data/trash_dao.dart';
import 'package:estudicards/features/trash/data/trash_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_image_files.dart';
import '../../../helpers/test_app.dart';

void main() {
  late AppDatabase db;
  late SettingsRepository settings;
  final clock = FakeClock(DateTime.utc(2026, 10, 19));

  setUp(() {
    db = createTestDatabase();
    settings = SettingsRepository(SettingsDao(db));
  });

  test('starts with the defaults', () async {
    final read = await settings.read();

    expect(read.themeMode, AppThemeMode.system);
    expect(read.cardTextScale, 1.0);
    expect(read.dailyGoal, isNull);
  });

  test('saves each setting in the settings table, where backups take them '
      'from', () async {
    await settings.setThemeMode(AppThemeMode.dark);
    await settings.setCardTextScale(1.3);
    await settings.setDailyGoal(25);

    final rows = {
      for (final row in await db.select(db.settings).get()) row.key: row.value,
    };
    expect(rows, {
      'theme_mode': 'dark',
      'card_text_scale': '1.3',
      'daily_goal': '25',
    });
  });

  test('turning the daily goal off stores no goal', () async {
    await settings.setDailyGoal(25);
    await settings.setDailyGoal(null);

    expect((await settings.read()).dailyGoal, isNull);
  });

  test('the settings are kept for the next start: another repository on the '
      'same database reads them', () async {
    await settings.setThemeMode(AppThemeMode.light);
    await settings.setCardTextScale(1.5);

    final read = await SettingsRepository(SettingsDao(db)).read();
    expect(read.themeMode, AppThemeMode.light);
    expect(read.cardTextScale, 1.5);
  });

  test('watching emits the settings and again after each change', () async {
    final emitted = <AppThemeMode>[];
    final subscription = settings.watch().listen(
      (value) => emitted.add(value.themeMode),
    );
    await pumpEventQueue();
    await settings.setThemeMode(AppThemeMode.dark);
    await pumpEventQueue();
    await subscription.cancel();

    expect(emitted, [AppThemeMode.system, AppThemeMode.dark]);
  });

  group('languages of the decks (voice status)', () {
    late ProjectsRepository projects;
    late DecksRepository decks;

    setUp(() {
      projects = ProjectsRepository(ProjectsDao(db), clock);
      decks = DecksRepository(DecksDao(db), clock);
    });

    Future<String> languageDeck(
      String projectId,
      String source,
      String target,
    ) async => (await decks.create(
      projectId,
      DeckInput(
        name: '$source → $target',
        type: DeckType.language,
        sourceLang: source,
        targetLang: target,
      ),
    )).id;

    Future<String> project(String name) async => (await projects.create(
      ProjectInput(name: name, color: 'blue', icon: 'globe'),
    )).id;

    test('lists the languages of every language deck, archived projects '
        'included, and leaves out general decks and the trash', () async {
      final english = await project('Inglés');
      await languageDeck(english, 'en-GB', 'es-ES');
      await decks.create(english, const DeckInput(name: 'Gramática'));
      final trashedDeck = await languageDeck(english, 'fr-FR', 'es-ES');

      final german = await project('Alemán');
      await languageDeck(german, 'de-DE', 'es-ES');
      await projects.setArchived(german, isArchived: true);

      final italian = await project('Italiano');
      await languageDeck(italian, 'it-IT', 'es-ES');

      final trash = TrashRepository(TrashDao(db), clock, FakeImageFiles());
      await trash.moveDeckToTrash(trashedDeck);
      await trash.moveProjectToTrash(italian);

      expect(
        await settings.languagesOfDecks(),
        unorderedEquals(['en-GB', 'es-ES', 'de-DE']),
      );
    });
  });
}
