import 'package:estudicards/app/l10n/generated/app_localizations.dart';
import 'package:estudicards/features/projects/presentation/project_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// "Buscar proyectos": writes what the user types into
/// `projectSearchQueryProvider`, which filters the dashboard and the
/// sidebar as they type (US-05 AC3).
class ProjectSearchField extends ConsumerStatefulWidget {
  const new({this.dense = false, super.key});

  /// Smaller, for the sidebar.
  final bool dense;

  @override
  ConsumerState<ProjectSearchField> createState() => _ProjectSearchFieldState();
}

class _ProjectSearchFieldState extends ConsumerState<ProjectSearchField> {
  // Starts with the current search, e.g. after resizing the window from
  // desktop to mobile.
  late final _controller = TextEditingController(
    text: ref.read(projectSearchQueryProvider),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
    controller: _controller,
    onChanged: (text) =>
        ref.read(projectSearchQueryProvider.notifier).query = text,
    decoration: InputDecoration(
      hintText: AppLocalizations.of(context).searchProjects,
      prefixIcon: const Icon(Icons.search_rounded),
      isDense: widget.dense,
    ),
  );
}
