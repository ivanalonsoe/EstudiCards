import 'package:estudicards/core/providers.dart';
import 'package:estudicards/features/projects/data/projects_dao.dart';
import 'package:estudicards/features/projects/data/projects_repository.dart';
import 'package:estudicards/features/projects/domain/project.dart';
import 'package:estudicards/features/projects/domain/project_search.dart';
import 'package:estudicards/features/projects/domain/project_summary.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';

final projectsRepositoryProvider = Provider<ProjectsRepository>(
  (ref) => ProjectsRepository(
    ProjectsDao(ref.watch(databaseProvider)),
    ref.watch(clockProvider),
  ),
);

/// Every project on the dashboard, with its counts. A `StreamProvider`
/// listens to the repository's stream and rebuilds the widgets that watch
/// it whenever a new list arrives.
final projectSummariesProvider = StreamProvider<List<ProjectSummary>>(
  (ref) => ref.watch(projectsRepositoryProvider).watchProjects(),
);

/// One project, updated when it changes; null if it does not exist. One
/// provider per project ID (see `deckSummariesProvider` for `.family`).
final StreamProviderFamily<Project?, String> projectProvider =
    StreamProvider.family(
      (ref, id) => ref.watch(projectsRepositoryProvider).watchProject(id),
    );

/// What the user typed in the project search: the dashboard field on
/// mobile, the sidebar field on desktop.
///
/// A `Notifier` holds a piece of state that widgets can change; here it is
/// just the search text.
class ProjectSearchQuery extends Notifier<String> {
  @override
  String build() => '';

  String get query => state;
  set query(String value) => state = value;
}

final projectSearchQueryProvider = NotifierProvider<ProjectSearchQuery, String>(
  ProjectSearchQuery.new,
);

/// The projects that match the search, in dashboard order.
final visibleProjectsProvider = Provider<AsyncValue<List<ProjectSummary>>>((
  ref,
) {
  final query = ref.watch(projectSearchQueryProvider);
  return ref
      .watch(projectSummariesProvider)
      .whenData(
        (summaries) => [
          for (final summary in summaries)
            if (matchesProjectSearch(summary.project.name, query)) summary,
        ],
      );
});
