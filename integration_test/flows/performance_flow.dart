// T6.5 (SPEC §9): a deck with 5,000 cards loads and scrolls without errors,
// and starting a session takes less than 300 ms. Run from
// `integration_test/app_test.dart` and, to get real numbers, in profile mode
// from `integration_test/performance_profile.dart`.
//
// Debug mode is several times slower than the app people install, so the
// 300 ms limit is only checked in profile (or release) mode. In debug the
// test still loads, scrolls and starts the session, and prints the times.
import 'dart:io';
import 'dart:ui';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:estudicards/app/app.dart';
import 'package:estudicards/core/clock.dart';
import 'package:estudicards/core/db/app_database.dart';
import 'package:estudicards/core/ids.dart';
import 'package:estudicards/features/cards/presentation/card_providers.dart';
import 'package:estudicards/features/decks/data/decks_dao.dart';
import 'package:estudicards/features/decks/data/decks_repository.dart';
import 'package:estudicards/features/decks/domain/deck_input.dart';
import 'package:estudicards/features/projects/data/projects_dao.dart';
import 'package:estudicards/features/projects/data/projects_repository.dart';
import 'package:estudicards/features/projects/domain/project_input.dart';
import 'package:estudicards/features/study/presentation/study_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../app_flow.dart';

/// How many cards the big deck has (SPEC §9).
const _cardCount = 5000;

/// The longest a session may take to start (SPEC §9).
const _sessionStartLimit = Duration(milliseconds: 300);

/// A project "Rendimiento" with a deck "Grande" of [_cardCount] cards, as an
/// import would leave it: every fifth card is a test card with three
/// options, and half the cards have been answered before. Returns the IDs
/// of the project and the deck.
Future<(String, String)> _addBigDeck(AppDatabase db) async {
  const clock = SystemClock();
  final project = await ProjectsRepository(ProjectsDao(db), clock).create(
    const ProjectInput(name: 'Rendimiento', color: 'blue', icon: 'globe'),
  );
  final deck = await DecksRepository(
    DecksDao(db),
    clock,
  ).create(project.id, const DeckInput(name: 'Grande'));
  final start = DateTime.utc(2026);

  // A batch sends every insert to SQLite in one go, much faster than one
  // by one.
  await db.batch((batch) {
    for (var i = 0; i < _cardCount; i++) {
      final id = newId();
      final number = '${i + 1}'.padLeft(4, '0');
      final isTest = i % 5 == 0;
      final createdAt = start.add(Duration(minutes: i));
      batch.insert(
        db.cards,
        CardsCompanion.insert(
          id: id,
          deckId: deck.id,
          type: isTest ? 'test' : 'simple',
          question: 'Pregunta $number: ¿qué significa **to bring**?',
          answer: Value(isTest ? null : 'Respuesta $number'),
          createdAt: createdAt,
          updatedAt: createdAt,
        ),
      );
      if (isTest) {
        for (var position = 0; position < 3; position++) {
          batch.insert(
            db.cardOptions,
            CardOptionsCompanion.insert(
              id: newId(),
              cardId: id,
              optionText: 'Opción ${position + 1}',
              isCorrect: position == 0,
              position: position,
            ),
          );
        }
      }
      if (i.isEven) {
        batch.insert(
          db.cardStats,
          CardStatsCompanion.insert(
            cardId: id,
            direction: 'normal',
            correctCount: Value(i % 3),
            wrongCount: Value(i % 4 == 0 ? 1 : 0),
            inErrorList: Value(i % 4 == 0),
            lastAttemptAt: Value(createdAt),
          ),
        );
      }
    }
  });
  return (project.id, deck.id);
}

/// Any card of the deck screen, in the list (phone) or the table (desktop).
final Finder _anyCardRow = find.byWidgetPredicate(
  (widget) =>
      widget.key is ValueKey<String> &&
      RegExp(r'^cardRow\.[^.]+$')
          .hasMatch((widget.key! as ValueKey<String>).value),
);

/// The first card of a session: "Girar" for a simple card, "Comprobar" for
/// a test card.
final Finder _sessionCard = find.byWidgetPredicate(
  (widget) =>
      widget.key == const Key('session.flip') ||
      widget.key == const Key('session.check'),
);

/// How long [action] takes.
Future<Duration> _time(Future<void> Function() action) async {
  final stopwatch = Stopwatch()..start();
  await action();
  return stopwatch.elapsed;
}

/// Taps [target] and returns how long it takes until [until] is on screen,
/// drawing frames as fast as the device can (no waits in between).
Future<Duration> _timeUntil(
  WidgetTester tester,
  Finder target,
  Finder until,
) async {
  await waitFor(tester, target);
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  final elapsed = await _time(() async {
    await tester.tap(target);
    final deadline = DateTime.now().add(const Duration(seconds: 60));
    while (until.evaluate().isEmpty) {
      if (DateTime.now().isAfter(deadline)) {
        throw TestFailure('Timed out waiting for $until');
      }
      await tester.pump();
    }
  });
  await tester.pumpAndSettle();
  return elapsed;
}

/// Prints a measurement, so it appears in the test output.
void _report(String what, Duration time) =>
    debugPrint('[performance] $what: ${time.inMilliseconds} ms');

/// The frames drawn while [action] runs, with how long each took to build
/// and to draw (raster).
///
/// Flutter's `watchPerformance` does the same but also connects to the Dart
/// VM service, which an app on the Android emulator cannot reach. The
/// engine hands over frame timings in batches, so this waits for the last
/// ones before stopping.
Future<List<FrameTiming>> _framesDuring(Future<void> Function() action) async {
  final frames = <FrameTiming>[];
  final scheduler = SchedulerBinding.instance;
  // Timings of frames drawn before the action arrive first; skip them.
  await Future<void>.delayed(const Duration(seconds: 2));
  final TimingsCallback collect = frames.addAll;
  scheduler.addTimingsCallback(collect);
  await action();
  await Future<void>.delayed(const Duration(seconds: 2));
  scheduler.removeTimingsCallback(collect);
  return frames;
}

/// Prints the average and worst build and raster times of [frames], and
/// how many missed the 60 fps budget (16 ms) in either.
void _reportFrames(String what, List<FrameTiming> frames) {
  const budget = Duration(milliseconds: 16);
  String ms(Duration time) =>
      '${(time.inMicroseconds / 1000).toStringAsFixed(1)} ms';
  Duration average(Iterable<Duration> times) => times.isEmpty
      ? Duration.zero
      : times.reduce((a, b) => a + b) ~/ times.length;
  Duration worst(Iterable<Duration> times) =>
      times.fold(Duration.zero, (a, b) => a > b ? a : b);
  final build = [for (final frame in frames) frame.buildDuration];
  final raster = [for (final frame in frames) frame.rasterDuration];
  final slow = frames.where(
    (frame) => frame.buildDuration > budget || frame.rasterDuration > budget,
  );
  debugPrint(
    '[performance] $what: ${frames.length} frames, '
    '${slow.length} over 16 ms; '
    'build ${ms(average(build))} average, ${ms(worst(build))} worst; '
    'raster ${ms(average(raster))} average, ${ms(worst(raster))} worst',
  );
}

void performanceFlowTests() {
  testWidgets('a deck with $_cardCount cards loads and scrolls without '
      'errors, and a session starts in less than 300 ms', (tester) async {
    // A database file opened in the background, as the app opens it (an
    // in-memory database would answer on the screen's thread).
    final folder = await Directory.systemTemp.createTemp('estudicards_perf');
    final db = AppDatabase(
      driftDatabase(
        name: 'performance',
        native: DriftNativeOptions(
          databasePath: () async => '${folder.path}/performance.sqlite',
        ),
      ),
    );
    addTearDown(() async {
      await db.close();
      await folder.delete(recursive: true);
    });
    final (projectId, deckId) = await _addBigDeck(db);
    debugPrint(
      '[performance] mode: '
      '${kProfileMode ? 'profile' : (kReleaseMode ? 'release' : 'debug')}',
    );

    await tester.pumpWidget(appWithTestDatabase(db: db));
    await waitFor(tester, find.text('Rendimiento'));

    // Reading the data alone, without drawing it, to tell the database's
    // time from the screen's.
    final container = ProviderScope.containerOf(
      tester.element(find.byType(EstudiCardsApp)),
    );
    _report(
      'deck data',
      await _time(
        () => container.read(cardsRepositoryProvider).watchCards(deckId).first,
      ),
    );
    _report(
      'session data',
      await _time(
        () => container.read(studyRepositoryProvider).candidates(projectId),
      ),
    );

    // Load: from tapping the deck until its first card is on screen.
    await tapText(tester, 'Rendimiento');
    await waitFor(tester, find.text('Grande'));
    _report(
      'deck load',
      await _timeUntil(tester, find.text('Grande').last, _anyCardRow),
    );

    // Scroll: ten flings down the list, timing every frame drawn.
    final list = find.byType(Scrollable).first;
    final frames = await _framesDuring(() async {
      for (var i = 0; i < 10; i++) {
        await tester.fling(list, const Offset(0, -1500), 3000);
        await tester.pumpAndSettle();
      }
    });
    _reportFrames('scrolling', frames);

    // Session: from "Empezar" until the first card can be answered, with
    // every card of the deck. "Estudiar" is in the header, which the list
    // no longer builds after scrolling down, so scroll back up to it first.
    await tester.scrollUntilVisible(
      find.byKey(const Key('deckScreen.study')),
      -3000,
      scrollable: list,
    );
    await tapKey(tester, 'deckScreen.study');
    await expectSoon(
      tester,
      find.textContaining(RegExp(r'5\.?000 tarjetas disponibles')),
    );
    final sessionStart = await _timeUntil(
      tester,
      find.byKey(const Key('sessionSetup.start')),
      _sessionCard,
    );
    _report('session start', sessionStart);

    if (!kDebugMode) {
      expect(sessionStart, lessThan(_sessionStartLimit));
    }
  });
}
