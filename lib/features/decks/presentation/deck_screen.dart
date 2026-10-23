import 'dart:async';

import 'package:estudicards/app/l10n/generated/app_localizations.dart';
import 'package:estudicards/app/layout/breakpoints.dart';
import 'package:estudicards/app/router.dart';
import 'package:estudicards/app/theme/app_colors.dart';
import 'package:estudicards/app/theme/dimensions.dart';
import 'package:estudicards/app/theme/project_palette.dart';
import 'package:estudicards/core/providers.dart';
import 'package:estudicards/core/widgets/breadcrumb.dart';
import 'package:estudicards/core/widgets/confirm_dialog.dart';
import 'package:estudicards/core/widgets/empty_state.dart';
import 'package:estudicards/core/widgets/pill_selector.dart';
import 'package:estudicards/features/cards/domain/card_list.dart';
import 'package:estudicards/features/cards/domain/card_transfer.dart';
import 'package:estudicards/features/cards/domain/flashcard.dart';
import 'package:estudicards/features/cards/domain/inline_format.dart';
import 'package:estudicards/features/cards/presentation/card_providers.dart';
import 'package:estudicards/features/cards/presentation/delete_cards.dart';
import 'package:estudicards/features/cards/presentation/formatted_text.dart';
import 'package:estudicards/features/decks/domain/deck.dart';
import 'package:estudicards/features/decks/domain/deck_summary.dart';
import 'package:estudicards/features/decks/domain/languages.dart';
import 'package:estudicards/features/decks/presentation/deck_form.dart';
import 'package:estudicards/features/decks/presentation/deck_picker.dart';
import 'package:estudicards/features/decks/presentation/deck_providers.dart';
import 'package:estudicards/features/import_export/presentation/share.dart';
import 'package:estudicards/features/projects/domain/project.dart';
import 'package:estudicards/features/projects/presentation/project_providers.dart';
import 'package:estudicards/features/stats/presentation/stats_texts.dart';
import 'package:estudicards/features/study/presentation/review_errors_button.dart';
import 'package:estudicards/features/trash/presentation/move_to_trash.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// P05: a deck with its cards (`docs/design/movil-claro/baraja.png`,
/// `escritorio-claro/baraja.png`): a list on mobile and a table on desktop,
/// with search and sorting (US-12).
///
/// "Repasar errores (N)" only shows with pending errors. Hidden until phase
/// 5 (SPEC §13.2, assumption 16): "Importar CSV", "Plantilla", "Prompt
/// para IA" and "Compartir".
class DeckScreen extends ConsumerStatefulWidget {
  const new({required this.projectId, required this.deckId, super.key});

  final String projectId;
  final String deckId;

  @override
  ConsumerState<DeckScreen> createState() => _DeckScreenState();
}

class _DeckScreenState extends ConsumerState<DeckScreen> {
  String _query = '';
  CardSort _sort = CardSort.newest;

  /// The IDs of the selected cards (US-07). Selecting starts with a long
  /// press on mobile and with the checkboxes on desktop.
  final _selected = <String>{};

  void _toggle(String id) => setState(() {
    if (!_selected.remove(id)) _selected.add(id);
  });

  /// "Copiar a…" / "Mover a…": picks another deck of the project, of either
  /// type (US-07 AC2), and copies or moves the cards there.
  Future<void> _transfer(List<String> ids, {required bool move}) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final repository = ref.read(cardsRepositoryProvider);
    final decks = [
      for (final summary
          in ref.read(deckSummariesProvider(widget.projectId)).value ??
              const <DeckSummary>[])
        summary.deck,
    ];
    final from = decks.firstWhere((deck) => deck.id == widget.deckId);
    final target = await showDeckPicker(
      context,
      title: move ? l10n.moveTo : l10n.copyTo,
      decks: [
        for (final deck in decks)
          if (deck.id != widget.deckId) deck,
      ],
    );
    if (target == null || !mounted) return;

    // A deck of another type or with other languages shows the cards
    // differently: say how before doing it (US-07 AC4).
    final cards = [
      for (final summary
          in ref.read(deckCardsProvider(widget.deckId)).value ??
              const <CardSummary>[])
        if (ids.contains(summary.card.id)) summary.card,
    ];
    final warning = transferWarning(from: from, to: target, cards: cards);
    if (warning != null) {
      final confirmed = await showConfirmDialog(
        context,
        title: move
            ? l10n.moveCardsTitle(ids.length, target.name)
            : l10n.copyCardsTitle(ids.length, target.name),
        body: _warningText(l10n, warning),
        confirmLabel: move ? l10n.move : l10n.copy,
        icon: Icons.info_outline_rounded,
        destructive: false,
      );
      if (!confirmed) return;
    }
    if (move) {
      await repository.moveCards(ids, target.id);
    } else {
      await repository.copyCards(ids, target.id);
    }
    if (mounted) setState(() => _selected.removeAll(ids));
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            move
                ? l10n.cardsMoved(ids.length, target.name)
                : l10n.cardsCopied(ids.length, target.name),
          ),
        ),
      );
  }

  /// "Eliminar": asks, hides the cards and offers "Deshacer" (US-11 AC2).
  Future<void> _delete(List<String> ids) => confirmDeleteCards(
    context,
    ref,
    ids,
    afterConfirm: () {
      if (mounted) setState(() => _selected.removeAll(ids));
    },
  );

  @override
  Widget build(BuildContext context) {
    final project = ref.watch(projectProvider(widget.projectId));
    // The project's deck list is watched, so the screen follows edits to
    // the deck (name, colour, type) and notices when it goes to the trash.
    final decks = ref.watch(deckSummariesProvider(widget.projectId));
    final cards = ref.watch(deckCardsProvider(widget.deckId));
    // Cards waiting for their "Deshacer" to run out are hidden.
    final pending = ref.watch(pendingCardDeletionsProvider);

    if (project.hasError || decks.hasError || cards.hasError) {
      return Scaffold(
        appBar: AppBar(),
        body: LoadErrorState(
          onRetry: () => ref
            ..invalidate(projectProvider(widget.projectId))
            ..invalidate(deckSummariesProvider(widget.projectId))
            ..invalidate(deckCardsProvider(widget.deckId)),
        ),
      );
    }
    if (!project.hasValue || !decks.hasValue || !cards.hasValue) {
      return const Scaffold();
    }
    final loadedProject = project.value;
    final deckSummary = [
      for (final summary in decks.value!)
        if (summary.deck.id == widget.deckId) summary,
    ].firstOrNull;
    final deck = deckSummary?.deck;
    if (loadedProject == null || deckSummary == null || deck == null) {
      return const _DeckNotFound();
    }

    final all = [
      for (final summary in cards.value!)
        if (!pending.contains(summary.card.id)) summary,
    ];
    final shown = sortCards(
      all.where((s) => matchesCardSearch(s.card, _query)),
      _sort,
    );
    // Cards that left the deck (moved, deleted) are no longer selected.
    _selected.retainAll({for (final summary in all) summary.card.id});
    final view = _DeckView(
      project: loadedProject,
      deck: deck,
      errorCount: deckSummary.errorCount,
      allCards: all,
      shownCards: shown,
      query: _query,
      sort: _sort,
      selected: _selected,
      onQueryChanged: (query) => setState(() => _query = query),
      onSortChanged: (sort) => setState(() => _sort = sort),
      onToggle: _toggle,
      onSelectShown: (select) => setState(() {
        final ids = [for (final summary in shown) summary.card.id];
        select ? _selected.addAll(ids) : _selected.removeAll(ids);
      }),
      onClearSelection: () => setState(_selected.clear),
      onCopy: (ids) => unawaited(_transfer(ids, move: false)),
      onMove: (ids) => unawaited(_transfer(ids, move: true)),
      onDelete: (ids) => unawaited(_delete(ids)),
    );
    final isDesktop =
        FormFactor.fromWidth(MediaQuery.sizeOf(context).width) ==
        FormFactor.desktop;
    return isDesktop ? _DesktopDeck(view) : _MobileDeck(view);
  }
}

/// What both layouts show.
class _DeckView {
  const new({
    required this.project,
    required this.deck,
    required this.errorCount,
    required this.allCards,
    required this.shownCards,
    required this.query,
    required this.sort,
    required this.selected,
    required this.onQueryChanged,
    required this.onSortChanged,
    required this.onToggle,
    required this.onSelectShown,
    required this.onClearSelection,
    required this.onCopy,
    required this.onMove,
    required this.onDelete,
  });

  final Project project;
  final Deck deck;

  /// Pending errors of the deck: (card, direction) pairs (R 7.6).
  final int errorCount;

  /// Every card of the deck, for the counts in the header.
  final List<CardSummary> allCards;

  /// The cards that match the search, in the chosen order.
  final List<CardSummary> shownCards;
  final String query;
  final CardSort sort;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<CardSort> onSortChanged;

  /// The IDs of the selected cards.
  final Set<String> selected;
  final ValueChanged<String> onToggle;

  /// Selects (true) or unselects (false) every card shown.
  final ValueChanged<bool> onSelectShown;
  final VoidCallback onClearSelection;

  /// The actions on some cards: the selection, or one card from its menu.
  final ValueChanged<List<String>> onCopy;
  final ValueChanged<List<String>> onMove;
  final ValueChanged<List<String>> onDelete;

  bool get isSelecting => selected.isNotEmpty;

  /// Taps a card: opens it, or selects it while selecting.
  void tapCard(BuildContext context, Flashcard card) =>
      isSelecting ? onToggle(card.id) : openCard(context, card);

  /// "EN → ES", only for a language deck with both languages.
  String? languagePair(AppLocalizations l10n) {
    final source = deck.sourceLang;
    final target = deck.targetLang;
    if (!deck.isLanguage || source == null || target == null) return null;
    return l10n.languagePair(
      shortLanguageCode(source),
      shortLanguageCode(target),
    );
  }

  /// "3 tarjetas · 74% aciertos". The % adds up every card's answers.
  List<String> counts(AppLocalizations l10n) => [
    l10n.cardCount(allCards.length),
    l10n.correctRate(rateText(l10n, combinedCorrectRate(allCards))),
  ];

  void openCard(BuildContext context, Flashcard card) =>
      context.go(AppRoutes.editCard(project.id, deck.id, card.id));

  void addCard(BuildContext context) =>
      context.go(AppRoutes.newCard(project.id, deck.id));

  /// Opens the import wizard to add cards to this deck (US-27).
  void importCards(BuildContext context) =>
      context.go(AppRoutes.importCards(projectId: project.id, deckId: deck.id));
}

/// The explanation of a [TransferWarning], with the pairs in short form
/// ("EN → ES").
String _warningText(AppLocalizations l10n, TransferWarning warning) {
  String pair(String? source, String? target) => l10n.languagePair(
    source == null ? '?' : shortLanguageCode(source),
    target == null ? '?' : shortLanguageCode(target),
  );
  return switch (warning) {
    ToGeneralDeck(:final cardsWithLanguageFields) => l10n.transferToGeneral(
      cardsWithLanguageFields,
    ),
    ToLanguageDeck(:final sourceLang, :final targetLang) =>
      l10n.transferToLanguage(pair(sourceLang, targetLang)),
    LanguagesChange() => l10n.transferLanguagesChange(
      pair(warning.fromSourceLang, warning.fromTargetLang),
      pair(warning.toSourceLang, warning.toTargetLang),
    ),
  };
}

/// Mobile and tablet: the deck's details, "Añadir tarjeta", the search and
/// the list.
class _MobileDeck extends StatelessWidget {
  const new(this.view);

  final _DeckView view;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(view.deck.name),
        actions: [
          _DeckMenu(view: view),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
      floatingActionButton: view.isSelecting
          ? _SelectionBar(view: view, compact: true)
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          // On tablets the list keeps a comfortable reading width.
          constraints: const BoxConstraints(maxWidth: 640),
          // A `CustomScrollView` joins several scrolling pieces ("slivers")
          // in one scroll: the deck's details, then the cards. The cards are
          // a `SliverList.builder`, which only builds the ones on screen, so
          // a deck with 5,000 cards opens as fast as one with 5 (T6.5).
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                // While selecting, room for the selection bar below the
                // list.
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  0,
                  AppSpacing.lg,
                  view.isSelecting ? 120 : AppSpacing.xxxl,
                ),
                sliver: SliverMainAxisGroup(
                  slivers: [
                    SliverToBoxAdapter(child: _MobileHeader(view: view)),
                    if (view.shownCards.isNotEmpty)
                      SliverList.builder(
                        itemCount: view.shownCards.length,
                        itemBuilder: (context, index) => Column(
                          children: [
                            _CardTile(
                              view: view,
                              summary: view.shownCards[index],
                            ),
                            Divider(height: 1, color: colors.border),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Everything above the cards in the mobile deck: the details, the buttons,
/// the search and sorting, or the empty state.
class _MobileHeader extends StatelessWidget {
  const new({required this.view});

  final _DeckView view;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final details = [
      view.project.name,
      ?view.languagePair(l10n),
      ...view.counts(l10n),
    ].join(l10n.detailsSeparator);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            _ColorDot(colorKey: view.deck.color),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                details,
                style: Theme.of(context).textTheme.titleSmall
                    ?.copyWith(color: colors.textMuted),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                key: const Key('deckScreen.addCard'),
                onPressed: () => view.addCard(context),
                icon: const Icon(Icons.add_rounded),
                label: Text(l10n.addCard),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: _StudyButton(view: view)),
          ],
        ),
        if (view.errorCount > 0) ...[
          const SizedBox(height: AppSpacing.md),
          _ReviewErrors(view: view, expanded: true),
        ],
        const SizedBox(height: AppSpacing.md),
        // The file actions in a row that scrolls sideways, as in the
        // design.
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _ImportButton(view: view),
              const SizedBox(width: AppSpacing.sm),
              const _TemplateButton(),
              const SizedBox(width: AppSpacing.sm),
              _AiPromptButton(deck: view.deck),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        if (view.allCards.isEmpty)
          _EmptyDeck(view: view)
        else ...[
          Row(
            children: [
              Expanded(
                child: _SearchField(view: view, hint: l10n.searchCards),
              ),
              const SizedBox(width: AppSpacing.sm),
              _SortMenu(view: view),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (view.shownCards.isEmpty) _NoResults(query: view.query),
        ],
      ],
    );
  }
}

/// Desktop: breadcrumb, header with the actions, and the cards in a table.
class _DesktopDeck extends StatelessWidget {
  const new(this.view);

  final _DeckView view;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: view.isSelecting
          ? _SelectionBar(view: view, compact: false)
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      // The header, then the table, which only builds the rows on screen
      // (see `_MobileDeck`).
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              40,
              AppSpacing.xl,
              40,
              view.isSelecting ? 120 : AppSpacing.xl,
            ),
            sliver: SliverMainAxisGroup(
              slivers: [
                SliverToBoxAdapter(child: _DesktopHeader(view: view)),
                if (view.shownCards.isNotEmpty) _CardTable(view: view),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Everything above the table in the desktop deck: breadcrumb, title,
/// actions and toolbar, or the empty state.
class _DesktopHeader extends StatelessWidget {
  const new({required this.view});

  final _DeckView view;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    final details = [
      ?view.languagePair(l10n),
      ...view.counts(l10n),
      if (view.errorCount > 0) l10n.pendingErrors(view.errorCount),
    ].join(l10n.detailsSeparator);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Breadcrumb(view: view),
        const SizedBox(height: AppSpacing.xl),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(view.deck.name, style: text.displaySmall),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    details,
                    style: text.titleSmall?.copyWith(color: colors.textMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.lg),
            // The file actions next to the title, as in the design. In a
            // narrow window they go onto more lines instead of overflowing.
            Flexible(
              flex: 3,
              child: Wrap(
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  _ImportButton(view: view),
                  const _TemplateButton(),
                  _AiPromptButton(deck: view.deck),
                  _ShareButton(view: view),
                  _DeckMenu(view: view),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        _Toolbar(view: view),
        const SizedBox(height: AppSpacing.lg),
        if (view.allCards.isEmpty)
          _EmptyDeck(view: view)
        else if (view.shownCards.isEmpty)
          _NoResults(query: view.query),
      ],
    );
  }
}

/// The desktop search, the three orders, "Repasar errores", "Estudiar" and
/// "Añadir tarjeta" in one row, as in the design; in a narrow window the
/// search gets its own row and the rest wrap below it.
class _Toolbar extends StatelessWidget {
  const new({required this.view});

  final _DeckView view;

  /// The width from which everything fits in one row; "Repasar errores"
  /// needs more.
  double get _oneRowWidth => view.errorCount > 0 ? 1080 : 880;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final actions = [
      if (view.errorCount > 0) _ReviewErrors(view: view),
      _StudyButton(view: view),
      FilledButton.icon(
        key: const Key('deckScreen.addCard'),
        onPressed: () => view.addCard(context),
        icon: const Icon(Icons.add_rounded),
        label: Text(l10n.addCard),
      ),
    ];
    Widget wrap(List<Widget> children) => Wrap(
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: children,
    );
    if (view.allCards.isEmpty) {
      return Align(alignment: Alignment.centerRight, child: wrap(actions));
    }
    final search = _SearchField(view: view, hint: l10n.searchCardsLong);
    return LayoutBuilder(
      builder: (context, constraints) {
        // The labels grow with the system text, and so does the width the
        // toolbar needs to fit in one row.
        final oneRow = MediaQuery.textScalerOf(context).scale(_oneRowWidth);
        if (constraints.maxWidth >= oneRow) {
          // The search takes 30% of the row, enough for its whole hint as
          // in the design; "Repasar errores" takes two lines when it is
          // long, and if the buttons still do not fit they wrap instead of
          // overflowing.
          final searchWidth = (constraints.maxWidth * 0.3).clamp(240.0, 360.0);
          return Row(
            children: [
              SizedBox(width: searchWidth, child: search),
              const SizedBox(width: AppSpacing.md),
              _SortSelector(view: view),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: wrap([
                    for (final action in actions)
                      if (action is _ReviewErrors)
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 160),
                          child: action,
                        )
                      else
                        action,
                  ]),
                ),
              ),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            search,
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _SortSelector(view: view),
                ...actions,
              ],
            ),
          ],
        );
      },
    );
  }
}

/// "Estudiar": opens the session setup (P08) with only this deck chosen.
class _StudyButton extends StatelessWidget {
  const new({required this.view});

  final _DeckView view;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      key: const Key('deckScreen.study'),
      onPressed: () => context.go(
        AppRoutes.sessionSetup(view.project.id, deckId: view.deck.id),
      ),
      icon: const Icon(Icons.play_arrow_outlined),
      label: Text(AppLocalizations.of(context).study),
    );
  }
}

/// "Repasar errores (N)" for this deck only (US-21); shown only with
/// errors.
class _ReviewErrors extends StatelessWidget {
  const new({required this.view, this.expanded = false});

  final _DeckView view;
  final bool expanded;

  @override
  Widget build(BuildContext context) => ReviewErrorsButton(
    key: const Key('deckScreen.reviewErrors'),
    projectId: view.project.id,
    deckId: view.deck.id,
    count: view.errorCount,
    expanded: expanded,
  );
}

/// "Inicio › Inglés B2 › Verbos irregulares" above the desktop header.
class _Breadcrumb extends StatelessWidget {
  const new({required this.view});

  final _DeckView view;

  @override
  Widget build(BuildContext context) => Breadcrumb([
    (
      label: AppLocalizations.of(context).home,
      location: AppRoutes.home,
      key: const Key('deckScreen.breadcrumbHome'),
    ),
    (
      label: view.project.name,
      location: AppRoutes.project(view.project.id),
      key: const Key('deckScreen.breadcrumbProject'),
    ),
    (label: view.deck.name, location: null, key: null),
  ]);
}

class _ColorDot extends StatelessWidget {
  const new({required this.colorKey});

  final String colorKey;

  @override
  Widget build(BuildContext context) => Container(
    width: 12,
    height: 12,
    decoration: BoxDecoration(
      color: ProjectColor.fromKey(colorKey)
          .resolve(Theme.of(context).brightness),
      shape: BoxShape.circle,
    ),
  );
}

/// The search box: filters as the user types (US-12 AC1).
class _SearchField extends StatelessWidget {
  const new({required this.view, required this.hint});

  final _DeckView view;
  final String hint;

  @override
  Widget build(BuildContext context) => TextField(
    key: const Key('deckScreen.search'),
    onChanged: view.onQueryChanged,
    decoration: InputDecoration(
      hintText: hint,
      prefixIcon: const Icon(Icons.search_rounded),
    ),
  );
}

String _sortLabel(AppLocalizations l10n, CardSort sort) => switch (sort) {
  CardSort.newest => l10n.sortNewest,
  CardSort.alphabetical => l10n.sortAlphabetical,
  CardSort.mostMissed => l10n.sortMostMissed,
};

/// Mobile: a button with the current order that opens the three orders.
class _SortMenu extends StatelessWidget {
  const new({required this.view});

  final _DeckView view;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PopupMenuButton<CardSort>(
      key: const Key('deckScreen.sort'),
      tooltip: l10n.sortCards,
      initialValue: view.sort,
      onSelected: view.onSortChanged,
      itemBuilder: (context) => [
        for (final sort in CardSort.values)
          PopupMenuItem(
            key: Key('deckScreen.sort.${sort.name}'),
            value: sort,
            child: Text(_sortLabel(l10n, sort)),
          ),
      ],
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.of(context).border),
          borderRadius: BorderRadius.circular(AppRadii.control),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _sortLabel(l10n, view.sort),
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const Icon(Icons.expand_more_rounded),
          ],
        ),
      ),
    );
  }
}

/// Desktop: "Recientes / A–Z / Más falladas" side by side.
class _SortSelector extends StatelessWidget {
  const new({required this.view});

  final _DeckView view;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // Each order as wide as its label, as in the design.
    return PillSelector<CardSort>(
      expand: false,
      options: [
        for (final sort in CardSort.values)
          (
            value: sort,
            label: _sortLabel(l10n, sort),
            key: Key('deckScreen.sort.${sort.name}'),
          ),
      ],
      selected: view.sort,
      onChanged: view.onSortChanged,
    );
  }
}

/// A card in the mobile list: type icon, question, type, and % correct with
/// its bar.
class _CardTile extends StatelessWidget {
  const new({required this.view, required this.summary});

  final _DeckView view;
  final CardSummary summary;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    final card = summary.card;
    final isSelected = view.selected.contains(card.id);
    return InkWell(
      key: Key('cardRow.${card.id}'),
      onTap: () => view.tapCard(context, card),
      // A long press starts selecting (US-07 AC1).
      onLongPress: () => view.onToggle(card.id),
      child: Ink(
        color: isSelected ? colors.primarySoft : null,
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
        child: Row(
          children: [
            if (view.isSelecting)
              SizedBox(
                width: minTouchTarget,
                child: Checkbox(
                  key: Key('cardRow.${card.id}.select'),
                  value: isSelected,
                  semanticLabel: AppLocalizations.of(context)
                      .selectCard(withoutFormatMarks(card.question)),
                  onChanged: (_) => view.onToggle(card.id),
                ),
              )
            else
              _TypeIcon(type: card.type),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Question(card: card, maxLines: 2),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    _typeLabel(l10n, card.type),
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
                  Text(
                    rateText(l10n, summary.correctRate),
                    style: text.titleSmall,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _RateBar(rate: summary.correctRate),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _typeLabel(AppLocalizations l10n, CardType type) => switch (type) {
  CardType.simple => l10n.cardTypeSimple,
  CardType.test => l10n.cardTypeTest,
};

IconData _typeIconData(CardType type) => switch (type) {
  CardType.simple => Icons.filter_none_rounded,
  CardType.test => Icons.check_rounded,
};

/// The grey square with the type icon of the mobile list.
class _TypeIcon extends StatelessWidget {
  const new({required this.type});

  final CardType type;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: colors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppRadii.control),
      ),
      child: Icon(_typeIconData(type), size: 20, color: colors.textMuted),
    );
  }
}

/// The question as it is studied: bold and italic applied, markers hidden.
class _Question extends StatelessWidget {
  const new({required this.card, required this.maxLines});

  final Flashcard card;
  final int maxLines;

  @override
  Widget build(BuildContext context) => DefaultTextStyle.merge(
    maxLines: maxLines,
    overflow: TextOverflow.ellipsis,
    child: FormattedText(
      card.question,
      style: Theme.of(context).textTheme.titleMedium,
    ),
  );
}

/// The small % correct bar: green from 70%, amber from 40% and red below;
/// empty with no answers. The number is always next to it, so the colour is
/// not the only cue.
class _RateBar extends StatelessWidget {
  const new({required this.rate});

  final double? rate;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final value = rate;
    final color = value == null
        ? colors.border
        : switch (RateLevel.of(value)) {
            RateLevel.good => colors.success,
            RateLevel.fair => colors.warning,
            RateLevel.poor => colors.error,
          };
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.chip),
      child: LinearProgressIndicator(
        value: value ?? 0,
        minHeight: 6,
        color: color,
        backgroundColor: colors.surfaceVariant,
      ),
    );
  }
}

/// The desktop table: question, type, correct, wrong, % correct and last
/// review, with a ⋮ menu per card.
class _CardTable extends ConsumerWidget {
  const new({required this.view});

  final _DeckView view;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final now = ref.watch(clockProvider).now();
    final header = Theme.of(context).textTheme.labelMedium
        ?.copyWith(color: colors.textMuted, letterSpacing: 0.6);
    Text heading(String label, {TextAlign? align}) =>
        Text(label.toUpperCase(), style: header, textAlign: align);
    final selectedShown = view.shownCards
        .where((s) => view.selected.contains(s.card.id))
        .length;

    const radius = Radius.circular(AppRadii.listCard);
    final shown = view.shownCards;

    // A narrow desktop window has no room for every column: the correct and
    // wrong counts and the last review go, the question and the % stay.
    // `SliverLayoutBuilder` is the `LayoutBuilder` of slivers.
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.crossAxisExtent < _fullTableWidth;
        // The look of a `Card` (background, border and rounded corners)
        // drawn behind a list that only builds the rows on screen.
        return DecoratedSliver(
          decoration: ShapeDecoration(
            color: colors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: const BorderRadius.all(radius),
              side: BorderSide(color: colors.border),
            ),
          ),
          sliver: SliverPadding(
            // The rows stay inside the border.
            padding: const EdgeInsets.all(1),
            sliver: SliverList.builder(
              itemCount: shown.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _TableRow(
                    compact: compact,
                    // All, none, or some (a dash) of the cards shown are
                    // selected.
                    select: Checkbox(
                      key: const Key('deckScreen.selectAll'),
                      tristate: true,
                      value: switch (selectedShown) {
                        0 => false,
                        _ when selectedShown == shown.length => true,
                        _ => null,
                      },
                      semanticLabel: l10n.selectAll,
                      onChanged: (_) =>
                          view.onSelectShown(selectedShown != shown.length),
                    ),
                    question: heading(l10n.columnQuestion),
                    type: heading(l10n.columnType),
                    correct: heading(l10n.columnCorrect, align: TextAlign.end),
                    wrong: heading(l10n.columnWrong, align: TextAlign.end),
                    rate: heading(l10n.columnRate),
                    review: heading(l10n.columnLastReview),
                    menu: const SizedBox.shrink(),
                  );
                }
                final row = Column(
                  children: [
                    Divider(height: 1, color: colors.border),
                    // A transparent `Material` of its own, so the tap ripple
                    // and the selected colour show above the background.
                    Material(
                      type: MaterialType.transparency,
                      child: _CardTableRow(
                        view: view,
                        summary: shown[index - 1],
                        now: now,
                        compact: compact,
                      ),
                    ),
                  ],
                );
                // The last row keeps the rounded corners of the table.
                return index == shown.length
                    ? ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          bottom: radius,
                        ),
                        child: row,
                      )
                    : row;
              },
            ),
          ),
        );
      },
    );
  }
}

/// The table width from which every column fits; narrower, the table is
/// compact.
const double _fullTableWidth = 860;

/// The column widths of the table, shared by the heading and every row.
class _TableRow extends StatelessWidget {
  const new({
    required this.compact,
    required this.select,
    required this.question,
    required this.type,
    required this.correct,
    required this.wrong,
    required this.rate,
    required this.review,
    required this.menu,
  });

  /// Without the correct, wrong and last review columns.
  final bool compact;
  final Widget select;
  final Widget question;
  final Widget type;
  final Widget correct;
  final Widget wrong;
  final Widget rate;
  final Widget review;
  final Widget menu;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.lg,
      vertical: AppSpacing.sm,
    ),
    child: Row(
      children: [
        // 48 dp wide, so the checkbox is easy to hit (brief §9).
        SizedBox(width: minTouchTarget, child: select),
        const SizedBox(width: AppSpacing.xs),
        Expanded(child: question),
        const SizedBox(width: AppSpacing.lg),
        SizedBox(width: 128, child: type),
        if (!compact) ...[
          SizedBox(width: 88, child: correct),
          SizedBox(width: 72, child: wrong),
        ],
        const SizedBox(width: AppSpacing.xl),
        SizedBox(width: 150, child: rate),
        if (!compact) ...[
          const SizedBox(width: AppSpacing.xl),
          SizedBox(width: 110, child: review),
        ],
        SizedBox(width: 48, child: menu),
      ],
    ),
  );
}

class _CardTableRow extends StatelessWidget {
  const new({
    required this.view,
    required this.summary,
    required this.now,
    required this.compact,
  });

  final _DeckView view;
  final CardSummary summary;
  final DateTime now;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    final card = summary.card;
    final isSelected = view.selected.contains(card.id);
    return InkWell(
      key: Key('cardRow.${card.id}'),
      onTap: () => view.tapCard(context, card),
      child: Ink(
        color: isSelected ? colors.primarySoft : null,
        child: _TableRow(
          compact: compact,
          select: Checkbox(
            key: Key('cardRow.${card.id}.select'),
            value: isSelected,
            semanticLabel: l10n.selectCard(withoutFormatMarks(card.question)),
            onChanged: (_) => view.onToggle(card.id),
          ),
          question: _Question(card: card, maxLines: 1),
          type: Align(
            alignment: Alignment.centerLeft,
            child: _TypeChip(type: card.type),
          ),
          correct: Text(
            '${summary.correctCount}',
            style: text.titleSmall,
            textAlign: TextAlign.end,
          ),
          wrong: Text(
            '${summary.wrongCount}',
            style: text.titleSmall,
            textAlign: TextAlign.end,
          ),
          rate: Row(
            children: [
              Expanded(child: _RateBar(rate: summary.correctRate)),
              const SizedBox(width: AppSpacing.md),
              // Room for "100%" on one line.
              SizedBox(
                width: 48,
                child: Text(
                  rateText(l10n, summary.correctRate),
                  style: text.titleSmall,
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
          review: Text(
            reviewedText(l10n, summary.lastReviewedAt, now),
            style: text.bodyMedium?.copyWith(color: colors.textMuted),
          ),
          menu: _CardMenu(view: view, card: card),
        ),
      ),
    );
  }
}

/// "Simple" or "Test" with its icon, in a grey chip.
class _TypeChip extends StatelessWidget {
  const new({required this.type});

  final CardType type;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final style = Theme.of(context).textTheme.labelMedium
        ?.copyWith(color: colors.textMuted);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: colors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppRadii.chip),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_typeIconData(type), size: 14, color: colors.textMuted),
          const SizedBox(width: AppSpacing.xs),
          Flexible(
            child: Text(
              _typeLabel(AppLocalizations.of(context), type),
              style: style,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// The ⋮ menu of a card in the table: the actions of the selection bar, for
/// this card only.
class _CardMenu extends StatelessWidget {
  const new({required this.view, required this.card});

  final _DeckView view;
  final Flashcard card;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PopupMenuButton<VoidCallback>(
      key: Key('cardRow.${card.id}.menu'),
      tooltip: l10n.cardOptions,
      icon: const Icon(Icons.more_vert_rounded),
      onSelected: (action) => action(),
      itemBuilder: (menuContext) => [
        PopupMenuItem(
          value: () => view.openCard(context, card),
          child: Text(l10n.edit),
        ),
        PopupMenuItem(
          value: () => view.onCopy([card.id]),
          child: Text(l10n.copyTo),
        ),
        PopupMenuItem(
          value: () => view.onMove([card.id]),
          child: Text(l10n.moveTo),
        ),
        PopupMenuItem(
          value: () => view.onDelete([card.id]),
          child: Text(l10n.delete),
        ),
      ],
    );
  }
}

/// The dark bar at the bottom while cards are selected (design
/// `escritorio-claro/baraja.png`): "3 seleccionadas", "Copiar a…", "Mover
/// a…", "Eliminar" and ✕. On a phone the actions are icons with tooltips,
/// so the bar fits.
class _SelectionBar extends StatelessWidget {
  const new({required this.view, required this.compact});

  final _DeckView view;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    // The bar uses the text colour as its background, so it is dark in the
    // light theme and light in the dark theme.
    final foreground = colors.background;
    final ids = view.selected.toList();

    Widget action(String key, IconData icon, String label, VoidCallback run) =>
        compact
        ? IconButton(
            key: Key(key),
            tooltip: label,
            onPressed: run,
            icon: Icon(icon, color: foreground),
          )
        : TextButton.icon(
            key: Key(key),
            onPressed: run,
            style: TextButton.styleFrom(foregroundColor: foreground),
            icon: Icon(icon, size: 18),
            label: Text(label),
          );

    return Material(
      key: const Key('deckScreen.selectionBar'),
      color: colors.text,
      elevation: 6,
      borderRadius: BorderRadius.circular(AppRadii.listCard),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? AppSpacing.sm : AppSpacing.lg,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              child: Text(
                l10n.selectedCount(ids.length),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall
                    ?.copyWith(color: foreground),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            action(
              'deckScreen.copyTo',
              Icons.copy_outlined,
              l10n.copyTo,
              () => view.onCopy(ids),
            ),
            action(
              'deckScreen.moveTo',
              Icons.drive_file_move_outline,
              l10n.moveTo,
              () => view.onMove(ids),
            ),
            action(
              'deckScreen.deleteSelected',
              Icons.delete_outline_rounded,
              l10n.delete,
              () => view.onDelete(ids),
            ),
            IconButton(
              key: const Key('deckScreen.clearSelection'),
              tooltip: l10n.clearSelection,
              onPressed: view.onClearSelection,
              icon: Icon(Icons.close_rounded, color: foreground),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Compartir" the deck (US-26): an icon in the desktop header, as in the
/// design.
class _ShareButton extends ConsumerWidget {
  const new({required this.view});

  final _DeckView view;

  @override
  Widget build(BuildContext context, WidgetRef ref) => IconButton.outlined(
    key: const Key('deckScreen.share'),
    tooltip: AppLocalizations.of(context).shareDeck,
    onPressed: () => unawaited(
      shareDeck(context, ref, project: view.project, deck: view.deck),
    ),
    icon: const Icon(Icons.share_outlined),
  );
}

/// The ⋮ menu of the deck: edit or share it (on mobile; desktop has an
/// icon), or move it to the trash and go back to the project.
class _DeckMenu extends ConsumerWidget {
  const new({required this.view});

  final _DeckView view;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final isDesktop =
        FormFactor.fromWidth(MediaQuery.sizeOf(context).width) ==
        FormFactor.desktop;
    return PopupMenuButton<VoidCallback>(
      key: const Key('deckScreen.menu'),
      tooltip: l10n.deckOptions,
      icon: const Icon(Icons.more_vert_rounded),
      onSelected: (action) => action(),
      itemBuilder: (menuContext) => [
        PopupMenuItem(
          value: () => unawaited(
            showDeckForm(context, project: view.project, deck: view.deck),
          ),
          child: Text(l10n.editDeck),
        ),
        if (!isDesktop)
          PopupMenuItem(
            key: const Key('deckScreen.share'),
            value: () => unawaited(
              shareDeck(context, ref, project: view.project, deck: view.deck),
            ),
            child: Text(l10n.share),
          ),
        PopupMenuItem(
          value: () => unawaited(
            confirmMoveDeckToTrash(
              context,
              ref,
              deck: view.deck,
              cardCount: view.allCards.length,
              // The deck is gone: back to its project, where "Deshacer" is
              // shown.
              afterMove: () {
                if (context.mounted) {
                  context.go(AppRoutes.project(view.project.id));
                }
              },
            ),
          ),
          child: Text(l10n.deleteDeck),
        ),
      ],
    );
  }
}

/// "Importar CSV": adds the cards of a file to this deck (P07).
class _ImportButton extends StatelessWidget {
  const new({required this.view});

  final _DeckView view;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    key: const Key('deckScreen.import'),
    onPressed: () => view.importCards(context),
    icon: const Icon(Icons.file_upload_outlined),
    label: Text(AppLocalizations.of(context).importCsv),
  );
}

/// "Plantilla": saves the CSV template (US-28).
class _TemplateButton extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) => OutlinedButton.icon(
    key: const Key('deckScreen.template'),
    onPressed: () => unawaited(saveCsvTemplate(context, ref)),
    icon: const Icon(Icons.file_download_outlined),
    label: Text(AppLocalizations.of(context).template),
  );
}

/// "Prompt para IA": opens the window that copies a prompt of SPEC §8.5
/// for this deck (US-28).
class _AiPromptButton extends StatelessWidget {
  const new({required this.deck});

  final Deck deck;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    key: const Key('deckScreen.aiPrompt'),
    onPressed: () => unawaited(showAiPromptDialog(context, deck: deck)),
    icon: const Icon(Icons.auto_awesome_outlined),
    label: Text(AppLocalizations.of(context).aiPrompt),
  );
}

/// A deck with no cards (SPEC §5.3): "Añade tu primera tarjeta", "o
/// importa desde CSV" and "Descargar plantilla".
class _EmptyDeck extends StatelessWidget {
  const new({required this.view});

  final _DeckView view;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return EmptyState(
      key: const Key('deckScreen.empty'),
      icon: Icons.style_outlined,
      title: l10n.emptyCards,
      // "Añadir tarjeta" is already right above, with the deck's actions.
      actions: [
        TextButton(
          key: const Key('deckScreen.emptyImport'),
          onPressed: () => view.importCards(context),
          child: Text(l10n.emptyCardsImport),
        ),
        Consumer(
          builder: (context, ref, _) => TextButton.icon(
            key: const Key('deckScreen.emptyTemplate'),
            onPressed: () => unawaited(saveCsvTemplate(context, ref)),
            icon: const Icon(Icons.file_download_outlined),
            label: Text(l10n.downloadTemplate),
          ),
        ),
      ],
    );
  }
}

/// The search found nothing.
class _NoResults extends StatelessWidget {
  const new({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) => EmptyState(
    key: const Key('deckScreen.noResults'),
    icon: Icons.search_off_rounded,
    title: AppLocalizations.of(context).noCardResults(query.trim()),
  );
}

/// A deck that no longer exists, e.g. an old link or a deck in the trash.
class _DeckNotFound extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        key: const Key('deckScreen.notFound'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.deckNotFound,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              onPressed: () => context.go(AppRoutes.home),
              child: Text(l10n.backToHome),
            ),
          ],
        ),
      ),
    );
  }
}
