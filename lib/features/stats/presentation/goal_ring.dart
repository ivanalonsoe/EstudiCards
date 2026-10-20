import 'package:estudicards/app/l10n/generated/app_localizations.dart';
import 'package:estudicards/app/theme/app_colors.dart';
import 'package:estudicards/features/stats/domain/metrics.dart';
import 'package:flutter/material.dart';

/// Today's progress towards the daily goal (US-23 AC2): an orange ring
/// with the cards answered in the middle and, if [showGoal], "de 20" under
/// them (`docs/design/movil-claro/dashboard.png`).
class GoalRing extends StatelessWidget {
  const new({
    required this.progress,
    required this.size,
    this.showGoal = true,
    super.key,
  });

  final DailyGoalProgress progress;
  final double size;
  final bool showGoal;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    // Screen readers hear "14 de 20 tarjetas hoy" instead of the parts.
    return Semantics(
      label: l10n.goalRingLabel(progress.done, progress.goal),
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: size,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CircularProgressIndicator(
              value: progress.fraction,
              strokeWidth: size / 9,
              strokeCap: StrokeCap.round,
              backgroundColor: colors.surfaceVariant,
              color: colors.primary,
            ),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${progress.done}',
                    style: text.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      height: 1,
                    ),
                  ),
                  if (showGoal)
                    Text(
                      l10n.goalOf(progress.goal),
                      style: text.labelSmall?.copyWith(
                        color: colors.textMuted,
                        height: 1.1,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
