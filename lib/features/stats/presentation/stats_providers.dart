import 'package:estudicards/core/providers.dart';
import 'package:estudicards/features/stats/data/stats_dao.dart';
import 'package:estudicards/features/stats/data/stats_repository.dart';
import 'package:estudicards/features/stats/domain/metrics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
