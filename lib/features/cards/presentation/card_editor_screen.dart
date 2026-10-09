import 'dart:async';
import 'dart:io';

import 'package:estudicards/app/l10n/generated/app_localizations.dart';
import 'package:estudicards/app/layout/breakpoints.dart';
import 'package:estudicards/app/theme/app_colors.dart';
import 'package:estudicards/app/theme/dimensions.dart';
import 'package:estudicards/app/theme/project_palette.dart';
import 'package:estudicards/core/providers.dart';
import 'package:estudicards/core/widgets/confirm_dialog.dart';
import 'package:estudicards/features/cards/domain/card_input.dart';
import 'package:estudicards/features/cards/domain/flashcard.dart';
import 'package:estudicards/features/cards/domain/inline_format.dart';
import 'package:estudicards/features/cards/presentation/card_providers.dart';
import 'package:estudicards/features/cards/presentation/formatted_text_controller.dart';
import 'package:estudicards/features/cards/presentation/study_card.dart';
import 'package:estudicards/features/decks/domain/deck.dart';
import 'package:estudicards/features/decks/presentation/deck_providers.dart';
import 'package:estudicards/features/projects/domain/project.dart';
import 'package:estudicards/features/projects/presentation/form_parts.dart';
import 'package:estudicards/features/projects/presentation/project_labels.dart';
import 'package:estudicards/features/projects/presentation/project_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// P06: creates a card in a deck, or edits [cardId] when given
/// (`docs/design/movil-claro/editor.png`, `escritorio-claro/editor.png`).
///
/// The image buttons arrive with T2.6. "Eliminar
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
  late final _explanation = FormattedTextController(
    text: widget.card?.explanation,
  );
  final _questionFocus = FocusNode();

  late CardType _type = widget.card?.type ?? CardType.simple;
  late bool _allowMultiple = widget.card?.allowMultiple ?? false;

  /// The options of a test card, in the order shown. They are kept while
  /// "Tipo test" is off, so turning it on again brings them back.
  late final List<_OptionDraft> _options = [
    for (final option in widget.card?.options ?? const <CardOption>[])
      _OptionDraft(
        id: option.id,
        text: option.text,
        isCorrect: option.isCorrect,
      ),
  ];

  /// Whether the user has typed in each field, so "Escribe la pregunta" only
  /// appears after emptying it, not on a new card.
  bool _questionEdited = false;
  bool _answerEdited = false;
  bool _optionsEdited = false;
  bool _saving = false;
  CardFace _previewFace = CardFace.front;

  /// The card's images, as names in the images folder (see `ImageFiles`).
  /// The answer image goes with the explanation on a test card.
  late String? _questionImage = widget.card?.questionImage;
  late String? _answerImage = widget.card?.answerImage;

  /// Images picked in this editor and not saved in a card yet. They are
  /// deleted if the user leaves without saving or replaces them; the images
  /// of a saved card are deleted by the repository instead.
  final _unsavedImages = <String>{};

  /// A new test card starts with 4 empty options (decided with the owner).
  static const _initialOptions = 4;

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
    '$_questionImage',
    '$_answerImage',
    if (_type == CardType.test) ...[
      '$_allowMultiple',
      _explanation.text,
      for (final option in _options) '${option.isCorrect}${option.text.text}',
    ],
  ].join('\u0000');

  bool get _hasChanges => _signature != _savedSignature;

  CardInput get _input => CardInput(
    type: _type,
    question: _question.text,
    questionImage: _questionImage,
    answer: _answer.text,
    answerImage: _answerImage,
    explanation: _explanation.text,
    allowMultiple: _allowMultiple,
    // Example and notes are kept even in a general project, whose fields
    // are hidden: switching back to "Idioma" shows them again (US-02 AC2).
    example: _example.text,
    notes: _notes.text,
    options: [
      for (final option in _options)
        CardOptionInput(
          id: option.id,
          text: option.text.text,
          isCorrect: option.isCorrect,
        ),
    ],
  );

  @override
  void dispose() {
    _question.dispose();
    _answer.dispose();
    _example.dispose();
    _notes.dispose();
    _explanation.dispose();
    for (final option in _options) {
      option.dispose();
    }
    _questionFocus.dispose();
    super.dispose();
  }

  /// "Tipo test" (US-09 AC1): a new test card starts with 4 empty options.
  void _setTestType({required bool isTest}) => setState(() {
    _type = isTest ? CardType.test : CardType.simple;
    if (isTest && _options.isEmpty) _resetOptions();
  });

  /// Replaces the options with 4 empty ones.
  void _resetOptions() {
    for (final option in _options) {
      option.dispose();
    }
    _options
      ..clear()
      ..addAll([for (var i = 0; i < _initialOptions; i++) _OptionDraft()]);
  }

  /// Ticks or unticks the option at [index]. Without "Permitir varias
  /// correctas" the options act as radio buttons: ticking one unticks the
  /// rest (US-09 AC2).
  void _tick(int index) => setState(() {
    _optionsEdited = true;
    if (_allowMultiple) {
      _options[index].isCorrect = !_options[index].isCorrect;
    } else {
      for (final (i, option) in _options.indexed) {
        option.isCorrect = i == index;
      }
    }
  });

  void _addOption() => setState(() => _options.add(_OptionDraft()));

  void _removeOption(int index) => setState(() {
    _optionsEdited = true;
    _options.removeAt(index).dispose();
  });

  /// Turning "Permitir varias correctas" off with several options ticked
  /// asks which one to keep (US-09 AC4).
  Future<void> _setAllowMultiple({required bool allow}) async {
    final ticked = [
      for (final (i, option) in _options.indexed)
        if (option.isCorrect) i,
    ];
    if (allow || ticked.length < 2) {
      setState(() => _allowMultiple = allow);
      return;
    }
    final keep = await _askWhichToKeep(ticked);
    if (keep == null || !mounted) return;
    setState(() {
      _allowMultiple = false;
      for (final (i, option) in _options.indexed) {
        option.isCorrect = i == keep;
      }
    });
  }

  /// The index of the option to keep, or null if the user cancelled.
  Future<int?> _askWhichToKeep(List<int> ticked) {
    final l10n = AppLocalizations.of(context);
    return showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        key: const Key('keepCorrectDialog'),
        title: Text(l10n.keepCorrectTitle),
        children: [
          for (final i in ticked)
            SimpleDialogOption(
              key: Key('keepCorrectDialog.option.$i'),
              onPressed: () => Navigator.of(context).pop(i),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Text(
                  _options[i].text.text.trim().isEmpty
                      ? l10n.optionHint(i + 1)
                      : _options[i].text.text.trim(),
                ),
              ),
            ),
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(right: AppSpacing.lg),
              child: TextButton(
                key: const Key('keepCorrectDialog.cancel'),
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l10n.cancel),
              ),
            ),
          ),
        ],
      ),
    );
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
    // The picked images now belong to the saved card.
    _unsavedImages.clear();
    if (!mounted) return;
    if (!addAnother) {
      context.pop();
      return;
    }
    // US-10: a clean form of the same type, with the same "Permitir varias
    // correctas", ready for the next card.
    setState(() {
      _question.clear();
      _answer.clear();
      _example.clear();
      _notes.clear();
      _explanation.clear();
      _questionImage = null;
      _answerImage = null;
      if (_type == CardType.test) _resetOptions();
      _questionEdited = false;
      _answerEdited = false;
      _optionsEdited = false;
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

  /// Leaves the editor, asking first if there are unsaved changes. The
  /// images picked here are deleted: no card uses them.
  Future<void> _leave() async {
    if (_hasChanges && !await _confirmDiscard()) return;
    await ref.read(imageFilesProvider).delete(_unsavedImages);
    _unsavedImages.clear();
    if (mounted) context.pop();
  }

  /// Opens the gallery (mobile) or the file dialog (desktop) and stores the
  /// picked image, resized (SPEC §3.4), as the question or answer image.
  Future<void> _pickImage({required bool forQuestion}) async {
    final bytes = await ref.read(imageSourceProvider).pick();
    if (bytes == null || !mounted) return;
    final path = await ref.read(imageFilesProvider).save(bytes);
    if (!mounted) return;
    if (path == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).imageNotOpened)),
      );
      return;
    }
    _unsavedImages.add(path);
    _setImage(path, forQuestion: forQuestion);
  }

  /// Sets or removes ([path] null) an image. An image picked in this editor
  /// and replaced is deleted at once, since nothing else uses it.
  void _setImage(String? path, {required bool forQuestion}) {
    final previous = forQuestion ? _questionImage : _answerImage;
    if (previous != null && _unsavedImages.remove(previous)) {
      unawaited(ref.read(imageFilesProvider).delete([previous]));
    }
    setState(() {
      if (forQuestion) {
        _questionImage = path;
      } else {
        _answerImage = path;
      }
    });
  }

  /// The image at [path] in the images folder, to show it; null while the
  /// folder is not known yet.
  ImageProvider? _imageFor(String? path) {
    final folder = ref.watch(imagesFolderProvider).value;
    if (path == null || folder == null) return null;
    return FileImage(File('${folder.path}/$path'));
  }

  /// The thumbnail and "Quitar imagen" under a field with an image.
  Widget? _imageRow(String keyPrefix, {required bool forQuestion}) {
    final image = _imageFor(forQuestion ? _questionImage : _answerImage);
    if (image == null) return null;
    return _ImageThumbnail(
      keyPrefix: keyPrefix,
      image: image,
      onRemove: () => _setImage(null, forQuestion: forQuestion),
    );
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
                preview: _DesktopPreview(
                  face: _previewFace,
                  onFaceChanged: (face) => setState(() => _previewFace = face),
                  card: _previewCard(l10n),
                ),
              )
            : _MobileFrame(
                title: title,
                project: widget.project,
                deck: widget.deck,
                onClose: () => unawaited(_leave()),
                actions: actions,
                fields: _fields(l10n),
                preview: SizedBox(height: 440, child: _previewCard(l10n)),
              ),
      ),
    );
  }

  /// The card as it will be studied, updated while typing (US-08 AC4).
  /// Tapping it turns it over; the back of a test card shows the solution.
  StudyCard _previewCard(AppLocalizations l10n) {
    final input = _input;
    final project = widget.project;
    final source = project.sourceLang;
    final target = project.targetLang;
    final now = DateTime.utc(2000);
    return StudyCard(
      card: Flashcard(
        id: 'preview',
        deckId: widget.deck.id,
        type: _type,
        question: input.trimmedQuestion,
        answer: input.trimmedAnswer,
        explanation: input.trimmedExplanation,
        allowMultiple: _allowMultiple,
        example: input.trimmedExample,
        notes: input.trimmedNotes,
        options: [
          for (final (i, option) in input.filledOptions.indexed)
            CardOption(
              id: 'preview.$i',
              text: option.text,
              isCorrect: option.isCorrect,
              position: i,
            ),
        ],
        // Not shown; a card needs them.
        createdAt: now,
        updatedAt: now,
      ),
      label: l10n.cardLabel(project.name, widget.deck.name),
      color: widget.deck.color,
      face: _previewFace,
      languagePair: _isLanguage && source != null && target != null
          ? l10n.languagePair(
              languageName(l10n, source),
              languageName(l10n, target),
            )
          : null,
      questionImage: _imageFor(_questionImage),
      answerImage: _imageFor(_answerImage),
      onTap: () => setState(
        () => _previewFace = _previewFace == CardFace.front
            ? CardFace.back
            : CardFace.front,
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
        onPickImage: () => unawaited(_pickImage(forQuestion: true)),
        imageRow: _imageRow('cardEditor.question', forQuestion: true),
      ),
      const SizedBox(height: AppSpacing.lg),
      _TypeSwitches(
        isTest: _type == CardType.test,
        allowMultiple: _allowMultiple,
        onTestTypeChanged: (isTest) => _setTestType(isTest: isTest),
        onAllowMultipleChanged: (allow) =>
            unawaited(_setAllowMultiple(allow: allow)),
      ),
      const SizedBox(height: AppSpacing.xl),
      if (_type == CardType.simple) ...[
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
          onPickImage: () => unawaited(_pickImage(forQuestion: false)),
          imageRow: _imageRow('cardEditor.answer', forQuestion: false),
        ),
      ] else ...[
        ..._optionsSection(l10n),
        const SizedBox(height: AppSpacing.xl),
        FormLabel(l10n.explanationOptionalLabel),
        TextField(
          key: const Key('cardEditor.explanation'),
          controller: _explanation,
          textCapitalization: TextCapitalization.sentences,
          minLines: 2,
          maxLines: null,
          onChanged: (_) => setState(() {}),
        ),
        // On a test card the answer image goes with the explanation.
        _imageRow('cardEditor.explanation', forQuestion: false) ??
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: const Key('cardEditor.explanation.image'),
                onPressed: () => unawaited(_pickImage(forQuestion: false)),
                icon: const Icon(Icons.image_outlined),
                label: Text(l10n.addImage),
              ),
            ),
      ],
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

  /// "Opciones" with its counter, one row per option, "Añadir opción" and,
  /// once the user has touched the options, what is still missing.
  List<Widget> _optionsSection(AppLocalizations l10n) {
    final colors = AppColors.of(context);
    final input = _input;
    final correct = input.filledOptions.where((o) => o.isCorrect).length;
    final errors = input.validate();
    final problems = [
      if (_optionsEdited) ...[
        if (errors.contains(CardInputError.tooFewOptions)) l10n.optionsTooFew,
        if (errors.contains(CardInputError.noCorrectOption))
          l10n.noCorrectOption,
      ],
    ];
    final canRemove = _options.length > CardInput.minOptions;

    return [
      Row(
        children: [
          Expanded(child: FormLabel(l10n.optionsLabel)),
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Text(
              l10n.optionsCounter(
                _options.length,
                CardInput.maxOptions,
                correct,
              ),
              style: Theme.of(context).textTheme.labelLarge
                  ?.copyWith(color: colors.textMuted),
            ),
          ),
        ],
      ),
      for (final (i, option) in _options.indexed)
        Padding(
          // The draft as key keeps each row's state with its option when
          // one above it is removed.
          key: ObjectKey(option),
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: _OptionRow(
            index: i,
            option: option,
            allowMultiple: _allowMultiple,
            onTick: () => _tick(i),
            onRemove: canRemove ? () => _removeOption(i) : null,
            onChanged: () => setState(() => _optionsEdited = true),
          ),
        ),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          key: const Key('cardEditor.addOption'),
          onPressed: _options.length < CardInput.maxOptions ? _addOption : null,
          icon: const Icon(Icons.add_rounded),
          label: Text(l10n.addOption),
        ),
      ),
      for (final problem in problems)
        Text(
          problem,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: colors.error),
        ),
    ];
  }
}

/// A small picture of a field's image with "Quitar imagen". Keys:
/// `<keyPrefix>.imagePreview` and `<keyPrefix>.removeImage`.
class _ImageThumbnail extends StatelessWidget {
  const new({
    required this.keyPrefix,
    required this.image,
    required this.onRemove,
  });

  final String keyPrefix;
  final ImageProvider image;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Row(
        children: [
          ClipRRect(
            key: Key('$keyPrefix.imagePreview'),
            borderRadius: BorderRadius.circular(AppRadii.control),
            child: Container(
              width: 64,
              height: 64,
              color: colors.surfaceVariant,
              child: Image(
                image: image,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    Icon(Icons.broken_image_outlined, color: colors.textMuted),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          TextButton.icon(
            key: Key('$keyPrefix.removeImage'),
            onPressed: onRemove,
            icon: const Icon(Icons.delete_outline_rounded),
            label: Text(AppLocalizations.of(context).removeImage),
          ),
        ],
      ),
    );
  }
}

/// One option of a test card while it is being edited.
class _OptionDraft {
  new({this.id, String? text, this.isCorrect = false})
    : text = TextEditingController(text: text);

  /// The stored option's ID; null for a new one.
  final String? id;
  final TextEditingController text;
  bool isCorrect;

  void dispose() => text.dispose();
}

/// The "Tipo test" and "Permitir varias correctas" switches, in one box as
/// in the design. The second one only appears on a test card.
class _TypeSwitches extends StatelessWidget {
  const new({
    required this.isTest,
    required this.allowMultiple,
    required this.onTestTypeChanged,
    required this.onAllowMultipleChanged,
  });

  final bool isTest;
  final bool allowMultiple;
  final ValueChanged<bool> onTestTypeChanged;
  final ValueChanged<bool> onAllowMultipleChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final style = Theme.of(context).textTheme.titleMedium;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          SwitchListTile(
            key: const Key('cardEditor.testType'),
            title: Text(l10n.testTypeLabel, style: style),
            value: isTest,
            onChanged: onTestTypeChanged,
          ),
          if (isTest) ...[
            const Divider(height: 1, indent: AppSpacing.lg),
            SwitchListTile(
              key: const Key('cardEditor.allowMultiple'),
              title: Text(l10n.allowMultipleLabel, style: style),
              value: allowMultiple,
              onChanged: onAllowMultipleChanged,
            ),
          ],
        ],
      ),
    );
  }
}

/// The correct-answer selector, the text and the ✕ of one option. The
/// selector is a radio button, or a checkbox with "Permitir varias
/// correctas"; a ticked option is tinted green, always with its ✓.
class _OptionRow extends StatelessWidget {
  const new({
    required this.index,
    required this.option,
    required this.allowMultiple,
    required this.onTick,
    required this.onRemove,
    required this.onChanged,
  });

  final int index;
  final _OptionDraft option;
  final bool allowMultiple;
  final VoidCallback onTick;

  /// Null disables the ✕: a test card needs at least 2 options.
  final VoidCallback? onRemove;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final ticked = option.isCorrect;
    final icon = switch ((allowMultiple, ticked)) {
      (true, true) => Icons.check_box_rounded,
      (true, false) => Icons.check_box_outline_blank_rounded,
      (false, true) => Icons.check_circle_rounded,
      (false, false) => Icons.radio_button_unchecked_rounded,
    };
    OutlineInputBorder border(Color color) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadii.control),
      borderSide: BorderSide(color: color, width: ticked ? 2 : 1),
    );

    return Row(
      children: [
        Semantics(
          label: l10n.markCorrect,
          checked: ticked,
          inMutuallyExclusiveGroup: !allowMultiple,
          child: InkResponse(
            key: Key('cardEditor.option.$index.correct'),
            onTap: onTick,
            child: SizedBox.square(
              dimension: minTouchTarget,
              child: Icon(
                icon,
                size: 28,
                color: ticked ? colors.success : colors.textMuted,
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: TextField(
            key: Key('cardEditor.option.$index'),
            controller: option.text,
            textCapitalization: TextCapitalization.sentences,
            // A long option wraps instead of scrolling sideways.
            maxLines: null,
            style: Theme.of(context).textTheme.titleMedium,
            decoration: InputDecoration(
              hintText: l10n.optionHint(index + 1),
              fillColor: ticked
                  ? colors.success.withValues(alpha: 0.12)
                  : colors.surface,
              enabledBorder: border(ticked ? colors.success : colors.border),
            ),
            onChanged: (_) => onChanged(),
          ),
        ),
        IconButton(
          key: Key('cardEditor.option.$index.remove'),
          tooltip: l10n.removeOption,
          onPressed: onRemove,
          icon: const Icon(Icons.close_rounded),
        ),
      ],
    );
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
    required this.preview,
  });

  final String title;
  final Project project;
  final Deck deck;
  final VoidCallback onClose;
  final _Actions actions;
  final List<Widget> fields;

  /// Shown below the form.
  final Widget preview;

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
          // A Column builds every field, unlike a ListView, which only
          // builds the visible ones and would lose a field's state when it
          // scrolls away.
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.xl,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _DeckPath(project: project, deck: deck),
                const SizedBox(height: AppSpacing.xl),
                ...fields,
                const SizedBox(height: AppSpacing.xxl),
                Text(
                  l10n.previewTapToFlip.toUpperCase(),
                  style: _previewHeadingStyle(context),
                ),
                const SizedBox(height: AppSpacing.md),
                preview,
              ],
            ),
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

/// "VISTA PREVIA" above the preview, in small capitals.
TextStyle? _previewHeadingStyle(BuildContext context) =>
    Theme.of(context).textTheme.labelMedium?.copyWith(
      color: AppColors.of(context).textMuted,
      fontWeight: FontWeight.w700,
      letterSpacing: 1,
    );

/// The desktop preview column: "VISTA PREVIA" with "Anverso" / "Reverso",
/// the card and a caption, as in `escritorio-claro/editor.png`.
class _DesktopPreview extends StatelessWidget {
  const new({
    required this.face,
    required this.onFaceChanged,
    required this.card,
  });

  final CardFace face;
  final ValueChanged<CardFace> onFaceChanged;
  final StudyCard card;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.previewLabel.toUpperCase(),
                style: _previewHeadingStyle(context),
              ),
            ),
            SegmentedButton<CardFace>(
              showSelectedIcon: false,
              // As in the design: the chosen side is a light "pill" on a
              // grey track, not an orange fill.
              style: SegmentedButton.styleFrom(
                backgroundColor: colors.surfaceVariant,
                selectedBackgroundColor: colors.surface,
                foregroundColor: colors.textMuted,
                selectedForegroundColor: colors.text,
                side: BorderSide(color: colors.border),
              ),
              segments: [
                ButtonSegment(
                  value: CardFace.front,
                  label: Text(
                    l10n.previewFront,
                    key: const Key('cardEditor.preview.front'),
                  ),
                ),
                ButtonSegment(
                  value: CardFace.back,
                  label: Text(
                    l10n.previewBack,
                    key: const Key('cardEditor.preview.back'),
                  ),
                ),
              ],
              selected: {face},
              onSelectionChanged: (selection) =>
                  onFaceChanged(selection.single),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        SizedBox(height: 460, child: card),
        const SizedBox(height: AppSpacing.md),
        Text(
          l10n.previewCaption,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
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
    required this.preview,
  });

  final String title;
  final Project project;
  final Deck deck;
  final VoidCallback onCancel;
  final _Actions actions;
  final List<Widget> fields;
  final Widget preview;

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
            // The form on the left and the preview on the right.
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: fields,
                  ),
                ),
                const SizedBox(width: 40),
                SizedBox(width: 380, child: preview),
              ],
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
    this.onPickImage,
    this.imageRow,
    super.key,
  });

  /// Key of the text field; the buttons get `<fieldKey>.bold`,
  /// `<fieldKey>.italic` and `<fieldKey>.image`.
  final String fieldKey;
  final FormattedTextController controller;
  final VoidCallback onChanged;
  final FocusNode? focusNode;
  final bool autofocus;
  final String? errorText;

  /// The image button at the right of the bar; null hides it.
  final VoidCallback? onPickImage;

  /// The field's image with "Quitar imagen", shown under it.
  final Widget? imageRow;

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
                child: IconButtonTheme(
                  // The B and I in the text colour, as in the design.
                  data: IconButtonThemeData(
                    style: IconButton.styleFrom(foregroundColor: colors.text),
                  ),
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
                      const Spacer(),
                      if (widget.onPickImage case final onPickImage?)
                        IconButton(
                          key: Key('${widget.fieldKey}.image'),
                          tooltip: l10n.addImage,
                          onPressed: onPickImage,
                          icon: const Icon(Icons.image_outlined),
                        ),
                    ],
                  ),
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
                // Regular weight, so the words marked bold stand out.
                style: Theme.of(context).textTheme.bodyLarge
                    ?.copyWith(fontSize: 17),
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
        ?widget.imageRow,
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
