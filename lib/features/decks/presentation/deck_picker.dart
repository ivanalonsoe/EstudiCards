import 'package:estudicards/app/l10n/generated/app_localizations.dart';
import 'package:estudicards/app/theme/app_colors.dart';
import 'package:estudicards/app/theme/dimensions.dart';
import 'package:estudicards/app/theme/project_palette.dart';
import 'package:estudicards/features/decks/domain/deck.dart';
import 'package:estudicards/features/decks/domain/languages.dart';
import 'package:flutter/material.dart';

/// The "Copiar a…" / "Mover a…" dialog (DESIGN_BRIEF.md §6.5): one option
/// per deck in [decks], with its colour and, for a language deck, its pair.
/// Returns the chosen deck, or null if the user closes it.
///
/// Keys: `deckPicker.<deckId>` per option, `deckPicker.empty` when there is
/// no deck to offer.
Future<Deck?> showDeckPicker(
  BuildContext context, {
  required String title,
  required List<Deck> decks,
}) => showDialog<Deck>(
  context: context,
  builder: (context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    return SimpleDialog(
      title: Text(title),
      children: [
        if (decks.isEmpty) ...[
          Padding(
            key: const Key('deckPicker.empty'),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl,
              vertical: AppSpacing.sm,
            ),
            child: Text(
              l10n.noOtherDecks,
              style: text.bodyMedium?.copyWith(color: colors.textMuted),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(right: AppSpacing.lg),
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l10n.close),
              ),
            ),
          ),
        ],
        for (final deck in decks)
          SimpleDialogOption(
            key: Key('deckPicker.${deck.id}'),
            onPressed: () => Navigator.of(context).pop(deck),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl,
              vertical: AppSpacing.md,
            ),
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: ProjectColor.fromKey(deck.color)
                        .resolve(Theme.of(context).brightness),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(child: Text(deck.name, style: text.titleMedium)),
                if (deck case Deck(
                  isLanguage: true,
                  :final sourceLang?,
                  :final targetLang?,
                ))
                  Text(
                    l10n.languagePair(
                      shortLanguageCode(sourceLang),
                      shortLanguageCode(targetLang),
                    ),
                    style: text.labelMedium?.copyWith(color: colors.textMuted),
                  ),
              ],
            ),
          ),
      ],
    );
  },
);
