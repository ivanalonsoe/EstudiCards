import 'package:flutter/widgets.dart';

/// Plays an animation from 0 to 1 once when it first appears, and again
/// whenever [replayKey] changes, calling [builder] with the value on every
/// frame.
///
/// Unlike `TweenAnimationBuilder`, it keeps its duration when the system
/// asks to reduce motion. Flutter otherwise plays every animation 20 times
/// faster then, which turns the fades that replace movement (brief §8) into
/// a blink. Each use decides what to show with reduced motion
/// (`AppMotion.reduced`).
class PlayOnce extends StatefulWidget {
  const new({
    required this.duration,
    required this.builder,
    this.replayKey,
    this.child,
    super.key,
  });

  final Duration duration;

  /// Changing it plays the animation again from the start.
  final Object? replayKey;

  /// Builds the widget for the animation's value, from 0 to 1. [child] is
  /// passed back as is, so the part that does not move is built once.
  final ValueWidgetBuilder<double> builder;
  final Widget? child;

  @override
  State<PlayOnce> createState() => _PlayOnceState();
}

class _PlayOnceState extends State<PlayOnce>
    with SingleTickerProviderStateMixin {
  // `preserve`: the duration is kept with "reduce motion" on (see above).
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
    animationBehavior: AnimationBehavior.preserve,
  )..forward();

  @override
  void didUpdateWidget(PlayOnce oldWidget) {
    super.didUpdateWidget(oldWidget);
    _controller.duration = widget.duration;
    if (widget.replayKey != oldWidget.replayKey) _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, child) =>
        widget.builder(context, _controller.value, child),
    child: widget.child,
  );
}
