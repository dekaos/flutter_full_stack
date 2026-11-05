import 'package:flutter/widgets.dart';

/// Motion that keeps to the reduced-motion setting, said once instead of at
/// every animation.
///
/// Reduced motion is an accessibility setting, not a preference: under it
/// nothing travels, but nothing is withheld either - an animation lands
/// where it would have ended.
extension Motion on BuildContext {
  /// Whether the device asks for reduced motion.
  bool get still => MediaQuery.disableAnimationsOf(this);

  /// [duration], or none under reduced motion: for implicit animations,
  /// which then simply arrive.
  Duration motion(Duration duration) => still ? Duration.zero : duration;

  /// Plays [controller] through once, if it has not started yet - or, under
  /// reduced motion, puts it straight at its end. For an arrival: safe to
  /// call from `didChangeDependencies`, which runs more than once.
  void playOnce(AnimationController controller) {
    if (still) {
      controller.value = 1;
    } else if (!controller.isAnimating && controller.value == 0) {
      controller.forward().ignore();
    }
  }
}
