import 'dart:async';

import 'package:estudicards/app/l10n/generated/app_localizations.dart';
import 'package:estudicards/app/theme/app_colors.dart';
import 'package:estudicards/app/theme/dimensions.dart';
import 'package:estudicards/core/providers.dart';
import 'package:estudicards/core/widgets/adaptive_actions_row.dart';
import 'package:estudicards/core/widgets/confirm_dialog.dart';
import 'package:estudicards/core/widgets/empty_state.dart';
import 'package:estudicards/features/projects/presentation/project_icon.dart';
import 'package:estudicards/features/trash/domain/trash_item.dart';
import 'package:estudicards/features/trash/domain/trash_rules.dart';
import 'package:estudicards/features/trash/presentation/trash_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// P15: deleted projects and decks with the days they have left
/// (`docs/design/movil-claro/papelera.png`).
class TrashScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<TrashScreen> createState() => _TrashScreenState();
}

class _TrashScreenState extends ConsumerState<TrashScreen> {
  @override
  void initState() {
    super.initState();
    // Purge what expired while the app was open (SPEC §7.1).
    unawaited(ref.read(trashRepositoryProvider).purgeExpired());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final now = ref.watch(clockProvider).now();
    final loaded = ref.watch(trashItemsProvider);
    // Expired items are hidden even before the purge finishes.
    final items = [
      for (final item in loaded.value ?? <TrashItem>[])
        if (!isExpired(item.deletedAt, now: now)) item,
    ];
    // Nothing yet, or it could not be read: never an empty trash by
    // mistake.
    if (!loaded.hasValue) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.trash)),
        body: loaded.hasError
            ? LoadErrorState(onRetry: () => ref.invalidate(trashItemsProvider))
            : const SizedBox.shrink(),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.trash)),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: items.isEmpty
              ? const _EmptyTrash()
              : ListView(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  children: [
                    const _TrashNotice(),
                    const SizedBox(height: AppSpacing.lg),
                    for (final item in items) ...[
                      _TrashItemCard(item: item, now: now),
                      const SizedBox(height: AppSpacing.md),
                    ],
                  ],
                ),
        ),
      ),
      bottomNavigationBar: items.isEmpty
          ? null
          : SafeArea(
              child: Align(
                heightFactor: 1,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: _EmptyTrashButton(count: items.length),
                  ),
                ),
              ),
            ),
    );
  }
}

/// "Los proyectos y barajas se eliminan definitivamente a los 15 días…"
class _TrashNotice extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppRadii.listCard),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: colors.textMuted),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              AppLocalizations.of(context).trashInfo,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _TrashItemCard extends ConsumerWidget {
  const new({required this.item, required this.now});

  final TrashItem item;
  final DateTime now;

  bool get _isProject => item.type == TrashItemType.project;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    final details = _isProject
        ? l10n.trashProjectDetails(
            l10n.deckCount(item.deckCount),
            l10n.cardCount(item.cardCount),
          )
        : l10n.trashDeckDetails(
            item.projectName ?? '',
            l10n.cardCount(item.cardCount),
          );
    final left = daysLeft(item.deletedAt, now: now);

    return Card(
      key: Key('trashItem.${item.id}'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // A deck shows the layers icon in its colour.
                ProjectIconTile(
                  icon: item.icon ?? ProjectIcon.layers.key,
                  color: item.color,
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: text.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        details,
                        style: text.bodyMedium?.copyWith(
                          color: colors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            AdaptiveActionsRow(
              leading: DaysLeftChip(
                key: Key('trashItem.${item.id}.daysLeft'),
                daysLeft: left,
                urgent: isUrgent(left),
              ),
              // A `Wrap`: with large text the button goes on a new line.
              actions: Wrap(
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  IconButton(
                    key: Key('trashItem.${item.id}.delete'),
                    tooltip: l10n.deletePermanently,
                    color: colors.error,
                    onPressed: () => _deletePermanently(context, ref),
                    icon: const Icon(Icons.delete_outline_rounded),
                  ),
                  FilledButton.icon(
                    key: Key('trashItem.${item.id}.restore'),
                    style: FilledButton.styleFrom(
                      backgroundColor: colors.primarySoft,
                      foregroundColor: colors.primaryStrong,
                      // Compact, so the days left and the buttons fit on one
                      // row on most phones (from about 395 px wide).
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                      ),
                    ),
                    onPressed: () => unawaited(_restore(ref)),
                    icon: const Icon(Icons.refresh_rounded),
                    label: Text(l10n.restore),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _restore(WidgetRef ref) {
    final trash = ref.read(trashRepositoryProvider);
    return _isProject
        ? trash.restoreProject(item.id)
        : trash.restoreDeck(item.id);
  }

  Future<void> _deletePermanently(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final trash = ref.read(trashRepositoryProvider);
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.deletePermanentlyTitle(item.name),
      body: _isProject
          ? l10n.deletePermanentlyProjectBody
          : l10n.deletePermanentlyDeckBody,
      confirmLabel: l10n.delete,
    );
    if (!confirmed) return;
    await (_isProject
        ? trash.deleteProjectPermanently(item.id)
        : trash.deleteDeckPermanently(item.id));
  }
}

/// "Se elimina en N días": grey, or amber when few days are left.
class DaysLeftChip extends StatelessWidget {
  const new({required this.daysLeft, required this.urgent, super.key});

  final int daysLeft;
  final bool urgent;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final foreground = urgent ? colors.warning : colors.textMuted;
    return Container(
      // Compact, so it fits on one row with the buttons on most phones.
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs + 2,
      ),
      decoration: BoxDecoration(
        color: urgent
            ? colors.warning.withValues(alpha: 0.15)
            : colors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppRadii.chip),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.schedule_outlined, size: 16, color: foreground),
          const SizedBox(width: AppSpacing.xs),
          Flexible(
            child: Text(
              AppLocalizations.of(context).deletesIn(daysLeft),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium
                  ?.copyWith(color: foreground),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyTrashButton extends ConsumerWidget {
  const new({required this.count});

  /// How many items will be deleted.
  final int count;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    return OutlinedButton.icon(
      key: const Key('trash.empty'),
      style: OutlinedButton.styleFrom(
        foregroundColor: colors.error,
        minimumSize: const Size.fromHeight(minTouchTarget + AppSpacing.sm),
      ),
      onPressed: () async {
        final trash = ref.read(trashRepositoryProvider);
        final confirmed = await showConfirmDialog(
          context,
          title: l10n.emptyTrashTitle,
          body: l10n.emptyTrashBody(count),
          confirmLabel: l10n.emptyTrash,
        );
        if (confirmed) await trash.emptyTrash();
      },
      icon: const Icon(Icons.delete_outline_rounded),
      label: Text(l10n.emptyTrash),
    );
  }
}

/// Nothing in the trash (SPEC §5.3).
class _EmptyTrash extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      key: const Key('trash.emptyState'),
      child: SingleChildScrollView(
        child: EmptyState(
          icon: Icons.delete_outline_rounded,
          title: l10n.trashEmptyTitle,
          body: l10n.trashEmptyBody,
        ),
      ),
    );
  }
}
