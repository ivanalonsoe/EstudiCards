import 'package:estudicards/app/l10n/generated/app_localizations.dart';
import 'package:estudicards/app/router.dart';
import 'package:estudicards/app/theme/app_colors.dart';
import 'package:estudicards/app/theme/dimensions.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// "Repasar errores (N)" (US-21): opens the session setup of one project in
/// "Solo errores", never mixing projects. From a deck ([deckId]) only that
/// deck is chosen.
/// The screens show it only when [count] > 0.
class ReviewErrorsButton extends StatelessWidget {
  const new({
    required this.projectId,
    required this.count,
    this.deckId,
    this.expanded = false,
    super.key,
  });

  final String projectId;
  final String? deckId;

  /// Pending errors: (card, direction) pairs in the error list (R 7.6).
  final int count;

  /// Full width and taller, as under "Estudiar" on the mobile project.
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return FilledButton.icon(
      style: FilledButton.styleFrom(
        backgroundColor: colors.primarySoft,
        foregroundColor: colors.primaryStrong,
        minimumSize: expanded
            ? const Size.fromHeight(minTouchTarget + AppSpacing.sm)
            : null,
      ),
      onPressed: () => context.go(
        AppRoutes.sessionSetup(projectId, deckId: deckId, reviewErrors: true),
      ),
      icon: const Icon(Icons.refresh_rounded),
      // In a narrow place the label takes two lines, as in the design, and
      // only then ends in "…".
      label: Text(
        AppLocalizations.of(context).reviewErrors(count),
        maxLines: 2,
        textAlign: TextAlign.center,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
