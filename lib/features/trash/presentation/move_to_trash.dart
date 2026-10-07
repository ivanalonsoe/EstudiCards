import 'dart:async';

import 'package:estudicards/app/l10n/generated/app_localizations.dart';
import 'package:estudicards/core/widgets/confirm_dialog.dart';
import 'package:estudicards/features/decks/domain/deck.dart';
import 'package:estudicards/features/projects/domain/project.dart';
import 'package:estudicards/features/trash/presentation/trash_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Deletes a project as US-03 asks: a dialog with how many decks and cards
/// it holds, then the trash, with "Deshacer" for 5 seconds. [afterMove]
/// runs once it is in the trash, e.g. to leave the project screen.
Future<void> confirmMoveProjectToTrash(
  BuildContext context,
  WidgetRef ref, {
  required Project project,
  required int deckCount,
  required int cardCount,
  VoidCallback? afterMove,
}) async {
  final l10n = AppLocalizations.of(context);
  // Read before the dialog: the widget that asked may be gone afterwards
  // (the deleted project's card leaves the dashboard).
  final trash = ref.read(trashRepositoryProvider);
  final messenger = ScaffoldMessenger.of(context);

  final confirmed = await showConfirmDialog(
    context,
    title: l10n.deleteTitle(project.name),
    body: l10n.deleteProjectBody(
      l10n.deckCount(deckCount),
      l10n.cardCount(cardCount),
    ),
    confirmLabel: l10n.delete,
  );
  if (!confirmed) return;

  await trash.moveProjectToTrash(project.id);
  afterMove?.call();
  _showUndo(
    messenger,
    l10n,
    name: project.name,
    undo: () => trash.restoreProject(project.id),
  );
}

/// Deletes a deck as US-06 AC2 asks: a dialog with its number of cards,
/// then the trash, with "Deshacer" for 5 seconds.
Future<void> confirmMoveDeckToTrash(
  BuildContext context,
  WidgetRef ref, {
  required Deck deck,
  required int cardCount,
}) async {
  final l10n = AppLocalizations.of(context);
  final trash = ref.read(trashRepositoryProvider);
  final messenger = ScaffoldMessenger.of(context);

  final confirmed = await showConfirmDialog(
    context,
    title: l10n.deleteTitle(deck.name),
    body: l10n.deleteDeckBody(l10n.cardCount(cardCount)),
    confirmLabel: l10n.delete,
  );
  if (!confirmed) return;

  await trash.moveDeckToTrash(deck.id);
  _showUndo(
    messenger,
    l10n,
    name: deck.name,
    undo: () => trash.restoreDeck(deck.id),
  );
}

/// The snackbar with "Deshacer". The item is already in the trash, so
/// undoing just restores it.
void _showUndo(
  ScaffoldMessengerState messenger,
  AppLocalizations l10n, {
  required String name,
  required Future<void> Function() undo,
}) {
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(l10n.movedToTrash(name)),
        duration: const Duration(seconds: 5),
        // A snackbar with an action stays until it is closed unless told
        // otherwise; this one must go after its 5 seconds.
        persist: false,
        action: SnackBarAction(
          label: l10n.undo,
          onPressed: () => unawaited(undo()),
        ),
      ),
    );
}
