import 'package:estudicards/app/theme/dimensions.dart';
import 'package:estudicards/app/theme/project_palette.dart';
import 'package:flutter/material.dart';

/// The icons a user can pick for a project (`docs/design/movil-claro/
/// nuevo-proyecto.png`). The database stores the [key] (`projects.icon`).
enum ProjectIcon {
  globe(Icons.language_outlined),
  scales(Icons.balance_outlined),
  flask(Icons.science_outlined),
  book(Icons.menu_book_outlined),
  cards(Icons.filter_none_rounded),
  layers(Icons.layers_outlined),
  star(Icons.star_outline_rounded),
  sparkles(Icons.auto_awesome_outlined);

  new(this.icon);

  final IconData icon;

  String get key => name;

  /// The icon for a stored [key]. Unknown keys (e.g. from an import file)
  /// fall back to [book] instead of failing.
  static ProjectIcon fromKey(String key) => values.asNameMap()[key] ?? book;
}

/// A project's icon in its colour, on a square tinted with that colour at
/// 12% (DESIGN_BRIEF.md §3.4).
class ProjectIconTile extends StatelessWidget {
  const new({
    required this.icon,
    required this.color,
    this.size = 48,
    super.key,
  });

  /// Stored keys, e.g. `globe` and `blue`.
  final String icon;
  final String color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final resolved = ProjectColor.fromKey(color)
        .resolve(Theme.of(context).brightness);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: resolved.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(
          size >= 40 ? AppRadii.control : AppSpacing.sm,
        ),
      ),
      child: Icon(
        ProjectIcon.fromKey(icon).icon,
        color: resolved,
        size: size / 2,
      ),
    );
  }
}
