import 'package:estudicards/core/providers.dart';
import 'package:estudicards/features/stats/data/stats_dao.dart';
import 'package:estudicards/features/stats/data/stats_repository.dart';
import 'package:estudicards/features/stats/domain/metrics.dart';
import 'package:estudicards/features/stats/domain/project_statistics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';

final statsRepositoryProvider = Provider<StatsRepository>(
  (ref) => StatsRepository(
    StatsDao(ref.watch(databaseProvider)),
    ref.watch(clockProvider),
  ),
);

/// Streak, cards answered and daily goal, updated after every answer.
final statsOverviewProvider = StreamProvider<StatsOverview>(
  (ref) => ref.watch(statsRepositoryProvider).watchOverview(),
);

// The providers below are only used by the statistics screens.
// `autoDispose` forgets them when those screens close, so reopening one
// reads the numbers again, with "today" up to date.

/// The 30-day chart of a project, or of every project with a null ID.
final StreamProviderFamily<DailySeries, String?> dailyAnswersProvider =
    StreamProvider.autoDispose.family(
      (ref, projectId) => ref
          .watch(statsRepositoryProvider)
          .watchDailyAnswers(projectId: projectId),
    );

/// The 10 most missed cards of a project.
final StreamProviderFamily<List<MissedCard>, String> mostMissedProvider =
    StreamProvider.autoDispose.family(
      (ref, projectId) =>
          ref.watch(statsRepositoryProvider).watchMostMissed(projectId),
    );

/// The latest sessions of a project: one provider per project and number
/// of sessions shown (a record, so "Ver más" asks for a new one).
final StreamProviderFamily<SessionHistory, ({String projectId, int limit})>
sessionHistoryProvider = StreamProvider.autoDispose.family(
  (ref, arg) => ref
      .watch(statsRepositoryProvider)
      .watchSessionHistory(arg.projectId, limit: arg.limit),
);
