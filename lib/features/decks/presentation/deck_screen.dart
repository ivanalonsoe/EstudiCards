import 'dart:async';

import 'package:estudicards/app/l10n/generated/app_localizations.dart';
import 'package:estudicards/app/layout/breakpoints.dart';
import 'package:estudicards/app/router.dart';
import 'package:estudicards/app/theme/app_colors.dart';
import 'package:estudicards/app/theme/dimensions.dart';
import 'package:estudicards/app/theme/project_palette.dart';
import 'package:estudicards/core/providers.dart';
import 'package:estudicards/core/widgets/confirm_dialog.dart';
import 'package:estudicards/features/cards/domain/card_list.dart';
import 'package:estudicards/features/cards/domain/card_transfer.dart';
import 'package:estudicards/features/cards/domain/flashcard.dart';
import 'package:estudicards/features/cards/presentation/card_providers.dart';
import 'package:estudicards/features/cards/presentation/delete_cards.dart';
import 'package:estudicards/features/cards/presentation/formatted_text.dart';
import 'package:estudicards/features/decks/domain/deck.dart';
import 'package:estudicards/features/decks/domain/deck_summary.dart';
import 'package:estudicards/features/decks/domain/languages.dart';
import 'package:estudicards/features/decks/presentation/deck_form.dart';
import 'package:estudicards/features/decks/presentation/deck_picker.dart';
import 'package:estudicards/features/decks/presentation/deck_providers.dart';
import 'package:estudicards/features/projects/domain/project.dart';
import 'package:estudicards/features/projects/presentation/project_providers.dart';
import 'package:estudicards/features/trash/presentation/move_to_trash.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// P05: a deck with its cards (`docs/design/movil-claro/baraja.png`,
/// `escritorio-claro/baraja.png`): a list on mobile and a table on desktop,
/// with search and sorting (US-12).
///
/// Hidden until their phases (SPEC §13.2, assumption 16): "Estudiar"
/// (phase 3), "Repasar errores" (phase 4), and "Importar CSV", "Plantilla",
/// "Prompt para IA" and "Compartir" (phase 5).
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
    final l10n = AppLocalizations.of(context);
    final project = ref.watch(projectProvider(widget.projectId));
    // The project's deck list is watched, so the screen follows edits to
    // the deck (name, colour, type) and notices when it goes to the trash.
    final decks = ref.watch(deckSummariesProvider(widget.projectId));
    final cards = ref.watch(deckCardsProvider(widget.deckId));
    // Cards waiting for their "Deshacer" to run out are hidden.
    final pending = ref.watch(pendingCardDeletionsProvider);

    if (project.hasError || decks.hasError || cards.hasError) {
      return _Message(l10n.loadError);
    }
    if (!project.hasValue || !decks.hasValue || !cards.hasValue) {
      return const Scaffold();
    }
    final loadedProject = project.value;
    final deck = [
      for (final summary in decks.value!)
        if (summary.deck.id == widget.deckId) summary.deck,
    ].firstOrNull;
    if (loadedProject == null || deck == null) {
      return const _Message(null);
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

/// "92%", or "—" with no answers.
String rateText(AppLocalizations l10n, double? rate) =>
    rate == null ? '—' : l10n.percent((rate * 100).round());

/// "Hoy", "Ayer", "Hace 3 días" or "Nunca".
String _reviewText(AppLocalizations l10n, DateTime? reviewedAt, DateTime now) =>
    switch (daysSinceReview(reviewedAt, now)) {
      null => l10n.reviewedNever,
      <= 0 => l10n.reviewedToday,
      1 => l10n.reviewedYesterday,
      final days => l10n.reviewedDaysAgo(days),
    };

/// Mobile and tablet: the deck's details, "Añadir tarjeta", the search and
/// the list.
class _MobileDeck extends StatelessWidget {
  const new(this.view);

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
          child: ListView(
            // While selecting, room for the selection bar below the list.
            padding: EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              view.isSelecting ? 120 : AppSpacing.xxxl,
            ),
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
              FilledButton.icon(
                key: const Key('deckScreen.addCard'),
                onPressed: () => view.addCard(context),
                icon: const Icon(Icons.add_rounded),
                label: Text(l10n.addCard),
              ),
              const SizedBox(height: AppSpacing.lg),
              if (view.allCards.isEmpty)
                const _EmptyDeck()
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
                if (view.shownCards.isEmpty)
                  _NoResults(query: view.query)
                else
                  for (final summary in view.shownCards) ...[
                    _CardTile(view: view, summary: summary),
                    Divider(height: 1, color: colors.border),
                  ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Desktop: breadcrumb, header with the actions, and the cards in a table.
class _DesktopDeck extends StatelessWidget {
  const new(this.view);

  final _DeckView view;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    final details = [
      ?view.languagePair(l10n),
      ...view.counts(l10n),
    ].join(l10n.detailsSeparator);

    return Scaffold(
      floatingActionButton: view.isSelecting
          ? _SelectionBar(view: view, compact: false)
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          40,
          AppSpacing.xl,
          40,
          view.isSelecting ? 120 : AppSpacing.xl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Breadcrumb(view: view),
            const SizedBox(height: AppSpacing.xl),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(view.deck.name, style: text.displaySmall),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        details,
                        style: text.titleSmall?.copyWith(
                          color: colors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.lg),
                _DeckMenu(view: view),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            _Toolbar(view: view),
            const SizedBox(height: AppSpacing.lg),
            if (view.allCards.isEmpty)
              const _EmptyDeck()
            else if (view.shownCards.isEmpty)
              _NoResults(query: view.query)
            else
              _CardTable(view: view),
          ],
        ),
      ),
    );
  }
}

/// The desktop search, the three orders and "Añadir tarjeta" in one row;
/// in a narrow window, the orders go on a second row.
class _Toolbar extends StatelessWidget {
  const new({required this.view});

  final _DeckView view;

  /// The width from which the three fit in one row.
  static const _oneRowWidth = 900.0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final addCard = FilledButton.icon(
      key: const Key('deckScreen.addCard'),
      onPressed: () => view.addCard(context),
      icon: const Icon(Icons.add_rounded),
      label: Text(l10n.addCard),
    );
    if (view.allCards.isEmpty) {
      return Align(alignment: Alignment.centerRight, child: addCard);
    }
    final search = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 360),
      child: _SearchField(view: view, hint: l10n.searchCardsLong),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= _oneRowWidth) {
          return Row(
            children: [
              Flexible(child: search),
              const SizedBox(width: AppSpacing.md),
              _SortSelector(view: view),
              const SizedBox(width: AppSpacing.md),
              const Spacer(),
              addCard,
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: search),
                const SizedBox(width: AppSpacing.md),
                addCard,
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            _SortSelector(view: view),
          ],
        );
      },
    );
  }
}

/// "Inicio › Inglés B2 › Verbos irregulares" above the desktop header.
class _Breadcrumb extends StatelessWidget {
  const new({required this.view});

  final _DeckView view;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final style = Theme.of(context).textTheme.labelLarge;
    final muted = style?.copyWith(color: colors.textMuted);

    Widget link(String label, String location, String key) => InkWell(
      key: Key(key),
      onTap: () => context.go(location),
      borderRadius: BorderRadius.circular(AppSpacing.xs),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xs),
        child: Text(label, style: muted),
      ),
    );

    final chevron = Icon(
      Icons.chevron_right_rounded,
      size: 18,
      color: colors.textMuted,
    );
    return Row(
      children: [
        link(
          AppLocalizations.of(context).home,
          AppRoutes.home,
          'deckScreen.breadcrumbHome',
        ),
        chevron,
        Flexible(
          child: link(
            view.project.name,
            AppRoutes.project(view.project.id),
            'deckScreen.breadcrumbProject',
          ),
        ),
        chevron,
        const SizedBox(width: AppSpacing.xs),
        Flexible(
          child: Text(
            view.deck.name,
            style: style,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
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
    final colors = AppColors.of(context);
    return SegmentedButton<CardSort>(
      segments: [
        for (final sort in CardSort.values)
          ButtonSegment(
            value: sort,
            label: Text(
              _sortLabel(l10n, sort),
              key: Key('deckScreen.sort.${sort.name}'),
            ),
          ),
      ],
      selected: {view.sort},
      showSelectedIcon: false,
      // The same grey track as the type selector of the forms.
      style: SegmentedButton.styleFrom(
        backgroundColor: colors.surfaceVariant,
        foregroundColor: colors.textMuted,
        selectedBackgroundColor: colors.surface,
        selectedForegroundColor: colors.text,
        side: BorderSide(color: colors.border),
        textStyle: Theme.of(context).textTheme.labelLarge,
      ),
      onSelectionChanged: (selection) => view.onSortChanged(selection.single),
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
                width: 44,
                child: Checkbox(
                  key: Key('cardRow.${card.id}.select'),
                  value: isSelected,
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

    // A narrow desktop window has no room for every column: the correct and
    // wrong counts and the last review go, the question and the % stay.
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < _fullTableWidth;
        return Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              _TableRow(
                compact: compact,
                // All, none, or some (a dash) of the cards shown are selected.
                select: Checkbox(
                  key: const Key('deckScreen.selectAll'),
                  tristate: true,
                  value: switch (selectedShown) {
                    0 => false,
                    _ when selectedShown == view.shownCards.length => true,
                    _ => null,
                  },
                  semanticLabel: l10n.selectAll,
                  onChanged: (_) => view.onSelectShown(
                    selectedShown != view.shownCards.length,
                  ),
                ),
                question: heading(l10n.columnQuestion),
                type: heading(l10n.columnType),
                correct: heading(l10n.columnCorrect, align: TextAlign.end),
                wrong: heading(l10n.columnWrong, align: TextAlign.end),
                rate: heading(l10n.columnRate),
                review: heading(l10n.columnLastReview),
                menu: const SizedBox.shrink(),
              ),
              for (final summary in view.shownCards) ...[
                Divider(height: 1, color: colors.border),
                _CardTableRow(
                  view: view,
                  summary: summary,
                  now: now,
                  compact: compact,
                ),
              ],
            ],
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
        SizedBox(width: 40, child: select),
        const SizedBox(width: AppSpacing.sm),
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
              SizedBox(
                width: 40,
                child: Text(
                  rateText(l10n, summary.correctRate),
                  style: text.titleSmall,
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
          review: Text(
            _reviewText(l10n, summary.lastReviewedAt, now),
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
              Icons.copy_rounded,
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

/// The ⋮ menu of the deck: edit it, or move it to the trash and go back to
/// the project. "Compartir" arrives in phase 5.
class _DeckMenu extends ConsumerWidget {
  const new({required this.view});

  final _DeckView view;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
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

/// A deck with no cards (SPEC §5.3). "o importa desde CSV" and "Descargar
/// plantilla" arrive in phase 5 (decided with the owner).
class _EmptyDeck extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
      key: const Key('deckScreen.empty'),
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
      child: Column(
        children: [
          Icon(Icons.style_outlined, size: 40, color: colors.textMuted),
          const SizedBox(height: AppSpacing.md),
          Text(
            AppLocalizations.of(context).emptyCards,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge
                ?.copyWith(color: colors.textMuted),
          ),
        ],
      ),
    );
  }
}

/// The search found nothing.
class _NoResults extends StatelessWidget {
  const new({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) => Padding(
    key: const Key('deckScreen.noResults'),
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
    child: Text(
      AppLocalizations.of(context).noCardResults(query.trim()),
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.bodyLarge
          ?.copyWith(color: AppColors.of(context).textMuted),
    ),
  );
}

/// A screen with only a message: a load error, or a deck that no longer
/// exists ([message] null), e.g. an old link or a deck in the trash.
class _Message extends StatelessWidget {
  const new(this.message);

  final String? message;

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
              message ?? l10n.deckNotFound,
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
