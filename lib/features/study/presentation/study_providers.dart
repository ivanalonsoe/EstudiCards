import 'package:estudicards/core/providers.dart';
import 'package:estudicards/features/study/data/study_dao.dart';
import 'package:estudicards/features/study/data/study_repository.dart';
import 'package:estudicards/features/study/domain/session_results.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';

final studyRepositoryProvider = Provider<StudyRepository>(
  (ref) => StudyRepository(
    StudyDao(ref.watch(databaseProvider)),
    ref.watch(clockProvider),
  ),
);

/// The results of one session, read once when the results screen opens
/// (see `deckProvider` for `autoDispose`).
final FutureProviderFamily<SessionResults?, String> sessionResultsProvider =
    FutureProvider.autoDispose.family(
      (ref, sessionId) => ref.watch(studyRepositoryProvider).results(sessionId),
    );
