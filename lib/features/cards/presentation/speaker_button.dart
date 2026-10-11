import 'dart:async';

import 'package:estudicards/app/l10n/generated/app_localizations.dart';
import 'package:estudicards/app/theme/app_colors.dart';
import 'package:estudicards/app/theme/dimensions.dart';
import 'package:estudicards/core/providers.dart';
import 'package:estudicards/features/cards/domain/card_speech.dart';
import 'package:estudicards/features/projects/presentation/project_labels.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The speaker of a card in a language deck (US-13): reads [speech] aloud
/// with the system voice of its language. If the system has no voice for
/// it, the button is disabled and "Sin voz" next to it explains how to
/// install one (US-13 AC2).
class SpeakerButton extends ConsumerWidget {
  const new({required this.speech, super.key});

  final Speech speech;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    // While the system answers, the button waits disabled.
    final available = ref.watch(voiceAvailableProvider(speech.language)).value;
    final button = IconButton(
      tooltip: l10n.listen,
      style: IconButton.styleFrom(backgroundColor: colors.surfaceVariant),
      onPressed: available ?? false
          ? () => unawaited(
              ref
                  .read(voiceProvider)
                  .speak(speech.text, language: speech.language),
            )
          : null,
      icon: Icon(
        available == false ? Icons.volume_off_rounded : Icons.volume_up_rounded,
        size: 20,
      ),
    );
    if (available != false) return button;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        button,
        TextButton.icon(
          onPressed: () => unawaited(_explain(context)),
          style: TextButton.styleFrom(
            foregroundColor: colors.textMuted,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          ),
          icon: const Icon(Icons.info_outline_rounded, size: 16),
          label: Text(l10n.voiceMissing),
        ),
      ],
    );
  }

  /// How to install a voice on this system.
  Future<void> _explain(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final steps = switch (defaultTargetPlatform) {
      TargetPlatform.android => l10n.voiceMissingAndroid,
      TargetPlatform.windows => l10n.voiceMissingWindows,
      TargetPlatform.macOS => l10n.voiceMissingMacos,
      TargetPlatform.iOS => l10n.voiceMissingIos,
      _ => l10n.voiceMissingOther,
    };
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          l10n.voiceMissingTitle(languageName(l10n, speech.language)),
        ),
        content: Text(steps),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.close),
          ),
        ],
      ),
    );
  }
}
