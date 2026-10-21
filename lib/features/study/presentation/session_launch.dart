// Starting a study session: it is saved in the database and its queue of
// cards waits in memory until the session screen (T3.7) shows it.
import 'package:estudicards/core/providers.dart';
import 'package:estudicards/features/study/domain/card_selection.dart';
import 'package:estudicards/features/study/domain/session_config.dart';
import 'package:estudicards/features/study/domain/session_results.dart';
import 'package:estudicards/features/study/domain/session_state.dart';
import 'package:estudicards/features/study/presentation/study_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A session ready to be shown: its project, its cards in order and its
/// settings.
class SessionLaunch {
  const new({
    required this.projectId,
    required this.cards,
    required this.settings,
  });

  /// The card labels show the project's and deck's names and colours.
  final String projectId;
  final List<SelectedCard> cards;
  final SessionSettings settings;
}

/// The sessions started in this run of the app, by session ID.
///
/// A `Notifier` holds a value that can change (`state`) and tells the
/// widgets watching it when it does.
class LaunchedSessions extends Notifier<Map<String, SessionLaunch>> {
  @override
  Map<String, SessionLaunch> build() => const {};

  void add(String sessionId, SessionLaunch launch) =>
      state = {...state, sessionId: launch};

  /// Forgets a finished session, so going back to its path cannot start it
  /// again.
  void remove(String sessionId) => state = {...state}..remove(sessionId);
}

final launchedSessionsProvider =
    NotifierProvider<LaunchedSessions, Map<String, SessionLaunch>>(
      LaunchedSessions.new,
    );

/// Starts a session of [projectId] with [config]: chooses its cards from
/// the chosen decks (R 7.2), saves the session and leaves its queue for the
/// session screen. Returns its ID. Used by "Empezar" (P08) and "Repetir
/// sesión" (US-20 AC2).
///
/// The setup passes the [candidates] it has already read, so starting does
/// not read every card again (T6.5); without them they are read here.
Future<String> launchSession(
  WidgetRef ref,
  String projectId,
  SessionConfig config, {
  List<StudyCandidate>? candidates,
}) async {
  final repository = ref.read(studyRepositoryProvider);
  candidates ??= await repository.candidates(projectId);
  final cards = selectCards(
    candidates.where((c) => config.deckIds.contains(c.card.deckId)),
    mode: config.mode,
    direction: config.direction,
    random: ref.read(randomProvider),
    count: config.requestedCount,
    prioritizeFailed: config.prioritizeFailed,
  );
  final sessionId = await repository.startSession(projectId, config);
  ref
      .read(launchedSessionsProvider.notifier)
      .add(
        sessionId,
        SessionLaunch(
          projectId: projectId,
          cards: cards,
          settings: config.settings,
        ),
      );
  return sessionId;
}

/// "Repasar falladas ahora" (US-20 AC1): a new session with only the cards
/// missed in [results], shuffled. Returns its ID.
Future<String> startReviewOfMissed(
  WidgetRef ref,
  SessionResults results,
) async {
  final config = results.reviewConfig;
  final cards = results.reviewQueue(ref.read(randomProvider));
  final sessionId = await ref
      .read(studyRepositoryProvider)
      .startSession(results.projectId, config);
  ref
      .read(launchedSessionsProvider.notifier)
      .add(
        sessionId,
        SessionLaunch(
          projectId: results.projectId,
          cards: cards,
          settings: config.settings,
        ),
      );
  return sessionId;
}
