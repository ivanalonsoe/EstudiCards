import 'package:flutter/material.dart';

/// Paints a dashed rounded border around its child, as in the "Nuevo
/// proyecto" and "Nueva baraja" tiles of the design. Flutter has no dashed
/// border, so it is drawn by hand.
class DashedBorder extends StatelessWidget {
  const new({
    required this.color,
    required this.radius,
    required this.child,
    super.key,
  });

  final Color color;
  final double radius;
  final Widget child;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _DashedBorderPainter(color: color, radius: radius),
    child: child,
  );
}

class _DashedBorderPainter extends CustomPainter {
  const new({required this.color, required this.radius});

  final Color color;
  final double radius;

  static const _dash = 6.0;
  static const _gap = 4.0;

  @override
  void paint(Canvas canvas, Size size) {
    final border = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          Radius.circular(radius),
        ).deflate(0.5),
      );
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke;
    // Walk along the border, drawing a dash and skipping a gap each time.
    for (final metric in border.computeMetrics()) {
      for (var start = 0.0; start < metric.length; start += _dash + _gap) {
        canvas.drawPath(metric.extractPath(start, start + _dash), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}
