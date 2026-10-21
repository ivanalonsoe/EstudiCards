// The pieces the statistics screens share: a card with a heading, a
// coloured % bar, and the empty state.
import 'package:estudicards/app/l10n/generated/app_localizations.dart';
import 'package:estudicards/app/theme/app_colors.dart';
import 'package:estudicards/app/theme/dimensions.dart';
import 'package:estudicards/core/widgets/empty_state.dart';
import 'package:flutter/material.dart';

/// A card with a [title], an optional [trailing] widget on the right of it
/// (a caption or a link), and its content.
class StatsCard extends StatelessWidget {
  const new({
    required this.title,
    required this.child,
    this.trailing,
    super.key,
  });

  final String title;
  final Widget? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                // Shrinks, rather than pushing the title out, with large
                // system text.
                if (trailing case final trailing?) Flexible(child: trailing),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            child,
          ],
        ),
      ),
    );
  }
}

/// A muted caption for [StatsCard.trailing], e.g. "tarjetas por día".
class StatsCaption extends StatelessWidget {
  const new(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: Theme.of(context).textTheme.labelMedium
        ?.copyWith(color: AppColors.of(context).textMuted),
  );
}

/// A % bar in the colour of its deck or project, empty with no answers. The
/// number is always next to it, so the colour is not the only cue.
class ColoredRateBar extends StatelessWidget {
  const new({required this.rate, required this.color, super.key});

  final double? rate;
  final Color color;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(AppRadii.chip),
    child: LinearProgressIndicator(
      value: rate ?? 0,
      minHeight: 8,
      color: color,
      backgroundColor: AppColors.of(context).surfaceVariant,
    ),
  );
}

/// Nothing studied yet (SPEC §5.3, "statistics with no data"). [body]
/// says what to study; a project's by default.
class NoStatistics extends StatelessWidget {
  const new({this.body, super.key});

  final String? body;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return EmptyState(
      icon: Icons.bar_chart_rounded,
      title: l10n.noStatisticsTitle,
      body: body ?? l10n.noStatisticsBody,
    );
  }
}
