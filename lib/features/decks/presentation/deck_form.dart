import 'package:estudicards/app/l10n/generated/app_localizations.dart';
import 'package:estudicards/app/theme/app_colors.dart';
import 'package:estudicards/app/theme/dimensions.dart';
import 'package:estudicards/features/decks/domain/deck.dart';
import 'package:estudicards/features/decks/domain/deck_input.dart';
import 'package:estudicards/features/decks/domain/languages.dart';
import 'package:estudicards/features/decks/presentation/deck_providers.dart';
import 'package:estudicards/features/projects/domain/project.dart';
import 'package:estudicards/features/projects/presentation/form_parts.dart';
import 'package:estudicards/features/projects/presentation/project_labels.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Opens P04 to create a deck in [project], or to edit [deck] when given:
/// a bottom sheet on mobile and a dialog on tablet and desktop. After
/// saving, the user stays on the project screen.
Future<void> showDeckForm(
  BuildContext context, {
  required Project project,
  Deck? deck,
}) => showFormSheet<Deck>(context, DeckForm(project: project, deck: deck));

/// The fields of P04: name, description, colour, type and languages
/// (US-06 AC1, AC2). Closes itself with the saved deck.
class DeckForm extends ConsumerStatefulWidget {
  const new({required this.project, this.deck, super.key});

  final Project project;

  /// The deck being edited; null when creating one.
  final Deck? deck;

  @override
  ConsumerState<DeckForm> createState() => _DeckFormState();
}

class _DeckFormState extends ConsumerState<DeckForm> {
  late final _name = TextEditingController(text: widget.deck?.name);
  late final _description = TextEditingController(
    text: widget.deck?.description,
  );

  /// Null while the deck uses the project's colour: the default for a new
  /// deck.
  late String? _color = switch (widget.deck) {
    final deck? when !deck.inheritsColor => deck.color,
    _ => null,
  };

  /// A new deck is general. A language deck turned general keeps its
  /// languages, so switching back shows them again.
  late DeckType _type = widget.deck?.type ?? DeckType.general;
  late String? _sourceLang = widget.deck?.sourceLang;
  late String? _targetLang = widget.deck?.targetLang;
  bool _saving = false;

  bool get _isEditing => widget.deck != null;

  DeckInput get _input => DeckInput(
    name: _name.text,
    description: _description.text,
    color: _color,
    type: _type,
    sourceLang: _sourceLang,
    targetLang: _targetLang,
  );

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  /// Changing a stored language deck to general asks first (US-06 AC3).
  /// While creating, or for a deck that was general, it just changes.
  Future<void> _changeType(DeckType type) async {
    final asks =
        type == DeckType.general && widget.deck?.type == DeckType.language;
    if (asks && !await _confirmSwitchToGeneral()) return;
    setState(() => _type = type);
  }

  Future<bool> _confirmSwitchToGeneral() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.switchToGeneralTitle),
        content: Text(l10n.switchToGeneralBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            key: const Key('deckForm.confirmTypeChange'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.switchToGeneralConfirm),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final repository = ref.read(decksRepositoryProvider);
    final deck = widget.deck;
    final saved = deck == null
        ? await repository.create(widget.project.id, _input)
        : await repository.update(deck.id, _input);
    if (mounted) Navigator.of(context).pop(saved);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final canSave = !_saving && _input.validate().isEmpty;

    return FormFrame(
      keyPrefix: 'deckForm',
      title: _isEditing ? l10n.editDeck : l10n.newDeck,
      saveLabel: _isEditing ? l10n.save : l10n.createDeck,
      onSave: canSave ? _save : null,
      fields: [
        FormLabel(l10n.nameLabel),
        TextField(
          key: const Key('deckForm.name'),
          controller: _name,
          autofocus: !_isEditing,
          textCapitalization: TextCapitalization.sentences,
          // Typing stops at the maximum length instead of showing an error.
          inputFormatters: [
            LengthLimitingTextInputFormatter(DeckInput.maxNameLength),
          ],
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: AppSpacing.xl),
        FormLabel(l10n.descriptionOptionalLabel),
        TextField(
          key: const Key('deckForm.description'),
          controller: _description,
          textCapitalization: TextCapitalization.sentences,
          maxLines: null,
        ),
        const SizedBox(height: AppSpacing.xl),
        FormLabel(l10n.colorLabel),
        ColorPicker(
          keyPrefix: 'deckForm',
          selected: _color,
          inheritedColor: widget.project.color,
          onChanged: (color) => setState(() => _color = color),
        ),
        const SizedBox(height: AppSpacing.xl),
        FormLabel(l10n.typeLabel),
        _TypeSelector(selected: _type, onChanged: _changeType),
        if (_type == DeckType.language) ...[
          const SizedBox(height: AppSpacing.xl),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _LanguageField(
                  key: const Key('deckForm.sourceLang'),
                  label: l10n.sourceLanguageLabel,
                  value: _sourceLang,
                  onChanged: (code) => setState(() => _sourceLang = code),
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: _LanguageField(
                  key: const Key('deckForm.targetLang'),
                  label: l10n.targetLanguageLabel,
                  value: _targetLang,
                  onChanged: (code) => setState(() => _targetLang = code),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// "General / Idioma": a grey track with the chosen option in white, as in
/// the design.
class _TypeSelector extends StatelessWidget {
  const new({required this.selected, required this.onChanged});

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
          label: Text(
            l10n.typeGeneral,
            key: const Key('deckForm.type.general'),
          ),
        ),
        ButtonSegment(
          value: DeckType.language,
          label: Text(
            l10n.typeLanguage,
            key: const Key('deckForm.type.language'),
          ),
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
