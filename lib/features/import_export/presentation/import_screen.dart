// P07: the import wizard (US-27, `docs/design/movil-claro/importar.png`).
//
// Three steps: pick a file, choose where it goes, and review what will be
// imported before confirming (SPEC §8.4). Where the cards go depends on
// where the wizard was opened: the dashboard imports a new project, a
// project a new deck, and a deck adds to itself (then there is nothing to
// choose and step 2 is skipped).
import 'dart:async';

import 'package:estudicards/app/l10n/generated/app_localizations.dart';
import 'package:estudicards/app/router.dart';
import 'package:estudicards/app/theme/app_colors.dart';
import 'package:estudicards/app/theme/dimensions.dart';
import 'package:estudicards/core/providers.dart';
import 'package:estudicards/features/cards/domain/flashcard.dart';
import 'package:estudicards/features/cards/presentation/formatted_text.dart';
import 'package:estudicards/features/decks/domain/deck.dart';
import 'package:estudicards/features/decks/domain/deck_input.dart';
import 'package:estudicards/features/decks/presentation/deck_providers.dart';
import 'package:estudicards/features/decks/presentation/deck_type_fields.dart';
import 'package:estudicards/features/import_export/data/import_repository.dart';
import 'package:estudicards/features/import_export/domain/import_file.dart';
import 'package:estudicards/features/import_export/domain/import_plan.dart';
import 'package:estudicards/features/import_export/presentation/import_messages.dart';
import 'package:estudicards/features/import_export/presentation/import_providers.dart';
import 'package:estudicards/features/projects/domain/project_input.dart';
import 'package:estudicards/features/projects/presentation/form_parts.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

enum _Step { file, destination, review }

/// Where the wizard puts the cards, from where it was opened.
enum _Mode { newProject, newDeck, intoDeck }

/// How many warnings the review lists before "y N avisos más".
const _maxWarnings = 50;

/// How many of the new cards the review shows.
const _firstCards = 5;

/// P07: the import wizard.
class ImportScreen extends ConsumerStatefulWidget {
  const new({this.projectId, this.deckId, super.key});

  /// Set when opened from a project (a new deck) or a deck.
  final String? projectId;

  /// Set when opened from a deck: the cards are added to it.
  final String? deckId;

  @override
  ConsumerState<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends ConsumerState<ImportScreen> {
  _Step _step = _Step.file;

  // Step 1.
  late String _fileName;
  ImportSource? _source;
  bool _reading = false;
  String? _error;

  // Step 2: the name of the new project or deck and, for a CSV, the type.
  final _name = TextEditingController();
  DeckType _type = DeckType.general;
  String? _sourceLang;
  String? _targetLang;

  // Step 3.
  ImportPlan? _plan;

  /// The name of the deck the cards are added to.
  String? _deckName;
  bool _busy = false;

  _Mode get _mode => widget.deckId != null
      ? _Mode.intoDeck
      : widget.projectId != null
      ? _Mode.newDeck
      : _Mode.newProject;

  bool get _isCsv => _source is CsvSource;

  /// Where ✕ goes: back to where the wizard was opened.
  String get _origin => switch (_mode) {
    _Mode.newProject => AppRoutes.home,
    _Mode.newDeck => AppRoutes.project(widget.projectId!),
    _Mode.intoDeck => AppRoutes.deck(widget.projectId!, widget.deckId!),
  };

  DeckSettings get _settings => DeckSettings(
    type: _type,
    sourceLang: _sourceLang,
    targetLang: _targetLang,
  );

  ImportDestination get _destination => switch (_mode) {
    _Mode.newProject => NewProjectDestination(
      name: _name.text,
      settings: _settings,
    ),
    _Mode.newDeck => NewDeckDestination(
      projectId: widget.projectId!,
      name: _name.text,
      settings: _settings,
    ),
    _Mode.intoDeck => ExistingDeckDestination(widget.deckId!),
  };

  /// Whether step 2 is complete: a valid name and, for a CSV language
  /// deck, both languages (the editors' own rules).
  bool get _destinationValid {
    final name = _name.text;
    final nameValid = _mode == _Mode.newProject
        ? ProjectInput(
            name: name,
            color: 'orange',
            icon: 'book',
          ).validate().isEmpty
        : DeckInput(name: name).validate().isEmpty;
    final languagesValid =
        !_isCsv ||
        !DeckInput(
          name: name,
          type: _type,
          sourceLang: _sourceLang,
          targetLang: _targetLang,
        ).validate().contains(DeckInputError.languagesMissing);
    return nameValid && languagesValid;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _error = null);
    final file = await ref.read(documentPickerProvider).pick(const [
      'csv',
      'json',
    ]);
    if (file == null || !mounted) return;

    final type = ImportFileType.fromName(file.name);
    final size = file.size;
    if (type == null || (size != null && size > type.maxBytes)) {
      // Refused before reading it: the file may be huge.
      setState(
        () => _error = importErrorMessage(
          l10n,
          ImportFileException(type == null ? .unsupportedType : .tooLarge),
          file.name,
        ),
      );
      return;
    }

    setState(() => _reading = true);
    try {
      final source = await _readInBackground(
        ref.read(backgroundRunnerProvider),
        file.name,
        await file.read(),
      );
      if (!mounted) return;
      if (source is ProjectFileSource && _mode != _Mode.newProject) {
        setState(() => _error = l10n.importErrorProjectHere);
        return;
      }
      _source = source;
      _fileName = file.name;
      _name.text = switch (source) {
        CsvSource() => _withoutExtension(file.name),
        DeckFileSource(:final deck) => deck.name.trim(),
        ProjectFileSource(:final project) => project.name.trim(),
      };
      if (_mode == _Mode.intoDeck) {
        await _preview();
      } else {
        setState(() => _step = _Step.destination);
      }
    } on Object catch (error) {
      if (mounted) {
        setState(() => _error = importErrorMessage(l10n, error, file.name));
      }
    } finally {
      if (mounted) setState(() => _reading = false);
    }
  }

  /// Works out the review (step 3) without writing anything.
  Future<void> _preview() async {
    final l10n = AppLocalizations.of(context);
    final plan = await ref
        .read(importRepositoryProvider)
        .preview(
          _source!,
          _destination,
          defaultDeckName: l10n.importDefaultDeck,
        );
    String? deckName;
    if (widget.deckId case final deckId?) {
      deckName = (await ref.read(decksRepositoryProvider).getById(deckId))
          ?.name;
    }
    if (!mounted) return;
    setState(() {
      _plan = plan;
      _deckName = deckName;
      _step = _Step.review;
    });
  }

  Future<void> _import() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    final ImportResult result;
    try {
      result = await ref.read(importRepositoryProvider).commit(_plan!);
    } on Object {
      // Nothing was saved (one transaction, SPEC §8.4 rule 8).
      if (mounted) setState(() => _busy = false);
      messenger.showSnackBar(SnackBar(content: Text(l10n.importFailed)));
      return;
    }
    if (!mounted) return;
    context.go(switch (_mode) {
      _Mode.newProject => AppRoutes.project(result.projectId),
      _Mode.newDeck => AppRoutes.deck(result.projectId, result.deckIds.single),
      _Mode.intoDeck => AppRoutes.deck(widget.projectId!, widget.deckId!),
    });
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          [
            l10n.importAdded(result.added),
            if (result.duplicates > 0)
              l10n.importSkippedDuplicates(result.duplicates),
            if (result.errors > 0) l10n.importSkippedErrors(result.errors),
            if (result.imagesSkipped > 0)
              l10n.importSkippedImages(result.imagesSkipped),
          ].join(', '),
        ),
      ),
    );
  }

  /// Goes back to a step already done, from the step indicator.
  void _goBack(_Step step) => setState(() {
    _step = step;
    if (step == _Step.file) _error = null;
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: CloseButton(
          key: const Key('import.close'),
          onPressed: () => context.go(_origin),
        ),
        title: Text(l10n.importCardsTitle),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          // The same reading width as the other mobile screens on tablets
          // and desktop.
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.sm,
                  AppSpacing.lg,
                  AppSpacing.lg,
                ),
                child: _Steps(
                  current: _step,
                  skipsDestination: _mode == _Mode.intoDeck,
                  onBack: _busy ? null : _goBack,
                ),
              ),
              Expanded(
                child: ListView(
                  key: const Key('import.list'),
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    0,
                    AppSpacing.lg,
                    AppSpacing.xl,
                  ),
                  children: switch (_step) {
                    _Step.file => _fileStep(l10n),
                    _Step.destination => _destinationStep(l10n),
                    _Step.review => _reviewStep(l10n),
                  },
                ),
              ),
              if (_step != _Step.file) _bottomBar(l10n),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _fileStep(AppLocalizations l10n) {
    final colors = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    return [
      _Panel(
        child: Column(
          children: [
            const _FileIcon(),
            const SizedBox(height: AppSpacing.lg),
            Text(l10n.importChooseTitle, style: text.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            Text(
              l10n.importChooseBody,
              textAlign: TextAlign.center,
              style: text.bodyMedium?.copyWith(color: colors.textMuted),
            ),
            const SizedBox(height: AppSpacing.xl),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: const Key('import.chooseFile'),
                onPressed: _reading ? null : _pickFile,
                icon: _reading
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.upload_rounded),
                label: Text(
                  _reading ? l10n.importReading : l10n.importChooseFile,
                ),
              ),
            ),
          ],
        ),
      ),
      if (_error case final error?) ...[
        const SizedBox(height: AppSpacing.lg),
        _ErrorBox(message: error),
      ],
    ];
  }

  List<Widget> _destinationStep(AppLocalizations l10n) {
    final colors = AppColors.of(context);
    final muted = Theme.of(context).textTheme.bodyMedium
        ?.copyWith(color: colors.textMuted);
    return [
      _FileCard(name: _fileName, details: _fileDetails(l10n)),
      const SizedBox(height: AppSpacing.xl),
      FormLabel(
        _mode == _Mode.newProject
            ? l10n.importProjectName
            : l10n.importDeckName,
      ),
      TextField(
        key: const Key('import.name'),
        controller: _name,
        textCapitalization: TextCapitalization.sentences,
        inputFormatters: [
          LengthLimitingTextInputFormatter(DeckInput.maxNameLength),
        ],
        onChanged: (_) => setState(() {}),
      ),
      const SizedBox(height: AppSpacing.xl),
      // A CSV has no type: it is asked here, once (SPEC §8.4 rule 6).
      if (_isCsv) ...[
        FormLabel(
          _mode == _Mode.newProject ? l10n.importDecksType : l10n.typeLabel,
        ),
        DeckTypeSelector(
          keyPrefix: 'import',
          selected: _type,
          onChanged: (type) => setState(() => _type = type),
        ),
        if (_mode == _Mode.newProject) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(l10n.importDecksTypeHint, style: muted),
        ],
        if (_type == DeckType.language) ...[
          const SizedBox(height: AppSpacing.xl),
          LanguagePairFields(
            keyPrefix: 'import',
            sourceLang: _sourceLang,
            targetLang: _targetLang,
            onSourceChanged: (code) => setState(() => _sourceLang = code),
            onTargetChanged: (code) => setState(() => _targetLang = code),
          ),
        ],
      ] else
        Text(l10n.importKeepsType, style: muted),
    ];
  }

  List<Widget> _reviewStep(AppLocalizations l10n) {
    final plan = _plan!;
    final colors = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    final (target, targetName) = switch (_mode) {
      _Mode.newProject => (l10n.importNewProjectTarget, _name.text.trim()),
      _Mode.newDeck => (l10n.importNewDeckTarget, _name.text.trim()),
      _Mode.intoDeck => (l10n.importAddTo, _deckName ?? ''),
    };
    final warnings = [
      for (final issue in plan.errors) (issue, true),
      for (final issue in plan.duplicates) (issue, false),
    ];
    final firstCards = [for (final deck in plan.decks) ...deck.cards]
        .take(_firstCards)
        .toList();

    return [
      _FileCard(
        name: _fileName,
        details: '${_fileDetails(l10n)} → $target ',
        target: targetName,
      ),
      const SizedBox(height: AppSpacing.lg),
      Row(
        children: [
          Expanded(
            child: _Metric(
              key: const Key('import.new'),
              value: plan.newCards,
              label: l10n.importNew,
              color: colors.success,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: _Metric(
              key: const Key('import.duplicates'),
              value: plan.duplicates.length,
              label: l10n.importDuplicates,
              color: colors.text,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: _Metric(
              key: const Key('import.errors'),
              value: plan.errors.length,
              label: l10n.importWithErrors,
              color: colors.error,
            ),
          ),
        ],
      ),
      if (warnings.isNotEmpty) ...[
        const SizedBox(height: AppSpacing.lg),
        _Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.importWarnings, style: text.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              for (final (i, (issue, isError))
                  in warnings.take(_maxWarnings).indexed) ...[
                if (i > 0) Divider(height: 1, color: colors.border),
                _Warning(issue: issue, isError: isError),
              ],
              if (warnings.length > _maxWarnings)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.md),
                  child: Text(
                    l10n.importMoreWarnings(warnings.length - _maxWarnings),
                    style: text.bodyMedium?.copyWith(color: colors.textMuted),
                  ),
                ),
            ],
          ),
        ),
      ],
      const SizedBox(height: AppSpacing.xl),
      if (firstCards.isEmpty)
        Text(
          l10n.importNothingNew,
          textAlign: TextAlign.center,
          style: text.bodyLarge?.copyWith(color: colors.textMuted),
        )
      else ...[
        Text(
          l10n.importFirstNewCards.toUpperCase(),
          style: text.labelMedium?.copyWith(
            color: colors.textMuted,
            letterSpacing: 1.2,
          ),
        ),
        for (final card in firstCards) ...[
          _NewCardRow(card: card),
          Divider(height: 1, color: colors.border),
        ],
      ],
    ];
  }

  Widget _bottomBar(AppLocalizations l10n) {
    final colors = AppColors.of(context);
    final review = _step == _Step.review;
    final count = _plan?.newCards ?? 0;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: colors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.md,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (review)
                FilledButton.icon(
                  key: const Key('import.confirm'),
                  onPressed: _busy || count == 0 ? null : _import,
                  icon: const Icon(Icons.upload_rounded),
                  label: Text(l10n.importConfirm(count)),
                )
              else
                FilledButton(
                  key: const Key('import.continue'),
                  onPressed: _destinationValid ? _preview : null,
                  child: Text(l10n.importContinue),
                ),
              if (review) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  l10n.importSkippedNote,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelMedium
                      ?.copyWith(color: colors.textMuted),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// "46 filas", "12 tarjetas" or "3 barajas · 120 tarjetas".
  String _fileDetails(AppLocalizations l10n) => switch (_source!) {
    CsvSource(:final csv) => l10n.importRows(
      csv.cards.length + csv.errors.length,
    ),
    DeckFileSource(:final deck) => l10n.cardCount(deck.cards.length),
    ProjectFileSource(:final project) => [
      l10n.deckCount(project.decks.length),
      l10n.cardCount(
        project.decks.fold(0, (sum, deck) => sum + deck.cards.length),
      ),
    ].join(l10n.detailsSeparator),
  };

  static String _withoutExtension(String name) {
    final dot = name.lastIndexOf('.');
    return (dot > 0 ? name.substring(0, dot) : name).trim();
  }
}

/// Reads the file in the background (see `backgroundRunnerProvider`). It is
/// a top-level function so the work sent to the isolate holds only the name
/// and the bytes, not the screen.
Future<ImportSource> _readInBackground(
  BackgroundRunner run,
  String name,
  Uint8List bytes,
) => run(() => readImportFile(name, bytes));

/// "✓ Fichero —— ✓ Destino —— 3 Revisar": the steps done are green and
/// can be tapped to go back to them.
class _Steps extends StatelessWidget {
  const new({
    required this.current,
    required this.skipsDestination,
    required this.onBack,
  });

  final _Step current;

  /// Adding to a deck has nothing to choose: "Destino" cannot be opened.
  final bool skipsDestination;
  final ValueChanged<_Step>? onBack;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final labels = {
      _Step.file: l10n.importStepFile,
      _Step.destination: l10n.importStepDestination,
      _Step.review: l10n.importStepReview,
    };
    final style = Theme.of(context).textTheme.titleSmall;
    final textScaler = MediaQuery.textScalerOf(context);
    double labelWidth(String label) {
      final painter = TextPainter(
        text: TextSpan(text: label, style: style),
        textDirection: TextDirection.ltr,
        textScaler: textScaler,
      )..layout();
      final width = painter.width;
      painter.dispose();
      return width;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // The labels take what they need and the lines fill the rest. If
        // the labels and a short line do not fit (a very narrow phone or
        // large text), each label may shrink and end in "…".
        final needed =
            labels.values.fold<double>(
              0,
              (sum, label) => sum + _StepLabel.fixedWidth + labelWidth(label),
            ) +
            2 * _minLine;
        final fits = needed <= constraints.maxWidth;
        return Row(
          children: [
            for (final step in _Step.values) ...[
              if (step != _Step.file)
                Expanded(
                  child: Container(
                    height: 2,
                    margin: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                    ),
                    color: step.index <= current.index
                        ? colors.success
                        : colors.border,
                  ),
                ),
              if (fits)
                _step(step, labels[step]!, shrinkable: false)
              else
                Flexible(
                  flex: 4,
                  child: _step(step, labels[step]!, shrinkable: true),
                ),
            ],
          ],
        );
      },
    );
  }

  /// The shortest line between two steps, margins included.
  static const double _minLine = 32;

  Widget _step(_Step step, String label, {required bool shrinkable}) =>
      _StepLabel(
        key: Key('import.step.${step.name}'),
        number: step.index + 1,
        label: label,
        done: step.index < current.index,
        current: step == current,
        shrinkable: shrinkable,
        onTap:
            step.index < current.index &&
                !(skipsDestination && step == _Step.destination)
            ? () => onBack?.call(step)
            : null,
      );
}

class _StepLabel extends StatelessWidget {
  const new({
    required this.number,
    required this.label,
    required this.done,
    required this.current,
    required this.shrinkable,
    required this.onTap,
    super.key,
  });

  /// The circle and the gap after it: everything but the label.
  static const double fixedWidth = 28 + AppSpacing.sm;

  /// Whether the label may end in "…" to fit.
  final bool shrinkable;

  final int number;
  final String label;
  final bool done;
  final bool current;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    final (background, foreground) = done
        ? (colors.success, colors.onSuccess)
        : current
        ? (colors.primaryStrong, colors.onPrimaryStrong)
        : (colors.surfaceVariant, colors.textMuted);
    final labelText = Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: text.titleSmall?.copyWith(
        color: done || current ? colors.text : colors.textMuted,
      ),
    );
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.chip),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: background,
                shape: BoxShape.circle,
              ),
              child: done
                  ? Icon(Icons.check_rounded, size: 18, color: foreground)
                  : Text(
                      '$number',
                      style: text.labelLarge?.copyWith(color: foreground),
                    ),
            ),
            const SizedBox(width: AppSpacing.sm),
            if (shrinkable) Flexible(child: labelText) else labelText,
          ],
        ),
      ),
    );
  }
}

/// A white card with a border, as the panels of the design.
class _Panel extends StatelessWidget {
  const new({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(AppRadii.listCard),
      ),
      child: child,
    );
  }
}

/// The grey square with the upload arrow.
class _FileIcon extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: colors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppRadii.control),
      ),
      child: Icon(Icons.upload_rounded, color: colors.textMuted),
    );
  }
}

/// The picked file: its name and "46 filas → añadir a **Verbos**".
class _FileCard extends StatelessWidget {
  const new({required this.name, required this.details, this.target});

  final String name;
  final String details;

  /// The project or deck the cards go to, in bold.
  final String? target;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(AppRadii.listCard),
      ),
      child: Row(
        children: [
          const _FileIcon(),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: text.titleMedium),
                const SizedBox(height: AppSpacing.xs),
                Text.rich(
                  TextSpan(
                    text: details,
                    children: [
                      if (target case final target?)
                        TextSpan(
                          text: target,
                          style: TextStyle(
                            color: colors.text,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                    ],
                  ),
                  style: text.bodyMedium?.copyWith(color: colors.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "42 / nuevas": a number and its caption.
class _Metric extends StatelessWidget {
  const new({
    required this.value,
    required this.label,
    required this.color,
    super.key,
  });

  final int value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    return Container(
      // Narrower side padding than other panels: three boxes share the
      // width of a phone, and "duplicadas" must fit.
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(AppRadii.listCard),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$value', style: text.headlineSmall?.copyWith(color: color)),
          const SizedBox(height: AppSpacing.xs),
          Text(
            label,
            maxLines: 2,
            style: text.titleSmall?.copyWith(color: colors.textMuted),
          ),
        ],
      ),
    );
  }
}

/// One line of "Avisos": a row with an error (red ⓘ) or a duplicate.
class _Warning extends StatelessWidget {
  const new({required this.issue, required this.isError});

  final ImportIssue issue;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final question = issue.question;
    // CSV rows are named by their number; JSON cards by their question.
    final lead = switch (issue.row) {
      final row? => l10n.importRow(row),
      null when isError && question != null => l10n.importQuoted(question),
      null => null,
    };
    final String message;
    if (isError) {
      final problem = importProblemText(l10n, issue.problem!);
      message = l10n.importErrorWarning(
        lead == null ? _capitalized(problem) : problem,
      );
    } else {
      message = l10n.importDuplicateWarning(question ?? '');
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isError ? Icons.error_outline_rounded : Icons.layers_outlined,
            size: 20,
            color: isError ? colors.error : colors.textMuted,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  if (lead != null)
                    TextSpan(
                      text: '$lead ',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  TextSpan(text: message),
                ],
              ),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  static String _capitalized(String text) =>
      text.isEmpty ? text : '${text[0].toUpperCase()}${text.substring(1)}';
}

/// A card to import: its type, question and "Nueva".
class _NewCardRow extends StatelessWidget {
  const new({required this.card});

  final PlannedCard card;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    final isTest = card.input.type == CardType.test;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: colors.surfaceVariant,
              borderRadius: BorderRadius.circular(AppRadii.control),
            ),
            child: Icon(
              isTest ? Icons.check_rounded : Icons.filter_none_rounded,
              size: 20,
              color: colors.textMuted,
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DefaultTextStyle.merge(
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  child: FormattedText(
                    card.input.trimmedQuestion,
                    style: text.titleMedium,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  isTest ? l10n.cardTypeTest : l10n.cardTypeSimple,
                  style: text.bodyMedium?.copyWith(color: colors.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          SizedBox(
            width: 96,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(l10n.importNewBadge, style: text.titleSmall),
                const SizedBox(height: AppSpacing.sm),
                // The empty bar of a card never studied, as in the design.
                Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: colors.surfaceVariant,
                    borderRadius: BorderRadius.circular(AppRadii.chip),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The reason a file cannot be imported, under the button of step 1.
class _ErrorBox extends StatelessWidget {
  const new({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      key: const Key('import.error'),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        border: Border.all(color: colors.error),
        borderRadius: BorderRadius.circular(AppRadii.control),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline_rounded, color: colors.error),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: colors.text),
            ),
          ),
        ],
      ),
    );
  }
}
