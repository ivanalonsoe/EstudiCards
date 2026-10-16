import 'package:estudicards/app/l10n/generated/app_localizations.dart';
import 'package:estudicards/app/layout/breakpoints.dart';
import 'package:estudicards/app/router.dart';
import 'package:estudicards/app/theme/app_colors.dart';
import 'package:estudicards/app/theme/dimensions.dart';
import 'package:estudicards/features/decks/domain/deck.dart';
import 'package:estudicards/features/decks/domain/deck_summary.dart';
import 'package:estudicards/features/decks/presentation/deck_providers.dart';
import 'package:estudicards/features/projects/domain/project.dart';
import 'package:estudicards/features/projects/presentation/project_labels.dart';
import 'package:estudicards/features/projects/presentation/project_providers.dart';
import 'package:estudicards/features/study/domain/card_selection.dart';
import 'package:estudicards/features/study/domain/session_config.dart';
import 'package:estudicards/features/study/domain/session_setup.dart';
import 'package:estudicards/features/study/domain/session_state.dart';
import 'package:estudicards/features/study/domain/study_options.dart';
import 'package:estudicards/features/study/presentation/session_launch.dart';
import 'package:estudicards/features/study/presentation/study_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// P08: the session setup (`docs/design/movil-claro/configurar.png`,
/// `escritorio-claro/configurar.png`, US-14). It opens with the project's
/// last configuration; opened from a deck ([deckId]), only that deck is
/// chosen, and from "Repasar errores" ([reviewErrors]) it starts in "Solo
/// errores" (US-21).
class SessionSetupScreen extends ConsumerWidget {
  const new({
    required this.projectId,
    this.deckId,
    this.reviewErrors = false,
    super.key,
  });

  final String projectId;
  final String? deckId;
  final bool reviewErrors;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final project = ref.watch(projectProvider(projectId));
    final decks = ref.watch(deckSummariesProvider(projectId));
    final data = ref.watch(sessionSetupDataProvider(projectId));
    if (project.hasError || decks.hasError || data.hasError) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(AppLocalizations.of(context).loadError)),
      );
    }
    final loadedProject = project.value;
    final loadedDecks = decks.value;
    final loadedData = data.value;
    if (loadedDecks == null || loadedData == null) return const Scaffold();
    if (loadedProject == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(AppLocalizations.of(context).projectNotFound)),
      );
    }
    return _SetupForm(
      project: loadedProject,
      decks: loadedDecks,
      candidates: loadedData.candidates,
      lastConfig: loadedData.lastConfig,
      deckId: deckId,
      reviewErrors: reviewErrors,
    );
  }
}

/// The form itself, once everything is loaded. It keeps the choices in a
/// [SetupForm] and shows them on mobile or desktop.
class _SetupForm extends ConsumerStatefulWidget {
  const new({
    required this.project,
    required this.decks,
    required this.candidates,
    required this.lastConfig,
    required this.deckId,
    required this.reviewErrors,
  });

  final Project project;
  final List<DeckSummary> decks;
  final List<StudyCandidate> candidates;
  final SessionConfig? lastConfig;
  final String? deckId;
  final bool reviewErrors;

  @override
  ConsumerState<_SetupForm> createState() => _SetupFormState();
}

class _SetupFormState extends ConsumerState<_SetupForm> {
  late SetupForm _form = _initialForm();

  SetupForm _initialForm() {
    final form = SetupForm.initial(
      decks: _decks,
      last: widget.lastConfig,
      deckId: widget.deckId,
    );
    return widget.reviewErrors ? form.forErrorReview(widget.candidates) : form;
  }

  bool _starting = false;

  List<Deck> get _decks => [for (final summary in widget.decks) summary.deck];

  void _update(SetupForm form) => setState(() => _form = form);

  Future<void> _start() async {
    setState(() => _starting = true);
    final sessionId = await launchSession(
      ref,
      widget.project.id,
      _form.toConfig(_decks),
    );
    if (mounted) context.go(AppRoutes.session(sessionId));
  }

  @override
  Widget build(BuildContext context) {
    final available = _form.availableCount(widget.candidates);
    final view = _SetupView(
      project: widget.project,
      decks: widget.decks,
      form: _form,
      available: available,
      errorsCount: _form
          .copyWith(mode: StudyMode.errors)
          .availableCount(widget.candidates),
      onChanged: _update,
      onStart: available > 0 && !_starting ? _start : null,
    );
    final isDesktop =
        FormFactor.fromWidth(MediaQuery.sizeOf(context).width) ==
        FormFactor.desktop;
    return isDesktop ? _DesktopSetup(view) : _MobileSetup(view);
  }
}

/// What both layouts show.
class _SetupView {
  const new({
    required this.project,
    required this.decks,
    required this.form,
    required this.available,
    required this.errorsCount,
    required this.onChanged,
    required this.onStart,
  });

  final Project project;
  final List<DeckSummary> decks;
  final SetupForm form;

  /// The cards the session can use with these choices (US-14 AC2).
  final int available;

  /// The cards in errors in the chosen decks, for "Solo errores (9)".
  final int errorsCount;
  final ValueChanged<SetupForm> onChanged;

  /// Null while it cannot start: no card available, or already starting.
  final VoidCallback? onStart;

  List<Deck> get deckList => [for (final summary in decks) summary.deck];

  /// How many cards the session will use.
  int get used {
    final count = form.count;
    return count == null || count > available ? available : count;
  }

  /// "136 tarjetas disponibles · se usarán 20", or "se usarán todas" when
  /// fewer are available than asked for (US-14 AC3).
  String availableText(AppLocalizations l10n) {
    if (available == 0) return l10n.noCardsAvailable;
    final usesAll = used == available;
    return [
      l10n.availableCards(available),
      if (usesAll) l10n.willUseAll else l10n.willUseCount(used),
    ].join(l10n.detailsSeparator);
  }

  /// The labels of the two directions: the language pair when the chosen
  /// language decks share it, "Normal" and "Inverso" otherwise.
  (String, String) directionLabels(AppLocalizations l10n) {
    final pair = form.languagePair(deckList);
    if (pair == null) return (l10n.directionNormal, l10n.directionReverse);
    final source = languageName(l10n, pair.source);
    final target = languageName(l10n, pair.target);
    return (
      l10n.languagePair(source, target),
      l10n.languagePair(target, source),
    );
  }
}

/// Mobile and tablet: the sections in one column, with the available cards
/// and "Empezar" fixed at the bottom.
class _MobileSetup extends StatelessWidget {
  const new(this.view);

  final _SetupView view;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.newSession)),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          // A short form: every section is built at once, unlike a
          // ListView, which builds only what is on screen.
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.xl,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _DecksSection(view: view, withCounts: false),
                const SizedBox(height: AppSpacing.xl),
                _CountSection(view: view),
                const SizedBox(height: AppSpacing.xl),
                _ModeSection(view: view, withCount: false),
                if (view.form.hasLanguageDeck(view.deckList)) ...[
                  const SizedBox(height: AppSpacing.xl),
                  _DirectionSection(view: view),
                ],
                const SizedBox(height: AppSpacing.xl),
                _OrderSwitches(view: view),
                const SizedBox(height: AppSpacing.xl),
                _TimerSection(view: view),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.background,
          border: Border(top: BorderSide(color: colors.border)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _AvailableLine(view: view),
                const SizedBox(height: AppSpacing.md),
                _StartButton(view: view),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Desktop: breadcrumb and title, the sections in two columns, and the
/// summary with "Empezar" on the right.
class _DesktopSetup extends StatelessWidget {
  const new(this.view);

  final _SetupView view;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final showsDirection = view.form.hasLanguageDeck(view.deckList);
    Widget pair(Widget left, Widget right) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: left),
        const SizedBox(width: AppSpacing.xl),
        Expanded(child: right),
      ],
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
            _Breadcrumb(project: view.project),
            const SizedBox(height: AppSpacing.xl),
            Text(
              l10n.newStudySession,
              style: Theme.of(context).textTheme.displaySmall,
            ),
            const SizedBox(height: AppSpacing.xl),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _DecksSection(view: view, withCounts: true),
                      const SizedBox(height: AppSpacing.xl),
                      pair(
                        _CountSection(view: view),
                        _ModeSection(view: view, withCount: true),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      pair(
                        showsDirection
                            ? _DirectionSection(view: view)
                            : const SizedBox.shrink(),
                        _Section(
                          title: l10n.setupOrder,
                          child: _OrderSwitches(view: view),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      _TimerSection(view: view),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.xxl),
                Expanded(flex: 2, child: _Summary(view: view)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// "Inicio › Inglés B2 › Nueva sesión" above the desktop title.
class _Breadcrumb extends StatelessWidget {
  const new({required this.project});

  final Project project;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final style = Theme.of(context).textTheme.labelLarge;
    Widget link(String label, String location) => InkWell(
      onTap: () => context.go(location),
      borderRadius: BorderRadius.circular(AppSpacing.xs),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xs),
        child: Text(label, style: style?.copyWith(color: colors.textMuted)),
      ),
    );
    final separator = Icon(
      Icons.chevron_right_rounded,
      size: 18,
      color: colors.textMuted,
    );
    return Row(
      children: [
        link(l10n.home, AppRoutes.home),
        separator,
        Flexible(child: link(project.name, AppRoutes.project(project.id))),
        separator,
        const SizedBox(width: AppSpacing.xs),
        Text(l10n.newSession, style: style),
      ],
    );
  }
}

/// A titled block of the form, e.g. "Modo" and its choices.
class _Section extends StatelessWidget {
  const new({required this.title, required this.child, this.trailing});

  final String title;
  final Widget child;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final trailing = this.trailing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            if (trailing != null)
              Text(
                trailing,
                style: text.labelLarge?.copyWith(
                  color: AppColors.of(context).textMuted,
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        child,
      ],
    );
  }
}

/// "Barajas": "Todo el proyecto" and one chip per deck. On desktop each
/// chip also shows its number of cards.
class _DecksSection extends StatelessWidget {
  const new({required this.view, required this.withCounts});

  final _SetupView view;
  final bool withCounts;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final form = view.form;
    final allIds = [for (final deck in view.deckList) deck.id];
    final allChosen = allIds.isNotEmpty && allIds.every(form.deckIds.contains);
    return _Section(
      title: l10n.decks,
      trailing: l10n.setupDecksChosen(form.deckIds.length, allIds.length),
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          _Chip(
            chipKey: const Key('sessionSetup.allDecks'),
            label: l10n.allDecks,
            selected: allChosen,
            onTap: () => view.onChanged(form.copyWith(deckIds: allIds)),
          ),
          for (final summary in view.decks)
            _Chip(
              chipKey: Key('sessionSetup.deck.${summary.deck.id}'),
              label: withCounts
                  ? l10n.deckWithCount(summary.deck.name, summary.cardCount)
                  : summary.deck.name,
              selected: form.deckIds.contains(summary.deck.id),
              onTap: () {
                final id = summary.deck.id;
                view.onChanged(
                  form.copyWith(
                    deckIds: form.deckIds.contains(id)
                        ? [...form.deckIds.where((other) => other != id)]
                        : [...form.deckIds, id],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

/// A deck chip: orange with a tick when chosen, as in the design.
class _Chip extends StatelessWidget {
  const new({
    required this.chipKey,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  /// The key of the [FilterChip] itself, so tests can read `selected`.
  final Key chipKey;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return FilterChip(
      key: chipKey,
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      showCheckmark: true,
      checkmarkColor: colors.primaryStrong,
      backgroundColor: colors.surface,
      selectedColor: colors.primarySoft,
      labelStyle: Theme.of(context).textTheme.labelLarge
          ?.copyWith(color: selected ? colors.primaryStrong : colors.text),
      side: BorderSide(color: selected ? colors.primaryStrong : colors.border),
      shape: const StadiumBorder(),
    );
  }
}

/// The grey track with the chosen option in white, as in the design.
class _Segmented<T> extends StatelessWidget {
  const new({
    required this.buttonKey,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  /// The key of the [SegmentedButton] itself, so tests can read `selected`.
  final Key buttonKey;

  /// Each option's value, label and key.
  final List<(T, String, Key)> options;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return SegmentedButton<T>(
      key: buttonKey,
      segments: [
        for (final (value, label, key) in options)
          ButtonSegment(
            value: value,
            // Long pairs ("Inglés (R. U.) → Español") take two lines.
            label: Text(
              label,
              key: key,
              maxLines: 2,
              textAlign: TextAlign.center,
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
        // Less padding than the default, so "Todas" fits in five segments.
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs,
          vertical: AppSpacing.sm,
        ),
      ),
      onSelectionChanged: (selection) => onChanged(selection.single),
    );
  }
}

/// "Número de tarjetas": 10, 20, 50, "Todas" or "Otro" with its − / + row.
class _CountSection extends StatelessWidget {
  const new({required this.view});

  final _SetupView view;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final form = view.form;
    final count = form.count;
    final selected = form.customCount
        ? 'custom'
        : count == null
        ? 'all'
        : '$count';
    // "Otro" goes from 1 to the available cards.
    final maxCount = view.available < 1 ? 1 : view.available;
    return _Section(
      title: l10n.setupCount,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Segmented<String>(
            buttonKey: const Key('sessionSetup.count'),
            options: [
              for (final preset in presetCounts)
                ('$preset', '$preset', Key('sessionSetup.count.$preset')),
              ('all', l10n.countAll, const Key('sessionSetup.count.all')),
              (
                'custom',
                l10n.countCustom,
                const Key('sessionSetup.count.custom'),
              ),
            ],
            selected: selected,
            onChanged: (choice) => view.onChanged(switch (choice) {
              'all' => form.withCount(null),
              'custom' => form.withCount(
                (count ?? maxCount).clamp(1, maxCount),
                custom: true,
              ),
              _ => form.withCount(int.parse(choice)),
            }),
          ),
          if (form.customCount && count != null) ...[
            const SizedBox(height: AppSpacing.md),
            _Stepper(
              key: const Key('sessionSetup.customCount'),
              keyPrefix: 'sessionSetup.customCount',
              label: l10n.customCountLabel,
              value: '$count',
              onDecrease: count > 1
                  ? () =>
                        view.onChanged(form.withCount(count - 1, custom: true))
                  : null,
              onIncrease: count < maxCount
                  ? () =>
                        view.onChanged(form.withCount(count + 1, custom: true))
                  : null,
            ),
          ],
        ],
      ),
    );
  }
}

/// "Modo": Normal / Solo errores. On desktop "Solo errores (9)".
class _ModeSection extends StatelessWidget {
  const new({required this.view, required this.withCount});

  final _SetupView view;
  final bool withCount;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _Section(
      title: l10n.setupMode,
      child: _Segmented<StudyMode>(
        buttonKey: const Key('sessionSetup.mode'),
        options: [
          (
            StudyMode.normal,
            l10n.modeNormal,
            const Key('sessionSetup.mode.normal'),
          ),
          (
            StudyMode.errors,
            withCount
                ? l10n.modeErrorsCount(view.errorsCount)
                : l10n.modeErrors,
            const Key('sessionSetup.mode.errors'),
          ),
        ],
        selected: view.form.mode,
        onChanged: (mode) => view.onChanged(view.form.copyWith(mode: mode)),
      ),
    );
  }
}

/// "Sentido", only when a chosen deck is a language deck (R 7.3).
class _DirectionSection extends StatelessWidget {
  const new({required this.view});

  final _SetupView view;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final (normal, reverse) = view.directionLabels(l10n);
    return _Section(
      title: l10n.setupDirection,
      child: _Segmented<StudyDirection>(
        buttonKey: const Key('sessionSetup.direction'),
        options: [
          (
            StudyDirection.normal,
            normal,
            const Key('sessionSetup.direction.normal'),
          ),
          (
            StudyDirection.reverse,
            reverse,
            const Key('sessionSetup.direction.reverse'),
          ),
        ],
        selected: view.form.direction,
        onChanged: (direction) =>
            view.onChanged(view.form.copyWith(direction: direction)),
      ),
    );
  }
}

/// "Priorizar las más falladas" and "Repetir falladas al final".
class _OrderSwitches extends StatelessWidget {
  const new({required this.view});

  final _SetupView view;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final form = view.form;
    return Card(
      child: Column(
        children: [
          _SwitchRow(
            switchKey: const Key('sessionSetup.prioritize'),
            label: l10n.prioritizeFailed,
            value: form.prioritizeFailed,
            onChanged: (value) =>
                view.onChanged(form.copyWith(prioritizeFailed: value)),
          ),
          Divider(
            height: 1,
            indent: AppSpacing.lg,
            endIndent: AppSpacing.lg,
            color: AppColors.of(context).border,
          ),
          _SwitchRow(
            switchKey: const Key('sessionSetup.repeat'),
            label: l10n.repeatFailed,
            value: form.repeatFailed,
            onChanged: (value) =>
                view.onChanged(form.copyWith(repeatFailed: value)),
          ),
        ],
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const new({
    required this.switchKey,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final Key switchKey;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            Switch(key: switchKey, value: value, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}

/// "Temporizador": none, per question (5–120 s) or global (1–120 min),
/// with the value of the chosen one (R 7.5).
class _TimerSection extends StatelessWidget {
  const new({required this.view});

  final _SetupView view;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final form = view.form;
    final choice = _Segmented<TimerType>(
      buttonKey: const Key('sessionSetup.timer'),
      options: [
        (TimerType.none, l10n.timerNone, const Key('sessionSetup.timer.none')),
        (
          TimerType.perCard,
          l10n.timerPerQuestion,
          const Key('sessionSetup.timer.perCard'),
        ),
        (
          TimerType.global,
          l10n.timerGlobal,
          const Key('sessionSetup.timer.global'),
        ),
      ],
      selected: form.timerType,
      onChanged: (type) => view.onChanged(form.copyWith(timerType: type)),
    );
    final value = switch (form.timerType) {
      TimerType.none => null,
      TimerType.perCard => _Stepper(
        key: const Key('sessionSetup.timerValue'),
        keyPrefix: 'sessionSetup.timerValue',
        label: l10n.questionTime,
        value: l10n.secondsShort(form.questionSeconds),
        onDecrease: form.questionSeconds > 5
            ? () => view.onChanged(
                form.copyWith(
                  questionSeconds: previousQuestionSeconds(
                    form.questionSeconds,
                  ),
                ),
              )
            : null,
        onIncrease: form.questionSeconds < 120
            ? () => view.onChanged(
                form.copyWith(
                  questionSeconds: nextQuestionSeconds(form.questionSeconds),
                ),
              )
            : null,
      ),
      TimerType.global => _Stepper(
        key: const Key('sessionSetup.timerValue'),
        keyPrefix: 'sessionSetup.timerValue',
        label: l10n.sessionTime,
        value: l10n.minutesShort(form.sessionMinutes),
        onDecrease: form.sessionMinutes > 1
            ? () => view.onChanged(
                form.copyWith(
                  sessionMinutes: previousSessionMinutes(form.sessionMinutes),
                ),
              )
            : null,
        onIncrease: form.sessionMinutes < 120
            ? () => view.onChanged(
                form.copyWith(
                  sessionMinutes: nextSessionMinutes(form.sessionMinutes),
                ),
              )
            : null,
      ),
    };
    return _Section(
      title: l10n.setupTimer,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          choice,
          if (value != null) ...[const SizedBox(height: AppSpacing.md), value],
        ],
      ),
    );
  }
}

/// A label with "− value +", for the timer and "Otro". A button is
/// disabled (null) at its limit.
class _Stepper extends StatelessWidget {
  const new({
    required this.keyPrefix,
    required this.label,
    required this.value,
    required this.onDecrease,
    required this.onIncrease,
    super.key,
  });

  /// The buttons get the keys `<keyPrefix>.minus` and `<keyPrefix>.plus`.
  final String keyPrefix;
  final String label;
  final String value;
  final VoidCallback? onDecrease;
  final VoidCallback? onIncrease;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    final buttonStyle = IconButton.styleFrom(
      backgroundColor: colors.surfaceVariant,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.control),
      ),
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.sm,
          AppSpacing.sm,
        ),
        child: Row(
          children: [
            Expanded(child: Text(label, style: text.titleSmall)),
            IconButton(
              key: Key('$keyPrefix.minus'),
              tooltip: l10n.decrease,
              style: buttonStyle,
              onPressed: onDecrease,
              icon: const Icon(Icons.remove_rounded),
            ),
            SizedBox(
              width: 72,
              child: Text(
                value,
                textAlign: TextAlign.center,
                style: text.titleMedium,
              ),
            ),
            IconButton(
              key: Key('$keyPrefix.plus'),
              tooltip: l10n.increase,
              style: buttonStyle,
              onPressed: onIncrease,
              icon: const Icon(Icons.add_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

/// "136 tarjetas disponibles · se usarán 20".
class _AvailableLine extends StatelessWidget {
  const new({required this.view});

  final _SetupView view;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.filter_none_rounded, size: 18, color: colors.textMuted),
        const SizedBox(width: AppSpacing.sm),
        Flexible(
          child: Text(
            view.availableText(AppLocalizations.of(context)),
            key: const Key('sessionSetup.available'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelLarge
                ?.copyWith(color: colors.textMuted),
          ),
        ),
      ],
    );
  }
}

class _StartButton extends StatelessWidget {
  const new({required this.view});

  final _SetupView view;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      key: const Key('sessionSetup.start'),
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(minTouchTarget + AppSpacing.sm),
      ),
      onPressed: view.onStart,
      icon: const Icon(Icons.play_arrow_rounded),
      label: Text(AppLocalizations.of(context).startSession),
    );
  }
}

/// The desktop "Resumen": what the session will be, "Empezar" and a note
/// that the configuration is remembered for the project.
class _Summary extends StatelessWidget {
  const new({required this.view});

  final _SetupView view;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    final form = view.form;
    final chosenNames = [
      for (final deck in view.deckList)
        if (form.deckIds.contains(deck.id)) deck.name,
    ];
    final (normal, reverse) = view.directionLabels(l10n);
    final rows = [
      (l10n.decks, chosenNames.isEmpty ? '—' : chosenNames.join(', ')),
      (l10n.summaryCards, l10n.cardsOfAvailable(view.used, view.available)),
      if (form.hasLanguageDeck(view.deckList))
        (
          l10n.setupDirection,
          form.direction == StudyDirection.normal ? normal : reverse,
        ),
      (
        l10n.summaryTimer,
        switch (form.timerType) {
          TimerType.none => l10n.timerNone,
          TimerType.perCard => l10n.perQuestionSummary(form.questionSeconds),
          TimerType.global => l10n.globalSummary(form.sessionMinutes),
        },
      ),
      (
        l10n.setupOrder,
        form.prioritizeFailed ? l10n.orderPrioritized : l10n.orderRandom,
      ),
    ];
    return Card(
      key: const Key('sessionSetup.summary'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.summary, style: text.titleLarge),
            const SizedBox(height: AppSpacing.md),
            for (final (index, (label, value)) in rows.indexed) ...[
              if (index > 0) Divider(height: 1, color: colors.border),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: text.bodyMedium?.copyWith(color: colors.textMuted),
                    ),
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(
                      child: Text(
                        value,
                        textAlign: TextAlign.end,
                        style: text.titleSmall,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            _AvailableLine(view: view),
            const SizedBox(height: AppSpacing.md),
            _StartButton(view: view),
            const SizedBox(height: AppSpacing.md),
            Text(
              l10n.configRemembered(view.project.name),
              textAlign: TextAlign.center,
              style: text.bodySmall?.copyWith(color: colors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}
