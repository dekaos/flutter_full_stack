import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_full_stack_flutter/theme/app_theme.dart';

/// The word hunt is played in space, so it is always dark: its screens take
/// the app's dark theme - or its high-contrast dark one, when the device
/// asks for more contrast - whatever the rest of the app is showing.
///
/// Everything on them still comes from that theme's colour scheme and
/// tokens, so the brand, the font and the contrast request all carry over.
/// A light theme here would be a white page over a night sky.
class HuntTheme extends StatelessWidget {
  const HuntTheme({required this.child, super.key});

  final Widget child;

  static final ThemeData _dark = AppTheme.dark();
  static final ThemeData _contrast = AppTheme.highContrastDark();

  @override
  Widget build(BuildContext context) => Theme(
    data: MediaQuery.highContrastOf(context) ? _contrast : _dark,
    child: child,
  );
}

/// The few colours that mean the same in every corner of space, which the
/// colour scheme has no slot for. Like the score colours in `AppTokens`,
/// each is a fixed meaning rather than decoration.
abstract final class HuntColours {
  /// Stars, points, the answer: gold is what the learner earns.
  static const gold = Color(0xFFFFD166);

  /// A shield, still up.
  static const shield = Color(0xFF7FDBFF);
}

/// Tells [onSize] how big [child] is laid out, after the frame, whenever
/// that changes - so the space behind a panel knows how much of it is
/// covered.
class Measured extends SingleChildRenderObjectWidget {
  const Measured({required this.onSize, required super.child, super.key});

  final ValueChanged<Size> onSize;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderMeasured(onSize);

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    (renderObject as _RenderMeasured).onSize = onSize;
  }
}

class _RenderMeasured extends RenderProxyBox {
  _RenderMeasured(this.onSize);

  ValueChanged<Size> onSize;
  Size? _told;

  @override
  void performLayout() {
    super.performLayout();
    final measured = size;
    if (measured == _told) return;
    _told = measured;
    WidgetsBinding.instance.addPostFrameCallback((_) => onSize(measured));
  }
}

/// Three stars, [earned] of them filled.
class StarRow extends StatelessWidget {
  const StarRow({required this.earned, this.size = 18, super.key});

  final int earned;
  final double size;

  @override
  Widget build(BuildContext context) {
    final empty = Theme.of(context).colorScheme.onSurfaceVariant.withValues(
      alpha: 0.5,
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 3; i++)
          Icon(
            i < earned ? Icons.star_rounded : Icons.star_outline_rounded,
            size: size,
            color: i < earned ? HuntColours.gold : empty,
          ),
      ],
    );
  }
}
