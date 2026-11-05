import 'dart:math' as math;

import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_full_stack_flutter/app/cna_logo.dart';
import 'package:flutter_full_stack_flutter/theme/app_theme.dart';

/// The app's mark: CNA's logo, white on CNA's red - and, as the splash
/// plays it, a speech bubble that pops out of the logo's A, speaks, and
/// turns what it said into a tick: said, and said right.
///
/// Drawn here once, for everything that shows it: the launcher icons and
/// the native splash are rendered from it at rest
/// (`tool/render_branding.dart`), and the animated splash (`Splash`) poses
/// it moment by moment. So the icon on the home screen, the splash the
/// system shows and the one the app plays are the same drawing, and cannot
/// drift apart.
///
/// Laid out on a unit square - the mark's box - and scaled to whatever size
/// it is painted at. Only the logo is inside the box at rest; the bubble and
/// its burst, which only the animation shows, reach out of it.
class AppMark extends CustomPainter {
  const AppMark({this.pose = const MarkPose()});

  /// Where the mark is in its animation; at rest, it is the icon.
  final MarkPose pose;

  /// The logo's white, and the bubble's.
  static const paper = Color(0xFFFFFFFF);

  /// The voice's red: CNA's own.
  static const Color voice = Brand.red;

  /// How wide the logo is, as a share of the box. Its height follows from
  /// its own proportions.
  static const logoShare = 0.88;

  /// Where the bubble's tail starts, just off the apex of the logo's A, and
  /// the bubble it grows out of - up and to the right of it.
  static const _tail = Offset(0.785, 0.365);
  static const _bubble = Rect.fromLTRB(0.71, 0.13, 0.97, 0.3);

  @override
  void paint(Canvas canvas, Size size) {
    canvas
      ..save()
      ..scale(size.width, size.height);
    _logo(canvas);
    _burst(canvas);
    _speech(canvas);
    canvas.restore();
  }

  void _logo(Canvas canvas) {
    const scale = logoShare / CnaLogo.width;
    const height = logoShare / CnaLogo.aspect;
    canvas
      ..save()
      ..translate((1 - logoShare) / 2, (1 - height) / 2)
      ..scale(scale)
      ..drawPath(CnaLogo.path, Paint()..color = paper)
      ..restore();
  }

  /// The bubble, grown out of the A as [MarkPose.bubble] goes to one, with
  /// a voice in it as tall as [MarkPose.levels] say.
  void _speech(Canvas canvas) {
    final pop = pose.bubble;
    if (pop <= 0) return;
    canvas
      ..save()
      ..translate(_tail.dx, _tail.dy)
      ..scale(pop)
      ..translate(-_tail.dx, -_tail.dy);
    final bubble = Path.combine(
      PathOperation.union,
      Path()..addRRect(
        RRect.fromRectAndRadius(_bubble, const Radius.circular(0.06)),
      ),
      Path()
        ..moveTo(_bubble.left + 0.035, _bubble.bottom - 0.03)
        ..quadraticBezierTo(
          _bubble.left + 0.02,
          _tail.dy - 0.03,
          _tail.dx,
          _tail.dy,
        )
        ..quadraticBezierTo(
          _bubble.left + 0.06,
          _bubble.bottom + 0.01,
          _bubble.left + 0.1,
          _bubble.bottom - 0.01,
        )
        ..close(),
    );
    canvas.drawPath(bubble, Paint()..color = paper);

    const width = 0.022;
    const tallest = 0.11;
    final ink = Paint()..color = voice;
    // Gathering: the bars draw in to dots, and the dots line up on the
    // tick. Then the tick is drawn through them, in the voice's own ink.
    final gather = Curves.easeInOut.transform(
      (pose.tick / _gathered).clamp(0.0, 1.0),
    );
    final drawn = Curves.easeOut.transform(
      ((pose.tick - _gathered) / (1 - _gathered)).clamp(0.0, 1.0),
    );
    final tick = _tick.computeMetrics().single;
    for (var i = 0; i < 5; i++) {
      // Where along the tick this one's dot goes, and whether the stroke
      // has got there yet - if it has, the dot is part of it.
      final along = i / 4;
      if (drawn > 0 && drawn >= along) continue;
      final dot = tick.getTangentForOffset(tick.length * along)!.position;
      final bar = Offset(_bubble.center.dx + (i - 2) * 0.04, _bubble.center.dy);
      final height = math.max(width, tallest * pose.levels[i]);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset.lerp(bar, dot, gather)!,
            width: width,
            height: height + (width - height) * gather,
          ),
          const Radius.circular(width / 2),
        ),
        ink,
      );
    }
    if (drawn > 0) {
      canvas.drawPath(
        tick.extractPath(0, tick.length * drawn),
        Paint()
          ..color = voice
          ..style = PaintingStyle.stroke
          ..strokeWidth = width
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }
    canvas.restore();
  }

  /// How much of [MarkPose.tick] the bars take to gather on it.
  static const _gathered = 0.45;

  /// The tick the voice turns into, in the middle of the bubble: down to
  /// the left, then a long stroke up to the right.
  static final Path _tick = Path()
    ..moveTo(_bubble.center.dx - 0.052, _bubble.center.dy + 0.002)
    ..lineTo(_bubble.center.dx - 0.016, _bubble.center.dy + 0.036)
    ..lineTo(_bubble.center.dx + 0.056, _bubble.center.dy - 0.038);

  /// The bubble's "pop!" as the tick lands: short strokes flying out from
  /// it, up and to the sides - never down, over the logo - and fading as
  /// they go.
  void _burst(Canvas canvas) {
    final out = pose.burst;
    if (out <= 0 || out >= 1) return;
    final travel = Curves.easeOut.transform(out);
    final ray = Paint()
      ..color = paper.withValues(alpha: 1 - out)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.014 * (1 - 0.5 * out)
      ..strokeCap = StrokeCap.round;
    final centre = _bubble.center;
    for (final degrees in const [-165, -128, -92, -56, -20, 16]) {
      final a = degrees * math.pi / 180;
      final direction = Offset(math.cos(a), math.sin(a));
      // Out past the bubble's edge, wider than tall as the bubble is.
      final reach = Offset(direction.dx * 1.35, direction.dy);
      canvas.drawLine(
        centre + reach * (0.11 + 0.05 * travel),
        centre + reach * (0.13 + 0.1 * travel),
        ray,
      );
    }
  }

  @override
  bool shouldRepaint(AppMark old) => old.pose != pose;
}

/// The mark at a moment of its animation. The default is the mark at rest:
/// the logo alone - the icon, and the native splash.
@immutable
class MarkPose {
  const MarkPose({
    this.bubble = 0,
    this.levels = rest,
    this.tick = 0,
    this.burst = 0,
  });

  /// The voice at rest: a word's outline, highest in the middle.
  static const rest = [0.38, 0.68, 1.0, 0.78, 0.48];

  /// How far the speech bubble has grown out of the logo, `0` to `1` - a
  /// little past one, as it springs.
  final double bubble;

  /// Each bar's height, `0` to `1` of the tallest.
  final List<double> levels;

  /// How far the voice has turned into a tick, `0` to `1`: its bars
  /// gathering into dots on the tick, then the tick drawn through them.
  final double tick;

  /// How far the bubble's "pop!" has flown out, `0` to `1`.
  final double burst;

  @override
  bool operator ==(Object other) =>
      other is MarkPose &&
      other.bubble == bubble &&
      listEquals(other.levels, levels) &&
      other.tick == tick &&
      other.burst == burst;

  @override
  int get hashCode => Object.hash(bubble, Object.hashAll(levels), tick, burst);
}
