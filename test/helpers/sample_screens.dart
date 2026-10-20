// The main screens of the app (SPEC §5.2) filled with realistic data, for
// tests that check every screen at once: accessibility guidelines and
// large system text (T6.3).
import 'package:drift/drift.dart' show Value;
import 'package:estudicards/app/app.dart';
import 'package:estudicards/app/router.dart';
import 'package:estudicards/core/clock.dart';
import 'package:estudicards/core/db/app_database.dart';
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
import 'package:estudicards/features/study/domain/attempt_record.dart';
import 'package:estudicards/features/study/domain/card_selection.dart';
import 'package:estudicards/features/study/domain/session_config.dart';
import 'package:estudicards/features/study/domain/session_engine.dart';
import 'package:estudicards/features/study/domain/session_state.dart';
import 'package:estudicards/features/study/domain/study_options.dart';
import 'package:estudicards/features/study/presentation/session_launch.dart';
import 'package:estudicards/features/trash/data/trash_dao.dart';
import 'package:estudicards/features/trash/data/trash_repository.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_image_files.dart';
import 'fake_voice.dart';
import 'test_app.dart';
import 'test_data.dart';

/// The IDs of the sample data.
typedef SampleIds = ({
  String project,
  String languageDeck,
  String generalDeck,
  String testCard,
  String finishedSession,
  String openSession,
  List<Flashcard> sessionCards,
});

/// "Inglés B2" (a favourite) with a language deck of three simple cards and
/// a general deck with a multiple-answer test card, answers today with
/// some errors, a finished session and one ready to study; "Biología 2º
/// Bach." archived and "Oposiciones · Tema 3" in the trash; a daily goal.
Future<SampleIds> addSampleData(AppDatabase db) async {
  final clock = FakeClock(DateTime.utc(2026, 10, 6, 12));
  final projects = ProjectsRepository(ProjectsDao(db), clock);
  final decks = DecksRepository(DecksDao(db), clock);
  final cards = CardsRepository(CardsDao(db), clock, FakeImageFiles());

  final english = await projects.create(
    const ProjectInput(
      name: 'Inglés B2',
      description: 'Preparación del examen de junio',
      color: 'blue',
      icon: 'globe',
    ),
  );
  await projects.setFavorite(english.id, isFavorite: true);
  final verbs = await decks.create(
    english.id,
    const DeckInput(
      name: 'Verbos irregulares',
      type: DeckType.language,
      sourceLang: 'en-GB',
      targetLang: 'es-ES',
    ),
  );
  final grammar = await decks.create(
    english.id,
    const DeckInput(name: 'Gramática'),
  );
  final simple = [
    for (final (question, answer) in [
      ('to bring', 'traer'),
      ('to seek', 'buscar'),
      ('to lend', 'prestar'),
    ])
      await cards.create(
        verbs.id,
        CardInput(
          type: CardType.simple,
          question: question,
          answer: answer,
          example: 'Can you **$question** it?',
          notes: 'Verbo irregular.',
        ),
      ),
  ];
  final test = await cards.create(
    grammar.id,
    const CardInput(
      type: CardType.test,
      question: '¿Qué frases están en pasado?',
      allowMultiple: true,
      explanation: 'El pasado simple de los verbos irregulares.',
      options: [
        CardOptionInput(text: 'I brought it', isCorrect: true),
        CardOptionInput(text: 'I sought it', isCorrect: true),
        CardOptionInput(text: 'I bring it'),
      ],
    ),
  );
  await addTestAnswers(
    db,
    projectId: english.id,
    cardId: simple.first.id,
    results: ['wrong', 'correct', 'correct'],
  );
  await addTestAnswers(
    db,
    projectId: english.id,
    cardId: simple[1].id,
    results: ['wrong'],
  );

  final study = StudyRepository(StudyDao(db), clock);
  final finished = await study.startSession(
    english.id,
    SessionConfig(deckIds: [verbs.id]),
  );
  await study.record(
    finished,
    SessionStep(
      const Finished(
        status: SessionStatus.completed,
        activeDuration: Duration(minutes: 3, seconds: 42),
        correctCount: 2,
        wrongCount: 1,
        unansweredCount: 0,
      ),
      [
        for (final (i, card) in simple.indexed)
          AttemptRecord(
            cardId: card.id,
            direction: StudyDirection.normal,
            result: i == 1 ? AttemptResult.wrong : AttemptResult.correct,
            source: AttemptSource.selfEval,
            isFirstAttempt: true,
            responseTime: const Duration(seconds: 12),
            answeredAt: clock.now(),
          ),
      ],
    ),
  );
  final open = await study.startSession(
    english.id,
    SessionConfig(deckIds: [verbs.id, grammar.id]),
  );

  final biology = await projects.create(
    const ProjectInput(
      name: 'Biología 2º Bach.',
      color: 'green',
      icon: 'flask',
    ),
  );
  await projects.setArchived(biology.id, isArchived: true);
  final law = await projects.create(
    const ProjectInput(
      name: 'Oposiciones · Tema 3',
      color: 'orange',
      icon: 'scales',
    ),
  );
  await TrashRepository(
    TrashDao(db),
    clock,
    FakeImageFiles(),
  ).moveProjectToTrash(law.id);

  await db
      .into(db.settings)
      .insert(
        SettingsCompanion.insert(key: 'daily_goal', value: const Value('20')),
      );

  return (
    project: english.id,
    languageDeck: verbs.id,
    generalDeck: grammar.id,
    testCard: test.id,
    finishedSession: finished,
    openSession: open,
    sessionCards: [...simple, test],
  );
}

/// One of the main screens: its name in test descriptions and where it is.
typedef SampleScreen = ({String name, String Function(SampleIds ids) path});

final List<SampleScreen> mainScreens = [
  (name: 'dashboard', path: (_) => AppRoutes.home),
  (name: 'project', path: (ids) => AppRoutes.project(ids.project)),
  (
    name: 'project statistics',
    path: (ids) => AppRoutes.projectStatistics(ids.project),
  ),
  (name: 'deck', path: (ids) => AppRoutes.deck(ids.project, ids.languageDeck)),
  (
    name: 'card editor',
    path: (ids) =>
        AppRoutes.editCard(ids.project, ids.generalDeck, ids.testCard),
  ),
  (name: 'session setup', path: (ids) => AppRoutes.sessionSetup(ids.project)),
  (name: 'study session', path: (ids) => AppRoutes.session(ids.openSession)),
  (name: 'results', path: (ids) => AppRoutes.results(ids.finishedSession)),
  (name: 'statistics', path: (_) => AppRoutes.statistics),
  (name: 'import', path: (_) => AppRoutes.import),
  (name: 'archived', path: (_) => AppRoutes.archived),
  (name: 'trash', path: (_) => AppRoutes.trash),
  (name: 'settings', path: (_) => AppRoutes.settings),
];

/// Opens [screen] with the sample data on a screen of [size].
Future<void> pumpSampleScreen(
  WidgetTester tester,
  SampleScreen screen, {
  required Size size,
}) async {
  final db = createTestDatabase();
  final ids = await addSampleData(db);
  final router = await pumpTestApp(
    tester,
    size: size,
    db: db,
    voice: FakeVoice(missing: {'de-DE'}),
  );
  // The study session needs its cards in memory, as "Empezar" leaves them.
  ProviderScope.containerOf(tester.element(find.byType(EstudiCardsApp)))
      .read(launchedSessionsProvider.notifier)
      .add(
        ids.openSession,
        SessionLaunch(
          projectId: ids.project,
          cards: [
            for (final card in ids.sessionCards)
              SelectedCard(card: card, direction: StudyDirection.normal),
          ],
          settings: SessionConfig(deckIds: [ids.languageDeck]).settings,
        ),
      );
  router.go(screen.path(ids));
  await tester.pumpAndSettle();
}
