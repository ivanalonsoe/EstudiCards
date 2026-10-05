import 'dart:ui';

import 'package:estudicards/app/theme/project_palette.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('has the 12 colours from the brief, in order', () {
    expect(ProjectColor.values.map((c) => c.key), [
      'orange',
      'amber',
      'lime',
      'green',
      'teal',
      'cyan',
      'blue',
      'indigo',
      'violet',
      'pink',
      'fuchsia',
      'slate',
    ]);
  });

  test('each colour has the light and dark values from the brief', () {
    const expected = {
      ProjectColor.orange: (0xFFEA580C, 0xFFFB923C),
      ProjectColor.amber: (0xFFD97706, 0xFFFBBF24),
      ProjectColor.lime: (0xFF65A30D, 0xFFA3E635),
      ProjectColor.green: (0xFF16A34A, 0xFF4ADE80),
      ProjectColor.teal: (0xFF0D9488, 0xFF2DD4BF),
      ProjectColor.cyan: (0xFF0891B2, 0xFF22D3EE),
      ProjectColor.blue: (0xFF2563EB, 0xFF60A5FA),
      ProjectColor.indigo: (0xFF4F46E5, 0xFF818CF8),
      ProjectColor.violet: (0xFF7C3AED, 0xFFA78BFA),
      ProjectColor.pink: (0xFFDB2777, 0xFFF472B6),
      ProjectColor.fuchsia: (0xFFC026D3, 0xFFE879F9),
      ProjectColor.slate: (0xFF475569, 0xFF94A3B8),
    };

    for (final MapEntry(key: color, value: (light, dark)) in expected.entries) {
      expect(color.resolve(Brightness.light), Color(light), reason: color.key);
      expect(color.resolve(Brightness.dark), Color(dark), reason: color.key);
    }
  });

  test('finds a colour by the key stored in the database', () {
    expect(ProjectColor.fromKey('blue'), ProjectColor.blue);
  });

  test('falls back to orange for an unknown key', () {
    expect(ProjectColor.fromKey('raspberry'), ProjectColor.orange);
  });
}
