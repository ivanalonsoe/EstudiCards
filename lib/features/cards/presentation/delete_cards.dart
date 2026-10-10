import 'package:estudicards/app/l10n/generated/app_localizations.dart';
import 'package:estudicards/core/widgets/confirm_dialog.dart';
import 'package:estudicards/core/widgets/undo_snackbar.dart';
import 'package:estudicards/features/cards/presentation/card_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The cards waiting for their "Deshacer" to run out. The deck screen hides
/// them; they are deleted when the snackbar closes.
class PendingCardDeletions extends Notifier<Set<String>> {
  @override
  Set<String> build() => const {};

  void add(Iterable<String> ids) => state = {...state, ...ids};

  void remove(Iterable<String> ids) => state = state.difference(ids.toSet());
}

final pendingCardDeletionsProvider =
    NotifierProvider<PendingCardDeletions, Set<String>>(
      PendingCardDeletions.new,
    );

/// Deletes cards as US-11 AC2 asks: a confirmation, then "Deshacer" for 5
/// seconds, and then the cards are deleted for good with their statistics,
/// attempts and images. Cards do not go to the trash (SPEC §7.1).
///
/// The cards are hidden at once and deleted only when the snackbar closes
/// without "Deshacer", so undoing brings everything back as it was. If the
/// app closes during those 5 seconds, nothing is deleted.
///
/// [afterConfirm] runs once the user confirms, e.g. to leave the editor.
/// Returns whether the user confirmed.
Future<bool> confirmDeleteCards(
  BuildContext context,
  WidgetRef ref,
  List<String> ids, {
  VoidCallback? afterConfirm,
}) async {
  final l10n = AppLocalizations.of(context);
  // Read before the dialog: the widget that asked may be gone afterwards.
  final repository = ref.read(cardsRepositoryProvider);
  final pending = ref.read(pendingCardDeletionsProvider.notifier);
  final messenger = ScaffoldMessenger.of(context);

  final confirmed = await showConfirmDialog(
    context,
    title: l10n.deleteCardsTitle(ids.length),
    body: l10n.deleteCardsBody,
    confirmLabel: l10n.delete,
  );
  if (!confirmed) return false;

  pending.add(ids);
  afterConfirm?.call();
  final reason = await showUndoSnackBar(
    messenger,
    l10n,
    message: l10n.cardsDeleted(ids.length),
    undo: () async => pending.remove(ids),
  );
  if (reason != SnackBarClosedReason.action) {
    await repository.deleteCards(ids);
    pending.remove(ids);
  }
  return true;
}
