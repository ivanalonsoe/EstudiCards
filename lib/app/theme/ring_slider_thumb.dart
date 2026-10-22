import 'package:flutter/material.dart';

/// The slider thumb of the design (`movil-claro/ajustes.png`): a white
/// circle with an orange ring, larger than Material's.
///
/// A `SliderComponentShape` tells the slider how big its thumb is
/// ([getPreferredSize]) and draws it ([paint]).
class RingSliderThumbShape extends SliderComponentShape {
  const new({required this.fill, this.radius = 11, this.ringWidth = 3});

  /// The inside of the circle: the cards' colour.
  final Color fill;
  final double radius;
  final double ringWidth;

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) =>
      Size.fromRadius(radius);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    context.canvas
      ..drawCircle(center, radius, Paint()..color = fill)
      ..drawCircle(
        center,
        radius - ringWidth / 2,
        Paint()
          ..color = sliderTheme.thumbColor ?? sliderTheme.activeTrackColor!
          ..style = PaintingStyle.stroke
          ..strokeWidth = ringWidth,
      );
  }
}
