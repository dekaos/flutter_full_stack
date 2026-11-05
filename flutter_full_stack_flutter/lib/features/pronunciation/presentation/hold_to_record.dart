import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart'
    show GestureDisposition, OneSequenceGestureRecognizer;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_full_stack_flutter/theme/motion.dart';

/// The record button: held while the learner reads and let go when they
/// are done, as a voice message is sent - with the time an attempt may run
/// strung round it as beads, one a second.
///
/// At rest the beads ring the button faintly, a dial of the [seconds] there
/// are. Pressed, the button swells and they light up round it; as the
/// learner speaks a thread runs round through them, and each bead it
/// reaches pops like a soap bubble - what is left of the string is what is
/// left of the time, and the button counts it down. The last five turn
/// red again, and the button gives a little nudge each second. Under reduced
/// motion the beads simply go out and the count simply changes.
///
/// A press shorter than [tap] was a tap, not a hold: [onCancel] throws the
/// attempt away, and a bubble over the button says to hold it. The same
/// bubble offers the button, with the time there is, while [firstTime].
class HoldToRecord extends StatefulWidget {
  const HoldToRecord({
    required this.seconds,
    required this.recording,
    required this.label,
    required this.recordingLabel,
    required this.offer,
    required this.holdLonger,
    required this.onPress,
    required this.onRelease,
    required this.onCancel,
    this.firstTime = false,
    super.key,
  });

  /// The button's diameter; the beads ring it in [extent].
  static const size = 76.0;

  /// The square the button and its beads take.
  static const double extent = size + 40;

  /// Shorter than this, a press was a tap.
  static const tap = Duration(milliseconds: 300);

  /// How long the bubble saying to hold the button stays up.
  static const nudge = Duration(seconds: 3);

  /// From how many seconds left the beads hurry the learner.
  static const hurryFrom = 5;

  /// How long an attempt may run, one bead a second.
  final int seconds;

  /// Whether the microphone is open - from when it has opened, which is a
  /// moment after the press.
  final bool recording;

  /// What the button does, for a screen reader: "Hold to record".
  final String label;

  /// What it is doing while it records, with the seconds left.
  final String Function(int left) recordingLabel;

  /// The bubble offering the button while [firstTime].
  final String offer;

  /// The bubble after a tap.
  final String holdLonger;

  /// Pressed: the microphone should open.
  final VoidCallback onPress;

  /// Let go after a hold: what was said should be scored.
  final VoidCallback onRelease;

  /// Let go after a tap: what was recorded should be thrown away.
  final VoidCallback onCancel;

  /// Whether the learner has not recorded yet, and should be shown how.
  final bool firstTime;

  @override
  State<HoldToRecord> createState() => _HoldToRecordState();
}

class _HoldToRecordState extends State<HoldToRecord>
    with TickerProviderStateMixin {
  /// Swells the button and lights the beads as it is pressed.
  late final AnimationController _press = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 240),
    reverseDuration: const Duration(milliseconds: 280),
  );

  /// The time the attempt has run, `0` to `1` over [HoldToRecord.seconds].
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: Duration(seconds: widget.seconds),
  )..addListener(_count);

  /// The halo rippling out while the microphone is open.
  late final AnimationController _ripple = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  /// The whole seconds left, for the count and for a screen reader.
  late final ValueNotifier<int> _left = ValueNotifier(widget.seconds);

  bool _holding = false;

  /// Whether the press has lasted longer than [HoldToRecord.tap].
  bool _held = false;
  Timer? _tapping;

  /// Whether the last press was a tap, while its bubble is up.
  bool _tapped = false;
  Timer? _nudging;

  /// Taps so far, so each one shakes its bubble again.
  int _taps = 0;

  /// Whether [_clock] is running for an open microphone.
  bool _timing = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(HoldToRecord old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    if (widget.recording != _timing) {
      _timing = widget.recording;
      if (_timing) {
        _clock.forward(from: 0);
      } else {
        _clock
          ..stop()
          ..value = 0;
      }
    }
    final ripple = widget.recording && !context.still;
    if (ripple && !_ripple.isAnimating) {
      _ripple.repeat();
    } else if (!ripple && _ripple.isAnimating) {
      _ripple
        ..stop()
        ..value = 0;
    }
  }

  void _count() {
    final left = (widget.seconds * (1 - _clock.value)).ceil();
    if (left == _left.value) return;
    _left.value = left;
    // A tap on the hand for each of the last three.
    if (left > 0 && left <= 3) unawaited(HapticFeedback.selectionClick());
  }

  void _down() {
    _holding = true;
    _held = false;
    _tapping?.cancel();
    _tapping = Timer(HoldToRecord.tap, () => _held = true);
    _nudging?.cancel();
    setState(() => _tapped = false);
    _press.forward();
    unawaited(HapticFeedback.mediumImpact());
    widget.onPress();
  }

  void _up() {
    if (!_holding) return;
    _holding = false;
    _tapping?.cancel();
    _press.reverse();
    if (_held) {
      unawaited(HapticFeedback.lightImpact());
      widget.onRelease();
      setState(() {});
      return;
    }
    widget.onCancel();
    _nudging?.cancel();
    _nudging = Timer(HoldToRecord.nudge, () {
      if (mounted) setState(() => _tapped = false);
    });
    setState(() {
      _tapped = true;
      _taps++;
    });
  }

  /// A screen reader cannot hold: activating the button starts the
  /// attempt, and activating it again ends it.
  void _activate() {
    if (widget.recording) {
      widget.onRelease();
    } else {
      widget.onPress();
    }
  }

  @override
  void dispose() {
    _tapping?.cancel();
    _nudging?.cancel();
    _press.dispose();
    _clock.dispose();
    _ripple.dispose();
    _left.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final still = context.still;
    // Held, it turns from the call to action to the calm colour: the red is
    // already what it is at rest, and a change the eye can catch is the
    // point.
    final live = widget.recording || _holding;
    final fill = live ? scheme.secondary : scheme.primary;
    final ink = live ? scheme.onSecondary : scheme.onPrimary;
    final bubble = _tapped
        ? widget.holdLonger
        : widget.firstTime && !live
        ? widget.offer
        : null;

    return SizedBox.square(
      dimension: HoldToRecord.extent,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _Beads(
                press: _press,
                clock: _clock,
                ripple: _ripple,
                count: widget.seconds,
                recording: widget.recording,
                still: still,
                rest: scheme.primary,
                live: scheme.secondary,
                hurry: scheme.primary,
              ),
            ),
          ),
          ValueListenableBuilder<int>(
            valueListenable: _left,
            builder: (context, left, _) => Semantics(
              button: true,
              label: widget.recording
                  ? widget.recordingLabel(left)
                  : widget.label,
              onTap: _activate,
              excludeSemantics: true,
              child: RawGestureDetector(
                behavior: HitTestBehavior.opaque,
                gestures: {
                  _Hold: GestureRecognizerFactoryWithHandlers<_Hold>(
                    _Hold.new,
                    (hold) => hold
                      ..onPress = _down
                      ..onRelease = _up,
                  ),
                },
                child: AnimatedBuilder(
                  animation: Listenable.merge([_press, _clock]),
                  builder: (context, _) => _face(
                    theme,
                    fill: fill,
                    ink: ink,
                    left: left,
                    still: still,
                  ),
                ),
              ),
            ),
          ),
          // Over the button, pointing at it. Wider than the button's square,
          // which it is allowed to be: it is not something to tap.
          Positioned(
            left: -140,
            right: -140,
            bottom: HoldToRecord.extent - 2,
            child: IgnorePointer(
              child: Center(
                child: AnimatedSwitcher(
                  duration: context.motion(const Duration(milliseconds: 320)),
                  reverseDuration: context.motion(
                    const Duration(milliseconds: 160),
                  ),
                  switchInCurve: Curves.easeOutBack,
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: ScaleTransition(
                      alignment: Alignment.bottomCenter,
                      scale: animation,
                      child: child,
                    ),
                  ),
                  child: bubble == null
                      ? const SizedBox.shrink(key: ValueKey('no-bubble'))
                      : _Bubble(
                          key: ValueKey((bubble, _taps)),
                          text: bubble,
                          shake: _tapped && !still,
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// The button itself: swelling as it is pressed, and while it records,
  /// the seconds left in place of the microphone, landing with a little
  /// bounce each second - and, in the last few, a nudge.
  Widget _face(
    ThemeData theme, {
    required Color fill,
    required Color ink,
    required int left,
    required bool still,
  }) {
    final swell = Curves.easeOutBack.transform(_press.value);
    final elapsed = _clock.value * widget.seconds;
    // How far into its second the count is, `0` as it changes.
    final into = elapsed - elapsed.floor();
    final landing = widget.recording && !still
        ? math.pow(1 - (into / 0.25).clamp(0.0, 1.0), 2).toDouble()
        : 0.0;
    final nudging =
        widget.recording && !still && left <= HoldToRecord.hurryFrom;
    final tilt = nudging
        ? math.sin(into * math.pi * 6) * 0.08 * (1 - (into / 0.4).clamp(0, 1))
        : 0.0;

    return Transform.rotate(
      angle: tilt,
      child: Transform.scale(
        scale: 1 + 0.1 * swell,
        child: Container(
          width: HoldToRecord.size,
          height: HoldToRecord.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: fill,
            boxShadow: [
              BoxShadow(
                color: fill.withValues(alpha: 0.45),
                blurRadius: 10 + 8 * swell,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: widget.recording
              ? Transform.scale(
                  scale: 1 + 0.2 * landing,
                  child: Text(
                    '$left',
                    key: const Key('practice-record-left'),
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: ink,
                      fontWeight: FontWeight.w800,
                      height: 1,
                    ),
                  ),
                )
              : Icon(Icons.mic_rounded, size: 34, color: ink),
        ),
      ),
    );
  }
}

/// A press held on the button, from the finger going down to it coming up
/// - wherever it has wandered to in between, as long as it has not left
/// the screen.
///
/// It claims the press the moment it starts, so nothing else can take it:
/// a finger that drifts sideways while the learner reads is still holding
/// the button, not swiping to the next prompt.
class _Hold extends OneSequenceGestureRecognizer {
  VoidCallback? onPress;
  VoidCallback? onRelease;

  int? _pointer;

  @override
  void addAllowedPointer(PointerDownEvent event) {
    // One finger holds it; a second does nothing.
    if (_pointer != null) return;
    super.addAllowedPointer(event);
    _pointer = event.pointer;
    resolve(GestureDisposition.accepted);
    onPress?.call();
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event.pointer != _pointer) return;
    if (event is PointerUpEvent || event is PointerCancelEvent) _let(event);
  }

  @override
  void rejectGesture(int pointer) {
    if (pointer == _pointer) _letGo(pointer);
  }

  void _let(PointerEvent event) {
    stopTrackingPointer(event.pointer);
    _letGo(event.pointer);
  }

  void _letGo(int pointer) {
    if (_pointer != pointer) return;
    _pointer = null;
    onRelease?.call();
  }

  @override
  void didStopTrackingLastPointer(int pointer) {}

  @override
  void dispose() {
    final pointer = _pointer;
    if (pointer != null) stopTrackingPointer(pointer);
    _pointer = null;
    super.dispose();
  }

  @override
  String get debugDescription => 'hold';
}

/// The seconds an attempt may run, as beads round the button.
///
/// Bead `i` stands where the thread will be when second `i` is up, so the
/// thread reaches each just as it pops.
class _Beads extends CustomPainter {
  _Beads({
    required this.press,
    required this.clock,
    required this.ripple,
    required this.count,
    required this.recording,
    required this.still,
    required this.rest,
    required this.live,
    required this.hurry,
  }) : super(repaint: Listenable.merge([press, clock, ripple]));

  final Animation<double> press;
  final Animation<double> clock;
  final Animation<double> ripple;
  final int count;
  final bool recording;
  final bool still;
  final Color rest;
  final Color live;
  final Color hurry;

  /// How long a bead takes to pop, in seconds.
  static const _pop = 0.3;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    const button = HoldToRecord.size / 2;
    const ring = button + 15;
    final lit = recording ? 1.0 : Curves.easeOut.transform(press.value);
    final elapsed = clock.value * count;
    final left = count - elapsed;
    final calm = Color.lerp(rest, live, lit)!;
    // Into the last few seconds, turning to [hurry] over half of one.
    final hurrying = ((HoldToRecord.hurryFrom - left) * 2).clamp(0.0, 1.0);
    final colour = recording ? Color.lerp(calm, hurry, hurrying)! : calm;

    if (recording && !still) {
      final t = ripple.value;
      canvas.drawCircle(
        centre,
        button + 4 + 9 * t,
        Paint()..color = live.withValues(alpha: 0.2 * (1 - t)),
      );
    }

    // The thread, round as far as the time has gone.
    if (clock.value > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: centre, radius: ring),
        -math.pi / 2,
        2 * math.pi * clock.value,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round
          ..color = colour.withValues(alpha: 0.45),
      );
    }

    for (var i = 0; i < count; i++) {
      final angle = -math.pi / 2 + 2 * math.pi * (i + 1) / count;
      final direction = Offset(math.cos(angle), math.sin(angle));
      final at = centre + direction * ring;
      final gone = elapsed - (i + 1);
      if (gone < 0) {
        // Lit one after another round the ring as the button is pressed.
        final own = (lit * 1.6 - 0.6 * i / count).clamp(0.0, 1.0);
        canvas.drawCircle(
          at,
          2.2 + 1.8 * own,
          Paint()..color = colour.withValues(alpha: 0.35 + 0.65 * own),
        );
      } else if (!still && gone < _pop) {
        // Popped: a ring swelling and thinning away, a few drops flying off.
        final e = gone / _pop;
        final out = Curves.easeOut.transform(e);
        final fade = colour.withValues(alpha: 1 - e);
        canvas.drawCircle(
          at,
          4 + 6 * out,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6 * (1 - e)
            ..color = fade,
        );
        for (final spread in const [-0.9, 0.0, 0.9]) {
          final a = angle + spread;
          canvas.drawCircle(
            at + Offset(math.cos(a), math.sin(a)) * (5 + 9 * out),
            1.3 * (1 - e),
            Paint()..color = fade,
          );
        }
      } else {
        // Where it was.
        canvas.drawCircle(
          at,
          1.2,
          Paint()..color = colour.withValues(alpha: 0.2),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_Beads old) =>
      old.count != count ||
      old.recording != recording ||
      old.still != still ||
      old.rest != rest ||
      old.live != live ||
      old.hurry != hurry;
}

/// A speech bubble over the button, its tail pointing down at it - shaken
/// when it comes up after a tap, as a head is shaken.
class _Bubble extends StatelessWidget {
  const _Bubble({required this.text, required this.shake, super.key});

  final String text;
  final bool shake;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final bubble = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 240),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: scheme.inverseSurface,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: scheme.shadow.withValues(alpha: 0.18),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Text(
                text,
                textAlign: TextAlign.center,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: scheme.onInverseSurface,
                ),
              ),
            ),
          ),
          CustomPaint(
            size: const Size(16, 8),
            painter: _Tail(scheme.inverseSurface),
          ),
        ],
      ),
    );
    if (!shake) return bubble;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 520),
      builder: (context, t, child) => Transform.translate(
        offset: Offset(math.sin(t * math.pi * 5) * 7 * (1 - t), 0),
        child: child,
      ),
      child: bubble,
    );
  }
}

class _Tail extends CustomPainter {
  const _Tail(this.colour);

  final Color colour;

  @override
  void paint(Canvas canvas, Size size) => canvas.drawPath(
    Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close(),
    Paint()..color = colour,
  );

  @override
  bool shouldRepaint(_Tail old) => old.colour != colour;
}
