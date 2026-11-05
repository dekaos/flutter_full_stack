import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_full_stack_flutter/app/app_mark.dart';
import 'package:flutter_full_stack_flutter/theme/app_theme.dart';
import 'package:flutter_full_stack_flutter/theme/motion.dart';

/// The app's first two seconds: the native splash come to life, telling
/// what the app is for before it opens.
///
/// It starts on the very frame the system's splash shows - CNA's logo,
/// white on CNA's red, in the middle - so the hand-over from the native
/// splash cannot be seen. Then, in a little under two seconds:
///
/// 1. a speech bubble pops out of the logo's A;
/// 2. it speaks - its voice moving, as a voice message's does;
/// 3. what it said turns into a tick - the bars drawing in to dots, the
///    dots lining up, the tick drawn through them - and the bubble hops
///    with a "pop!": said, and said right;
/// 4. the logo swells and the red clears, and the app is there underneath,
///    rising in as it always does.
///
/// The app itself is only built as it is revealed, so its own entrance
/// plays as the splash clears instead of unseen behind it. A tap skips
/// straight to the reveal. Under reduced motion nothing moves: the logo
/// simply gives way to the app.
class Splash extends StatefulWidget {
  const Splash({required this.child, super.key});

  /// The app, revealed underneath.
  final Widget child;

  /// How long the whole of it takes.
  static const duration = Duration(milliseconds: 1950);

  /// Under reduced motion: the mark, then the app, with nothing travelling.
  static const still = Duration(milliseconds: 450);

  /// The colour behind the mark: CNA's red, the native splash's own.
  static const Color ground = Brand.red;

  /// How wide the mark's box is, as the native splash shows it: the logo
  /// is most of its width ([AppMark.logoShare]), 176 dp - as wide as it can
  /// be and still show whole inside the circle Android 12 shows a splash
  /// icon in.
  static const markSize = 200.0;

  @override
  State<Splash> createState() => _SplashState();
}

class _SplashState extends State<Splash> with SingleTickerProviderStateMixin {
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: Splash.duration,
  )..addStatusListener(_finished);

  /// Gone for good, once the app is fully revealed.
  bool _done = false;

  /// When, as a fraction of the clock, the app starts to show through.
  double get _reveal =>
      _clock.duration == Splash.still ? 0 : _Beats.reveal / _Beats.length;

  void _finished(AnimationStatus status) {
    if (status == AnimationStatus.completed) setState(() => _done = true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_clock.isAnimating || _clock.value > 0 || _done) return;
    if (context.still) _clock.duration = Splash.still;
    _clock.forward().ignore();
  }

  /// A tap goes straight to the reveal.
  void _skip() {
    if (_clock.value < _reveal) {
      _clock
        ..value = _reveal
        ..forward().ignore();
    }
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_done) return widget.child;
    return AnimatedBuilder(
      animation: _clock,
      builder: (context, _) {
        final t = _clock.value;
        final revealing = t >= _reveal;
        final clearing = revealing && _reveal < 1
            ? ((t - _reveal) / (1 - _reveal)).clamp(0.0, 1.0)
            : 0.0;
        final pose = _clock.duration == Splash.still
            ? const MarkPose()
            : _Beats.poseAt(t * _Beats.length);
        return Stack(
          fit: StackFit.expand,
          children: [
            if (revealing) widget.child,
            IgnorePointer(
              ignoring: revealing,
              child: GestureDetector(
                onTap: _skip,
                child: Opacity(
                  opacity: 1 - Curves.easeIn.transform(clearing),
                  child: AnnotatedRegion<SystemUiOverlayStyle>(
                    value: SystemUiOverlayStyle.light,
                    child: ColoredBox(
                      color: Splash.ground,
                      child: Center(
                        child: Transform.scale(
                          // The logo swells towards the learner as the red
                          // clears: the app opens out of it.
                          scale: 1 + 0.35 * Curves.easeIn.transform(clearing),
                          child: SizedBox.square(
                            dimension: Splash.markSize,
                            child: CustomPaint(
                              painter: AppMark(pose: pose),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// The splash's beats, in seconds - kept together so its story can be read
/// in one place.
abstract final class _Beats {
  static const length = 1.95;

  /// The bubble springs out of the logo's A.
  static const bubbleFrom = 0.12;
  static const bubbleTo = 0.6;

  /// It speaks: the voice moves, and comes back to rest.
  static const speakFrom = 0.35;
  static const speakTo = 1.0;

  /// What it said turns into a tick.
  static const tickFrom = 0.95;
  static const tickTo = 1.4;

  /// The tick lands: the bubble hops, and its "pop!" flies out.
  static const hopFrom = 1.28;
  static const hopTo = 1.5;
  static const burstFrom = 1.3;
  static const burstTo = 1.75;

  /// The app starts to show through.
  static const reveal = 1.45;

  /// How fast each bar moves while it speaks, and where in its swing it
  /// starts: unevenly, as a voice does.
  static const _rates = [3.1, 4.3, 2.7, 3.7, 5.0];
  static const _phases = [0.2, 0.9, 0.0, 0.55, 1.3];

  static double _span(double s, double from, double to) =>
      ((s - from) / (to - from)).clamp(0.0, 1.0);

  /// The mark [s] seconds in.
  static MarkPose poseAt(double s) {
    // How much it is speaking: up from rest and back to it.
    final speaking = math.sin(math.pi * _span(s, speakFrom, speakTo));
    return MarkPose(
      bubble:
          Curves.elasticOut.transform(_span(s, bubbleFrom, bubbleTo)) +
          0.1 * math.sin(math.pi * _span(s, hopFrom, hopTo)),
      // Exactly at rest when it is not speaking - sin(pi) is not quite
      // nought - so the voice it ends on is the one it started with.
      levels: speaking < 1e-9
          ? MarkPose.rest
          : [
              for (var i = 0; i < 5; i++)
                MarkPose.rest[i] * (1 - speaking) +
                    speaking *
                        (0.25 +
                            0.75 *
                                math
                                    .sin(
                                      2 * math.pi * _rates[i] * s + _phases[i],
                                    )
                                    .abs()),
            ],
      tick: _span(s, tickFrom, tickTo),
      burst: _span(s, burstFrom, burstTo),
    );
  }
}
