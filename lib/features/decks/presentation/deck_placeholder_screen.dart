import 'package:estudicards/app/l10n/generated/app_localizations.dart';
import 'package:estudicards/app/router.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Temporary deck screen (P05) with only "Añadir tarjeta", so the card
/// editor can be tried by hand before the real deck screen arrives with
/// T2.8 (decided with the owner).
class DeckPlaceholderScreen extends StatelessWidget {
  const new({required this.projectId, required this.deckId, super.key});

  final String projectId;
  final String deckId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.deck)),
      body: Center(
        child: FilledButton.icon(
          key: const Key('deckScreen.addCard'),
          onPressed: () => context.go(AppRoutes.newCard(projectId, deckId)),
          icon: const Icon(Icons.add_rounded),
          label: Text(l10n.addCard),
        ),
      ),
    );
  }
}
