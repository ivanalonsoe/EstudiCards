// "Compartir" a project or a deck (US-26): the dialog of
// `docs/design/movil-claro/dialogos.png` asks for JSON (to open in the app)
// or CSV (for Excel or Google Sheets); then the file goes to the native
// share menu on mobile or to "Save as…" on desktop (SPEC §3.5).
import 'package:estudicards/app/l10n/generated/app_localizations.dart';
import 'package:estudicards/app/theme/app_colors.dart';
import 'package:estudicards/app/theme/dimensions.dart';
import 'package:estudicards/core/providers.dart';
import 'package:estudicards/core/widgets/choice_tile.dart';
import 'package:estudicards/features/decks/domain/deck.dart';
import 'package:estudicards/features/import_export/domain/cards_csv.dart';
import 'package:estudicards/features/import_export/domain/csv_template.dart';
import 'package:estudicards/features/import_export/domain/exchange_document.dart';
import 'package:estudicards/features/import_export/domain/exchange_json.dart';
import 'package:estudicards/features/import_export/domain/export_names.dart';
import 'package:estudicards/features/import_export/presentation/import_providers.dart';
import 'package:estudicards/features/projects/domain/project.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The two formats of a shared file.
enum ShareFormat {
  json('json', 'application/json'),
  csv('csv', 'text/csv');

  new(this.extension, this.mimeType);

  final String extension;
  final String mimeType;
}

/// Shares [project] with its decks and cards: `<project>.json` or `.csv`,
/// with a `deck` column (SPEC §8.1).
Future<void> shareProject(
  BuildContext context,
  WidgetRef ref,
  Project project,
) => _share(
  context,
  ref,
  title: project.name,
  nameParts: [project.name],
  document: () =>
      ref.read(exchangeRepositoryProvider).exportProject(project.id),
);

/// Shares [deck]: `<project>-<deck>.json` or `.csv` (SPEC §8.1).
Future<void> shareDeck(
  BuildContext context,
  WidgetRef ref, {
  required Project project,
  required Deck deck,
}) => _share(
  context,
  ref,
  title: deck.name,
  nameParts: [project.name, deck.name],
  document: () => ref.read(exchangeRepositoryProvider).exportDeck(deck.id),
);

Future<void> _share(
  BuildContext context,
  WidgetRef ref, {
  required String title,
  required List<String> nameParts,
  required Future<ExchangeDocument> Function() document,
}) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final origin = _originOf(context);

  final format = await showDialog<ShareFormat>(
    context: context,
    builder: (context) => _ShareDialog(title: title),
  );
  if (format == null) return;
  try {
    final bytes = await _encode(
      ref.read(backgroundRunnerProvider),
      await document(),
      format,
    );
    final saved = await ref
        .read(fileExporterProvider)
        .export(
          name: exportFileName(nameParts, format.extension),
          bytes: bytes,
          mimeType: format.mimeType,
          origin: origin,
        );
    if (saved != null) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.savedTo(saved))));
    }
  } on Object {
    messenger.showSnackBar(SnackBar(content: Text(l10n.shareFailed)));
  }
}

/// "Descargar plantilla" (US-28): shares or saves the CSV template.
Future<void> saveCsvTemplate(BuildContext context, WidgetRef ref) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  try {
    final saved = await ref
        .read(fileExporterProvider)
        .export(
          name: csvTemplateFileName,
          bytes: csvTemplate(),
          mimeType: ShareFormat.csv.mimeType,
          origin: _originOf(context),
        );
    if (saved != null) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.savedTo(saved))));
    }
  } on Object {
    messenger.showSnackBar(SnackBar(content: Text(l10n.shareFailed)));
  }
}

/// "Prompt para IA" (US-28): copies the prompt of SPEC §8.5.
Future<void> copyAiPrompt(BuildContext context) async {
  final message = AppLocalizations.of(context).aiPromptCopied;
  final messenger = ScaffoldMessenger.of(context);
  await Clipboard.setData(ClipboardData(text: aiPrompt));
  messenger.showSnackBar(SnackBar(content: Text(message)));
}

/// Where the share menu points on an iPad: the widget that opened it.
Rect? _originOf(BuildContext context) {
  final box = context.findRenderObject() as RenderBox?;
  return box == null ? null : box.localToGlobal(Offset.zero) & box.size;
}

/// Writes the file in a background isolate: a deck with many images can
/// be megabytes of JSON. It is a top-level function so the work sent to the
/// isolate holds only the document and the format.
Future<Uint8List> _encode(
  BackgroundRunner run,
  ExchangeDocument document,
  ShareFormat format,
) => run(
  () => switch ((format, document)) {
    (.json, _) => encodeExchange(document),
    (.csv, ProjectDocument(:final project)) => encodeCardsCsv(
      project.decks,
      withDeckColumn: true,
    ),
    (.csv, DeckDocument(:final deck)) => encodeCardsCsv([deck]),
    (.csv, BackupDocument()) => throw ArgumentError('A backup is JSON only'),
  },
);

/// "Compartir «Verbos irregulares»": JSON or CSV, then "Compartir".
class _ShareDialog extends StatefulWidget {
  const new({required this.title});

  final String title;

  @override
  State<_ShareDialog> createState() => _ShareDialogState();
}

class _ShareDialogState extends State<_ShareDialog> {
  ShareFormat _format = ShareFormat.json;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    return AlertDialog(
      key: const Key('shareDialog'),
      // Scrolls if it does not fit: a small phone or large text.
      scrollable: true,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: colors.primarySoft,
              borderRadius: BorderRadius.circular(AppRadii.control),
            ),
            child: Icon(Icons.ios_share_rounded, color: colors.primaryStrong),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(l10n.shareTitle(widget.title), style: text.titleLarge),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.shareBody,
            style: text.bodyMedium?.copyWith(color: colors.textMuted),
          ),
          const SizedBox(height: AppSpacing.lg),
          ChoiceTile(
            key: const Key('shareDialog.json'),
            icon: Icons.filter_none_rounded,
            title: l10n.shareJson,
            hint: l10n.shareJsonHint,
            selected: _format == ShareFormat.json,
            onTap: () => setState(() => _format = ShareFormat.json),
          ),
          const SizedBox(height: AppSpacing.sm),
          ChoiceTile(
            key: const Key('shareDialog.csv'),
            icon: Icons.download_rounded,
            title: l10n.shareCsv,
            hint: l10n.shareCsvHint,
            selected: _format == ShareFormat.csv,
            onTap: () => setState(() => _format = ShareFormat.csv),
          ),
        ],
      ),
      actions: [
        TextButton(
          key: const Key('shareDialog.cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton.icon(
          key: const Key('shareDialog.confirm'),
          onPressed: () => Navigator.of(context).pop(_format),
          icon: const Icon(Icons.ios_share_rounded),
          label: Text(l10n.share),
        ),
      ],
    );
  }
}
