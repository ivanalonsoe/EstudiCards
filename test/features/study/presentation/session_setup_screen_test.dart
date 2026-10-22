import 'package:drift/drift.dart' show OrderingTerm;
import 'package:estudicards/app/router.dart';
import 'package:estudicards/core/clock.dart';
import 'package:estudicards/core/db/app_database.dart';
import 'package:estudicards/core/widgets/pill_selector.dart';
import 'package:estudicards/features/cards/data/cards_dao.dart';
import 'package:estudicards/features/cards/data/cards_repository.dart';
import 'package:estudicards/features/cards/domain/card_input.dart';
import 'package:estudicards/features/cards/domain/flashcard.dart';
import 'package:estudicards/features/decks/data/decks_dao.dart';
import 'package:estudicards/features/decks/data/decks_repository.dart';
import 'package:estudicards/features/decks/domain/deck.dart';
import 'package:estudicards/features/decks/domain/deck_input.dart';
import 'package:estudicards/features/projects/data/projects_dao.dart';
import 'package:estudicards/features/projects/data/projects_repository.dart';
import 'package:estudicards/features/projects/domain/project_input.dart';
import 'package:estudicards/features/study/data/study_dao.dart';
import 'package:estudicards/features/study/data/study_repository.dart';
import 'package:estudicards/features/study/domain/session_config.dart';
import 'package:estudicards/features/study/domain/session_state.dart';
import 'package:estudicards/features/study/domain/study_options.dart';
import 'package:estudicards/features/study/presentation/session_launch.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_image_files.dart';
import '../../../helpers/test_app.dart';
import '../../../helpers/test_data.dart';

final _clock = FakeClock(DateTime.utc(2026, 10, 14, 9));

/// A project with two English → Spanish decks (3 and 2 cards) and a
/// general one (1 card).
typedef SetupProject = ({
  String projectId,
  Deck verbs,
  Deck phrasal,
  Deck travel,
});

Future<SetupProject> seedProject(AppDatabase db) async {
  final project = await ProjectsRepository(
    ProjectsDao(db),
    _clock,
  ).create(const ProjectInput(name: 'Inglés B2', color: 'blue', icon: 'globe'));
  final decks = DecksRepository(DecksDao(db), _clock);
  final cards = CardsRepository(CardsDao(db), _clock, FakeImageFiles());
  Future<Deck> deck(String name, int cardCount, {bool language = true}) async {
    final deck = await decks.create(
      project.id,
      DeckInput(
        name: name,
        type: language ? DeckType.language : DeckType.general,
        sourceLang: language ? 'en-GB' : null,
        targetLang: language ? 'es-ES' : null,
      ),
    );
    for (var i = 1; i <= cardCount; i++) {
      await cards.create(
        deck.id,
        CardInput(type: CardType.simple, question: '$name $i', answer: 'x'),
      );
    }
    return deck;
  }

  return (
    projectId: project.id,
    verbs: await deck('Verbos irregulares', 3),
    phrasal: await deck('Phrasal verbs', 2),
    travel: await deck('Vocabulario viajes', 1, language: false),
  );
}

/// The IDs of [deck]'s cards, by question ("… 1", "… 2"…).
Future<List<String>> cardIdsOf(AppDatabase db, Deck deck) async => [
  for (final card
      in await (db.select(db.cards)
            ..where((c) => c.deckId.equals(deck.id))
            ..orderBy([(c) => OrderingTerm.asc(c.question)]))
          .get())
    card.id,
];

/// Records a miss of [cardId] in [direction], which puts it in errors.
Future<void> miss(
  AppDatabase db,
  SetupProject project,
  String cardId,
  String direction,
) => addTestAnswers(
  db,
  projectId: project.projectId,
  cardId: cardId,
  direction: direction,
  results: ['wrong'],
);

FilterChip deckChip(WidgetTester tester, Deck deck) =>
    tester.widget(find.byKey(Key('sessionSetup.deck.${deck.id}')));

/// A text shown as [text]: the pill selector keeps what is in parentheses
/// on one line with non-breaking spaces, which read as plain spaces.
Finder findShownText(String text) => find.byWidgetPredicate(
  (widget) => widget is Text && widget.data?.replaceAll(' ', ' ') == text,
);

Set<T> segmentOf<T>(WidgetTester tester, String key) => {
  tester.widget<PillSelector<T>>(find.byKey(Key(key))).selected,
};

String availableText(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const Key('sessionSetup.available'))).data!;

bool startEnabled(WidgetTester tester) =>
    tester
        .widget<FilledButton>(find.byKey(const Key('sessionSetup.start')))
        .onPressed !=
    null;

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  for (final (name, size) in [('mobile', mobile), ('desktop', desktop)]) {
    testWidgets('loads the last configuration of the project ($name)', (
      tester,
    ) async {
      final db = createTestDatabase();
      final project = await seedProject(db);
      await StudyRepository(StudyDao(db), _clock).startSession(
        project.projectId,
        SessionConfig(
          deckIds: [project.phrasal.id],
          mode: StudyMode.errors,
          direction: StudyDirection.reverse,
          requestedCount: 50,
          prioritizeFailed: true,
          timerType: TimerType.perCard,
          timerSeconds: 45,
        ),
      );

      await pumpTestApp(
        tester,
        size: size,
        db: db,
        location: AppRoutes.sessionSetup(project.projectId),
      );

      expect(deckChip(tester, project.phrasal).selected, isTrue);
      expect(deckChip(tester, project.verbs).selected, isFalse);
      expect(deckChip(tester, project.travel).selected, isFalse);
      expect(segmentOf<String>(tester, 'sessionSetup.count'), {'50'});
      expect(segmentOf<StudyMode>(tester, 'sessionSetup.mode'), {
        StudyMode.errors,
      });
      expect(segmentOf<StudyDirection>(tester, 'sessionSetup.direction'), {
        StudyDirection.reverse,
      });
      expect(
        tester
            .widget<Switch>(find.byKey(const Key('sessionSetup.prioritize')))
            .value,
        isTrue,
      );
      expect(
        tester
            .widget<Switch>(find.byKey(const Key('sessionSetup.repeat')))
            .value,
        isFalse,
      );
      expect(segmentOf<TimerType>(tester, 'sessionSetup.timer'), {
        TimerType.perCard,
      });
      expect(find.text('45 s'), findsOneWidget);
    });

    testWidgets('the number of available cards changes when the decks or the '
        'mode change ($name)', (tester) async {
      final db = createTestDatabase();
      final project = await seedProject(db);
      await pumpTestApp(
        tester,
        size: size,
        db: db,
        location: AppRoutes.sessionSetup(project.projectId),
      );

      // Every deck by default: 6 cards, fewer than the 20 asked for.
      expect(availableText(tester), '6 tarjetas disponibles · se usarán todas');

      await tapVisible(
        tester,
        find.byKey(Key('sessionSetup.deck.${project.verbs.id}')),
      );
      expect(availableText(tester), '3 tarjetas disponibles · se usarán todas');

      await tapVisible(tester, find.byKey(const Key('sessionSetup.count.10')));
      await tapVisible(tester, find.text('Todo el proyecto'));
      expect(availableText(tester), '6 tarjetas disponibles · se usarán todas');

      // "Solo errores": no card has been missed yet.
      await tapVisible(
        tester,
        find.byKey(const Key('sessionSetup.mode.errors')),
      );
      expect(availableText(tester), 'No hay tarjetas disponibles');
    });

    testWidgets('"Sentido" only appears when a chosen deck is a language deck '
        '($name)', (tester) async {
      final db = createTestDatabase();
      final project = await seedProject(db);
      await pumpTestApp(
        tester,
        size: size,
        db: db,
        location: AppRoutes.sessionSetup(project.projectId),
      );

      expect(find.byKey(const Key('sessionSetup.direction')), findsOneWidget);
      // Both language decks are English → Spanish, so the pair is named.
      expect(findShownText('Inglés (R. U.) → Español'), findsWidgets);
      expect(findShownText('Español → Inglés (R. U.)'), findsOneWidget);

      await tapVisible(
        tester,
        find.byKey(Key('sessionSetup.deck.${project.verbs.id}')),
      );
      await tapVisible(
        tester,
        find.byKey(Key('sessionSetup.deck.${project.phrasal.id}')),
      );

      expect(find.byKey(const Key('sessionSetup.direction')), findsNothing);
    });
  }

  testWidgets('language decks with different pairs offer "Normal" and '
      '"Inverso"', (tester) async {
    final db = createTestDatabase();
    final project = await seedProject(db);
    await DecksRepository(DecksDao(db), _clock).create(
      project.projectId,
      const DeckInput(
        name: 'Francés',
        type: DeckType.language,
        sourceLang: 'fr-FR',
        targetLang: 'es-ES',
      ),
    );
    await pumpTestApp(
      tester,
      size: mobile,
      db: db,
      location: AppRoutes.sessionSetup(project.projectId),
    );

    expect(find.text('Normal'), findsWidgets);
    expect(find.text('Inverso'), findsOneWidget);
    expect(findShownText('Español → Inglés (R. U.)'), findsNothing);
  });

  for (final (name, size) in [('mobile', mobile), ('desktop', desktop)]) {
    testWidgets('with no cards available, "Empezar" is disabled ($name)', (
      tester,
    ) async {
      final db = createTestDatabase();
      final project = await ProjectsRepository(
        ProjectsDao(db),
        _clock,
      ).create(const ProjectInput(name: 'Vacío', color: 'blue', icon: 'globe'));
      await DecksRepository(
        DecksDao(db),
        _clock,
      ).create(project.id, const DeckInput(name: 'Sin tarjetas'));
      await pumpTestApp(
        tester,
        size: size,
        db: db,
        location: AppRoutes.sessionSetup(project.id),
      );

      expect(availableText(tester), 'No hay tarjetas disponibles');
      expect(startEnabled(tester), isFalse);
    });
  }

  testWidgets('without a chosen deck, "Empezar" is disabled', (tester) async {
    final db = createTestDatabase();
    final project = await seedProject(db);
    await pumpTestApp(
      tester,
      size: mobile,
      db: db,
      location: AppRoutes.sessionSetup(project.projectId),
    );
    expect(startEnabled(tester), isTrue);

    for (final deck in [project.verbs, project.phrasal, project.travel]) {
      await tapVisible(tester, find.byKey(Key('sessionSetup.deck.${deck.id}')));
    }

    expect(startEnabled(tester), isFalse);
  });

  testWidgets('"Otro" chooses the number with − and +, up to the available '
      'cards', (tester) async {
    final db = createTestDatabase();
    final project = await seedProject(db);
    await pumpTestApp(
      tester,
      size: mobile,
      db: db,
      location: AppRoutes.sessionSetup(project.projectId),
    );

    await tapVisible(
      tester,
      find.byKey(const Key('sessionSetup.count.custom')),
    );
    // 20 asked for, but only 6 available.
    expect(find.byKey(const Key('sessionSetup.customCount')), findsOneWidget);
    expect(find.text('6'), findsOneWidget);

    await tapVisible(
      tester,
      find.byKey(const Key('sessionSetup.customCount.plus')),
    );
    expect(find.text('6'), findsOneWidget);
    await tapVisible(
      tester,
      find.byKey(const Key('sessionSetup.customCount.minus')),
    );
    expect(find.text('5'), findsOneWidget);
    expect(availableText(tester), '6 tarjetas disponibles · se usarán 5');
  });

  testWidgets('the timer value goes up and down in its steps', (tester) async {
    final db = createTestDatabase();
    final project = await seedProject(db);
    await pumpTestApp(
      tester,
      size: mobile,
      db: db,
      location: AppRoutes.sessionSetup(project.projectId),
    );

    expect(find.byKey(const Key('sessionSetup.timerValue')), findsNothing);
    await tapVisible(tester, find.text('Por pregunta'));
    expect(find.text('30 s'), findsOneWidget);
    await tapVisible(
      tester,
      find.byKey(const Key('sessionSetup.timerValue.plus')),
    );
    expect(find.text('35 s'), findsOneWidget);

    await tapVisible(tester, find.text('General'));
    expect(find.text('10 min'), findsOneWidget);
    await tapVisible(
      tester,
      find.byKey(const Key('sessionSetup.timerValue.minus')),
    );
    expect(find.text('5 min'), findsOneWidget);
  });

  testWidgets('"Empezar" saves the session and opens it with its cards', (
    tester,
  ) async {
    final db = createTestDatabase();
    final project = await seedProject(db);
    final router = await pumpTestApp(
      tester,
      size: mobile,
      db: db,
      location: AppRoutes.sessionSetup(project.projectId),
    );
    await tapVisible(
      tester,
      find.byKey(Key('sessionSetup.deck.${project.travel.id}')),
    );
    await tapVisible(
      tester,
      find.byKey(const Key('sessionSetup.count.custom')),
    );
    await tapVisible(
      tester,
      find.byKey(const Key('sessionSetup.customCount.minus')),
    );

    await tapVisible(tester, find.byKey(const Key('sessionSetup.start')));

    final session = await db.select(db.studySessions).getSingle();
    expect(
      router.routerDelegate.currentConfiguration.uri.path,
      AppRoutes.session(session.id),
    );
    expect(session.requestedCount, 4);
    final launch = ProviderScope.containerOf(
      tester.element(find.byType(Navigator).first),
    ).read(launchedSessionsProvider)[session.id]!;
    expect(launch.cards, hasLength(4));
    expect(launch.cards.map((c) => c.card.deckId).toSet(), {
      project.verbs.id,
      project.phrasal.id,
    });
  });

  group('opening the setup', () {
    for (final (name, size) in [('mobile', mobile), ('desktop', desktop)]) {
      testWidgets('"Estudiar" on the project opens it with the last '
          'configuration ($name)', (tester) async {
        final db = createTestDatabase();
        final project = await seedProject(db);
        await StudyRepository(StudyDao(db), _clock).startSession(
          project.projectId,
          SessionConfig(deckIds: [project.travel.id]),
        );
        final router = await pumpTestApp(
          tester,
          size: size,
          db: db,
          location: AppRoutes.project(project.projectId),
        );

        await tapVisible(tester, find.byKey(const Key('projectScreen.study')));

        expect(
          router.routerDelegate.currentConfiguration.uri.path,
          AppRoutes.sessionSetup(project.projectId),
        );
        expect(deckChip(tester, project.travel).selected, isTrue);
        expect(deckChip(tester, project.verbs).selected, isFalse);
      });

      testWidgets('"Estudiar" on a deck opens it with only that deck '
          '($name)', (tester) async {
        final db = createTestDatabase();
        final project = await seedProject(db);
        await StudyRepository(StudyDao(db), _clock).startSession(
          project.projectId,
          SessionConfig(deckIds: [project.travel.id], requestedCount: 10),
        );
        await pumpTestApp(
          tester,
          size: size,
          db: db,
          location: AppRoutes.deck(project.projectId, project.phrasal.id),
        );

        await tapVisible(tester, find.byKey(const Key('deckScreen.study')));

        expect(deckChip(tester, project.phrasal).selected, isTrue);
        expect(deckChip(tester, project.travel).selected, isFalse);
        expect(segmentOf<String>(tester, 'sessionSetup.count'), {'10'});
      });

      testWidgets('"Repasar errores" on the project opens it with "Solo '
          'errores" in the direction with more errors ($name)', (tester) async {
        final db = createTestDatabase();
        final project = await seedProject(db);
        // One verb missed in the normal direction, two in reverse.
        final [first, second, third] = await cardIdsOf(db, project.verbs);
        await miss(db, project, first, 'normal');
        await miss(db, project, second, 'reverse');
        await miss(db, project, third, 'reverse');
        final router = await pumpTestApp(
          tester,
          size: size,
          db: db,
          location: AppRoutes.project(project.projectId),
        );

        await tapVisible(
          tester,
          find.byKey(const Key('projectScreen.reviewErrors')),
        );

        expect(
          router.routerDelegate.currentConfiguration.uri.toString(),
          AppRoutes.sessionSetup(project.projectId, reviewErrors: true),
        );
        expect(segmentOf<StudyMode>(tester, 'sessionSetup.mode'), {
          StudyMode.errors,
        });
        expect(segmentOf<StudyDirection>(tester, 'sessionSetup.direction'), {
          StudyDirection.reverse,
        });
        for (final deck in [project.verbs, project.phrasal, project.travel]) {
          expect(deckChip(tester, deck).selected, isTrue);
        }
        expect(
          availableText(tester),
          '2 tarjetas disponibles · se usarán todas',
        );
        expect(startEnabled(tester), isTrue);
      });

      testWidgets('"Repasar errores" on a deck opens it with only that deck '
          'and "Solo errores" ($name)', (tester) async {
        final db = createTestDatabase();
        final project = await seedProject(db);
        final [phrasal, _] = await cardIdsOf(db, project.phrasal);
        final [verb, _, _] = await cardIdsOf(db, project.verbs);
        await miss(db, project, phrasal, 'normal');
        await miss(db, project, verb, 'normal');
        await pumpTestApp(
          tester,
          size: size,
          db: db,
          location: AppRoutes.deck(project.projectId, project.phrasal.id),
        );

        await tapVisible(
          tester,
          find.byKey(const Key('deckScreen.reviewErrors')),
        );

        expect(deckChip(tester, project.phrasal).selected, isTrue);
        expect(deckChip(tester, project.verbs).selected, isFalse);
        expect(segmentOf<StudyMode>(tester, 'sessionSetup.mode'), {
          StudyMode.errors,
        });
        expect(availableText(tester), '1 tarjeta disponible · se usarán todas');
      });
    }

    testWidgets('"Repasar errores" on a dashboard card opens it with "Solo '
        'errores"', (tester) async {
      final db = createTestDatabase();
      final project = await seedProject(db);
      final [verb, _, _] = await cardIdsOf(db, project.verbs);
      await miss(db, project, verb, 'normal');
      await pumpTestApp(tester, size: mobile, db: db);

      await tapVisible(
        tester,
        find.byKey(Key('projectCard.${project.projectId}.reviewErrors')),
      );

      expect(segmentOf<StudyMode>(tester, 'sessionSetup.mode'), {
        StudyMode.errors,
      });
      expect(availableText(tester), '1 tarjeta disponible · se usarán todas');
    });
  });

  testWidgets('desktop shows a summary and that the configuration is '
      'remembered', (tester) async {
    final db = createTestDatabase();
    final project = await seedProject(db);
    await pumpTestApp(
      tester,
      size: desktop,
      db: db,
      location: AppRoutes.sessionSetup(project.projectId),
    );

    final summary = find.byKey(const Key('sessionSetup.summary'));
    Finder inSummary(String text) =>
        find.descendant(of: summary, matching: find.text(text));
    // In the order of the project screen: oldest first, then by name (the
    // decks were created at the same time).
    expect(
      inSummary('Phrasal verbs, Verbos irregulares, Vocabulario viajes'),
      findsOneWidget,
    );
    expect(inSummary('6 de 6'), findsOneWidget);
    expect(inSummary('Inglés (R. U.) → Español'), findsOneWidget);
    expect(inSummary('Sin timer'), findsOneWidget);
    expect(inSummary('Aleatorio'), findsOneWidget);
    expect(
      inSummary('Se recordará esta configuración para Inglés B2'),
      findsOneWidget,
    );
  });

  test('the router builds the setup path of a deck', () {
    expect(
      AppRoutes.sessionSetup('p1', deckId: 'd1'),
      '/project/p1/study?deck=d1',
    );
  });

  test('the router builds the setup path of an error review', () {
    expect(
      AppRoutes.sessionSetup('p1', reviewErrors: true),
      '/project/p1/study?errors=1',
    );
    expect(
      AppRoutes.sessionSetup('p1', deckId: 'd1', reviewErrors: true),
      '/project/p1/study?deck=d1&errors=1',
    );
  });
}
