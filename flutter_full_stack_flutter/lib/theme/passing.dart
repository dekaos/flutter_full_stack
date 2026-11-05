import 'package:flutter/animation.dart';

/// Tells which moments an animation went past on its latest frame: what
/// keeps a sound on the moment it belongs to - a bell as the clock strikes,
/// a meow as the cat starts to wash - when both run off the same clock.
///
/// Only while it plays: an animation put straight at its end, as reduced
/// motion does, or stopped short goes past nothing, so nothing is set off
/// out of turn.
class Passing {
  double _last = 0;

  /// Those of [moments] - `(at, what)`, `at` a value of [controller] - that
  /// it went past since this was last asked, in the order given.
  List<T> passed<T>(
    AnimationController controller,
    Iterable<(double, T)> moments,
  ) {
    final before = _last;
    final now = _last = controller.value;
    if (!controller.isAnimating) return const [];
    return [
      for (final (at, what) in moments)
        if (before < at && at <= now) what,
    ];
  }
}
