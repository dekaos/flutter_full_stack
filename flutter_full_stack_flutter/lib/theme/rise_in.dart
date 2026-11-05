import 'package:flutter/material.dart';
import 'package:flutter_full_stack_flutter/theme/motion.dart';
import 'package:flutter_full_stack_flutter/theme/reveal.dart';

/// Fades and lifts [child] into place once, after [delay].
///
/// Staggering a few of these is what makes a screen feel composed rather than
/// stamped: the eye is led through the hierarchy in the order the designer
/// meant, instead of everything arriving at once.
///
/// It runs on arrival and never again, so nothing is repainting at rest. Under
/// reduced motion the child is simply there.
///
/// The fade is a [Reveal], so glass rising in frosts as it comes rather than
/// arriving clear and frosting all at once at the end.
class RiseIn extends StatefulWidget {
  const RiseIn({
    required this.child,
    this.delay = Duration.zero,
    super.key,
  });

  final Widget child;
  final Duration delay;

  @override
  State<RiseIn> createState() => _RiseInState();
}

class _RiseInState extends State<RiseIn> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );
  late final Animation<double> _curve = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );

  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;

    if (context.still) {
      _controller.value = 1;
    } else {
      Future<void>.delayed(widget.delay, () {
        if (mounted) _controller.forward();
      }).ignore();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Reveal(
      opacity: _curve,
      child: AnimatedBuilder(
        animation: _curve,
        builder: (context, child) => Transform.translate(
          offset: Offset(0, 18 * (1 - _curve.value)),
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}
