import 'dart:async';

import 'package:estudicards/app/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';

/// Shows [message] for 5 seconds with a "Deshacer" button that runs [undo]
/// (SPEC §7.1). Pass the messenger read before any `await`, so it still
/// works if the widget that asked is gone.
///
/// The returned future completes when the snackbar closes, with
/// [SnackBarClosedReason.action] if "Deshacer" was tapped.
Future<SnackBarClosedReason> showUndoSnackBar(
  ScaffoldMessengerState messenger,
  AppLocalizations l10n, {
  required String message,
  required Future<void> Function() undo,
}) {
  messenger.hideCurrentSnackBar();
  return messenger
      .showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 5),
          // A snackbar with an action stays until it is closed unless told
          // otherwise; this one must go after its 5 seconds.
          persist: false,
          action: SnackBarAction(
            label: l10n.undo,
            onPressed: () => unawaited(undo()),
          ),
        ),
      )
      .closed;
}
