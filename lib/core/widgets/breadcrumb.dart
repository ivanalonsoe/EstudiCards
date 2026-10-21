import 'package:estudicards/app/theme/app_colors.dart';
import 'package:estudicards/app/theme/dimensions.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// One step of a [Breadcrumb]: a link to `location`, or the current page
/// when `location` is null. `key` lets tests find a link.
typedef Crumb = ({String label, String? location, Key? key});

/// "Inicio › Inglés B2 › Verbos" at the top of a desktop page. The links
/// are muted and the current page is not; each link can be tapped on an
/// area of at least 48 × 48 dp (brief §9), so it is easy to hit, while the
/// text looks as small as in the design. Long names end in "…".
class Breadcrumb extends StatelessWidget {
  const new(this.crumbs, {super.key});

  final List<Crumb> crumbs;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final style = Theme.of(context).textTheme.labelLarge;
    final separator = Icon(
      Icons.chevron_right_rounded,
      size: 18,
      color: colors.textMuted,
    );
    Widget crumb(Crumb crumb) {
      final location = crumb.location;
      final text = Text(
        crumb.label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: location == null
            ? style
            : style?.copyWith(color: colors.textMuted),
      );
      if (location == null) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          child: text,
        );
      }
      return InkWell(
        key: crumb.key,
        onTap: () => context.go(location),
        borderRadius: BorderRadius.circular(AppSpacing.xs),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: minTouchTarget,
            minHeight: minTouchTarget,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            child: Align(
              alignment: Alignment.centerLeft,
              widthFactor: 1,
              child: text,
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        for (final (i, item) in crumbs.indexed) ...[
          if (i > 0) separator,
          // "Inicio" keeps its width; the names give way when narrow.
          if (i == 0) crumb(item) else Flexible(child: crumb(item)),
        ],
      ],
    );
  }
}
