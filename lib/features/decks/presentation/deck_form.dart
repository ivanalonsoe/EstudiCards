import 'package:estudicards/app/l10n/generated/app_localizations.dart';
import 'package:estudicards/app/theme/dimensions.dart';
import 'package:estudicards/features/decks/domain/deck.dart';
import 'package:estudicards/features/decks/domain/deck_input.dart';
import 'package:estudicards/features/decks/presentation/deck_providers.dart';
import 'package:estudicards/features/projects/domain/project.dart';
import 'package:estudicards/features/projects/presentation/form_parts.dart';
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

/// The fields of P04: name, description and colour (US-06 AC1). Closes
/// itself with the saved deck.
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
  bool _saving = false;

  bool get _isEditing => widget.deck != null;

  DeckInput get _input => DeckInput(
    name: _name.text,
    description: _description.text,
    color: _color,
  );

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
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
      ],
    );
  }
}
