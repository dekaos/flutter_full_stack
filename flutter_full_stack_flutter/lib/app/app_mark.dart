import 'dart:math' as math;

import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_full_stack_flutter/app/cna_logo.dart';
import 'package:flutter_full_stack_flutter/theme/app_theme.dart';

/// The app's mark: CNA's logo, white on CNA's red - and, as the splash
/// plays it, a speech bubble that pops out of the logo's A and speaks, and
/// the stars of a score.
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
/// the stars, which only the animation shows, reach out of it.
class AppMark extends CustomPainter {
  const AppMark({this.pose = const MarkPose()});

  /// Where the mark is in its animation; at rest, it is the icon.
  final MarkPose pose;

  /// The logo's white, and the bubble's.
  static const paper = Color(0xFFFFFFFF);

  /// The voice's red: CNA's own.
  static const Color voice = Brand.red;

  /// A score's gold.
  static const gold = Color(0xFFFFC94A);

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
    _stars(canvas);
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
    final bars = Paint()..color = voice;
    for (var i = 0; i < 5; i++) {
      final height = math.max(width, tallest * pose.levels[i]);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(
              _bubble.center.dx + (i - 2) * 0.04,
              _bubble.center.dy,
            ),
            width: width,
            height: height,
          ),
          const Radius.circular(width / 2),
        ),
        bars,
      );
    }
    canvas.restore();
  }

  /// Up to three stars over the logo's C and N - the score - each popping
  /// in as [MarkPose.stars] passes its number.
  void _stars(Canvas canvas) {
    const spots = [Offset(0.16, 0.3), Offset(0.28, 0.24), Offset(0.4, 0.22)];
    for (final (i, spot) in spots.indexed) {
      final pop = (pose.stars - i).clamp(0.0, 1.0);
      if (pop <= 0) continue;
      final radius = Curves.elasticOut.transform(pop) * 0.04;
      canvas.drawPath(_star(spot, radius), Paint()..color = gold);
    }
  }

  static Path _star(Offset centre, double radius) {
    final star = Path();
    for (var k = 0; k < 10; k++) {
      final r = k.isEven ? radius : radius * 0.48;
      final a = -math.pi / 2 + k * math.pi / 5;
      final p = centre + Offset(math.cos(a) * r, math.sin(a) * r);
      k == 0 ? star.moveTo(p.dx, p.dy) : star.lineTo(p.dx, p.dy);
    }
    return star..close();
  }

  @override
  bool shouldRepaint(AppMark old) => old.pose != pose;
}

/// The mark at a moment of its animation. The default is the mark at rest:
/// the logo alone - the icon, and the native splash.
@immutable
class MarkPose {
  const MarkPose({this.bubble = 0, this.levels = rest, this.stars = 0});

  /// The voice at rest: a word's outline, highest in the middle.
  static const rest = [0.38, 0.68, 1.0, 0.78, 0.48];

  /// How far the speech bubble has grown out of the logo, `0` to `1` - a
  /// little past one, as it springs.
  final double bubble;

  /// Each bar's height, `0` to `1` of the tallest.
  final List<double> levels;

  /// How many of the three stars have popped in, fractionally.
  final double stars;

  @override
  bool operator ==(Object other) =>
      other is MarkPose &&
      other.bubble == bubble &&
      listEquals(other.levels, levels) &&
      other.stars == stars;

  @override
  int get hashCode => Object.hash(bubble, Object.hashAll(levels), stars);
}
