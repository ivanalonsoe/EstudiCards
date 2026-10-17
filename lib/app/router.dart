// The app's routes (SPEC §5.1), handled by go_router.
//
// A route maps a path such as `/project/123` to a screen. Routes are nested
// so that the path describes the stack: opening `/project/p1/deck/d1` on
// mobile puts the dashboard, the project and the deck on the stack, and the
// back button walks back through them.
//
// The screens are empty placeholders for now; each one is replaced by the
// real screen in the task that builds it.
import 'package:estudicards/app/l10n/generated/app_localizations.dart';
import 'package:estudicards/app/shell/app_shell.dart';
import 'package:estudicards/app/shell/not_found_screen.dart';
import 'package:estudicards/app/shell/placeholder_screen.dart';
import 'package:estudicards/features/cards/presentation/card_editor_screen.dart';
import 'package:estudicards/features/decks/presentation/deck_screen.dart';
import 'package:estudicards/features/import_export/presentation/import_screen.dart';
import 'package:estudicards/features/projects/presentation/archived_screen.dart';
import 'package:estudicards/features/projects/presentation/dashboard_screen.dart';
import 'package:estudicards/features/projects/presentation/project_screen.dart';
import 'package:estudicards/features/stats/presentation/project_statistics_screen.dart';
import 'package:estudicards/features/stats/presentation/statistics_screen.dart';
import 'package:estudicards/features/study/presentation/results_screen.dart';
import 'package:estudicards/features/study/presentation/session_screen.dart';
import 'package:estudicards/features/study/presentation/session_setup_screen.dart';
import 'package:estudicards/features/trash/presentation/trash_screen.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Paths of every screen. Build them with these helpers instead of writing
/// strings by hand, so a typo is a compile error.
abstract final class AppRoutes {
  static const home = '/';
  static const import = '/import';
  static const statistics = '/statistics';
  static const archived = '/archived';
  static const trash = '/trash';
  static const settings = '/settings';

  /// The import wizard (P07): as a new project; with [projectId], as a new
  /// deck of it; with [deckId] too, into that deck (US-27).
  static String importCards({String? projectId, String? deckId}) {
    final query = [
      if (projectId != null) 'project=$projectId',
      if (deckId != null) 'deck=$deckId',
    ];
    return query.isEmpty ? import : '$import?${query.join('&')}';
  }

  static String project(String projectId) => '/project/$projectId';

  /// A project's statistics on their own page (desktop, P12).
  static String projectStatistics(String projectId) =>
      '/project/$projectId/statistics';

  /// The session setup; opened from a deck ([deckId]), only that deck is
  /// chosen. From "Repasar errores" ([reviewErrors]) it starts in "Solo
  /// errores".
  static String sessionSetup(
    String projectId, {
    String? deckId,
    bool reviewErrors = false,
  }) {
    final query = [
      if (deckId != null) 'deck=$deckId',
      if (reviewErrors) 'errors=1',
    ];
    return '/project/$projectId/study'
        '${query.isEmpty ? '' : '?${query.join('&')}'}';
  }

  static String deck(String projectId, String deckId) =>
      '/project/$projectId/deck/$deckId';
  static String newCard(String projectId, String deckId) =>
      '${deck(projectId, deckId)}/card/new';
  static String editCard(String projectId, String deckId, String cardId) =>
      '${deck(projectId, deckId)}/card/$cardId';
  static String session(String sessionId) => '/session/$sessionId';
  static String results(String sessionId) => '/results/$sessionId';
}

/// Creates the router. Tests pass an [initialLocation] to start on any
/// screen.
GoRouter createRouter({String initialLocation = AppRoutes.home}) {
  // The root navigator holds everything; the shell navigator holds the
  // screens shown next to the sidebar on desktop.
  final rootKey = GlobalKey<NavigatorState>();
  final shellKey = GlobalKey<NavigatorState>();

  GoRoute screen(
    String path,
    String key,
    String Function(AppLocalizations l10n) title, {
    List<RouteBase> routes = const [],
    bool fullScreen = false,
  }) => GoRoute(
    path: path,
    parentNavigatorKey: fullScreen ? rootKey : null,
    builder: (context, state) => PlaceholderScreen(
      key: Key('screen.$key'),
      title: title(AppLocalizations.of(context)),
    ),
    routes: routes,
  );

  return GoRouter(
    navigatorKey: rootKey,
    initialLocation: initialLocation,
    errorBuilder: (context, state) => const NotFoundScreen(),
    routes: [
      // A ShellRoute wraps its screens in a common frame: the sidebar on
      // desktop (see AppShell).
      ShellRoute(
        navigatorKey: shellKey,
        builder: (context, state, child) =>
            AppShell(location: state.uri.path, child: child),
        routes: [
          GoRoute(
            path: AppRoutes.home,
            builder: (context, state) =>
                const DashboardScreen(key: Key('screen.dashboard')),
            routes: [
              GoRoute(
                path: 'project/:projectId',
                builder: (context, state) => ProjectScreen(
                  key: const Key('screen.project'),
                  projectId: state.pathParameters['projectId']!,
                ),
                routes: [
                  GoRoute(
                    path: 'study',
                    builder: (context, state) => SessionSetupScreen(
                      key: const Key('screen.sessionSetup'),
                      projectId: state.pathParameters['projectId']!,
                      // `?deck=` when opened from a deck.
                      deckId: state.uri.queryParameters['deck'],
                      // `?errors=1` when opened from "Repasar errores".
                      reviewErrors: state.uri.queryParameters['errors'] == '1',
                    ),
                  ),
                  GoRoute(
                    path: 'statistics',
                    builder: (context, state) => ProjectStatisticsScreen(
                      key: const Key('screen.projectStatistics'),
                      projectId: state.pathParameters['projectId']!,
                    ),
                  ),
                  GoRoute(
                    path: 'deck/:deckId',
                    builder: (context, state) => DeckScreen(
                      key: const Key('screen.deck'),
                      projectId: state.pathParameters['projectId']!,
                      deckId: state.pathParameters['deckId']!,
                    ),
                    routes: [
                      // `card/new` is declared before `card/:cardId` so
                      // "new" is not read as a card ID.
                      GoRoute(
                        path: 'card/new',
                        builder: (context, state) => CardEditorScreen(
                          key: const Key('screen.newCard'),
                          projectId: state.pathParameters['projectId']!,
                          deckId: state.pathParameters['deckId']!,
                        ),
                      ),
                      GoRoute(
                        path: 'card/:cardId',
                        builder: (context, state) => CardEditorScreen(
                          key: const Key('screen.editCard'),
                          projectId: state.pathParameters['projectId']!,
                          deckId: state.pathParameters['deckId']!,
                          cardId: state.pathParameters['cardId'],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              // The study session covers the whole window, without sidebar.
              GoRoute(
                path: 'session/:sessionId',
                parentNavigatorKey: rootKey,
                builder: (context, state) => SessionScreen(
                  key: const Key('screen.session'),
                  sessionId: state.pathParameters['sessionId']!,
                ),
              ),
              GoRoute(
                path: 'results/:sessionId',
                builder: (context, state) => ResultsScreen(
                  key: const Key('screen.results'),
                  sessionId: state.pathParameters['sessionId']!,
                ),
              ),
              GoRoute(
                path: 'import',
                builder: (context, state) => ImportScreen(
                  key: const Key('screen.import'),
                  // `?project=` imports as a new deck of that project, and
                  // `?project=&deck=` adds to that deck (US-27).
                  projectId: state.uri.queryParameters['project'],
                  deckId: state.uri.queryParameters['deck'],
                ),
              ),
              GoRoute(
                path: 'statistics',
                builder: (context, state) =>
                    const StatisticsScreen(key: Key('screen.statistics')),
              ),
              GoRoute(
                path: 'archived',
                builder: (context, state) =>
                    const ArchivedScreen(key: Key('screen.archived')),
              ),
              GoRoute(
                path: 'trash',
                builder: (context, state) =>
                    const TrashScreen(key: Key('screen.trash')),
              ),
              screen('settings', 'settings', (l10n) => l10n.settings),
            ],
          ),
        ],
      ),
    ],
  );
}
