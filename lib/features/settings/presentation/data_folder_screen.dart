// T5.11 (decided with the owner): on Windows the user chooses where the
// data lives, on the first start or when that folder is gone. It is shown
// before the app itself, since the database lives in that folder.
import 'dart:io';

import 'package:estudicards/app/l10n/generated/app_localizations.dart';
import 'package:estudicards/app/shell/brand_logo.dart';
import 'package:estudicards/app/theme/app_colors.dart';
import 'package:estudicards/app/theme/dimensions.dart';
import 'package:estudicards/features/settings/data/data_folder_store.dart';
import 'package:estudicards/features/settings/domain/data_folder.dart';
import 'package:flutter/material.dart';

/// Asks where the data lives on Windows: `Documents\EstudiCards` by
/// default. Calls [onReady] with the folder once it is chosen and saved.
class DataFolderScreen extends StatefulWidget {
  const new({
    required this.store,
    required this.documents,
    required this.onReady,
    required this.pickFolder,
    this.missingPath,
    super.key,
  });

  final DataFolderStore store;

  /// The user's Documents folder: the default place, and where earlier
  /// versions left the data loose.
  final Directory documents;
  final ValueChanged<Directory> onReady;

  /// The system folder dialog; null if the user cancelled.
  final Future<String?> Function() pickFolder;

  /// The folder chosen before, if it is gone.
  final String? missingPath;

  @override
  State<DataFolderScreen> createState() => _DataFolderScreenState();
}

class _DataFolderScreenState extends State<DataFolderScreen> {
  late String _path =
      widget.missingPath ?? dataFolderFor(widget.documents.path);
  bool _busy = false;

  Future<void> _change() async {
    final picked = await widget.pickFolder();
    if (picked != null && mounted) {
      setState(() => _path = dataFolderFor(picked));
    }
  }

  Future<void> _continue() async {
    final l10n = AppLocalizations.of(context);
    final folder = Directory(_path);
    if (DataFolderStore.hasData(folder)) {
      // A folder with data: the user decides whether to load it.
      final load = await _ask(
        title: l10n.dataFolderHasDataTitle,
        body: l10n.dataFolderHasDataBody(folder.path),
        noKey: 'dataFolder.chooseOther',
        noLabel: l10n.dataFolderChooseOther,
        yesKey: 'dataFolder.loadData',
        yesLabel: l10n.dataFolderLoad,
      );
      if (!load) return;
    } else if (DataFolderStore.hasData(widget.documents) &&
        !_samePath(widget.documents.path, folder.path)) {
      // The data of an earlier version, loose in Documents: it can move to
      // the new folder, so nothing is lost.
      final move = await _ask(
        title: l10n.dataFolderLegacyTitle,
        body: l10n.dataFolderLegacyBody(widget.documents.path),
        noKey: 'dataFolder.startEmpty',
        noLabel: l10n.dataFolderStartEmpty,
        yesKey: 'dataFolder.moveData',
        yesLabel: l10n.dataFolderMove,
      );
      if (move) DataFolderStore.moveData(from: widget.documents, to: folder);
    }
    setState(() => _busy = true);
    folder.createSync(recursive: true);
    widget.store.save(folder);
    widget.onReady(folder);
  }

  Future<bool> _ask({
    required String title,
    required String body,
    required String noKey,
    required String noLabel,
    required String yesKey,
    required String yesLabel,
  }) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(
              key: Key(noKey),
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(noLabel),
            ),
            FilledButton(
              key: Key(yesKey),
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(yesLabel),
            ),
          ],
        ),
      ) ??
      false;

  static bool _samePath(String a, String b) =>
      a.replaceAll('/', r'\').toLowerCase() ==
      b.replaceAll('/', r'\').toLowerCase();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: BrandLogo(size: 56),
                ),
                const SizedBox(height: AppSpacing.xl),
                Text(l10n.dataFolderTitle, style: text.headlineSmall),
                const SizedBox(height: AppSpacing.md),
                Text(
                  l10n.dataFolderBody,
                  style: text.bodyLarge?.copyWith(color: colors.textMuted),
                ),
                if (widget.missingPath != null) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    l10n.dataFolderMissing,
                    key: const Key('dataFolder.missing'),
                    style: text.bodyMedium?.copyWith(color: colors.error),
                  ),
                ],
                const SizedBox(height: AppSpacing.xl),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    border: Border.all(color: colors.border),
                    borderRadius: BorderRadius.circular(AppRadii.control),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.folder_outlined, color: colors.textMuted),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          _path,
                          key: const Key('dataFolder.path'),
                          style: text.bodyLarge,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      key: const Key('dataFolder.change'),
                      onPressed: _busy ? null : _change,
                      icon: const Icon(Icons.folder_open_outlined),
                      label: Text(l10n.dataFolderChange),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    FilledButton(
                      key: const Key('dataFolder.continue'),
                      onPressed: _busy ? null : _continue,
                      child: Text(l10n.restoreContinue),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
