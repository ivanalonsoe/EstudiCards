import 'dart:ui';

/// The 12 colours a user can pick for a project (DESIGN_BRIEF.md §3.1).
///
/// The database stores the [key] (`projects.color`); the colour shown
/// depends on the theme, so it is resolved with [resolve].
enum ProjectColor {
  orange(Color(0xFFEA580C), Color(0xFFFB923C)),
  amber(Color(0xFFD97706), Color(0xFFFBBF24)),
  lime(Color(0xFF65A30D), Color(0xFFA3E635)),
  green(Color(0xFF16A34A), Color(0xFF4ADE80)),
  teal(Color(0xFF0D9488), Color(0xFF2DD4BF)),
  cyan(Color(0xFF0891B2), Color(0xFF22D3EE)),
  blue(Color(0xFF2563EB), Color(0xFF60A5FA)),
  indigo(Color(0xFF4F46E5), Color(0xFF818CF8)),
  violet(Color(0xFF7C3AED), Color(0xFFA78BFA)),
  pink(Color(0xFFDB2777), Color(0xFFF472B6)),
  fuchsia(Color(0xFFC026D3), Color(0xFFE879F9)),
  slate(Color(0xFF475569), Color(0xFF94A3B8));

  new(this.light, this.dark);

  final Color light;
  final Color dark;

  /// The value stored in the database, e.g. `blue`.
  String get key => name;

  Color resolve(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;

  /// The colour for a stored [key]. Unknown keys (e.g. from a hand-edited
  /// import file) fall back to the brand orange instead of failing.
  static ProjectColor fromKey(String key) =>
      values.asNameMap()[key] ?? ProjectColor.orange;
}
