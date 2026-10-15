import 'package:estudicards/core/providers.dart';
import 'package:estudicards/features/study/data/study_dao.dart';
import 'package:estudicards/features/study/data/study_repository.dart';
import 'package:estudicards/features/study/domain/card_selection.dart';
import 'package:estudicards/features/study/domain/session_config.dart';
import 'package:estudicards/features/study/domain/session_results.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';

final studyRepositoryProvider = Provider<StudyRepository>(
  (ref) => StudyRepository(
    StudyDao(ref.watch(databaseProvider)),
    ref.watch(clockProvider),
  ),
);

/// What the session setup (P08) of a project starts from: the cards it can
/// choose from and the last configuration used. Read once when the setup
/// opens.
final FutureProviderFamily<
  ({List<StudyCandidate> candidates, SessionConfig? lastConfig}),
  String
>
sessionSetupDataProvider = FutureProvider.autoDispose.family((
  ref,
  projectId,
) async {
  final repository = ref.watch(studyRepositoryProvider);
  return (
    candidates: await repository.candidates(projectId),
    lastConfig: await repository.lastConfig(projectId),
  );
});

/// The results of one session, read once when the results screen opens
/// (see `deckProvider` for `autoDispose`).
final FutureProviderFamily<SessionResults?, String> sessionResultsProvider =
    FutureProvider.autoDispose.family(
      (ref, sessionId) => ref.watch(studyRepositoryProvider).results(sessionId),
    );
