import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter/painting.dart';
import 'package:flutter_full_stack_flutter/theme/scene_tone.dart';

/// A colour intent: a hue, how vivid, and how bright within the scene's band.
///
/// Scenes never hold a [Color]. They say "a warm terracotta, fairly dark",
/// and the theme's [SceneTone] decides what that is on a light screen and on
/// a dark one. That is what keeps every scene legible behind text without
/// anyone checking it colour by colour.
@immutable
class Tint {
  const Tint(this.hue, this.saturation, this.level);

  /// Degrees on the colour wheel: 0 red, 30 orange, 50 yellow, 120 green,
  /// 200 sky, 230 blue, 280 violet, 330 pink.
  final double hue;

  /// HSL saturation, `0` (grey) to `1`. Above about `0.7` stops being sober.
  final double saturation;

  /// `0` is the darkest the band allows, `1` the lightest.
  final double level;

  /// The same material, [by] lighter (or darker, if negative).
  Tint shade(double by) => Tint(hue, saturation, level + by);

  /// The same material at another [level].
  Tint at(double level) => Tint(hue, saturation, level);

  @override
  bool operator ==(Object other) =>
      other is Tint &&
      other.hue == hue &&
      other.saturation == saturation &&
      other.level == level;

  @override
  int get hashCode => Object.hash(hue, saturation, level);
}

/// A point in the scene's world: `x` runs down to the right, `y` down to the
/// left, `z` up. One unit is one tile of the island.
typedef V3 = ({double x, double y, double z});

/// Everything a scene is drawn with.
///
/// A scene is a small floating island seen in isometric projection, standing
/// in a sky of its own. The island is [span] tiles square, its back corner at
/// world `(0, 0, 0)`, and it sits along the bottom of the screen, under where
/// the deck and the record button are, so the deck reads as floating above
/// the world it describes. Everything above the island - sky, sun, far hills
/// - is drawn in screen fractions instead, because it is backdrop, not world.
///
/// Draw back to front: the painter has no depth buffer, so whatever is drawn
/// later covers what was drawn before. Within the island, that means smaller
/// `x + y` first.
class IsoStage {
  IsoStage(
    this.canvas,
    this.size,
    this.t,
    this.tone, {
    this.clear = EdgeInsets.zero,
    SceneTone? world,
  }) : world = world ?? tone;

  final Canvas canvas;
  final Size size;

  /// How far the arrival is, `0` to `1`. A scene at `1` is at rest.
  final double t;

  /// The band the backdrop - sky, sun, clouds, far hills - is painted in.
  final SceneTone tone;

  /// The wider band for the world on the island: everything drawn inside
  /// [rising]. It has the room for real light that the sky does not.
  final SceneTone world;

  /// How much of the canvas, from each edge, the page covers with its own
  /// things - the deck at the top, the record button at the bottom. The sky
  /// still runs under them; the island is stood in what is left, so it is
  /// seen whole instead of behind a button.
  final EdgeInsets clear;

  /// The island is this many tiles along each side.
  static const span = 6.0;

  /// How deep the soil under the grass is, in tiles.
  static const soil = 0.9;

  /// How far the rock under the island hangs, in tiles.
  static const rock = 1.7;

  static final double _cos = math.cos(math.pi / 6);
  static const _sin = 0.5;

  /// Pixels per tile. The island takes most of the width on a phone, is
  /// capped on a tablet, and shrinks when the screen is short (a phone on
  /// its side) so it never climbs over the headline.
  late final double unit = math.min(
    math.min(size.width * 0.92, 600) / (2 * span * _cos),
    // The clear stretch must hold the island and what stands on it - about
    // [headroom] tiles above the back corner. A phone on its side has
    // almost no clear stretch at all, and then half the screen is used
    // anyway: a small island behind the controls beats a speck.
    math.max(size.height - clear.vertical, size.height * 0.5) /
        (2 * span * _sin + soil + rock + headroom),
  );

  /// How far above the island's back corner the tallest things on it reach,
  /// in tiles, for sizing the island to the clear stretch.
  static const headroom = 3.0;

  /// The screen point of world `(0, 0, 0)`, the island's back corner. The
  /// island hangs just above whatever covers the bottom of the canvas.
  late final Offset origin = Offset(
    size.width / 2,
    size.height -
        clear.bottom -
        unit * (2 * span * _sin + soil + rock) -
        size.height * 0.015,
  );

  // ---------------------------------------------------------------- colour --

  final Map<Tint, Color> _sky = {};
  final Map<Tint, Color> _world = {};
  bool _inWorld = false;

  /// The colour [tint] is on this theme: in the world's band inside
  /// [rising], in the sky's everywhere else. Scenes do not choose - where a
  /// thing is drawn decides how much light it may have.
  Color colour(Tint tint) {
    final band = _inWorld ? world : tone;
    return (_inWorld ? _world : _sky).putIfAbsent(
      tint,
      () => band.color(tint.hue, tint.saturation, tint.level),
    );
  }

  /// A fill of [tint].
  Paint fill(Tint tint) => Paint()
    ..color = colour(tint)
    ..isAntiAlias = true;

  /// A stroke of [tint], [width] tiles wide.
  Paint stroke(Tint tint, double width) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = width * unit
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..color = colour(tint);

  // ------------------------------------------------------------- geometry --

  /// The screen point of a world point.
  Offset at(double x, double y, [double z = 0]) => origin.translate(
    (x - y) * _cos * unit,
    (x + y) * _sin * unit - z * unit,
  );

  /// A screen point given as fractions of the canvas, for backdrop.
  Offset screen(double fx, double fy) =>
      Offset(size.width * fx, size.height * fy);

  /// The polygon through world points [points].
  Path face(List<V3> points) {
    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final p = at(points[i].x, points[i].y, points[i].z);
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    return path..close();
  }

  /// The ellipse a horizontal circle of radius [r] at [x], [y], [z] projects
  /// to.
  Rect disc(double x, double y, double z, double r) => Rect.fromCenter(
    center: at(x, y, z),
    width: 2 * r * math.sqrt2 * _cos * unit,
    height: 2 * r * math.sqrt2 * _sin * unit,
  );

  // ------------------------------------------------------------ animation --

  /// The eased progress of one beat of the arrival, from [begin] to [end] of
  /// the whole. Staggered beats are what make a scene assemble as a little
  /// story instead of fading in as a picture.
  double phase(double begin, double end, [Curve curve = Curves.easeOutCubic]) =>
      curve.transform(((t - begin) / (end - begin)).clamp(0.0, 1.0));

  /// A pop: `0` to `1` with a little overshoot.
  double pop(double begin, double end) => phase(begin, end, Curves.easeOutBack);

  /// How high above its place something still is while it drops in, in
  /// tiles: [from] at [begin], landing with a bounce by [end].
  double drop(double begin, double end, {double from = 5}) =>
      from * (1 - phase(begin, end, Curves.bounceOut));

  /// Runs [draw] for something that drops into place between [begin] and
  /// [end], handing it how many tiles above its place it still is. Nothing
  /// is drawn before its beat, so a house does not hang in the sky waiting
  /// for the island to arrive, and it fades in over the first part of its
  /// fall instead of appearing whole out of nowhere.
  void dropping(
    double begin,
    double end,
    void Function(double lift) draw, {
    double from = 6,
  }) {
    if (t < begin) return;
    final lift = drop(begin, end, from: from);
    faded(phase(begin, begin + (end - begin) * 0.25), () => draw(lift));
  }

  /// Runs [draw] with the world raised into place: the island and everything
  /// on it come up from below the screen between [begin] and [end], settling
  /// with a small overshoot.
  void rising(double begin, double end, void Function() draw) {
    final p = phase(begin, end, Curves.easeOutBack);
    canvas
      ..save()
      ..translate(0, (1 - p) * size.height * 0.6);
    final outer = _inWorld;
    _inWorld = true;
    draw();
    _inWorld = outer;
    canvas.restore();
  }

  /// Runs [draw] scaled by [scale] about [anchor]; nothing when it is zero.
  void scaled(Offset anchor, double scale, void Function() draw) {
    if (scale <= 0) return;
    canvas
      ..save()
      ..translate(anchor.dx, anchor.dy)
      ..scale(scale)
      ..translate(-anchor.dx, -anchor.dy);
    draw();
    canvas.restore();
  }

  /// Runs [draw] at [opacity]. A layer is only made when it is needed.
  void faded(double opacity, void Function() draw) {
    if (opacity <= 0) return;
    if (opacity >= 1) return draw();
    canvas.saveLayer(
      null,
      Paint()..color = Color.fromRGBO(0, 0, 0, opacity),
    );
    draw();
    canvas.restore();
  }

  // -------------------------------------------------------------- backdrop --

  /// The sky: a vertical wash from [top] to [horizon], the whole canvas.
  void sky(Tint top, Tint horizon) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.linear(
          rect.topCenter,
          rect.bottomCenter,
          [colour(top), colour(horizon)],
        ),
    );
  }

  /// A sun or moon at screen fraction [fx], [fy], [radius] tiles across, with
  /// [rings] soft halos of [halo] around it.
  void sun(
    double fx,
    double fy,
    double radius,
    Tint body,
    Tint halo, {
    int rings = 3,
  }) {
    final c = screen(fx, fy);
    for (var i = rings; i > 0; i--) {
      canvas.drawCircle(
        c,
        radius * unit * (1 + i * 0.45),
        fill(halo.shade(0.04 * (rings - i))),
      );
    }
    // A light is never darker than its own glow. Asked for a body below the
    // innermost ring, the sun would read as a dark disc in a bright ring - on
    // the dark theme, where the band is shallow, an olive doughnut.
    final glow = halo.level + 0.04 * (rings - 1);
    final core = body.level <= glow ? body.at(glow + 0.06) : body;
    canvas.drawCircle(c, radius * unit, fill(core));
  }

  /// A soft cloud, [width] tiles wide, centred on the screen point [c]:
  /// round lobes over a flat base, lit from above.
  void cloud(Offset c, double width, Tint tint) {
    final w = width * unit;
    Path body(double dy) => Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: c.translate(0, dy),
            width: w,
            height: w * 0.28,
          ),
          Radius.circular(w * 0.14),
        ),
      )
      ..addOval(
        Rect.fromCircle(
          center: c.translate(-w * 0.16, -w * 0.12 + dy),
          radius: w * 0.21,
        ),
      )
      ..addOval(
        Rect.fromCircle(
          center: c.translate(w * 0.13, -w * 0.08 + dy),
          radius: w * 0.17,
        ),
      );
    // The shaded underside first, the lit body a little above it.
    canvas
      ..drawPath(body(w * 0.04), fill(tint.shade(-0.12)))
      ..drawPath(body(0), fill(tint));
  }

  /// A line of far hills across the screen, their base at screen fraction
  /// [baseline], peaking [height] tiles above it. [seed] varies the profile,
  /// so two ridges in one scene do not repeat each other.
  void ridge(double baseline, double height, Tint tint, {int seed = 0}) {
    final base = size.height * baseline;
    final path = Path()..moveTo(0, size.height);
    const steps = 48;
    for (var i = 0; i <= steps; i++) {
      final f = i / steps;
      final wave =
          0.55 * math.sin(f * math.pi * 2.2 + seed * 1.7) +
          0.3 * math.sin(f * math.pi * 5.3 + seed * 0.9) +
          0.15 * math.sin(f * math.pi * 11.0 + seed * 2.3);
      path.lineTo(size.width * f, base - height * unit * (0.6 + 0.4 * wave));
    }
    path
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(path, fill(tint));
  }

  // ---------------------------------------------------------------- island --

  /// The floating island: a grass top, layered soil, and rock hanging below.
  /// [strata] is how many bands of soil show on the sides.
  void island({
    required Tint grass,
    required Tint earth,
    required Tint stone,
    int strata = 3,
  }) {
    // Rock hanging under the soil, narrowing to a ragged point. Drawn as the
    // two visible faces of an uneven inverted pyramid.
    const bottom = -soil;
    const tip = (x: span * 0.55, y: span * 0.6, z: bottom - rock);
    const shelf = (x: span * 0.82, y: span * 0.84, z: bottom - rock * 0.55);
    canvas
      ..drawPath(
        face([
          (x: 0, y: span, z: bottom),
          (x: span * 0.5, y: span, z: bottom),
          (x: span, y: span, z: bottom),
          shelf,
          tip,
          (x: span * 0.2, y: span * 0.9, z: bottom - rock * 0.5),
        ]),
        fill(stone),
      )
      ..drawPath(
        face([
          (x: span, y: span, z: bottom),
          (x: span, y: 0, z: bottom),
          (x: span * 0.92, y: span * 0.2, z: bottom - rock * 0.45),
          tip,
          shelf,
        ]),
        fill(stone.shade(-0.14)),
      );

    // Soil, in bands that darken with depth.
    for (var i = 0; i < strata; i++) {
      final top = -soil * i / strata;
      final under = -soil * (i + 1) / strata;
      final band = earth.shade(-0.07 * i);
      canvas
        ..drawPath(
          face([
            (x: 0, y: span, z: top),
            (x: span, y: span, z: top),
            (x: span, y: span, z: under),
            (x: 0, y: span, z: under),
          ]),
          fill(band),
        )
        ..drawPath(
          face([
            (x: span, y: span, z: top),
            (x: span, y: 0, z: top),
            (x: span, y: 0, z: under),
            (x: span, y: span, z: under),
          ]),
          fill(band.shade(-0.12)),
        );
    }

    // The grass, with a lip of it curling over the soil edge.
    const lip = 0.16;
    canvas
      ..drawPath(
        face([
          (x: 0, y: span, z: 0),
          (x: span, y: span, z: 0),
          (x: span, y: span, z: -lip),
          (x: 0, y: span, z: -lip),
        ]),
        fill(grass.shade(-0.1)),
      )
      ..drawPath(
        face([
          (x: span, y: span, z: 0),
          (x: span, y: 0, z: 0),
          (x: span, y: 0, z: -lip),
          (x: span, y: span, z: -lip),
        ]),
        fill(grass.shade(-0.2)),
      )
      ..drawPath(
        face([
          (x: 0, y: 0, z: 0),
          (x: span, y: 0, z: 0),
          (x: span, y: span, z: 0),
          (x: 0, y: span, z: 0),
        ]),
        fill(grass),
      );
  }

  /// A flat patch on the ground from [x], [y], [w] by [d] tiles, at height
  /// [z] - a path, a pond, a plaza.
  void patch(
    double x,
    double y,
    double w,
    double d,
    Tint tint, {
    double z = 0.002,
  }) {
    canvas.drawPath(
      face([
        (x: x, y: y, z: z),
        (x: x + w, y: y, z: z),
        (x: x + w, y: y + d, z: z),
        (x: x, y: y + d, z: z),
      ]),
      fill(tint),
    );
  }

  /// A soft round shadow on the ground under something at [x], [y].
  void shadow(double x, double y, double r, Tint ground) {
    canvas.drawOval(disc(x, y, 0.002, r), fill(ground.shade(-0.14)));
  }

  // ---------------------------------------------------------------- solids --

  /// A box from [x], [y], [z], [w] by [d] tiles and [h] tall.
  ///
  /// Lit from the upper left: the top is the lightest face, the left face
  /// ([y] + [d]) is [tint] itself, and the right face ([x] + [w]) is the
  /// darkest. [edge] draws a hairline along the top's front edges, which is
  /// what makes a block read as crisp at a small size.
  void box(
    double x,
    double y,
    double z,
    double w,
    double d,
    double h,
    Tint tint, {
    bool edge = true,
  }) {
    final top = z + h;
    canvas
      ..drawPath(
        face([
          (x: x, y: y + d, z: z),
          (x: x + w, y: y + d, z: z),
          (x: x + w, y: y + d, z: top),
          (x: x, y: y + d, z: top),
        ]),
        fill(tint),
      )
      ..drawPath(
        face([
          (x: x + w, y: y + d, z: z),
          (x: x + w, y: y, z: z),
          (x: x + w, y: y, z: top),
          (x: x + w, y: y + d, z: top),
        ]),
        fill(tint.shade(-0.16)),
      )
      ..drawPath(
        face([
          (x: x, y: y, z: top),
          (x: x + w, y: y, z: top),
          (x: x + w, y: y + d, z: top),
          (x: x, y: y + d, z: top),
        ]),
        fill(tint.shade(0.14)),
      );
    if (edge) {
      final a = at(x, y + d, top);
      final b = at(x + w, y + d, top);
      final c = at(x + w, y, top);
      canvas.drawPath(
        Path()
          ..moveTo(a.dx, a.dy)
          ..lineTo(b.dx, b.dy)
          ..lineTo(c.dx, c.dy),
        stroke(tint.shade(0.24), 0.025),
      );
    }
  }

  /// A flat panel - a door, a window, a sign - on a left-facing wall, the
  /// plane at [y]: from [x] for [w] tiles along it, from [z] up [h].
  void onLeft(double y, double x, double z, double w, double h, Tint tint) {
    canvas.drawPath(
      face([
        (x: x, y: y, z: z),
        (x: x + w, y: y, z: z),
        (x: x + w, y: y, z: z + h),
        (x: x, y: y, z: z + h),
      ]),
      fill(tint),
    );
  }

  /// A flat panel on a right-facing wall, the plane at [x]: from [y] for
  /// [d] tiles along it, from [z] up [h].
  void onRight(double x, double y, double z, double d, double h, Tint tint) {
    canvas.drawPath(
      face([
        (x: x, y: y, z: z),
        (x: x, y: y + d, z: z),
        (x: x, y: y + d, z: z + h),
        (x: x, y: y, z: z + h),
      ]),
      fill(tint),
    );
  }

  /// A gable roof over [x], [y], [w] by [d], its eaves at [z] and its ridge
  /// [h] higher. [alongX] runs the ridge along x; otherwise along y.
  void roof(
    double x,
    double y,
    double z,
    double w,
    double d,
    double h,
    Tint tint, {
    bool alongX = true,
    double overhang = 0.12,
  }) {
    final x0 = x - overhang;
    final x1 = x + w + overhang;
    final y0 = y - overhang;
    final y1 = y + d + overhang;
    final ridge = z + h;
    if (alongX) {
      final ym = y + d / 2;
      canvas
        ..drawPath(
          face([
            (x: x0, y: y0, z: z),
            (x: x1, y: y0, z: z),
            (x: x1, y: ym, z: ridge),
            (x: x0, y: ym, z: ridge),
          ]),
          fill(tint.shade(0.12)),
        )
        ..drawPath(
          face([
            (x: x + w, y: y, z: z),
            (x: x + w, y: y + d, z: z),
            (x: x + w, y: ym, z: ridge),
          ]),
          fill(tint.shade(-0.04)),
        )
        ..drawPath(
          face([
            (x: x0, y: y1, z: z),
            (x: x1, y: y1, z: z),
            (x: x1, y: ym, z: ridge),
            (x: x0, y: ym, z: ridge),
          ]),
          fill(tint),
        );
    } else {
      final xm = x + w / 2;
      canvas
        ..drawPath(
          face([
            (x: x0, y: y0, z: z),
            (x: x0, y: y1, z: z),
            (x: xm, y: y1, z: ridge),
            (x: xm, y: y0, z: ridge),
          ]),
          fill(tint.shade(0.12)),
        )
        ..drawPath(
          face([
            (x: x, y: y + d, z: z),
            (x: x + w, y: y + d, z: z),
            (x: xm, y: y + d, z: ridge),
          ]),
          fill(tint.shade(0.02)),
        )
        ..drawPath(
          face([
            (x: x1, y: y0, z: z),
            (x: x1, y: y1, z: z),
            (x: xm, y: y1, z: ridge),
            (x: xm, y: y0, z: ridge),
          ]),
          fill(tint.shade(-0.14)),
        );
    }
  }

  /// An upright cylinder at [x], [y] from [z], radius [r] and [h] tall,
  /// shaded across like a lit can.
  void cylinder(double x, double y, double z, double r, double h, Tint tint) {
    final base = disc(x, y, z, r);
    final lid = disc(x, y, z + h, r);
    final side = Path()
      ..moveTo(base.left, base.center.dy)
      ..arcTo(base, math.pi, -math.pi, false)
      ..lineTo(lid.right, lid.center.dy)
      ..lineTo(lid.left, lid.center.dy)
      ..close();
    canvas
      ..drawPath(
        side,
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(base.left, 0),
            Offset(base.right, 0),
            [colour(tint.shade(0.06)), colour(tint), colour(tint.shade(-0.18))],
            [0, 0.4, 1],
          ),
      )
      ..drawOval(lid, fill(tint.shade(0.14)));
  }

  /// A cone at [x], [y] from [z], radius [r] and [h] tall - a pine, a tower
  /// top, a traffic cone.
  void cone(double x, double y, double z, double r, double h, Tint tint) {
    final base = disc(x, y, z, r);
    final apex = at(x, y, z + h);
    final body = Path()
      ..moveTo(base.left, base.center.dy)
      ..arcTo(base, math.pi, -math.pi, false)
      ..lineTo(apex.dx, apex.dy)
      ..close();
    canvas.drawPath(
      body,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(base.left, 0),
          Offset(base.right, 0),
          [colour(tint.shade(0.1)), colour(tint), colour(tint.shade(-0.18))],
          [0, 0.45, 1],
        ),
    );
  }

  /// A ball centred at [x], [y], [z], radius [r], lit from the upper left.
  void sphere(double x, double y, double z, double r, Tint tint) {
    final c = at(x, y, z);
    final radius = r * unit * 1.15;
    canvas.drawCircle(
      c,
      radius,
      Paint()
        ..shader = ui.Gradient.radial(
          c.translate(-radius * 0.35, -radius * 0.4),
          radius * 1.5,
          [colour(tint.shade(0.16)), colour(tint), colour(tint.shade(-0.16))],
          [0, 0.5, 1],
        ),
    );
  }

  // ------------------------------------------------------------- furniture --

  /// A round-crowned tree at [x], [y], [h] tiles to the top of its crown,
  /// [grow] of the way grown.
  void tree(
    double x,
    double y, {
    required Tint leaves,
    required Tint bark,
    required Tint ground,
    double h = 1.5,
    double grow = 1,
  }) {
    if (grow <= 0) return;
    shadow(x, y, 0.42 * grow, ground);
    final trunk = h * 0.42 * grow;
    cylinder(x, y, 0, 0.07, trunk, bark);
    final r = h * 0.3 * grow;
    sphere(x, y, trunk + r * 0.75, r, leaves);
    sphere(x - 0.12, y + 0.1, trunk + r * 1.25, r * 0.62, leaves.shade(0.05));
  }

  /// A pine at [x], [y]: stacked cones, [h] tall, [grow] of the way grown.
  void pine(
    double x,
    double y, {
    required Tint needles,
    required Tint bark,
    required Tint ground,
    double h = 1.8,
    double grow = 1,
  }) {
    if (grow <= 0) return;
    shadow(x, y, 0.36 * grow, ground);
    final s = h * grow;
    cylinder(x, y, 0, 0.06, s * 0.2, bark);
    for (var i = 0; i < 3; i++) {
      cone(
        x,
        y,
        s * (0.15 + i * 0.22),
        s * (0.3 - i * 0.07),
        s * (0.45 - i * 0.05),
        needles.shade(i * 0.05),
      );
    }
  }

  /// A low bush of three balls at [x], [y].
  void bush(
    double x,
    double y,
    Tint leaves, {
    double size = 1,
    double grow = 1,
  }) {
    if (grow <= 0) return;
    final r = 0.2 * size * grow;
    sphere(x - 0.15 * size, y + 0.05 * size, r * 0.9, r, leaves.shade(-0.04));
    sphere(x + 0.12 * size, y - 0.08 * size, r * 0.85, r * 0.9, leaves);
    sphere(x, y + 0.1 * size, r * 1.1, r * 1.05, leaves.shade(0.04));
  }

  /// A flower at [x], [y]: a stem and a head of [petals], [grow] open.
  void flower(double x, double y, Tint petals, Tint stem, {double grow = 1}) {
    if (grow <= 0) return;
    final foot = at(x, y);
    final head = at(x, y, 0.28 * grow);
    canvas
      ..drawLine(foot, head, stroke(stem, 0.035))
      ..drawCircle(head, 0.085 * unit * grow, fill(petals))
      ..drawCircle(head, 0.035 * unit * grow, fill(petals.shade(0.3)));
  }
}
