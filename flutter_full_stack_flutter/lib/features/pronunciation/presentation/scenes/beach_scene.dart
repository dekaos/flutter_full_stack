import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/animation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_full_stack_flutter/core/audio/sound.dart';
import 'package:flutter_full_stack_flutter/features/pronunciation/presentation/scenes/iso_stage.dart';
import 'package:flutter_full_stack_flutter/features/pronunciation/presentation/scenes/script.dart';

// The palette: a bright morning by the sea. Named for what they are, so the
// drawing below reads as a description of the place.
const _skyTop = Tint(204, 0.7, 0.5);
const _skyLow = Tint(188, 0.55, 0.96);
const _sunBody = Tint(46, 1, 0.72);
const _sunHalo = Tint(48, 0.9, 0.88);
const _cloud = Tint(204, 0.45, 1);
const _gull = Tint(214, 0.2, 0.42);
const _farLand = Tint(172, 0.3, 0.62);
const _farSea = Tint(192, 0.48, 0.78);
const _farSeaLow = Tint(200, 0.52, 0.56);
const _glint = Tint(186, 0.5, 0.98);
const _sand = Tint(34, 0.46, 0.78);
const _wetSand = Tint(30, 0.38, 0.62);
const _earth = Tint(26, 0.42, 0.5);
const _stone = Tint(24, 0.16, 0.28);
const _shallow = Tint(172, 0.46, 0.74);
const _sea = Tint(180, 0.52, 0.6);
const _open = Tint(188, 0.55, 0.5);
const _deep = Tint(196, 0.55, 0.42);
const _foam = Tint(176, 0.45, 1);
const _wall = Tint(40, 0.3, 0.96);
const _roof = Tint(8, 0.72, 0.42);
const _trim = Tint(198, 0.55, 0.28);
const _glass = Tint(192, 0.72, 0.58);
// The key light, a little warmer than the rest of the set's, so that it
// still shows on pale sand.
const _sunlit = Tint(44, 1, 0.9);
// The windows once he is home and the lamps are on.
const _lamplit = Tint(42, 0.92, 0.8);
const _wood = Tint(28, 0.44, 0.54);
const _frond = Tint(142, 0.5, 0.36);
const _trunk = Tint(30, 0.4, 0.4);
const _dune = Tint(86, 0.42, 0.44);
const _skin = Tint(24, 0.55, 0.68);
const _shirt = Tint(46, 0.9, 0.72);
const _pail = Tint(190, 0.62, 0.46);
const _straw = Tint(42, 0.62, 0.78);
const _towel = Tint(44, 0.88, 0.66);

const double _span = IsoStage.span;

/// Where the far sea meets the sky, as a fraction of the screen's height.
const _horizon = 0.7;

// The house: its footprint, and the heights its parts stand at.
const _hx = 0.6;
const _hy = 1.9;
const _hw = 2.0;
const _hd = 2.0;
const _plinth = 0.1;
const _storey = 0.88;
const double _upper = _plinth + _storey + 0.06;
const _upperH = 0.82;
const double _eaves = _upper + _upperH;

/// "He lives in a big house near the beach", in two acts.
///
/// The island assembles first, round an empty sandy plot: it rises out of
/// the sea, the surf rolls in, the palms spring up, the pier is laid plank
/// by plank, the sailboat splashes down and the beach things land. Then the
/// story, in one pool of light where the plot meets the shore, while the
/// rest of the island sinks back: the house is stacked on the plot a floor
/// at a time, so heavy it raises the sand as it lands (*big house*); a wave
/// rolls in and runs up the sand to the foot of its steps, sparkles break
/// out on the water and the parasol pops open (*beach*); and he steps out
/// onto his deck and waves as the windows warm (*He lives*).
const beachScene = SceneScript(
  paintBeach,
  cues: [
    Cue('big house', _built),
    Cue('beach', _surf),
    Cue('He lives', _home),
  ],
  sounds: [SceneSound(Sound.wave, _surf)],
  catWalks: true,
);

// The story's beats, on the arrival's clock: the house first, then the
// beach at its door, then the man who lives in it - so that "near" is seen
// before he is.
const _built = 0.42;
const _surf = 0.56;
const _home = 0.72;

// The house lands a part at a time, the roof on its beat.
const double _groundLands = _built - 0.005;
const double _upperLands = _built + 0.017;
const double _roofLands = _built + 0.04;

// The stage: where the plot meets the shore, so that the house and the
// beach stand in the one light.
const _stageX = 2.45;
const _stageY = 4.05;

/// Paints [beachScene].
void paintBeach(IsoStage s) {
  s.setting(() {
    s.sky(_skyTop, _skyLow);

    final climb = s.phase(0.1, 0.8);
    s.sun(0.8, 0.25 - 0.08 * climb, 0.8, _sunBody, _sunHalo);
    _farShore(s);

    // Clouds drift in from either side and stop.
    final drift = s.phase(0.2, 1);
    s
      ..cloud(s.screen(0.2 - 0.5 * (1 - drift), 0.23), 2.6, _cloud)
      ..cloud(s.screen(0.68 + 0.6 * (1 - drift), 0.44), 1.9, _cloud)
      ..cloud(s.screen(0.1 - 0.4 * (1 - drift), 0.57), 1.3, _cloud);
    _gulls(s);

    s.rising(0, 0.42, () {
      s.island(grass: _sand, earth: _earth, stone: _stone, strata: 4);
      _seaSides(s);
      s.canvas
        ..drawPath(_water(s, -0.32), s.fill(_wetSand))
        ..drawPath(_water(s, 0), s.fill(_shallow))
        ..drawPath(_water(s, 0.45), s.fill(_sea))
        ..drawPath(_water(s, 1.05), s.fill(_open))
        ..drawPath(_water(s, 1.8), s.fill(_deep));
      _turtle(s);
      _waves(s);
      s.story(() {
        // The beach's beat: the sand its wave wets, which the things on the
        // beach lie on; the sparkles breaking out on the water with it.
        _wetted(s);
        _sparkles(s);
      });
      _flats(s);
      // The wave itself runs up over them.
      s
        ..story(() => _swash(s))
        ..pool(
          _stageX,
          _stageY,
          2.15,
          strength: s.storyLight,
          light: _sunlit,
        );
      _dunes(s);
      _palm(
        s,
        3.6,
        0.55,
        h: 1.7,
        lean: (x: 0.35, y: -0.3),
        grow: s.pop(0.5, 0.72),
      );

      // The house is the story's first beat: it goes up on the lit plot.
      s.story(() {
        _landing(s, _groundLands, (lift) => _groundFloor(s, lift));
        _landing(s, _upperLands, (lift) => _upperFloor(s, lift));
        _landing(s, _roofLands, (lift) => _roofOver(s, lift));
        _dust(s);
      });
      _pier(s);
      _buoy(s);
      s.dropping(0.5, 0.78, (lift) => _boat(s, lift), from: 3);
      _frontBeach(s);

      // The rest of the island steps back while the house and its beach
      // have the stage.
      s.spotlight(
        s.at(_stageX - 0.1, _stageY - 0.5, 0.9),
        radius: 2.5,
        strength: s.storyLight,
      );
    });
  });
}

/// Runs [draw] for a part of the house that falls onto its place, landing
/// at [lands]: it fades in at the top of its fall and comes down faster and
/// faster, with no bounce - a big house is heavy - handing [draw] how many
/// tiles above its place it still is.
void _landing(IsoStage s, double lands, void Function(double lift) draw) {
  const fall = 0.035;
  final begin = lands - fall;
  if (s.t < begin) return;
  final lift = 2.4 * (1 - s.phase(begin, lands, Curves.easeInQuad));
  s.faded(s.phase(begin, begin + fall * 0.3), () => draw(lift));
}

/// The sand the ground floor throws up as it lands, in puffs along the
/// house's front that swell and thin away.
void _dust(IsoStage s) {
  final p = s.phase(_groundLands, _groundLands + 0.08);
  if (p <= 0 || p >= 1) return;
  final paint = Paint()
    ..color = s.colour(_sand.shade(0.22)).withValues(alpha: 1 - p * p);
  const puffs = [
    (x: 0.38, y: 4.02, r: 0.17),
    (x: 0.95, y: 4.16, r: 0.14),
    (x: 1.6, y: 4.2, r: 0.16),
    (x: 2.45, y: 4.14, r: 0.14),
    (x: 3.42, y: 4.02, r: 0.16),
  ];
  for (final puff in puffs) {
    final r = puff.r * (0.8 + 1.2 * p);
    final out = 0.25 * p;
    s.canvas
      ..drawOval(s.disc(puff.x, puff.y + out, 0.04 + 0.08 * p, r), paint)
      ..drawOval(
        s.disc(puff.x - 0.12, puff.y + out - 0.06, 0.1 + 0.14 * p, r * 0.7),
        paint,
      )
      ..drawOval(
        s.disc(puff.x + 0.12, puff.y + out + 0.04, 0.08 + 0.12 * p, r * 0.6),
        paint,
      );
  }
}

// ---------------------------------------------------------------- backdrop --

/// The far shore: a hazy headland either side of a calm sea, a lighthouse
/// on the right one, and the sun's path glittering on the water.
void _farShore(IsoStage s) {
  final horizon = s.size.height * _horizon;
  final u = s.unit;
  final w = s.size.width;

  double ripple(double from, double f) =>
      1 + 0.18 * math.sin(f * math.pi * 3 + from * 9);
  Path hill(double from, double to, double height) {
    final path = Path()..moveTo(w * from, horizon + 1);
    const steps = 16;
    for (var i = 0; i <= steps; i++) {
      final f = i / steps;
      path.lineTo(
        w * (from + (to - from) * f),
        horizon - height * u * math.sin(f * math.pi) * ripple(from, f),
      );
    }
    return path..close();
  }

  s.canvas
    ..drawPath(hill(-0.08, 0.34, 0.75), s.fill(_farLand))
    ..drawPath(hill(0.78, 1.1, 0.55), s.fill(_farLand.shade(0.06)));

  // The lighthouse on the right headland's crown.
  final foot = Offset(w * 0.94, horizon - 0.55 * u * ripple(0.78, 0.5) + 2);
  final tower = Path()
    ..moveTo(foot.dx - 0.09 * u, foot.dy)
    ..lineTo(foot.dx + 0.09 * u, foot.dy)
    ..lineTo(foot.dx + 0.06 * u, foot.dy - 0.62 * u)
    ..lineTo(foot.dx - 0.06 * u, foot.dy - 0.62 * u)
    ..close();
  final band = Rect.fromLTRB(
    foot.dx - 0.08 * u,
    foot.dy - 0.36 * u,
    foot.dx + 0.08 * u,
    foot.dy - 0.24 * u,
  );
  final cap = Path()
    ..moveTo(foot.dx - 0.08 * u, foot.dy - 0.74 * u)
    ..lineTo(foot.dx + 0.08 * u, foot.dy - 0.74 * u)
    ..lineTo(foot.dx, foot.dy - 0.86 * u)
    ..close();
  s.canvas
    ..drawPath(tower, s.fill(_wall.shade(-0.04)))
    ..drawRect(band, s.fill(_roof.shade(0.1)))
    ..drawRect(
      Rect.fromLTRB(
        foot.dx - 0.05 * u,
        foot.dy - 0.74 * u,
        foot.dx + 0.05 * u,
        foot.dy - 0.62 * u,
      ),
      s.fill(_sunBody),
    )
    ..drawPath(cap, s.fill(_roof.shade(0.1)));

  final sea = Rect.fromLTRB(0, horizon, w, s.size.height);
  s.canvas.drawRect(
    sea,
    Paint()
      ..shader = ui.Gradient.linear(sea.topCenter, sea.bottomCenter, [
        s.colour(_farSea),
        s.colour(_farSeaLow),
      ]),
  );

  // A few flecks of glitter on the water under the sun.
  const flecks = [
    (dx: -0.5, dy: 0.16, half: 0.42),
    (dx: 0.45, dy: 0.3, half: 0.26),
    (dx: -0.15, dy: 0.5, half: 0.3),
    (dx: 0.6, dy: 0.78, half: 0.16),
  ];
  final sx = w * 0.8;
  final glitter = Path();
  for (final f in flecks) {
    glitter
      ..moveTo(sx + (f.dx - f.half) * u, horizon + f.dy * u)
      ..lineTo(sx + (f.dx + f.half) * u, horizon + f.dy * u);
  }
  s.canvas.drawPath(glitter, s.stroke(_glint, 0.04));

  // Two far sails on the horizon.
  for (final sail in [(fx: 0.06, size: 0.3), (fx: 0.86, size: 0.22)]) {
    final base = Offset(w * sail.fx, horizon + 0.12 * u);
    final h = sail.size * u;
    s.canvas
      ..drawPath(
        Path()
          ..moveTo(base.dx, base.dy - h * 1.6)
          ..lineTo(base.dx + h * 0.7, base.dy - h * 0.15)
          ..lineTo(base.dx - h * 0.25, base.dy - h * 0.15)
          ..close(),
        s.fill(_wall.shade(-0.02)),
      )
      ..drawLine(
        base.translate(-h * 0.5, 0),
        base.translate(h * 0.6, 0),
        s.stroke(_farSeaLow.shade(-0.1), 0.035),
      );
  }
}

/// Three gulls glide in from the left and hang on the breeze, in the open
/// sky between the headline and the controls.
void _gulls(IsoStage s) {
  final glide = s.phase(0.3, 0.95);
  const flock = [
    (fx: 0.4, fy: 0.21, size: 0.5),
    (fx: 0.52, fy: 0.198, size: 0.6),
    (fx: 0.63, fy: 0.218, size: 0.5),
  ];
  final path = Path();
  for (var i = 0; i < flock.length; i++) {
    final g = flock[i];
    final c = s.screen(g.fx - 0.8 * (1 - glide), g.fy + 0.04 * (1 - glide));
    final span = g.size * s.unit;
    final flap = math.sin(glide * math.pi * 6 + i) * (1 - glide);
    final lift = span * (0.6 + 0.25 * flap);
    path
      ..moveTo(c.dx - span, c.dy - lift * 0.2)
      ..quadraticBezierTo(c.dx - span * 0.5, c.dy - lift * 1.1, c.dx, c.dy)
      ..quadraticBezierTo(
        c.dx + span * 0.5,
        c.dy - lift * 1.1,
        c.dx + span,
        c.dy - lift * 0.2,
      );
  }
  s.canvas.drawPath(path, s.stroke(_gull, 0.06));
}

// --------------------------------------------------------------- the sea --

/// Where the sand meets the sea along the island's depth: the water is
/// everything at a larger x.
double _shore(double y) => 4.15 - 0.22 * y + 0.16 * math.sin(y * 1.6 + 0.4);

/// The sea from [from] tiles out past the shoreline to the island's edges.
Path _water(IsoStage s, double from) => s.face([
  for (var i = 0; i <= 24; i++)
    (x: math.min(_shore(i / 4) + from, _span), y: i / 4, z: 0.004),
  (x: _span, y: _span, z: 0.004),
  (x: _span, y: 0, z: 0.004),
]);

/// The sea seen through the island's sides, as in a cut-away: clear water
/// over the sandy bed, shelving down from the shoreline, in bands that
/// deepen like the soil strata under them.
void _seaSides(IsoStage s) {
  const depth = 0.55;
  final x0 = _shore(_span);
  // Where the sea bed meets the near side, [z] tiles down.
  double bed(double z) => x0 + 1.2 * (-z / depth);
  const left = [_shallow, _sea, _deep];
  final right = [_shallow.shade(-0.12), _sea.shade(-0.12), _deep.shade(-0.22)];
  for (var k = 0; k < 3; k++) {
    final zt = -depth * k / 3;
    final zb = -depth * (k + 1) / 3;
    s.canvas
      ..drawPath(
        s.face([
          (x: bed(zt), y: _span, z: zt),
          (x: _span, y: _span, z: zt),
          (x: _span, y: _span, z: zb),
          (x: bed(zb), y: _span, z: zb),
        ]),
        s.fill(left[k]),
      )
      ..drawPath(
        s.face([
          (x: _span, y: _span, z: zt),
          (x: _span, y: 0, z: zt),
          (x: _span, y: 0, z: zb),
          (x: _span, y: _span, z: zb),
        ]),
        s.fill(right[k]),
      );
  }
  final edge = [s.at(x0, _span), s.at(_span, _span), s.at(_span, 0)];
  s.canvas.drawPath(
    Path()
      ..moveTo(edge[0].dx, edge[0].dy)
      ..lineTo(edge[1].dx, edge[1].dy)
      ..lineTo(edge[2].dx, edge[2].dy),
    s.stroke(_foam, 0.03),
  );
}

/// A sea turtle seen through the clear water, paddling in from the corner
/// of the island and stopping to drift.
void _turtle(IsoStage s) {
  final swim = s.phase(0.3, 0.95);
  const heading = math.pi * 1.1;
  final x = 4.55 - math.cos(heading) * 0.7 * (1 - swim);
  final y = 5.45 - math.sin(heading) * 0.7 * (1 - swim);
  final paddle = 0.5 * math.sin(swim * math.pi * 7) * (1 - swim);
  Path oval(double along, double across, double a, double b, double turn) {
    final cx = x + math.cos(heading) * along - math.sin(heading) * across;
    final cy = y + math.sin(heading) * along + math.cos(heading) * across;
    final angle = heading + turn;
    return s.face([
      for (var i = 0; i < 14; i++)
        (
          x:
              cx +
              math.cos(angle) * a * math.cos(i * math.pi / 7) -
              math.sin(angle) * b * math.sin(i * math.pi / 7),
          y:
              cy +
              math.sin(angle) * a * math.cos(i * math.pi / 7) +
              math.cos(angle) * b * math.sin(i * math.pi / 7),
          z: 0.005,
        ),
    ]);
  }

  // A little bigger than life, so it still reads as a turtle on a phone:
  // flippers and head, the shell, and a lighter plate on its back.
  const k = 1.4;
  final limbs = Path()
    ..addPath(
      oval(0.1 * k, 0.15 * k, 0.13 * k, 0.05 * k, 0.9 + paddle),
      Offset.zero,
    )
    ..addPath(
      oval(0.1 * k, -0.15 * k, 0.13 * k, 0.05 * k, -0.9 - paddle),
      Offset.zero,
    )
    ..addPath(
      oval(-0.13 * k, 0.11 * k, 0.08 * k, 0.04 * k, 2.3 - paddle),
      Offset.zero,
    )
    ..addPath(
      oval(-0.13 * k, -0.11 * k, 0.08 * k, 0.04 * k, -2.3 + paddle),
      Offset.zero,
    )
    ..addPath(oval(0.25 * k, 0, 0.07 * k, 0.055 * k, 0), Offset.zero);
  s.canvas
    ..drawPath(limbs, s.fill(_sea.shade(-0.24)))
    ..drawPath(oval(0, 0, 0.2 * k, 0.15 * k, 0), s.fill(_sea.shade(-0.18)))
    ..drawPath(oval(0.01, 0, 0.16, 0.11, 0), s.fill(_sea.shade(0.04)));
}

/// Little wave marks breaking out on the open water as the beach's wave
/// comes in, spreading out from it.
void _sparkles(IsoStage s) {
  const marks = [
    (x: 3.75, y: 4.85),
    (x: 5.2, y: 5.75),
    (x: 5.6, y: 5.1),
    (x: 5.55, y: 3.6),
    (x: 4.4, y: 1.7),
    (x: 5.6, y: 2.4),
    (x: 5.5, y: 1.35),
    (x: 4.75, y: 0.55),
  ];
  final path = Path();
  for (var i = 0; i < marks.length; i++) {
    final m = marks[i];
    final g = s.pop(_surf - 0.01 + i * 0.006, _surf + 0.04 + i * 0.006);
    if (g <= 0) continue;
    final half = 0.14 * g;
    final a = s.at(m.x - half, m.y + half, 0.006);
    final b = s.at(m.x - 0.05 * g, m.y - 0.05 * g, 0.006);
    final c = s.at(m.x + half, m.y - half, 0.006);
    path
      ..moveTo(a.dx, a.dy)
      ..lineTo(b.dx, b.dy)
      ..lineTo(c.dx, c.dy);
  }
  s.canvas.drawPath(path, s.stroke(_foam.shade(-0.04), 0.03));
}

/// Three lines of surf roll in to the shore, one after another, and settle.
void _waves(IsoStage s) {
  const rest = [0.07, 0.4, 0.9];
  const widths = [0.05, 0.03, 0.026];
  // While they roll in they reach past the island's edge, so they are kept
  // to the water; once the last has settled they all lie inside it.
  final rolling = s.t < 0.92;
  if (rolling) {
    s.canvas
      ..save()
      ..clipPath(_water(s, -0.08));
  }
  for (var i = 0; i < rest.length; i++) {
    final roll = s.phase(0.26 + i * 0.08, 0.72 + i * 0.1);
    _foamLine(
      s,
      rest[i] + 2.4 * (1 - roll),
      widths[i],
      i == 0 ? _foam : _foam.shade(-0.05),
      broken: i > 0,
      seed: i * 0.45,
    );
  }
  if (rolling) s.canvas.restore();
}

// The beach's wave runs up the shore in front of the house, from the deck
// steps to the island's front edge.
const _swashFrom = 3.0;
const _swashTo = 6.0;

/// How far up the sand the beach's wave runs at [y], at its highest: most
/// in front of the deck steps, tapering away to either side.
double _reach(double y) {
  final f = ((y - _swashFrom) / (_swashTo - _swashFrom)).clamp(0.0, 1.0);
  return 0.86 * math.sin(math.pi * f);
}

/// The stretch of shore the beach's wave covers, [up] of the way up its
/// run: from the water's edge to [up] of [_reach].
Path _tongue(IsoStage s, double up) {
  const steps = 24;
  double y(int i) => _swashFrom + (_swashTo - _swashFrom) * i / steps;
  return s.face([
    for (var i = 0; i <= steps; i++)
      (x: _shore(y(i)) - _reach(y(i)) * up, y: y(i), z: 0.005),
    for (var i = steps; i >= 0; i--)
      (x: _shore(y(i)) + 0.06, y: y(i), z: 0.005),
  ]);
}

/// A line along the beach's stretch of shore, [offset] times [_reach] up
/// the sand (or out to sea, if negative); [broken] into a lacy line.
Path _swashLine(IsoStage s, double offset, {bool broken = false}) {
  final path = Path();
  const steps = 30;
  for (var i = 0; i <= steps; i++) {
    final y = _swashFrom + (_swashTo - _swashFrom) * i / steps;
    final x = _shore(y) - _reach(y) * offset + 0.03 * math.sin(y * 9);
    // Broken, each dash runs three steps and the gap between them two.
    if (broken && i % 5 == 4) continue;
    final p = s.at(x, y, 0.008);
    i == 0 || (broken && i % 5 == 0)
        ? path.moveTo(p.dx, p.dy)
        : path.lineTo(p.dx, p.dy);
  }
  return path;
}

/// The sand the beach's wave has wet: darker up to where it reached, and it
/// stays that way.
void _wetted(IsoStage s) {
  final up = s.phase(_surf - 0.005, _surf + 0.03);
  if (up <= 0) return;
  s.canvas.drawPath(_tongue(s, up), s.fill(_wetSand.shade(-0.04)));
}

/// The beach's wave: a roller comes in to the shore in front of the house,
/// runs up the sand to the foot of the deck steps, then draws back and
/// leaves its line of foam at the top of its run.
void _swash(IsoStage s) {
  final come = s.phase(_surf - 0.045, _surf - 0.005, Curves.easeInQuad);
  if (come <= 0) return;
  if (come < 1) {
    // Coming in, out on the water, it reaches past the stretch it will run
    // up - kept to the sea.
    s.canvas
      ..save()
      ..clipPath(_water(s, 0))
      ..drawPath(
        _swashLine(s, -1.7 * (1 - come) - 0.08),
        s.stroke(_foam, 0.065),
      )
      ..restore();
    return;
  }
  final up = s.phase(_surf - 0.005, _surf + 0.03);
  final back = s.phase(_surf + 0.045, _surf + 0.15, Curves.easeInOut);
  final front = up * (1 - back);
  if (front > 0.02) {
    // A thin sheet of water over the sand, frothing at its edge.
    s.canvas
      ..drawPath(_tongue(s, front), s.fill(_shallow.shade(0.2)))
      ..drawPath(_swashLine(s, front * 0.6), s.stroke(_foam, 0.035))
      ..drawPath(_swashLine(s, front), s.stroke(_foam, 0.085));
  }
  // Spray thrown up where it breaks on the sand.
  final fly = s.phase(_surf - 0.005, _surf + 0.05, Curves.linear);
  if (fly > 0 && fly < 1) {
    final drop = s.fill(_foam);
    for (final (i, y) in const [4.05, 4.4, 4.75, 5.1, 5.45].indexed) {
      final x = _shore(y) - _reach(y) * up;
      for (var k = 0; k < 2; k++) {
        final arc = math.sin(math.pi * fly) * (0.34 + 0.14 * ((i + k) % 3));
        s.canvas.drawCircle(
          s.at(x - 0.14 * fly * (k + 1), y + 0.1 * (k - 0.5), arc),
          0.07 * (1 - 0.5 * fly) * s.unit,
          drop,
        );
      }
    }
  }
  if (back > 0) {
    s.canvas.drawPath(
      _swashLine(s, up, broken: true),
      s.stroke(_foam, 0.055 + 0.03 * (1 - back)),
    );
  }
}

/// A line of foam [offset] tiles out from the shore; [broken] into dashes.
void _foamLine(
  IsoStage s,
  double offset,
  double width,
  Tint tint, {
  required bool broken,
  double seed = 0,
}) {
  final path = Path();
  final dash = broken ? 1.1 : _span;
  final gap = broken ? 0.3 : 0.0;
  for (var start = -seed; start < _span; start += dash + gap) {
    final from = math.max<double>(start, 0);
    final to = math.min(start + dash, _span);
    if (to <= from) continue;
    for (var k = 0; k <= 12; k++) {
      final y = from + (to - from) * k / 12;
      final x = _shore(y) + offset + 0.05 * math.sin(y * 5 + offset * 3);
      final p = s.at(x, y, 0.008);
      k == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
  }
  s.canvas.drawPath(path, s.stroke(tint, width));
}

// ------------------------------------------------------------ the beach --

/// Flat things on the sand: the boardwalk from the front door, the towel
/// unrolling, a starfish and shells.
void _flats(IsoStage s) {
  // The boardwalk, a plank at a time from the door.
  for (var i = 0; i < 4; i++) {
    final laid = s.phase(0.5 + i * 0.03, 0.56 + i * 0.03);
    if (laid <= 0) continue;
    s.patch(1.85, 3.98 + i * 0.21, 0.42, 0.17 * laid, _wood);
  }

  // The parasol's shade, once its pole is in and spreading as it opens,
  // then the towel unrolling into it.
  if (s.t >= 0.7) {
    final open = _opened(s);
    s.canvas.drawOval(
      s.disc(1.55, 5.05, 0.003, 0.12 + 0.5 * open),
      s.fill(_sand.shade(-0.12)),
    );
  }
  final unroll = s.phase(0.66, 0.84);
  for (var i = 0; i < 5; i++) {
    final from = i * 0.2;
    final to = math.min(from + 0.2, unroll);
    if (to <= from) break;
    s.patch(
      1.85,
      4.42 + from,
      0.5,
      to - from,
      i.isEven ? _towel : _wall,
      z: 0.006,
    );
  }

  _starfish(s, 3.05, 4.55, s.pop(0.78, 0.9));
  final shell = s.pop(0.82, 0.94);
  if (shell > 0) {
    s.canvas
      ..drawOval(s.disc(1, 5.6, 0.01, 0.06 * shell), s.fill(_wall))
      ..drawOval(
        s.disc(2.05, 5.85, 0.01, 0.05 * shell),
        s.fill(_wall.shade(-0.06)),
      );
  }
}

/// How far the parasol is open: furled while the world assembles, popping
/// open with the beach's beat. Read off the arrival's clock, from either
/// timeline.
double _opened(IsoStage s) {
  var open = 0.0;
  s.story(() => open = s.pop(_surf - 0.005, _surf + 0.05));
  return open;
}

/// A golden starfish lying on the wet sand.
void _starfish(IsoStage s, double x, double y, double grow) {
  if (grow <= 0) return;
  final points = <V3>[
    for (var i = 0; i < 10; i++)
      (
        x:
            x +
            math.cos(i * math.pi / 5 - 0.3) * (i.isEven ? 0.17 : 0.07) * grow,
        y:
            y +
            math.sin(i * math.pi / 5 - 0.3) * (i.isEven ? 0.17 : 0.07) * grow,
        z: 0.01,
      ),
  ];
  s.canvas.drawPath(s.face(points), s.fill(_towel));
}

/// Dune grass and sea grape along the back of the beach.
void _dunes(IsoStage s) {
  const tufts = [
    (x: 0.35, y: 0.4),
    (x: 1.3, y: 0.3),
    (x: 0.3, y: 1.35),
    (x: 2.3, y: 0.3),
    (x: 0.25, y: 2.7),
    (x: 2.9, y: 1.2),
  ];
  for (var i = 0; i < tufts.length; i++) {
    final tuft = tufts[i];
    final grow = s.pop(0.52 + i * 0.03, 0.7 + i * 0.03);
    if (grow <= 0) continue;
    final foot = s.at(tuft.x, tuft.y);
    final blades = Path();
    for (var k = -2; k <= 2; k++) {
      final angle = -math.pi / 2 + k * 0.32;
      final length = (0.34 - k.abs() * 0.05) * s.unit * grow;
      blades
        ..moveTo(foot.dx + k * 0.03 * s.unit, foot.dy)
        ..lineTo(
          foot.dx + math.cos(angle) * length,
          foot.dy + math.sin(angle) * length,
        );
    }
    s.canvas.drawPath(blades, s.stroke(_dune, 0.03));
  }
  s
    ..bush(0.3, 3.7, _frond.shade(0.08), size: 0.85, grow: s.pop(0.5, 0.7))
    ..bush(2.95, 1, _frond, size: 0.75, grow: s.pop(0.54, 0.74));
}

/// A palm at [x], [y], [h] tall, its trunk curving [lean] tiles over by
/// the top, [grow] of the way grown.
void _palm(
  IsoStage s,
  double x,
  double y, {
  required double h,
  required ({double x, double y}) lean,
  required double grow,
}) {
  if (grow <= 0) return;
  final top = h * grow;
  V3 along(double f) =>
      (x: x + lean.x * grow * f * f, y: y + lean.y * grow * f * f, z: top * f);
  Offset point(V3 p) => s.at(p.x, p.y, p.z);

  s.shadow(x + lean.x * 0.8, y + lean.y * 0.8, 0.34 * grow, _sand);
  const segments = 9;
  for (var i = 0; i < segments; i++) {
    final a = point(along(i / segments));
    final b = point(along((i + 1) / segments));
    s.canvas.drawLine(
      a,
      b,
      s.stroke(
        _trunk.shade(i.isEven ? 0 : 0.07),
        0.12 - 0.05 * i / segments,
      ),
    );
  }

  final crown = along(1);
  final open = s.phase(0.62, 0.86);
  const count = 7;
  final fronds =
      [
        for (var i = 0; i < count; i++) i * 2 * math.pi / count + 0.35,
      ]..sort(
        (a, b) => (math.cos(a) + math.sin(a)).compareTo(
          math.cos(b) + math.sin(b),
        ),
      );
  var nutsDrawn = false;
  for (final angle in fronds) {
    if (!nutsDrawn && math.cos(angle) + math.sin(angle) > 0) {
      nutsDrawn = true;
      for (var k = 0; k < 3; k++) {
        final a = k * 2.1;
        s.sphere(
          crown.x + math.cos(a) * 0.06,
          crown.y + math.sin(a) * 0.06,
          crown.z - 0.08,
          0.06 * grow,
          _trunk.shade(-0.06),
        );
      }
    }
    _leaf(
      s,
      crown,
      angle,
      0.95 * grow,
      0.15 + 0.4 * open,
      _frond.shade(0.08 - 0.1 * math.cos(angle) + 0.03 * math.sin(angle)),
    );
  }
}

/// One palm frond from [crown] toward [angle], [length] tiles long,
/// arching up and drooping [droop] of its length at the tip.
void _leaf(
  IsoStage s,
  V3 crown,
  double angle,
  double length,
  double droop,
  Tint tint,
) {
  final dx = math.cos(angle);
  final dy = math.sin(angle);
  final c = s.at(crown.x, crown.y, crown.z);
  final mid = s.at(
    crown.x + dx * length * 0.5,
    crown.y + dy * length * 0.5,
    crown.z + length * 0.3,
  );
  final tip = s.at(
    crown.x + dx * length,
    crown.y + dy * length,
    crown.z - length * droop,
  );
  final reach = tip - c;
  if (reach.distance < 1) return;
  final normal = Offset(-reach.dy, reach.dx) / reach.distance;
  final w = length * s.unit * 0.2;
  final blade = Path()
    ..moveTo(c.dx, c.dy)
    ..quadraticBezierTo(
      mid.dx + normal.dx * w,
      mid.dy + normal.dy * w,
      tip.dx,
      tip.dy,
    )
    ..quadraticBezierTo(
      mid.dx - normal.dx * w,
      mid.dy - normal.dy * w,
      c.dx,
      c.dy,
    )
    ..close();
  s.canvas
    ..drawPath(blade, s.fill(tint))
    ..drawPath(
      Path()
        ..moveTo(c.dx, c.dy)
        ..quadraticBezierTo(mid.dx, mid.dy, tip.dx, tip.dy),
      s.stroke(tint.shade(-0.14), 0.02),
    );
}

// -------------------------------------------------------------- the house --

/// How warm the house's [i]th window is: they light up one after another,
/// from the doors he steps out of up to the attic, as he comes out.
double _warm(IsoStage s, int i) =>
    s.phase(_home - 0.01 + i * 0.006, _home + 0.035 + i * 0.006);

/// A window on a wall: a teal frame, the glass, and a glint across it.
/// [warm] is how far it has lit up from inside: the glass goes from sky
/// blue to lamplight, and the light spills onto the wall round it.
void _window(
  IsoStage s,
  double plane,
  double from,
  double z,
  double w,
  double h, {
  required bool left,
  double warm = 0,
}) {
  // A panel on the wall, [a] to [b] along it and [c] to [d] up.
  Path pane(double a, double b, double c, double d) => left
      ? s.face([
          (x: a, y: plane, z: c),
          (x: b, y: plane, z: c),
          (x: b, y: plane, z: d),
          (x: a, y: plane, z: d),
        ])
      : s.face([
          (x: plane, y: a, z: c),
          (x: plane, y: b, z: c),
          (x: plane, y: b, z: d),
          (x: plane, y: a, z: d),
        ]);
  Paint lit(Tint glass, Tint lamp) => warm <= 0
      ? s.fill(glass)
      : (Paint()
          ..color = Color.lerp(s.colour(glass), s.colour(lamp), warm)!
          ..isAntiAlias = true);

  const f = 0.045;
  final glass = left ? _glass : _glass.shade(-0.1);
  final lamp = left ? _lamplit : _lamplit.shade(-0.08);
  if (warm > 0) {
    s.glow(
      left
          ? s.at(from + w / 2, plane, z + h / 2)
          : s.at(plane, from + w / 2, z + h / 2),
      0.25 + 0.6 * math.max(w, h),
      strength: 0.8 * warm,
    );
  }
  final glint = left
      ? s.face([
          (x: from + w * 0.2, y: plane, z: z),
          (x: from + w * 0.42, y: plane, z: z),
          (x: from + w * 0.72, y: plane, z: z + h),
          (x: from + w * 0.5, y: plane, z: z + h),
        ])
      : s.face([
          (x: plane, y: from + w * 0.2, z: z),
          (x: plane, y: from + w * 0.42, z: z),
          (x: plane, y: from + w * 0.72, z: z + h),
          (x: plane, y: from + w * 0.5, z: z + h),
        ]);
  s.canvas
    ..drawPath(pane(from - f, from + w + f, z - f, z + h + f), s.fill(_trim))
    ..drawPath(pane(from, from + w, z, z + h), lit(glass, lamp))
    ..drawPath(glint, lit(glass.shade(0.16), lamp.shade(0.1)));
}

/// Clapboard lines across both walls of a storey from [z], [h] tall.
void _siding(IsoStage s, double z, double h) {
  final left = Path();
  final right = Path();
  for (var i = 1; i < 5; i++) {
    final level = z + h * i / 5;
    final a = s.at(_hx, _hy + _hd, level);
    final b = s.at(_hx + _hw, _hy + _hd, level);
    final c = s.at(_hx + _hw, _hy, level);
    left
      ..moveTo(a.dx, a.dy)
      ..lineTo(b.dx, b.dy);
    right
      ..moveTo(b.dx, b.dy)
      ..lineTo(c.dx, c.dy);
  }
  s.canvas
    ..drawPath(left, s.stroke(_wall.shade(-0.07), 0.014))
    ..drawPath(right, s.stroke(_wall.shade(-0.24), 0.014));
}

/// The ground floor, [lift] tiles above where it will stand, with its deck,
/// the front step and the man of the house.
void _groundFloor(IsoStage s, double lift) {
  final z = lift;
  const front = _hy + _hd;
  const side = _hx + _hw;
  if (lift < 0.05) {
    s.patch(_hx - 0.1, _hy - 0.1, _hw + 0.4, _hd + 0.3, _sand.shade(-0.1));
  }
  s
    ..box(_hx - 0.05, _hy - 0.05, z, _hw + 0.1, _hd + 0.1, _plinth, _wetSand)
    ..box(_hx, _hy, z + _plinth, _hw, _hd, _storey, _wall);
  _siding(s, z + _plinth, _storey);
  _window(
    s,
    front,
    _hx + 0.3,
    z + _plinth + 0.32,
    0.55,
    0.4,
    left: true,
    warm: _warm(s, 2),
  );
  s.onLeft(front, _hx + 1.25, z + _plinth, 0.42, 0.7, _trim.shade(-0.04));
  // The front door's light, and its step.
  final door = _warm(s, 3);
  s.canvas.drawPath(
    s.face([
      (x: _hx + 1.33, y: front, z: z + _plinth + 0.36),
      (x: _hx + 1.59, y: front, z: z + _plinth + 0.36),
      (x: _hx + 1.59, y: front, z: z + _plinth + 0.6),
      (x: _hx + 1.33, y: front, z: z + _plinth + 0.6),
    ]),
    Paint()..color = Color.lerp(s.colour(_glass), s.colour(_lamplit), door)!,
  );
  s
    ..box(_hx + 1.2, front, z, 0.52, 0.16, 0.08, _wood.shade(-0.06))
    // Sliding glass doors onto the deck, the first to light up behind him.
    ..onRight(side, _hy + 0.32, z + _plinth, 1.36, 0.74, _trim);
  for (final (i, along) in [_hy + 0.36, _hy + 1.02].indexed) {
    _window(
      s,
      side,
      along,
      z + _plinth + 0.04,
      0.62,
      0.66,
      left: false,
      warm: _warm(s, i),
    );
  }
  // The band between the floors, white on top while the upper floor is
  // still on its way down.
  s
    ..box(
      _hx - 0.05,
      _hy - 0.05,
      z + _plinth + _storey,
      _hw + 0.1,
      _hd + 0.1,
      0.06,
      _trim.shade(0.2),
    )
    ..patch(
      _hx - 0.05,
      _hy - 0.05,
      _hw + 0.1,
      _hd + 0.1,
      _wall.shade(0.1),
      z: z + _plinth + _storey + 0.06,
    );

  _deck(s, z);
  _surfboard(s, _hx + 1.05, front + 0.24, z);
}

/// The deck along the sea side, its railing, and him on it.
void _deck(IsoStage s, double z) {
  const x = _hx + _hw;
  const w = 0.7;
  const y = _hy + 0.05;
  const d = _hd - 0.05;
  const top = 0.16;
  s.box(x, y, z, w, d, top, _wood);
  final boards = Path();
  for (var i = 1; i < 5; i++) {
    final a = s.at(x + w * i / 5, y, z + top);
    final b = s.at(x + w * i / 5, y + d, z + top);
    boards
      ..moveTo(a.dx, a.dy)
      ..lineTo(b.dx, b.dy);
  }
  s.canvas.drawPath(boards, s.stroke(_wood.shade(0.06), 0.012));

  final rail = s.stroke(_wall, 0.028);
  final post = s.stroke(_wall.shade(-0.06), 0.022);
  const high = 0.36;
  void run(List<({double x, double y})> points) {
    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final p = points[i];
      final foot = s.at(p.x, p.y, z + top);
      final head = s.at(p.x, p.y, z + top + high);
      s.canvas.drawLine(foot, head, post);
      i == 0 ? path.moveTo(head.dx, head.dy) : path.lineTo(head.dx, head.dy);
    }
    s.canvas.drawPath(path, rail);
  }

  // The back rail, behind him; the rails toward the sea, in front of him.
  run([
    for (var i = 0; i <= 3; i++)
      (x: x + 0.04 + (w - 0.08) * i / 3, y: y + 0.04),
  ]);
  _resident(s, x + 0.36, y + 0.42, z + top);
  run([
    for (var i = 0; i <= 2; i++) (x: x + w - 0.04, y: y + 0.04 + 0.3 * i),
  ]);
  run([
    for (var i = 0; i <= 3; i++)
      (x: x + w - 0.04, y: y + 1.2 + (d - 1.24) * i / 3),
  ]);
  run([(x: x + 0.3, y: y + d - 0.04), (x: x + 0.04, y: y + d - 0.04)]);
  // Steps down to the sand through the gap in the front rail.
  s
    ..box(x + 0.34, y + d, z, 0.28, 0.14, 0.1, _wood.shade(-0.04))
    ..box(x + 0.34, y + d + 0.14, z, 0.28, 0.14, 0.05, _wood.shade(-0.04));
  _lifebuoy(s, x + w - 0.02, y + 1.5, z + top + 0.2);

  // A coral flag on the corner post by the steps, echoing the roof: it
  // flutters as the roof lands, then flies still.
  final foot = s.at(x + w - 0.04, y + d - 0.04, z + top + high);
  final head = s.at(x + w - 0.04, y + d - 0.04, z + top + 0.96);
  final settle = s.phase(_roofLands, _roofLands + 0.2);
  final flutter = math.sin(settle * math.pi * 6) * (1 - settle);
  final u = s.unit;
  s.canvas
    ..drawLine(foot, head, s.stroke(_wall.shade(-0.06), 0.022))
    ..drawPath(
      Path()
        ..moveTo(head.dx, head.dy)
        ..lineTo(head.dx + 0.34 * u, head.dy + (0.08 + 0.06 * flutter) * u)
        ..lineTo(head.dx, head.dy + 0.17 * u)
        ..close(),
      s.fill(_roof.shade(0.04)),
    );
}

/// A surfboard leaning on the gable wall, its foot [x], [y] on the sand.
void _surfboard(IsoStage s, double x, double y, double z) {
  const length = 1.16;
  const lean = 0.2;
  const half = 0.1;
  V3 along(double f, double side) {
    final width = half * math.pow(math.sin(math.pi * f), 0.6) * side;
    return (x: x + width, y: y - lean * f, z: z + length * f);
  }

  s.canvas
    ..drawPath(
      s.face([
        for (var i = 0; i <= 12; i++) along(i / 12, 1),
        for (var i = 11; i > 0; i--) along(i / 12, -1),
      ]),
      s.fill(_pail),
    )
    ..drawLine(
      s.at(x, y - lean * 0.08, z + length * 0.08),
      s.at(x, y - lean * 0.92, z + length * 0.92),
      s.stroke(_wall, 0.03),
    );
}

/// A red and white ring hung on the outer rail.
void _lifebuoy(IsoStage s, double x, double y, double z) {
  const r = 0.13;
  for (var k = 0; k < 4; k++) {
    final arc = Path();
    for (var i = 0; i <= 6; i++) {
      final a = (k + i / 6) * math.pi / 2;
      final p = s.at(x, y + r * math.cos(a), z + r * math.sin(a));
      i == 0 ? arc.moveTo(p.dx, p.dy) : arc.lineTo(p.dx, p.dy);
    }
    s.canvas.drawPath(
      arc,
      s.stroke(k.isEven ? _roof : _wall, 0.06)..strokeCap = StrokeCap.butt,
    );
  }
}

/// The man of the house: he steps out of the doors behind him to stand at
/// [at], [y], [z], and waves.
void _resident(IsoStage s, double at, double y, double z) {
  final appear = s.pop(_home - 0.015, _home + 0.035);
  if (appear <= 0) return;
  final x = at - 0.3 * (1 - s.phase(_home - 0.015, _home + 0.03));
  // A touch larger than life, so that he reads on a phone as the one who
  // lives here.
  s.scaled(s.at(x, y, z), 1.2 * appear, () {
    s.canvas.drawOval(
      s.disc(x, y, z + 0.002, 0.1),
      s.fill(_wood.shade(-0.12)),
    );
    s
      ..cylinder(x, y, z, 0.065, 0.2, _trim)
      ..cylinder(x, y, z + 0.2, 0.09, 0.22, _shirt)
      ..sphere(x, y, z + 0.52, 0.085, _skin);
    s.canvas.drawOval(s.disc(x, y, z + 0.58, 0.13), s.fill(_straw));
    s.cylinder(x, y, z + 0.58, 0.065, 0.07, _straw.shade(0.06));
    final wave = s.phase(_home + 0.01, _home + 0.17);
    final angle =
        -math.pi * 0.36 + 0.5 * math.sin(wave * math.pi * 5) * (1 - wave);
    final shoulder = s.at(x + 0.06, y - 0.06, z + 0.39);
    final hand =
        shoulder + Offset(math.cos(angle), math.sin(angle)) * (0.26 * s.unit);
    s.canvas.drawLine(shoulder, hand, s.stroke(_skin, 0.045));
  });
}

/// The upper floor, [lift] tiles above where it will stand, with its
/// shuttered windows and the balcony over the sea.
void _upperFloor(IsoStage s, double lift) {
  final z = lift + _upper;
  const front = _hy + _hd;
  const side = _hx + _hw;
  s.box(_hx, _hy, z, _hw, _hd, _upperH, _wall);
  _siding(s, z, _upperH);
  for (final (i, at) in [_hx + 0.3, _hx + 1.25].indexed) {
    s
      ..onLeft(front, at - 0.2, z + 0.22, 0.13, 0.48, _trim.shade(0.14))
      ..onLeft(front, at + 0.5, z + 0.22, 0.13, 0.48, _trim.shade(0.14));
    _window(
      s,
      front,
      at,
      z + 0.24,
      0.42,
      0.44,
      left: true,
      warm: _warm(s, 6 + i),
    );
  }
  _window(
    s,
    side,
    _hy + 0.35,
    z + 0.26,
    0.4,
    0.42,
    left: false,
    warm: _warm(s, 5),
  );
  _window(
    s,
    side,
    _hy + 1.0,
    z + 0.04,
    0.5,
    0.64,
    left: false,
    warm: _warm(s, 4),
  );

  // The balcony.
  const bx = side;
  const by = _hy + 0.82;
  const bw = 0.42;
  const bd = 0.96;
  s.box(bx, by, z - 0.04, bw, bd, 0.06, _wood);
  final rail = Path();
  final posts = Path();
  final corners = [
    (x: bx, y: by + 0.02),
    (x: bx + bw - 0.03, y: by + 0.02),
    (x: bx + bw - 0.03, y: by + bd - 0.02),
    (x: bx, y: by + bd - 0.02),
  ];
  for (var i = 0; i < corners.length; i++) {
    final c = corners[i];
    final head = s.at(c.x, c.y, z + 0.34);
    i == 0 ? rail.moveTo(head.dx, head.dy) : rail.lineTo(head.dx, head.dy);
  }
  for (var i = 0; i <= 4; i++) {
    final yy = by + 0.02 + (bd - 0.04) * i / 4;
    final foot = s.at(bx + bw - 0.03, yy, z + 0.02);
    final head = s.at(bx + bw - 0.03, yy, z + 0.34);
    posts
      ..moveTo(foot.dx, foot.dy)
      ..lineTo(head.dx, head.dy);
  }
  s.canvas
    ..drawPath(posts, s.stroke(_wall.shade(-0.06), 0.02))
    ..drawPath(rail, s.stroke(_wall, 0.028));
}

/// The roof, [lift] tiles above the eaves: coral slopes with standing
/// seams, a white gable with a round window, and a pennant on the ridge.
void _roofOver(IsoStage s, double lift) {
  final z = lift + _eaves;
  const h = 0.78;
  const o = 0.16;
  const x0 = _hx - o;
  const x1 = _hx + _hw + o;
  const y0 = _hy - o;
  const y1 = _hy + _hd + o;
  const xm = _hx + _hw / 2;
  const front = _hy + _hd;
  final ridge = z + h;

  Path seams(double x) {
    final path = Path();
    for (var i = 1; i < 9; i++) {
      final y = y0 + (y1 - y0) * i / 9;
      final a = s.at(x, y, z);
      final b = s.at(xm, y, ridge);
      path
        ..moveTo(a.dx, a.dy)
        ..lineTo(b.dx, b.dy);
    }
    return path;
  }

  s.canvas
    ..drawPath(
      s.face([
        (x: x0, y: y0, z: z),
        (x: x0, y: y1, z: z),
        (x: xm, y: y1, z: ridge),
        (x: xm, y: y0, z: ridge),
      ]),
      s.fill(_roof.shade(0.12)),
    )
    ..drawPath(seams(x0), s.stroke(_roof.shade(0.04), 0.014))
    ..drawPath(
      s.face([
        (x: _hx, y: front, z: z),
        (x: _hx + _hw, y: front, z: z),
        (x: xm, y: front, z: ridge),
      ]),
      s.fill(_wall),
    );

  // The round attic window in the gable.
  Path ring(double r) => s.face([
    for (var i = 0; i < 16; i++)
      (
        x: xm + r * math.cos(i * math.pi / 8),
        y: front,
        z: z + 0.3 + r * math.sin(i * math.pi / 8),
      ),
  ]);
  final attic = _warm(s, 8);
  s.glow(s.at(xm, front, z + 0.3), 0.4, strength: 0.8 * attic);
  s.canvas
    ..drawPath(ring(0.17), s.fill(_trim))
    ..drawPath(
      ring(0.12),
      Paint()..color = Color.lerp(s.colour(_glass), s.colour(_lamplit), attic)!,
    )
    ..drawPath(
      s.face([
        (x: x1, y: y0, z: z),
        (x: x1, y: y1, z: z),
        (x: xm, y: y1, z: ridge),
        (x: xm, y: y0, z: ridge),
      ]),
      s.fill(_roof.shade(-0.14)),
    )
    ..drawPath(seams(x1), s.stroke(_roof.shade(-0.22), 0.014));
  final a = s.at(x0, y1, z);
  final b = s.at(xm, y1, ridge);
  final c = s.at(x1, y1, z);
  s.canvas.drawPath(
    Path()
      ..moveTo(a.dx, a.dy)
      ..lineTo(b.dx, b.dy)
      ..lineTo(c.dx, c.dy),
    s.stroke(_wall, 0.04),
  );

  // The pennant on the ridge: it flutters as the roof lands, then flies.
  final foot = s.at(xm, y1 - 0.1, ridge);
  final head = s.at(xm, y1 - 0.1, ridge + 0.5);
  final settle = s.phase(_roofLands, _roofLands + 0.2);
  final flutter = math.sin(settle * math.pi * 6) * (1 - settle);
  final u = s.unit;
  s.canvas
    ..drawLine(foot, head, s.stroke(_trim, 0.025))
    ..drawPath(
      Path()
        ..moveTo(head.dx, head.dy)
        ..lineTo(head.dx + 0.34 * u, head.dy + (0.08 + 0.06 * flutter) * u)
        ..lineTo(head.dx, head.dy + 0.17 * u)
        ..close(),
      s.fill(_towel),
    );
}

// ------------------------------------------------------------- the water --

/// The pier, laid plank by plank from the deck out to sea, with a lamp at
/// its end.
void _pier(IsoStage s) {
  const y = 2.62;
  const d = 0.46;
  const x0 = _hx + _hw + 0.7;
  const planks = 11;
  const pitch = 0.16;
  if (s.t < 0.5) return;
  // The posts are driven in from the deck outward, just ahead of the
  // planks.
  double post(int i) => 0.24 * s.phase(0.5 + i * 0.06, 0.58 + i * 0.06);
  for (var i = 1; i < 4; i++) {
    final h = post(i);
    if (h <= 0) continue;
    s.cylinder(x0 + i * 0.5, y - 0.03, 0, 0.035, h, _wood.shade(-0.14));
  }
  for (var i = 0; i < planks; i++) {
    final begin = 0.52 + i * 0.022;
    if (s.t < begin) break;
    final z = 0.1 + s.drop(begin, begin + 0.1, from: 0.6);
    s.box(
      x0 + i * pitch,
      y,
      z,
      pitch - 0.03,
      d,
      0.05,
      _wood.shade(i.isEven ? 0 : 0.04),
      edge: false,
    );
  }
  for (var i = 1; i < 4; i++) {
    final h = post(i);
    if (h <= 0) continue;
    s.cylinder(x0 + i * 0.5, y + d + 0.03, 0, 0.035, h, _wood.shade(-0.1));
  }
  final lamp = s.pop(0.8, 0.92);
  if (lamp > 0) {
    const lx = x0 + planks * pitch - 0.12;
    const ly = y + d - 0.06;
    s.scaled(s.at(lx, ly, 0.15), lamp, () {
      s
        ..cylinder(lx, ly, 0.15, 0.025, 0.6, _trim)
        ..box(lx - 0.06, ly - 0.06, 0.75, 0.12, 0.12, 0.13, _glass.shade(0.1))
        ..cone(lx, ly, 0.88, 0.1, 0.1, _trim);
    });
  }
}

/// A buoy bobbing off the beach.
void _buoy(IsoStage s) {
  const x = 5.4;
  const y = 1.3;
  final appear = s.pop(0.6, 0.76);
  if (appear <= 0) return;
  final bob =
      0.08 * math.sin(s.phase(0.6, 1) * math.pi * 4) * (1 - s.phase(0.6, 1));
  s.canvas.drawOval(
    s.disc(x, y, 0.006, 0.16 * appear),
    s.fill(_foam.shade(-0.04)),
  );
  s.scaled(s.at(x, y), appear, () {
    s
      ..cylinder(x, y, bob, 0.1, 0.12, _roof)
      ..cylinder(x, y, bob + 0.12, 0.1, 0.07, _wall)
      ..cone(x, y, bob + 0.19, 0.1, 0.16, _roof);
  });
}

/// The sailboat, [lift] tiles above the water: a white hull with a navy
/// stripe, the sail hoisted once it has settled.
void _boat(IsoStage s, double lift) {
  const x = 4.3;
  const y = 4.3;
  final z = lift;
  const deck = 0.24;
  // Where it sits in the water: a collar of foam along the hull, the
  // ripple it lands with spreading out to a ring, and a wake behind it.
  if (lift < 0.05) {
    final splash = s.phase(0.66, 0.9);
    Path ellipse(double a, double b) => s.face([
      for (var i = 0; i < 24; i++)
        (
          x: x + 0.55 + a * math.cos(i * math.pi / 12),
          y: y + b * math.sin(i * math.pi / 12),
          z: 0.007,
        ),
    ]);
    final v0 = s.at(x - 0.7, y - 0.32, 0.007);
    final v1 = s.at(x - 0.04, y, 0.007);
    final v2 = s.at(x - 0.62, y + 0.4, 0.007);
    s.canvas
      ..drawPath(ellipse(0.66, 0.3), s.fill(_shallow.shade(0.06)))
      ..drawPath(
        ellipse(0.7 + 0.32 * splash, 0.34 + 0.2 * splash),
        s.stroke(_foam.shade(-0.08), 0.02),
      )
      ..drawPath(
        Path()
          ..moveTo(v0.dx, v0.dy)
          ..lineTo(v1.dx, v1.dy)
          ..lineTo(v2.dx, v2.dy),
        s.stroke(_foam.shade(-0.06), 0.025),
      );
  }
  V3 top(double dx, double dy) => (x: x + dx, y: y + dy, z: z + deck);
  V3 keel(double dx, double dy) => (x: x + dx, y: y + dy, z: z);
  final hull = _wall.shade(-0.02);
  s.canvas
    // The near side and the near half of the bow.
    ..drawPath(
      s.face([keel(0.08, 0.13), keel(0.75, 0.13), top(0.75, 0.2), top(0, 0.2)]),
      s.fill(hull),
    )
    ..drawPath(
      s.face([keel(0.75, 0.13), keel(1, 0), top(1.12, 0), top(0.75, 0.2)]),
      s.fill(hull.shade(-0.1)),
    )
    ..drawPath(
      s.face([
        top(0, 0.2),
        top(0.75, 0.2),
        top(1.12, 0),
        (x: x + 1.08, y: y + 0.02, z: z + deck - 0.06),
        (x: x + 0.75, y: y + 0.2, z: z + deck - 0.07),
        (x: x, y: y + 0.2, z: z + deck - 0.07),
      ]),
      s.fill(_trim.shade(0.1)),
    )
    // The inside of the hull, then the gunwale round it.
    ..drawPath(
      s.face([
        top(0, -0.2),
        top(0.75, -0.2),
        top(1.12, 0),
        top(0.75, 0.2),
        top(0, 0.2),
      ]),
      s.fill(_wood.shade(-0.04)),
    );
  s.box(x + 0.2, y - 0.17, z + 0.06, 0.14, 0.34, deck - 0.08, _wood);

  final hoist = s.phase(0.72, 0.92);
  const mast = 0.64;
  s.cylinder(x + mast, y, z + deck, 0.025, 1.3, _trim);
  if (hoist > 0) {
    s.canvas
      ..drawPath(
        s.face([
          (x: x + mast - 0.03, y: y, z: z + deck + 0.14),
          (x: x + mast - 0.03, y: y, z: z + deck + 0.14 + 1.08 * hoist),
          (x: x + 0.02, y: y, z: z + deck + 0.14),
        ]),
        s.fill(_wall),
      )
      ..drawPath(
        s.face([
          (x: x + mast + 0.03, y: y, z: z + deck + 0.12 + 0.96 * hoist),
          (x: x + 1.08, y: y, z: z + deck + 0.1),
          (x: x + mast + 0.03, y: y, z: z + deck + 0.1),
        ]),
        s.fill(_wall.shade(-0.06)),
      );
  }
  final head = s.at(x + mast, y, z + deck + 1.3);
  final u = s.unit;
  s.canvas.drawPath(
    Path()
      ..moveTo(head.dx, head.dy)
      ..lineTo(head.dx - 0.22 * u, head.dy + 0.05 * u)
      ..lineTo(head.dx, head.dy + 0.11 * u)
      ..close(),
    s.fill(_trim.shade(0.1)),
  );
}

// ------------------------------------------------------- the front beach --

/// The front of the beach: a ball, the leaning palm, the parasol, a bucket
/// and a sandcastle by the water.
void _frontBeach(IsoStage s) {
  _ball(s, 0.95, 4.45);
  _palm(
    s,
    0.35,
    5.55,
    h: 2.3,
    lean: (x: 0.3, y: -0.7),
    grow: s.pop(0.46, 0.7),
  );
  _parasol(s, 1.4, 5);
  _bucket(s, 2.8, 5, s.pop(0.76, 0.88));
  _castle(s, 2.4, 5.45, s.pop(0.72, 0.88));
}

/// A beach ball that drops in and bounces to rest.
void _ball(IsoStage s, double x, double y) {
  if (s.t < 0.7) return;
  final lift = s.drop(0.7, 0.94, from: 2);
  const r = 0.14;
  s.canvas.drawOval(
    s.disc(x, y, 0.004, r * (1 - lift * 0.2)),
    s.fill(_sand.shade(-0.12)),
  );
  s.sphere(x, y, r + lift, r, _towel);
  final c = s.at(x, y, r + lift);
  final band = Rect.fromCircle(center: c, radius: r * s.unit * 1.15);
  s.canvas
    ..drawArc(
      band.deflate(r * s.unit * 0.25),
      -math.pi * 0.85,
      math.pi * 0.7,
      false,
      s.stroke(_pail, 0.05)..strokeCap = StrokeCap.butt,
    )
    ..drawCircle(c, r * s.unit * 0.22, s.fill(_wall));
}

/// The striped parasol: the pole drops in with its canopy furled, and the
/// canopy pops open with the beach's beat.
void _parasol(IsoStage s, double x, double y) {
  if (s.t < 0.6) return;
  final lift = s.drop(0.6, 0.74, from: 3);
  const pole = 1.05;
  s.canvas.drawLine(
    s.at(x, y, lift),
    s.at(x, y, lift + pole + 0.08),
    s.stroke(_wall.shade(-0.12), 0.03),
  );
  final open = _opened(s);
  const n = 10;
  // Furled, the canopy hangs close round the top of the pole; open, it
  // spreads wide and nearly flat.
  final r = 0.66 * (0.1 + 0.9 * open);
  final apexZ = lift + pole + 0.1;
  final rimZ = apexZ - (0.55 - 0.29 * open);
  final apex = s.at(x, y, apexZ);
  double angle(double i) => i * 2 * math.pi / n + 0.2;
  double depth(int i) => math.cos(angle(i + 0.5)) + math.sin(angle(i + 0.5));
  Offset rim(double i, [double drop = 0]) => s.at(
    x + r * math.cos(angle(i)),
    y + r * math.sin(angle(i)),
    rimZ - drop,
  );
  // The far panels first, so that furled the near ones wrap over them.
  final panels = [for (var i = 0; i < n; i++) i]
    ..sort((a, b) => depth(a).compareTo(depth(b)));
  final canopy = Path();
  for (final i in panels) {
    final m = angle(i + 0.5);
    final tint = (i.isEven ? _pail.shade(0.14) : _wall).shade(
      0.04 - 0.1 * math.cos(m) - 0.02 * math.sin(m),
    );
    final a = rim(i.toDouble());
    final b = rim(i + 1.0);
    final sag = rim(i + 0.5, 0.1 * open);
    final control = sag * 2 - (a + b) / 2;
    final panel = Path()
      ..moveTo(apex.dx, apex.dy)
      ..lineTo(a.dx, a.dy)
      ..quadraticBezierTo(control.dx, control.dy, b.dx, b.dy)
      ..close();
    s.canvas.drawPath(panel, s.fill(tint));
    canopy.addPath(panel, Offset.zero);
  }
  s.sphere(x, y, apexZ + 0.03, 0.04, _wall);
  _cat(s, x, y, canopy);
}

/// The set's black cat, hiding behind the parasol at [x], [y]: at rest
/// only its ear tips show, pricked over the top of the canopy either side
/// of its peak. It comes out to answer the learner by ducking under the
/// canopy and out the front, onto the dry sand before the shade - clear of
/// the pole and the sandcastle - and goes back the same way. [canopy] is
/// the canopy's outline: it and the pole stand in front of the cat until
/// it is out from under them.
void _cat(IsoStage s, double x, double y, Path canopy) {
  // Only once the canopy is open to hide behind.
  if (_opened(s) < 1) return;
  final foot = s.at(x, y);
  final pole = Rect.fromLTRB(
    foot.dx - 0.015 * s.unit,
    canopy.getBounds().top,
    foot.dx + 0.015 * s.unit,
    foot.dy,
  );
  s.hidingCat(
    // On the sand behind the pole, its ears under the canopy's peak.
    hidden: s.at(x - 0.62, y - 0.66),
    // In front of the canopy's rim, a little to the left of the pole.
    out: s.at(x + 0.2, y + 0.72),
    reveal: Path.combine(
      PathOperation.difference,
      Path()..addRect((Offset.zero & s.size).inflate(s.size.longestSide)),
      Path.combine(PathOperation.union, canopy, Path()..addRect(pole)),
    ),
  );
}

/// A teal bucket with a handle.
void _bucket(IsoStage s, double x, double y, double grow) {
  if (grow <= 0) return;
  s.scaled(s.at(x, y), grow, () {
    s.cylinder(x, y, 0, 0.08, 0.14, _pail);
    final rim = s.disc(x, y, 0.14, 0.08);
    s.canvas.drawArc(
      rim.inflate(0.01 * s.unit).translate(0, -0.06 * s.unit),
      math.pi,
      math.pi,
      false,
      s.stroke(_trim, 0.015),
    );
  });
}

/// A sandcastle by the water's edge, with a coral flag.
void _castle(IsoStage s, double x, double y, double grow) {
  if (grow <= 0) return;
  final sand = _wetSand.shade(0.06);
  s.scaled(s.at(x, y), grow, () {
    s
      ..box(x - 0.24, y - 0.24, 0, 0.48, 0.48, 0.14, sand)
      ..cylinder(x - 0.17, y - 0.17, 0.14, 0.08, 0.16, sand)
      ..cone(x - 0.17, y - 0.17, 0.3, 0.09, 0.12, sand.shade(0.04))
      ..cylinder(x, y, 0.14, 0.11, 0.24, sand)
      ..cylinder(x + 0.16, y - 0.16, 0.14, 0.07, 0.12, sand)
      ..cylinder(x - 0.16, y + 0.16, 0.14, 0.07, 0.12, sand)
      ..cylinder(x + 0.16, y + 0.16, 0.14, 0.08, 0.16, sand)
      ..cone(x + 0.16, y + 0.16, 0.3, 0.09, 0.12, sand.shade(0.04));
    final foot = s.at(x, y, 0.38);
    final head = s.at(x, y, 0.62);
    final u = s.unit;
    s.canvas
      ..drawLine(foot, head, s.stroke(_trim, 0.015))
      ..drawPath(
        Path()
          ..moveTo(head.dx, head.dy)
          ..lineTo(head.dx + 0.16 * u, head.dy + 0.04 * u)
          ..lineTo(head.dx, head.dy + 0.09 * u)
          ..close(),
        s.fill(_roof),
      );
  });
}
