// "Reiniciar estadísticas" of a card (P06), a deck (P03) or a project (P02):
// confirm, delete the statistics and say so (R 7.4, US-11 AC1).
import 'package:estudicards/app/l10n/generated/app_localizations.dart';
import 'package:estudicards/core/widgets/confirm_dialog.dart';
import 'package:estudicards/features/stats/data/stats_repository.dart';
import 'package:estudicards/features/stats/presentation/stats_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Asks for confirmation with [body] (what will be deleted) and, if given,
/// runs [reset]. Past sessions keep their totals, as the dialog says.
/// There is no "Deshacer": the dialog is the safeguard.
Future<void> confirmResetStatistics(
  BuildContext context,
  WidgetRef ref, {
  required String body,
  required Future<void> Function(StatsRepository stats) reset,
}) async {
  final l10n = AppLocalizations.of(context);
  // Read before the dialog: the widget that opened it may go away.
  final messenger = ScaffoldMessenger.of(context);
  final stats = ref.read(statsRepositoryProvider);
  final confirmed = await showConfirmDialog(
    context,
    title: l10n.resetStatisticsTitle,
    body: body,
    confirmLabel: l10n.reset,
    icon: Icons.restart_alt_rounded,
  );
  if (!confirmed) return;
  await reset(stats);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(l10n.statisticsReset)));
}
