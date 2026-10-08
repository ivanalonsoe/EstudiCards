import 'package:estudicards/app/l10n/generated/app_localizations.dart';
import 'package:estudicards/core/widgets/undo_snackbar.dart';
import 'package:estudicards/features/projects/domain/project.dart';
import 'package:estudicards/features/projects/presentation/project_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Archives [project] (US-05 AC2) and shows "Deshacer" for 5 seconds. No
/// confirmation: archiving deletes nothing (decided with the owner).
/// [afterArchive] runs once it is archived, e.g. to leave the project
/// screen.
Future<void> archiveProject(
  BuildContext context,
  WidgetRef ref, {
  required Project project,
  VoidCallback? afterArchive,
}) async {
  final l10n = AppLocalizations.of(context);
  // Read before the `await`: the widget that asked may be gone afterwards.
  final repository = ref.read(projectsRepositoryProvider);
  final messenger = ScaffoldMessenger.of(context);

  await repository.setArchived(project.id, isArchived: true);
  afterArchive?.call();
  showUndoSnackBar(
    messenger,
    l10n,
    message: l10n.archivedNotice(project.name),
    undo: () => repository.setArchived(project.id, isArchived: false),
  );
}
