import 'package:estudicards/app/l10n/generated/app_localizations.dart';
import 'package:estudicards/app/theme/app_colors.dart';
import 'package:estudicards/app/theme/dimensions.dart';
import 'package:flutter/material.dart';

/// A screen or list with nothing to show yet (SPEC §5.3), as the "Estado
/// vacío" of `docs/design/sistema/componentes.png`: an icon on a soft
/// orange square, a title, an optional explanation and the actions that
/// fill it ("Añadir tarjeta", "Importar CSV"…).
class EmptyState extends StatelessWidget {
  const new({
    required this.icon,
    required this.title,
    this.body,
    this.actions = const [],
    this.illustration,
    this.large = false,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? body;

  /// Buttons under the text, side by side when they fit.
  final List<Widget> actions;

  /// Replaces the icon, e.g. the logo on the empty dashboard.
  final Widget? illustration;

  /// The first screen of the app (`dashboard-vacio.png`): bigger text and
  /// the actions one under the other, as wide as the text.
  final bool large;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    final body = this.body;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xxl,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: large ? 400 : 480),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: large
              ? CrossAxisAlignment.stretch
              : CrossAxisAlignment.center,
          children: [
            Center(
              child:
                  illustration ??
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: colors.primarySoft,
                      borderRadius: BorderRadius.circular(AppRadii.listCard),
                    ),
                    child: Icon(icon, size: 32, color: colors.primaryStrong),
                  ),
            ),
            SizedBox(height: large ? AppSpacing.xl : AppSpacing.lg),
            Text(
              title,
              textAlign: TextAlign.center,
              style: large ? text.headlineSmall : text.titleLarge,
            ),
            if (body != null) ...[
              SizedBox(height: large ? AppSpacing.md : AppSpacing.sm),
              Text(
                body,
                textAlign: TextAlign.center,
                style: (large ? text.bodyLarge : text.bodyMedium)?.copyWith(
                  color: colors.textMuted,
                ),
              ),
            ],
            if (actions.isNotEmpty) ...[
              SizedBox(height: large ? AppSpacing.xxl : AppSpacing.xl),
              if (large)
                for (final (i, action) in actions.indexed) ...[
                  if (i > 0) const SizedBox(height: AppSpacing.md),
                  action,
                ]
              else
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: AppSpacing.md,
                  runSpacing: AppSpacing.sm,
                  children: actions,
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The data of a screen could not be read: says so, with "Reintentar" to
/// read it again ([onRetry]). Without it, an empty screen would wrongly
/// look like there is nothing.
class LoadErrorState extends StatelessWidget {
  const new({required this.onRetry, super.key});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, size: 40, color: colors.error),
            const SizedBox(height: AppSpacing.md),
            Text(
              l10n.loadError,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
            OutlinedButton.icon(
              key: const Key('loadError.retry'),
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(l10n.retry),
            ),
          ],
        ),
      ),
    );
  }
}
