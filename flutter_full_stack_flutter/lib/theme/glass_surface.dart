import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_full_stack_flutter/theme/app_tokens.dart';

/// A translucent pane that blurs whatever is behind it.
///
/// Every value it paints with comes from [AppTokens], so the look is changed
/// in the theme rather than at each call site. In particular a token set with
/// `glassBlur: 0` — which is what [AppTokens.of] returns when the device asks
/// for high contrast — makes this render as an ordinary opaque card, with no
/// `BackdropFilter` inserted at all. Callers do not branch on that.
///
/// It has no idle animation on purpose. A pane that pulses forever costs a
/// repaint every frame for the life of the screen, and multiplies by the
/// number of panes on it.
class GlassSurface extends StatefulWidget {
  const GlassSurface({
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.onTap,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  /// When set, the pane becomes a button: it takes an ink ripple and a small
  /// press scale. Without it there is no gesture handling and no controller.
  final VoidCallback? onTap;

  @override
  State<GlassSurface> createState() => _GlassSurfaceState();
}

class _GlassSurfaceState extends State<GlassSurface> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.appTokens;
    final radius = BorderRadius.circular(tokens.radiusLarge);

    // The blur is bounded by the clip, and the tint is painted over it.
    Widget pane = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        color: tokens.glassTint,
        border: Border.all(color: tokens.glassBorder),
        // The sheen is what sells the material: a highlight that fades out
        // before the middle, as if light caught the top edge.
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [tokens.glassHighlight, Colors.transparent],
          stops: const [0, 0.45],
        ),
      ),
      child: Padding(padding: widget.padding, child: widget.child),
    );

    if (widget.onTap != null) {
      pane = Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: widget.onTap,
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          borderRadius: radius,
          child: pane,
        ),
      );
    }

    if (tokens.glassBlur > 0) {
      // RepaintBoundary because a BackdropFilter is one of the more expensive
      // things on the raster thread; this keeps it from being redrawn because
      // a sibling changed.
      pane = RepaintBoundary(
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: tokens.glassBlur,
            sigmaY: tokens.glassBlur,
          ),
          child: pane,
        ),
      );
    }

    // The shadow is outside the clip. Inside it, it would be clipped away and
    // paint for nothing.
    Widget result = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(borderRadius: radius, child: pane),
    );

    if (widget.onTap != null) {
      // Reduced motion is an accessibility setting, not a preference: when it
      // is on, the press still works, it just does not move.
      final animate = !MediaQuery.disableAnimationsOf(context);
      result = AnimatedScale(
        scale: _pressed && animate ? 0.97 : 1,
        duration: animate ? const Duration(milliseconds: 120) : Duration.zero,
        curve: Curves.easeOut,
        child: result,
      );
    }

    return result;
  }
}
