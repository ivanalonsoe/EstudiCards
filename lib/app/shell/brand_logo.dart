import 'package:flutter/material.dart';

/// The EstudiCards mark: two cards with a ✓ (DESIGN_BRIEF.md §10), drawn
/// from `assets/branding/marca-sin-placa.svg` so no SVG package is needed.
///
/// Its colours are brand artwork, the same in both themes as in the
/// approved icon, so they are fixed here instead of coming from the theme.
class BrandLogo extends StatelessWidget {
  const new({this.size = 28, super.key});

  final double size;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: const _BrandLogoPainter());
}

class _BrandLogoPainter extends CustomPainter {
  const new();

  static const _backCard = Color(0xFFFDBA74);
  static const _frontCard = Color(0xFFC2410C);
  static const _check = Color(0xFFFFFFFF);

  @override
  void paint(Canvas canvas, Size size) {
    // The SVG uses a 100 × 100 grid.
    canvas.scale(size.width / 100, size.height / 100);
    const radius = Radius.circular(9);

    // Back card, rotated -12° around its centre.
    canvas
      ..save()
      ..translate(40, 50)
      ..rotate(-12 * 3.1415926535 / 180)
      ..translate(-40, -50)
      ..drawRRect(
        RRect.fromLTRBR(20, 24, 60, 76, radius),
        Paint()..color = _backCard,
      )
      ..restore()
      // Front card.
      ..drawRRect(
        RRect.fromLTRBR(38, 22, 78, 76, radius),
        Paint()..color = _frontCard,
      )
      // The ✓.
      ..drawPath(
        Path()
          ..moveTo(47, 49)
          ..lineTo(55, 57)
          ..lineTo(69, 42),
        Paint()
          ..color = _check
          ..style = PaintingStyle.stroke
          ..strokeWidth = 7
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
  }

  @override
  bool shouldRepaint(_BrandLogoPainter oldDelegate) => false;
}
