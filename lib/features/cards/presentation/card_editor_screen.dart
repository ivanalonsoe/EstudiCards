import 'dart:async';

import 'package:estudicards/app/l10n/generated/app_localizations.dart';
import 'package:estudicards/app/layout/breakpoints.dart';
import 'package:estudicards/app/theme/app_colors.dart';
import 'package:estudicards/app/theme/dimensions.dart';
import 'package:estudicards/app/theme/project_palette.dart';
import 'package:estudicards/core/widgets/confirm_dialog.dart';
import 'package:estudicards/features/cards/domain/card_input.dart';
import 'package:estudicards/features/cards/domain/flashcard.dart';
import 'package:estudicards/features/cards/domain/inline_format.dart';
import 'package:estudicards/features/cards/presentation/card_providers.dart';
import 'package:estudicards/features/cards/presentation/formatted_text_controller.dart';
import 'package:estudicards/features/decks/domain/deck.dart';
import 'package:estudicards/features/decks/presentation/deck_providers.dart';
import 'package:estudicards/features/projects/domain/project.dart';
import 'package:estudicards/features/projects/presentation/form_parts.dart';
import 'package:estudicards/features/projects/presentation/project_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// P06: creates a card in a deck, or edits [cardId] when given
/// (`docs/design/movil-claro/editor.png`, `escritorio-claro/editor.png`).
///
/// The preview arrives with T2.5 and the image buttons with T2.6. "Eliminar
/// tarjeta" (T2.9) and "Reiniciar estadísticas" (phase 4) arrive with their
/// tasks.
class CardEditorScreen extends ConsumerWidget {
  const new({
    required this.projectId,
    required this.deckId,
    this.cardId,
    super.key,
  });

  final String projectId;
  final String deckId;

  /// The card to edit; null to create one.
  final String? cardId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final project = ref.watch(projectProvider(projectId));
    final deck = ref.watch(deckProvider(deckId));
    final id = cardId;
    final card = id == null
        ? const AsyncData<Flashcard?>(null)
        : ref.watch(cardProvider(id));

    if (project.hasError || deck.hasError || card.hasError) {
      return _Message(l10n.loadError);
    }
    if (!project.hasValue || !deck.hasValue || !card.hasValue) {
      return const Scaffold();
    }
    final loadedProject = project.value;
    final loadedDeck = deck.value;
    final loadedCard = card.value;
    if (loadedProject == null ||
        loadedDeck == null ||
        (id != null && loadedCard == null)) {
      return _Message(l10n.cardNotFound);
    }
    return _CardEditor(
      project: loadedProject,
      deck: loadedDeck,
      card: loadedCard,
    );
  }
}

class _CardEditor extends ConsumerStatefulWidget {
  const new({required this.project, required this.deck, this.card});

  final Project project;
  final Deck deck;
  final Flashcard? card;

  @override
  ConsumerState<_CardEditor> createState() => _CardEditorState();
}

class _CardEditorState extends ConsumerState<_CardEditor> {
  late final _question = FormattedTextController(text: widget.card?.question);
  late final _answer = FormattedTextController(text: widget.card?.answer);
  late final _example = FormattedTextController(text: widget.card?.example);
  late final _notes = TextEditingController(text: widget.card?.notes);
  final _questionFocus = FocusNode();

  late final CardType _type = widget.card?.type ?? CardType.simple;

  /// Whether the user has typed in each field, so "Escribe la pregunta" only
  /// appears after emptying it, not on a new card.
  bool _questionEdited = false;
  bool _answerEdited = false;
  bool _saving = false;

  /// The form as it was last loaded or saved, to tell if there are changes.
  late String _savedSignature = _signature;

  bool get _isEditing => widget.card != null;
  bool get _isLanguage => widget.project.type == ProjectType.language;

  /// Everything the user can change, in one string.
  String get _signature => [
    _type.name,
    _question.text,
    _answer.text,
    _example.text,
    _notes.text,
  ].join('\u0000');

  bool get _hasChanges => _signature != _savedSignature;

  CardInput get _input => CardInput(
    type: _type,
    question: _question.text,
    questionImage: widget.card?.questionImage,
    answer: _answer.text,
    answerImage: widget.card?.answerImage,
    // Example and notes are kept even in a general project, whose fields
    // are hidden: switching back to "Idioma" shows them again (US-02 AC2).
    example: _example.text,
    notes: _notes.text,
  );

  @override
  void dispose() {
    _question.dispose();
    _answer.dispose();
    _example.dispose();
    _notes.dispose();
    _questionFocus.dispose();
    super.dispose();
  }

  Future<void> _save({required bool addAnother}) async {
    setState(() => _saving = true);
    final repository = ref.read(cardsRepositoryProvider);
    final card = widget.card;
    try {
      if (card == null) {
        await repository.create(widget.deck.id, _input);
      } else {
        await repository.update(card.id, _input);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
    if (!mounted) return;
    if (!addAnother) {
      context.pop();
      return;
    }
    // US-10: a clean form of the same type, ready for the next card.
    setState(() {
      _question.clear();
      _answer.clear();
      _example.clear();
      _notes.clear();
      _questionEdited = false;
      _answerEdited = false;
      _savedSignature = _signature;
    });
    _questionFocus.requestFocus();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).cardSaved),
          duration: const Duration(seconds: 2),
        ),
      );
  }

  /// Leaves the editor, asking first if there are unsaved changes.
  Future<void> _leave() async {
    if (_hasChanges && !await _confirmDiscard()) return;
    if (mounted) context.pop();
  }

  Future<bool> _confirmDiscard() {
    final l10n = AppLocalizations.of(context);
    return showConfirmDialog(
      context,
      title: l10n.discardChangesTitle,
      body: l10n.discardChangesBody,
      confirmLabel: l10n.discard,
      icon: Icons.edit_off_rounded,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDesktop =
        FormFactor.fromWidth(MediaQuery.sizeOf(context).width) ==
        FormFactor.desktop;
    final canSave = !_saving && _input.validate().isEmpty;
    final actions = _Actions(
      isEditing: _isEditing,
      onSave: canSave ? () => unawaited(_save(addAnother: false)) : null,
      onSaveAndAdd: canSave ? () => unawaited(_save(addAnother: true)) : null,
    );
    final title = _isEditing ? l10n.editCard : l10n.newCard;

    // `PopScope` intercepts the system back button and the app bar's back
    // arrow: with unsaved changes it asks before leaving.
    return PopScope(
      canPop: !_hasChanges,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) unawaited(_leave());
      },
      child: KeyedSubtree(
        key: const Key('cardEditor'),
        child: isDesktop
            ? _DesktopFrame(
                title: title,
                project: widget.project,
                deck: widget.deck,
                onCancel: () => unawaited(_leave()),
                actions: actions,
                fields: _fields(l10n),
              )
            : _MobileFrame(
                title: title,
                project: widget.project,
                deck: widget.deck,
                onClose: () => unawaited(_leave()),
                actions: actions,
                fields: _fields(l10n),
              ),
      ),
    );
  }

  List<Widget> _fields(AppLocalizations l10n) {
    // The message under a field the user has emptied.
    String? missing({
      required bool edited,
      required TextEditingController field,
      required String message,
    }) => edited && field.text.trim().isEmpty ? message : null;
    return [
      FormLabel(_isLanguage ? l10n.languageQuestionLabel : l10n.questionLabel),
      FormattedField(
        fieldKey: 'cardEditor.question',
        controller: _question,
        focusNode: _questionFocus,
        autofocus: !_isEditing,
        errorText: missing(
          edited: _questionEdited,
          field: _question,
          message: l10n.questionMissing,
        ),
        onChanged: () => setState(() => _questionEdited = true),
      ),
      const SizedBox(height: AppSpacing.xl),
      FormLabel(_isLanguage ? l10n.languageAnswerLabel : l10n.answerLabel),
      FormattedField(
        fieldKey: 'cardEditor.answer',
        controller: _answer,
        errorText: missing(
          edited: _answerEdited,
          field: _answer,
          message: l10n.answerMissing,
        ),
        onChanged: () => setState(() => _answerEdited = true),
      ),
      if (_isLanguage) ...[
        const SizedBox(height: AppSpacing.xl),
        _LanguageFields(
          example: _example,
          notes: _notes,
          onChanged: () => setState(() {}),
        ),
      ],
    ];
  }
}

/// Mobile and tablet: ✕ and title at the top, the fields, and the buttons
/// fixed at the bottom.
class _MobileFrame extends StatelessWidget {
  const new({
    required this.title,
    required this.project,
    required this.deck,
    required this.onClose,
    required this.actions,
    required this.fields,
  });

  final String title;
  final Project project;
  final Deck deck;
  final VoidCallback onClose;
  final _Actions actions;
  final List<Widget> fields;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          key: const Key('cardEditor.close'),
          tooltip: l10n.close,
          onPressed: onClose,
          icon: const Icon(Icons.close_rounded),
        ),
        title: Text(title),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          // On tablets the form keeps a comfortable width.
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.xl,
            ),
            children: [
              _DeckPath(project: project, deck: deck),
              const SizedBox(height: AppSpacing.xl),
              ...fields,
            ],
          ),
        ),
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.of(context).background,
          border: Border(top: BorderSide(color: AppColors.of(context).border)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: [
                if (!actions.isEditing) ...[
                  Expanded(child: actions.saveAndAddButton(context)),
                  const SizedBox(width: AppSpacing.md),
                ],
                Expanded(child: actions.saveButton(context)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Desktop: breadcrumb, title with the buttons, and the fields.
class _DesktopFrame extends StatelessWidget {
  const new({
    required this.title,
    required this.project,
    required this.deck,
    required this.onCancel,
    required this.actions,
    required this.fields,
  });

  final String title;
  final Project project;
  final Deck deck;
  final VoidCallback onCancel;
  final _Actions actions;
  final List<Widget> fields;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final labelStyle = Theme.of(context).textTheme.labelLarge;
    Widget crumb(String text, {bool last = false}) => Text(
      text,
      style: last ? labelStyle : labelStyle?.copyWith(color: colors.textMuted),
    );
    final separator = Icon(
      Icons.chevron_right_rounded,
      size: 18,
      color: colors.textMuted,
    );

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: 40,
          vertical: AppSpacing.xl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // "Inicio › Inglés B2 › Verbos irregulares › Nueva tarjeta".
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: AppSpacing.xs,
              children: [
                crumb(l10n.home),
                separator,
                crumb(project.name),
                separator,
                crumb(deck.name),
                separator,
                crumb(title, last: true),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.displaySmall,
                  ),
                ),
                TextButton(
                  key: const Key('cardEditor.cancel'),
                  onPressed: onCancel,
                  child: Text(l10n.cancel),
                ),
                const SizedBox(width: AppSpacing.sm),
                if (!actions.isEditing) ...[
                  actions.saveAndAddButton(context),
                  const SizedBox(width: AppSpacing.sm),
                ],
                actions.saveButton(context),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            // The preview column on the right arrives with T2.5.
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 660),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: fields,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Guardar" and "Guardar y añadir otra"; a null callback disables them.
class _Actions {
  const new({
    required this.isEditing,
    required this.onSave,
    required this.onSaveAndAdd,
  });

  final bool isEditing;
  final VoidCallback? onSave;
  final VoidCallback? onSaveAndAdd;

  Widget saveButton(BuildContext context) => FilledButton.icon(
    key: const Key('cardEditor.save'),
    onPressed: onSave,
    icon: const Icon(Icons.check_rounded),
    label: Text(AppLocalizations.of(context).save),
  );

  Widget saveAndAddButton(BuildContext context) => OutlinedButton(
    key: const Key('cardEditor.saveAndAdd'),
    onPressed: onSaveAndAdd,
    child: Text(
      AppLocalizations.of(context).saveAndAddAnother,
      textAlign: TextAlign.center,
    ),
  );
}

/// The project colour dot and "Proyecto › Baraja" under the mobile title.
class _DeckPath extends StatelessWidget {
  const new({required this.project, required this.deck});

  final Project project;
  final Deck deck;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final color = ProjectColor.fromKey(deck.color)
        .resolve(Theme.of(context).brightness);
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            AppLocalizations.of(context).deckPath(project.name, deck.name),
            style: Theme.of(context).textTheme.titleSmall
                ?.copyWith(color: colors.textMuted),
          ),
        ),
      ],
    );
  }
}

/// A text field with the formatting bar on top (bold, italic), as the
/// question and answer fields of the design.
class FormattedField extends StatefulWidget {
  const new({
    required this.fieldKey,
    required this.controller,
    required this.onChanged,
    this.focusNode,
    this.autofocus = false,
    this.errorText,
    super.key,
  });

  /// Key of the text field; the buttons get `<fieldKey>.bold` and
  /// `<fieldKey>.italic`.
  final String fieldKey;
  final FormattedTextController controller;
  final VoidCallback onChanged;
  final FocusNode? focusNode;
  final bool autofocus;
  final String? errorText;

  @override
  State<FormattedField> createState() => _FormattedFieldState();
}

class _FormattedFieldState extends State<FormattedField> {
  FocusNode? _ownFocus;
  FocusNode get _focus => widget.focusNode ?? (_ownFocus ??= FocusNode());

  @override
  void initState() {
    super.initState();
    // Redraw the border when the field gains or loses focus.
    _focus.addListener(_onFocusChange);
  }

  void _onFocusChange() => setState(() {});

  @override
  void dispose() {
    _focus.removeListener(_onFocusChange);
    _ownFocus?.dispose();
    super.dispose();
  }

  void _toggle(InlineStyle style) {
    widget.controller.toggle(style);
    _focus.requestFocus();
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final focused = _focus.hasFocus;
    final error = widget.errorText;
    final borderColor = error != null
        ? colors.error
        : focused
        ? colors.primaryStrong
        : colors.border;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: focused ? colors.surface : colors.surfaceVariant,
            borderRadius: BorderRadius.circular(AppRadii.control),
            border: Border.all(color: borderColor, width: focused ? 2 : 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                child: Row(
                  children: [
                    IconButton(
                      key: Key('${widget.fieldKey}.bold'),
                      tooltip: l10n.bold,
                      onPressed: () => _toggle(InlineStyle.bold),
                      icon: const Icon(Icons.format_bold_rounded),
                    ),
                    IconButton(
                      key: Key('${widget.fieldKey}.italic'),
                      tooltip: l10n.italic,
                      onPressed: () => _toggle(InlineStyle.italic),
                      icon: const Icon(Icons.format_italic_rounded),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: colors.border),
              TextField(
                key: Key(widget.fieldKey),
                controller: widget.controller,
                focusNode: _focus,
                autofocus: widget.autofocus,
                textCapitalization: TextCapitalization.sentences,
                maxLines: null,
                style: Theme.of(context).textTheme.titleMedium,
                decoration: const InputDecoration(
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.all(AppSpacing.lg),
                ),
                onChanged: (_) => widget.onChanged(),
              ),
            ],
          ),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(
              top: AppSpacing.xs,
              left: AppSpacing.md,
            ),
            child: Text(
              error,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: colors.error),
            ),
          ),
      ],
    );
  }
}

/// "Frase de ejemplo" and "Notas" (language projects only, US-08 AC2):
/// side by side when there is room, one under the other on a phone.
class _LanguageFields extends StatelessWidget {
  const new({
    required this.example,
    required this.notes,
    required this.onChanged,
  });

  final TextEditingController example;
  final TextEditingController notes;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    Widget field(String key, String label, TextEditingController controller) =>
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FormLabel(label),
            TextField(
              key: Key(key),
              controller: controller,
              textCapitalization: TextCapitalization.sentences,
              minLines: 2,
              maxLines: null,
              onChanged: (_) => onChanged(),
            ),
          ],
        );
    final exampleField = field(
      'cardEditor.example',
      l10n.exampleOptionalLabel,
      example,
    );
    final notesField = field(
      'cardEditor.notes',
      l10n.notesOptionalLabel,
      notes,
    );
    return LayoutBuilder(
      builder: (context, constraints) => constraints.maxWidth >= 560
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: exampleField),
                const SizedBox(width: AppSpacing.lg),
                Expanded(child: notesField),
              ],
            )
          : Column(
              children: [
                exampleField,
                const SizedBox(height: AppSpacing.xl),
                notesField,
              ],
            ),
    );
  }
}

/// A screen with only a message, e.g. when the card no longer exists.
class _Message extends StatelessWidget {
  const new(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(),
    body: Center(
      child: Text(text, style: Theme.of(context).textTheme.titleMedium),
    ),
  );
}
