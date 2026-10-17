// The deck type and language fields, shared by the deck form (P04) and the
// import wizard (P07), which asks for them when a CSV creates decks.
import 'package:estudicards/app/l10n/generated/app_localizations.dart';
import 'package:estudicards/app/theme/app_colors.dart';
import 'package:estudicards/app/theme/dimensions.dart';
import 'package:estudicards/features/decks/domain/deck.dart';
import 'package:estudicards/features/decks/domain/languages.dart';
import 'package:estudicards/features/projects/presentation/form_parts.dart';
import 'package:estudicards/features/projects/presentation/project_labels.dart';
import 'package:flutter/material.dart';

/// "General / Idioma": a grey track with the chosen option in white, as in
/// the design. Its segments have the keys `<keyPrefix>.type.general` and
/// `<keyPrefix>.type.language`.
class DeckTypeSelector extends StatelessWidget {
  const new({
    required this.keyPrefix,
    required this.selected,
    required this.onChanged,
    super.key,
  });

  final String keyPrefix;
  final DeckType selected;
  final ValueChanged<DeckType> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    return SegmentedButton<DeckType>(
      segments: [
        ButtonSegment(
          value: DeckType.general,
          label: Text(l10n.typeGeneral, key: Key('$keyPrefix.type.general')),
        ),
        ButtonSegment(
          value: DeckType.language,
          label: Text(l10n.typeLanguage, key: Key('$keyPrefix.type.language')),
        ),
      ],
      selected: {selected},
      showSelectedIcon: false,
      style: SegmentedButton.styleFrom(
        backgroundColor: colors.surfaceVariant,
        foregroundColor: colors.textMuted,
        selectedBackgroundColor: colors.surface,
        selectedForegroundColor: colors.text,
        side: BorderSide(color: colors.border),
        textStyle: Theme.of(context).textTheme.labelLarge,
      ),
      onSelectionChanged: (selection) => onChanged(selection.single),
    );
  }
}

/// The source and target language selectors side by side, with the keys
/// `<keyPrefix>.sourceLang` and `<keyPrefix>.targetLang`.
class LanguagePairFields extends StatelessWidget {
  const new({
    required this.keyPrefix,
    required this.sourceLang,
    required this.targetLang,
    required this.onSourceChanged,
    required this.onTargetChanged,
    super.key,
  });

  final String keyPrefix;
  final String? sourceLang;
  final String? targetLang;
  final ValueChanged<String?> onSourceChanged;
  final ValueChanged<String?> onTargetChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _LanguageField(
            key: Key('$keyPrefix.sourceLang'),
            label: l10n.sourceLanguageLabel,
            value: sourceLang,
            onChanged: onSourceChanged,
          ),
        ),
        const SizedBox(width: AppSpacing.lg),
        Expanded(
          child: _LanguageField(
            key: Key('$keyPrefix.targetLang'),
            label: l10n.targetLanguageLabel,
            value: targetLang,
            onChanged: onTargetChanged,
          ),
        ),
      ],
    );
  }
}

/// A language selector with its label above.
class _LanguageField extends StatelessWidget {
  const new({
    required this.label,
    required this.value,
    required this.onChanged,
    super.key,
  });

  final String label;
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final bodyStyle = Theme.of(context).textTheme.bodyLarge;
    // A stored code outside the list (e.g. from an import) is still offered,
    // so the selector can show it.
    final codes = [
      ...supportedLanguages,
      if (value != null && !supportedLanguages.contains(value)) value!,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FormLabel(label),
        DropdownButtonFormField<String>(
          initialValue: value,
          isExpanded: true,
          style: bodyStyle,
          hint: Text(
            l10n.chooseLanguage,
            overflow: TextOverflow.ellipsis,
            style: bodyStyle?.copyWith(color: AppColors.of(context).textMuted),
          ),
          items: [
            for (final code in codes)
              DropdownMenuItem(
                value: code,
                child: Text(
                  languageName(l10n, code),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: onChanged,
        ),
      ],
    );
  }
}
