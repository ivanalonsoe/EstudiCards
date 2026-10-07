import 'dart:async';

import 'package:estudicards/app/l10n/generated/app_localizations.dart';
import 'package:estudicards/app/router.dart';
import 'package:estudicards/app/theme/app_colors.dart';
import 'package:estudicards/app/theme/dimensions.dart';
import 'package:estudicards/app/theme/project_palette.dart';
import 'package:estudicards/features/decks/domain/deck_summary.dart';
import 'package:estudicards/features/decks/presentation/deck_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// A deck in the project screen (DESIGN_BRIEF.md §6.3): a band in its
/// colour, the name and "84 tarjetas · 81% aciertos". Tapping it opens the
/// deck.
///
/// % correct and errors come from the statistics of phase 4; until then the
/// row shows "— aciertos" and no errors chip.
class DeckTile extends ConsumerWidget {
  const new({required this.summary, super.key});

  final DeckSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deck = summary.deck;
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    final deckColor = ProjectColor.fromKey(deck.color)
        .resolve(Theme.of(context).brightness);

    return Card(
      key: Key('deckTile.${deck.id}'),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _open(context, ref),
        // `IntrinsicHeight` lets the colour band stretch to the row's height.
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ColoredBox(color: deckColor, child: const SizedBox(width: 6)),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg + AppSpacing.xs,
                    vertical: AppSpacing.lg,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        deck.name,
                        style: text.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        l10n.deckContents(
                          l10n.cardCount(summary.cardCount),
                          l10n.correctRate('—'),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodyMedium?.copyWith(
                          color: colors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Opens the deck screen and records the use (R 7.7).
  void _open(BuildContext context, WidgetRef ref) {
    final deck = summary.deck;
    // The screen does not wait for the database write.
    unawaited(ref.read(decksRepositoryProvider).markUsed(deck.id));
    context.go(AppRoutes.deck(deck.projectId, deck.id));
  }
}
