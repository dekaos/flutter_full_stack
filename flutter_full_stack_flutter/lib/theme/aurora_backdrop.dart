import 'package:flutter/material.dart';
import 'package:flutter_full_stack_flutter/theme/app_tokens.dart';

/// The surface a screen sits on: a base wash with three pools of colour
/// drifting across it.
///
/// One linear gradient reads as a flat gradient. Three overlapping radial
/// pools read as light, and give `GlassSurface` something with structure to
/// refract — over an even field, glass looks like translucent paint.
///
/// The pools drift into place once, over [_settle], and then stop. That is
/// deliberate: a `BackdropFilter` re-rasterises whatever moves behind it, so a
/// backdrop that animates forever costs a blur every frame for the life of the
/// screen. Motion on arrival is free; motion at rest is a bill.
class AuroraBackdrop extends StatefulWidget {
  const AuroraBackdrop({required this.child, super.key});

  static const _settle = Duration(milliseconds: 2200);

  final Widget child;

  @override
  State<AuroraBackdrop> createState() => _AuroraBackdropState();
}

class _AuroraBackdropState extends State<AuroraBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AuroraBackdrop._settle,
  );
  late final Animation<double> _drift = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reduced motion gets the settled composition with no travel.
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
    } else if (!_controller.isAnimating && _controller.value == 0) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).appTokens;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [tokens.backdropTop, tokens.backdropBottom],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Isolated so the pools cannot drag the content into their repaints.
          RepaintBoundary(
            child: AnimatedBuilder(
              animation: _drift,
              builder: (context, _) => CustomPaint(
                painter: _AuroraPainter(
                  t: _drift.value,
                  one: tokens.auroraOne,
                  two: tokens.auroraTwo,
                  three: tokens.auroraThree,
                ),
              ),
            ),
          ),
          widget.child,
        ],
      ),
    );
  }
}

class _AuroraPainter extends CustomPainter {
  const _AuroraPainter({
    required this.t,
    required this.one,
    required this.two,
    required this.three,
  });

  final double t;
  final Color one;
  final Color two;
  final Color three;

  @override
  void paint(Canvas canvas, Size size) {
    // Each pool travels from `from` to `to` as t goes 0 → 1. The offsets are
    // fractions of the canvas so the composition holds on any screen.
    _pool(
      canvas,
      size,
      one,
      const Offset(0.05, -0.15),
      const Offset(0.2, 0.02),
      0.95,
    );
    _pool(
      canvas,
      size,
      two,
      const Offset(1.15, 0.35),
      const Offset(0.92, 0.22),
      0.8,
    );
    _pool(
      canvas,
      size,
      three,
      const Offset(0.3, 1.2),
      const Offset(0.45, 0.86),
      1.1,
    );
  }

  void _pool(
    Canvas canvas,
    Size size,
    Color color,
    Offset from,
    Offset to,
    double radiusFactor,
  ) {
    if (color.a == 0) return;

    final center = Offset(
      size.width * (from.dx + (to.dx - from.dx) * t),
      size.height * (from.dy + (to.dy - from.dy) * t),
    );
    final radius = size.shortestSide * radiusFactor;

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [color, color.withValues(alpha: 0)],
          stops: const [0, 1],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );
  }

  @override
  bool shouldRepaint(_AuroraPainter old) =>
      old.t != t || old.one != one || old.two != two || old.three != three;
}
