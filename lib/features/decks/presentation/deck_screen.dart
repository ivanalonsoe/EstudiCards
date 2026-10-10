import 'dart:async';

import 'package:estudicards/app/l10n/generated/app_localizations.dart';
import 'package:estudicards/app/layout/breakpoints.dart';
import 'package:estudicards/app/router.dart';
import 'package:estudicards/app/theme/app_colors.dart';
import 'package:estudicards/app/theme/dimensions.dart';
import 'package:estudicards/app/theme/project_palette.dart';
import 'package:estudicards/core/providers.dart';
import 'package:estudicards/features/cards/domain/card_list.dart';
import 'package:estudicards/features/cards/domain/flashcard.dart';
import 'package:estudicards/features/cards/presentation/card_providers.dart';
import 'package:estudicards/features/cards/presentation/formatted_text.dart';
import 'package:estudicards/features/decks/domain/deck.dart';
import 'package:estudicards/features/decks/domain/languages.dart';
import 'package:estudicards/features/decks/presentation/deck_form.dart';
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final project = ref.watch(projectProvider(widget.projectId));
    // The project's deck list is watched, so the screen follows edits to
    // the deck (name, colour, type) and notices when it goes to the trash.
    final decks = ref.watch(deckSummariesProvider(widget.projectId));
    final cards = ref.watch(deckCardsProvider(widget.deckId));

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

    final all = cards.value!;
    final view = _DeckView(
      project: loadedProject,
      deck: deck,
      allCards: all,
      shownCards: sortCards(
        all.where((s) => matchesCardSearch(s.card, _query)),
        _sort,
      ),
      query: _query,
      sort: _sort,
      onQueryChanged: (query) => setState(() => _query = query),
      onSortChanged: (sort) => setState(() => _sort = sort),
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
    required this.onQueryChanged,
    required this.onSortChanged,
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
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          // On tablets the list keeps a comfortable reading width.
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.xxxl,
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: 40,
          vertical: AppSpacing.xl,
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
            Row(
              children: [
                if (view.allCards.isNotEmpty) ...[
                  Flexible(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 320),
                      child: _SearchField(
                        view: view,
                        hint: l10n.searchCardsLong,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  _SortSelector(view: view),
                ],
                const SizedBox(width: AppSpacing.md),
                const Spacer(),
                FilledButton.icon(
                  key: const Key('deckScreen.addCard'),
                  onPressed: () => view.addCard(context),
                  icon: const Icon(Icons.add_rounded),
                  label: Text(l10n.addCard),
                ),
              ],
            ),
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
    return InkWell(
      key: Key('cardRow.${card.id}'),
      onTap: () => view.openCard(context, card),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
        child: Row(
          children: [
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

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _TableRow(
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
            _CardTableRow(view: view, summary: summary, now: now),
          ],
        ],
      ),
    );
  }
}

/// The column widths of the table, shared by the heading and every row.
class _TableRow extends StatelessWidget {
  const new({
    required this.question,
    required this.type,
    required this.correct,
    required this.wrong,
    required this.rate,
    required this.review,
    required this.menu,
  });

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
        Expanded(child: question),
        const SizedBox(width: AppSpacing.lg),
        SizedBox(width: 128, child: type),
        SizedBox(width: 88, child: correct),
        SizedBox(width: 72, child: wrong),
        const SizedBox(width: AppSpacing.xl),
        SizedBox(width: 150, child: rate),
        const SizedBox(width: AppSpacing.xl),
        SizedBox(width: 110, child: review),
        SizedBox(width: 48, child: menu),
      ],
    ),
  );
}

class _CardTableRow extends StatelessWidget {
  const new({required this.view, required this.summary, required this.now});

  final _DeckView view;
  final CardSummary summary;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    final card = summary.card;
    return InkWell(
      key: Key('cardRow.${card.id}'),
      onTap: () => view.openCard(context, card),
      child: _TableRow(
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

/// The ⋮ menu of a card in the table. "Copiar a…", "Mover a…" and
/// "Eliminar" arrive with T2.9.
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
      ],
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
