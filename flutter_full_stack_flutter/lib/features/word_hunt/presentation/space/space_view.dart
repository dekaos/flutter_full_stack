import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_full_stack_flutter/features/word_hunt/presentation/space/space_world.dart';

/// A [SpaceWorld] on screen: moved on every frame while [running], drawn
/// full-bleed, and told about taps on its ships.
///
/// One ticker and one painter for the whole scene. The painter listens to
/// the world, so a frame repaints the canvas and rebuilds nothing; and the
/// route underneath a mission stops ticking on its own, because Flutter
/// turns tickers off on a route that is covered.
class SpaceView extends StatefulWidget {
  const SpaceView({
    required this.world,
    this.clear = EdgeInsets.zero,
    this.running = true,
    this.onShip,
    super.key,
  });

  final SpaceWorld world;

  /// How much of each edge the screen covers with its own panels: the ships
  /// keep out from under it.
  final EdgeInsets clear;

  /// Whether time passes in it. Paused, it holds still and stops asking
  /// for frames.
  final bool running;

  /// A ship was tapped: its index in the round.
  final ValueChanged<int>? onShip;

  @override
  State<SpaceView> createState() => _SpaceViewState();
}

class _SpaceViewState extends State<SpaceView>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_tick);
  Duration _last = Duration.zero;

  @override
  void initState() {
    super.initState();
    if (widget.running) _ticker.start();
  }

  @override
  void didUpdateWidget(SpaceView old) {
    super.didUpdateWidget(old);
    if (widget.running && !_ticker.isActive) {
      _last = Duration.zero;
      _ticker.start();
    } else if (!widget.running && _ticker.isActive) {
      _ticker.stop();
    }
  }

  void _tick(Duration elapsed) {
    final dt = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    // A long frame - the app back from the background, a debugger - is
    // not a long step: the world would jump.
    widget.world.tick(math.min(dt, 1 / 20));
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    widget.world
      ..still = MediaQuery.disableAnimationsOf(context)
      ..typeset(
        (theme.textTheme.titleMedium ?? const TextStyle()).copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
        // Larger text is honoured, up to what a ship's label can carry
        // without crowding the others out of the sky.
        MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.35),
      );
    return LayoutBuilder(
      builder: (context, constraints) {
        widget.world.layout(constraints.biggest, widget.clear);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: widget.onShip == null
              ? null
              : (details) {
                  final ship = widget.world.pick(details.localPosition);
                  if (ship != null) widget.onShip!(ship);
                },
          child: RepaintBoundary(
            child: CustomPaint(
              size: constraints.biggest,
              painter: _SpacePainter(widget.world),
            ),
          ),
        );
      },
    );
  }
}

class _SpacePainter extends CustomPainter {
  _SpacePainter(this.world) : super(repaint: world);

  final SpaceWorld world;

  @override
  void paint(Canvas canvas, Size size) {
    world
      ..layout(size, world.clear)
      ..paint(canvas);
  }

  @override
  bool shouldRepaint(_SpacePainter old) => old.world != world;
}
