import 'dart:math' as math;

import 'package:flutter/animation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_full_stack_flutter/features/pronunciation/presentation/scenes/iso_stage.dart';

// The palette: a town crossing on a fresh, clear day. Blue and mint for the
// sky and the far city, slate for the road, warm sand for the pavements,
// sage for the grass - and red kept for the story: the car and the light.
const _skyTop = Tint(212, 0.6, 0.56);
const _skyLow = Tint(166, 0.42, 0.93);
const _sunBody = Tint(44, 0.9, 0.74);
const _sunHalo = Tint(48, 0.85, 0.9);
const _cloud = Tint(196, 0.35, 1);
const _farCity = Tint(214, 0.26, 0.84);
const _nearCity = Tint(208, 0.3, 0.44);
const _cityLights = Tint(32, 0.85, 1);
const _hill = Tint(158, 0.3, 0.5);
const _grass = Tint(104, 0.45, 0.46);
const _earth = Tint(24, 0.5, 0.32);
const _stone = Tint(28, 0.15, 0.17);
const _asphalt = Tint(214, 0.28, 0.22);
const _paint = Tint(44, 0.3, 1);
const _gold = Tint(44, 0.85, 0.72);
const _pavement = Tint(34, 0.4, 0.7);
const _carRed = Tint(3, 1, 0.24);
const _glass = Tint(196, 0.55, 0.66);
const _tyre = Tint(225, 0.2, 0.06);
const _hub = Tint(220, 0.12, 0.82);
const _iron = Tint(224, 0.4, 0.1);
// A lit lamp is brightest at its core and deepens outwards, so it reads as
// a light on both themes rather than as a target.
const _redLamp = Tint(0, 1, 0.74);
const _redRing = Tint(2, 0.95, 0.56);
const _redHalo = Tint(2, 0.85, 0.4);
const _redHot = Tint(8, 0.7, 0.95);
const _amber = Tint(40, 1, 0.72);
const _green = Tint(150, 0.85, 0.72);
const List<Tint> _lamps = [_green, _amber, _redLamp];
const _blueWall = Tint(208, 0.4, 0.66);
const _creamWall = Tint(38, 0.6, 0.82);
const _yellowWall = Tint(46, 0.62, 0.74);
const _slate = Tint(196, 0.4, 0.4);
const _awning = Tint(172, 0.55, 0.46);
const _leaves = Tint(128, 0.42, 0.32);
const _leavesLight = Tint(94, 0.44, 0.44);
const _bark = Tint(22, 0.4, 0.2);
const _stem = Tint(110, 0.45, 0.3);
const _petalPink = Tint(330, 0.6, 0.58);
const _petalGold = Tint(44, 0.9, 0.66);
const _petalLilac = Tint(272, 0.5, 0.58);
const _wood = Tint(28, 0.5, 0.46);
const _ginger = Tint(28, 0.75, 0.56);
const _coat = Tint(40, 0.8, 0.6);
const _skin = Tint(26, 0.5, 0.78);
const _bird = Tint(26, 0.5, 0.4);
const _cheek = Tint(40, 0.3, 0.92);

// The crossroads: a road along x and one along y, each from [_r0] to [_r1],
// so the junction is the square between them. Traffic keeps left.
const _r0 = 1.5;
const _r1 = 3.2;
const double _mid = (_r0 + _r1) / 2;

// The red car, in the near lane of the x road, heading back towards the
// junction: it lands at [_startAt] and stops with its nose at [_stopAt].
const double _carY = _mid + 0.08;
const _carW = 0.7;
const _carL = 1.4;
const _stopAt = 3.82;
const _startAt = 4.55;
const _wheelR = 0.15;

// The traffic light, on the corner, facing the car.
const double _poleX = _r1 + 0.22;
const double _poleY = _r1 + 0.28;
const _poleH = 1.05;
const _headH = 1.5;

/// "The red car stopped at the traffic light": a crossroads on a floating
/// island. The island rises, the shops and the house drop onto their
/// corners and the traffic light springs up showing green; the red car lands
/// at the end of the road and drives in, the light turns amber, then red, and
/// the car brakes to a stop at the line, rocking on its springs, brake lights
/// on. A sparrow lands on the light to watch.
void paintTraffic(IsoStage s) {
  // A small sun climbs to its place on the right, beside the subtitle like
  // the rest of the set, kept modest so it never competes with the red lamp.
  final climb = s.phase(0.1, 0.8);
  s
    ..sky(_skyTop, _skyLow)
    ..sun(0.84, 0.21 - 0.06 * climb, 0.62, _sunBody, _sunHalo, rings: 2);

  // The far city climbs out of the haze while the island rises.
  final rise = s.phase(0.05, 0.6);
  s
    ..canvas.save()
    ..canvas.translate(0, (1 - rise) * s.unit * 2.5);
  _skyline(s, 0.8, 3.6, _farCity, seed: 3);
  _skyline(s, 0.85, 2.4, _nearCity, seed: 8, lights: _cityLights);
  s
    ..canvas.restore()
    ..ridge(0.88, 0.8, _hill, seed: 4);

  final drift = s.phase(0.2, 1);
  s
    ..cloud(s.screen(0.74 + 0.5 * (1 - drift), 0.21), 2.4, _cloud)
    ..cloud(s.screen(0.1 - 0.5 * (1 - drift), 0.19), 1.9, _cloud)
    ..cloud(s.screen(0.08 - 0.4 * (1 - drift), 0.555), 1.1, _cloud);

  s.rising(0, 0.42, () {
    s.island(grass: _grass, earth: _earth, stone: _stone);
    _roads(s);
    _blocks(s);

    // Standing things, back to front.
    s
      ..bush(0.5, 0.75, _leaves, size: 0.8, grow: s.pop(0.46, 0.66))
      ..bush(0.85, 0.4, _leavesLight, size: 0.6, grow: s.pop(0.5, 0.7))
      ..dropping(0.26, 0.6, (lift) => _shopBlue(s, lift))
      ..dropping(0.32, 0.66, (lift) => _house(s, lift))
      ..dropping(0.38, 0.7, (lift) => _cafe(s, lift))
      // On the lawn in front of the house's side wall, so after the house.
      ..bush(1.18, 3.62, _leaves, size: 0.55, grow: s.pop(0.56, 0.76))
      ..tree(
        0.75,
        5.5,
        leaves: _leavesLight,
        bark: _bark,
        ground: _grass,
        h: 1.6,
        grow: s.pop(0.5, 0.7),
      );
    // Someone waits on the far corner to cross.
    _walker(s, _r1 + 0.25, _r0 - 0.18);
    _streetLamp(s, 5.7, 1.32);

    // The light springs up on green, goes amber, then red.
    final stage = s.t < 0.5
        ? 0
        : s.t < 0.68
        ? 1
        : s.t < 0.76
        ? 2
        : 3;
    _signal(s, grow: s.pop(0.4, 0.54), stage: stage);

    // The car lands at the end of the road, then brakes to the line: still
    // rolling on amber, the last stretch on red.
    if (s.t >= 0.48) {
      final drive = s.phase(0.56, 0.88, Curves.easeOutQuad);
      final run = s.phase(0.56, 0.88, Curves.linear);
      final speed = run > 0 ? 2 * (1 - run) : 0.0;
      final travel = (_startAt - _stopAt) * drive;
      final settle = s.phase(0.86, 0.98, Curves.linear);
      s.faded(s.phase(0.48, 0.52), () {
        _car(
          s,
          nose: _startAt - travel,
          lift: s.drop(0.48, 0.6, from: 4),
          roll: -travel / _wheelR,
          bob: 0.04 * math.sin(settle * math.pi * 2) * (1 - settle),
          speed: speed,
          braking: s.t >= 0.74,
        );
      });
    }

    // The little park in front: the bench and the flower beds, then the
    // trees, which stand in front of them all.
    _bench(s, 5.2, 4);
    const beds = [
      (x: 4.3, y: 4.0, tint: _petalPink),
      (x: 4.7, y: 4.25, tint: _petalGold),
      (x: 4.15, y: 4.5, tint: _petalLilac),
      (x: 4.0, y: 3.9, tint: _petalGold),
      (x: 4.55, y: 4.75, tint: _petalPink),
      (x: 5.6, y: 4.7, tint: _petalLilac),
      (x: 5.3, y: 5.15, tint: _petalGold),
      (x: 3.9, y: 4.85, tint: _petalPink),
    ];
    final ordered = [...beds]..sort((a, b) => (a.x + a.y).compareTo(b.x + b.y));
    for (var i = 0; i < ordered.length; i++) {
      final bed = ordered[i];
      s.flower(
        bed.x,
        bed.y,
        bed.tint,
        _stem,
        grow: s.pop(0.64 + i * 0.025, 0.8 + i * 0.025),
      );
    }
    s
      ..tree(
        3.8,
        5.62,
        leaves: _leaves,
        bark: _bark,
        ground: _grass,
        grow: s.pop(0.52, 0.74),
      )
      ..bush(4.65, 5.7, _leaves, size: 0.8, grow: s.pop(0.62, 0.84))
      ..tree(
        5.45,
        5.35,
        leaves: _leavesLight,
        bark: _bark,
        ground: _grass,
        h: 1.4,
        grow: s.pop(0.58, 0.8),
      );
  });
}

/// A distant city: a row of blocks of varied heights along screen fraction
/// [baseline], up to [height] tiles tall. With [lights], a scatter of its
/// windows catch the light: glints by day, lit rooms on a dark theme. Only
/// the blocks clear of the island are lit: around its soil and rock a few
/// stray panes would read as specks, not as windows.
void _skyline(
  IsoStage s,
  double baseline,
  double height,
  Tint tint, {
  required int seed,
  Tint? lights,
}) {
  final base = s.size.height * baseline;
  final path = Path();
  final windows = Path();
  final pane = s.unit * 0.09;
  final across = s.unit * 0.2;
  final down = s.unit * 0.26;
  // The island's flanks, with a margin: no lit panes below its top between
  // them.
  final flankLeft = s.at(0, IsoStage.span).dx - s.unit * 0.5;
  final flankRight = s.at(IsoStage.span, 0).dx + s.unit * 0.5;
  final islandTop = s.origin.dy;
  var x = -s.unit * 0.4;
  var i = 0;
  while (x < s.size.width) {
    final w = s.unit * (0.5 + 0.7 * _hash(i, seed));
    final h = s.unit * height * (0.3 + 0.7 * _hash(i + 31, seed));
    path.addRect(Rect.fromLTRB(x, base - h, x + w + 0.5, s.size.height));
    if (lights != null) {
      final cols = ((w - across * 0.6) / across).floor();
      final rows = ((h - down * 0.6) / down).floor();
      for (var row = 0; row < rows; row++) {
        for (var col = 0; col < cols; col++) {
          if (_hash(i * 97 + row * 13 + col, seed + 1) < 0.62) continue;
          final left = x + across * (0.6 + col);
          final top = base - h + down * (0.6 + row);
          final nearIsland =
              top > islandTop && left + pane > flankLeft && left < flankRight;
          if (nearIsland) continue;
          windows.addRect(Rect.fromLTWH(left, top, pane, pane));
        }
      }
    }
    // Some blocks step back to a narrower top or carry a mast.
    final kind = _hash(i + 57, seed);
    if (kind > 0.72) {
      path.addRect(
        Rect.fromLTRB(x + w * 0.25, base - h * 1.18, x + w * 0.75, base - h),
      );
    } else if (kind < 0.12) {
      path.addRect(
        Rect.fromLTRB(
          x + w * 0.47,
          base - h - s.unit * 0.5,
          x + w * 0.53,
          base - h,
        ),
      );
    }
    x += w;
    i++;
  }
  s.canvas.drawPath(path, s.fill(tint));
  if (lights != null) s.canvas.drawPath(windows, s.fill(lights));
}

/// A repeatable pseudo-random fraction for [i] - the same every frame.
double _hash(int i, int seed) {
  final v = math.sin(i * 12.9898 + seed * 78.233) * 43758.5453;
  return v - v.floorToDouble();
}

/// The asphalt, the road ends on the island's edge, and the markings.
void _roads(IsoStage s) {
  const width = _r1 - _r0;
  const far = IsoStage.span;
  s
    ..patch(0, _r0, far, width, _asphalt)
    ..patch(_r0, 0, width, far, _asphalt)
    // The roads run out over the island's lip.
    ..canvas.drawPath(
      s.face([
        (x: far, y: _r0, z: 0.004),
        (x: far, y: _r1, z: 0.004),
        (x: far, y: _r1, z: -0.2),
        (x: far, y: _r0, z: -0.2),
      ]),
      s.fill(_asphalt.shade(-0.18)),
    )
    ..canvas.drawPath(
      s.face([
        (x: _r0, y: far, z: 0.004),
        (x: _r1, y: far, z: 0.004),
        (x: _r1, y: far, z: -0.2),
        (x: _r0, y: far, z: -0.2),
      ]),
      s.fill(_asphalt.shade(-0.08)),
    );

  // Centre lines, dashed, from each crossing out to the edge.
  for (var a = _r1 + 0.75; a < far - 0.2; a += 0.6) {
    s
      ..patch(a, _mid - 0.035, 0.32, 0.07, _gold, z: 0.004)
      ..patch(_mid - 0.035, a, 0.07, 0.32, _gold, z: 0.004);
  }
  s
    ..patch(0.15, _mid - 0.035, 0.32, 0.07, _gold, z: 0.004)
    ..patch(_mid - 0.035, 0.15, 0.07, 0.32, _gold, z: 0.004);

  // Zebra crossings on the two near arms, just outside the junction,
  // painting themselves in stripe by stripe as the island settles.
  for (var i = 0; i < 8; i++) {
    final along = _r0 + 0.07 + i * 0.21;
    final stripe = 0.42 * s.phase(0.3 + i * 0.025, 0.4 + i * 0.025);
    if (stripe <= 0) continue;
    s
      ..patch(_r1 + 0.07, along, stripe, 0.12, _paint, z: 0.004)
      ..patch(along, _r1 + 0.07, 0.12, stripe, _paint, z: 0.004);
  }
  // The stop line the car will wait at.
  s.patch(
    _stopAt - 0.14,
    _mid + 0.04,
    0.08,
    _r1 - _mid - 0.08,
    _paint,
    z: 0.004,
  );
}

/// The four corners: raised pavement, with grass inside where nothing is
/// built.
void _blocks(IsoStage s) {
  const kerb = 0.07;
  const far = IsoStage.span;
  const lawn = kerb + 0.002;
  s
    ..box(0, 0, 0, _r0, _r0, kerb, _pavement)
    ..patch(0, 0, _r0 - 0.24, _r0 - 0.24, _grass, z: lawn)
    ..box(_r1, 0, 0, far - _r1, _r0, kerb, _pavement)
    ..box(0, _r1, 0, _r0, far - _r1, kerb, _pavement)
    ..patch(0, _r1 + 0.24, _r0 - 0.24, far - _r1 - 0.24, _grass, z: lawn)
    ..box(_r1, _r1, 0, far - _r1, far - _r1, kerb, _pavement)
    ..patch(
      _r1 + 0.42,
      _r1 + 0.42,
      far - _r1 - 0.42,
      far - _r1 - 0.42,
      _grass,
      z: lawn,
    );
}

/// A round panel on a left-facing wall (the plane at [y]), centred at [x],
/// [z], [r] tiles across.
Path _roundLeft(IsoStage s, double y, double x, double z, double r) => s.face([
  for (var i = 0; i < 16; i++)
    (
      x: x + r * math.cos(i * math.pi / 8),
      y: y,
      z: z + r * math.sin(i * math.pi / 8),
    ),
]);

/// A round panel on a right-facing wall (the plane at [x]), centred at [y],
/// [z], [r] tiles across.
Path _roundRight(IsoStage s, double x, double y, double z, double r) => s.face(
  [
    for (var i = 0; i < 16; i++)
      (
        x: x,
        y: y + r * math.cos(i * math.pi / 8),
        z: z + r * math.sin(i * math.pi / 8),
      ),
  ],
);

/// A half-round hood standing [out] tiles proud of a right-facing wall (the
/// plane at [x]) over a lamp centred at [y], [z], [r] across: the shell it
/// sweeps, and the rim of its front edge.
({Path shell, Path rim}) _hoodRight(
  IsoStage s,
  double x,
  double y,
  double z,
  double r,
  double out,
) {
  const steps = 10;
  Offset arc(double along, int i) {
    final a = i * math.pi / steps;
    return s.at(along, y + r * math.cos(a), z + r * math.sin(a));
  }

  final shell = Path();
  final rim = Path();
  for (var i = 0; i <= steps; i++) {
    final back = arc(x, i);
    final front = arc(x + out, i);
    i == 0 ? shell.moveTo(back.dx, back.dy) : shell.lineTo(back.dx, back.dy);
    i == 0 ? rim.moveTo(front.dx, front.dy) : rim.lineTo(front.dx, front.dy);
  }
  for (var i = steps; i >= 0; i--) {
    final front = arc(x + out, i);
    shell.lineTo(front.dx, front.dy);
  }
  return (shell: shell..close(), rim: rim);
}

/// A striped awning on a left-facing wall at [y], from [x] for [w] tiles,
/// hung at [z].
void _awningLeft(IsoStage s, double y, double x, double w, double z) {
  const stripes = 6;
  const out = 0.32;
  const fall = 0.2;
  for (var i = 0; i < stripes; i++) {
    final a = x + w * i / stripes;
    final b = x + w * (i + 1) / stripes;
    final tint = i.isEven ? _awning : _creamWall.shade(0.12);
    s.canvas
      ..drawPath(
        s.face([
          (x: a, y: y, z: z),
          (x: b, y: y, z: z),
          (x: b, y: y + out, z: z - fall),
          (x: a, y: y + out, z: z - fall),
        ]),
        s.fill(tint.shade(0.06)),
      )
      ..drawPath(
        s.face([
          (x: a, y: y + out, z: z - fall),
          (x: b, y: y + out, z: z - fall),
          (x: b, y: y + out, z: z - fall - 0.09),
          (x: a, y: y + out, z: z - fall - 0.09),
        ]),
        s.fill(tint.shade(-0.04)),
      );
  }
}

/// The soft shadow a building of [w] by [d] at [x], [y] casts on [ground]:
/// its footprint, a little wider on the sides away from the light, so it
/// never spills off the island the way a round shadow would.
void _footprint(
  IsoStage s,
  double x,
  double y,
  double w,
  double d,
  Tint ground,
) {
  s.patch(x, y, w + 0.09, d + 0.09, ground.shade(-0.12), z: 0.074);
}

/// The blue corner shop on the right-hand block, [lift] tiles up.
void _shopBlue(IsoStage s, double lift) {
  const x = 3.4;
  const y = 0.15;
  const w = 1.2;
  const d = 0.95;
  const h = 1.65;
  final z = lift;
  if (lift < 0.05) _footprint(s, x, y, w, d, _pavement);
  s
    ..box(x, y, z, w, d, h, _blueWall)
    // Upstairs windows, a door and a shop window below.
    ..onLeft(y + d, x + 0.14, z + 1.02, 0.26, 0.36, _glass)
    ..onLeft(y + d, x + 0.47, z + 1.02, 0.26, 0.36, _glass)
    ..onLeft(y + d, x + 0.8, z + 1.02, 0.26, 0.36, _glass)
    ..onLeft(y + d, x + 0.12, z, 0.28, 0.62, _slate)
    ..onLeft(y + d, x + 0.5, z + 0.16, 0.58, 0.44, _glass.shade(0.08))
    ..onRight(x + w, y + 0.16, z + 1.02, 0.26, 0.36, _glass.shade(-0.1))
    ..onRight(x + w, y + 0.54, z + 1.02, 0.26, 0.36, _glass.shade(-0.1))
    ..onRight(x + w, y + 0.2, z + 0.2, 0.55, 0.42, _glass.shade(-0.04))
    // A cornice, and a box of machinery on the flat roof.
    ..box(x - 0.04, y - 0.04, z + h, w + 0.08, d + 0.08, 0.07, _blueWall)
    ..box(x + 0.25, y + 0.18, z + h + 0.07, 0.36, 0.3, 0.2, _hub.shade(-0.2));
  _awningLeft(s, y + d, x + 0.44, 0.7, z + 0.8);
}

/// The cream café further along, [lift] tiles up.
void _cafe(IsoStage s, double lift) {
  const x = 4.8;
  const y = 0.15;
  const w = 1.1;
  const d = 0.95;
  const h = 1.15;
  final z = lift;
  if (lift < 0.05) _footprint(s, x, y, w, d, _pavement);
  s
    ..box(x, y, z, w, d, h, _creamWall)
    ..onLeft(y + d, x + 0.12, z + 0.14, 0.52, 0.46, _glass.shade(0.08))
    ..onLeft(y + d, x + 0.74, z, 0.26, 0.62, _awning.shade(-0.1))
    ..onRight(x + w, y + 0.22, z + 0.32, 0.5, 0.4, _glass.shade(-0.1))
    // A sign board along the top.
    ..onLeft(y + d, x + 0.1, z + 0.86, 0.9, 0.18, _awning);
  _awningLeft(s, y + d, x + 0.06, 0.66, z + 0.76);
}

/// The yellow house on the left-hand block, [lift] tiles up, with the cat
/// on its step.
void _house(IsoStage s, double lift) {
  const x = 0.15;
  const y = 3.6;
  const w = 0.9;
  const d = 1.5;
  const h = 1.05;
  final z = lift;
  if (lift < 0.05) _footprint(s, x, y, w, d, _grass);
  s
    ..box(x, y, z, w, d, h, _yellowWall)
    ..onLeft(y + d, x + 0.27, z + 0.42, 0.36, 0.36, _glass)
    ..onRight(x + w, y + 0.6, z, 0.34, 0.66, _slate)
    ..onRight(x + w, y + 0.14, z + 0.4, 0.3, 0.34, _glass.shade(-0.1))
    ..onRight(x + w, y + 1.06, z + 0.4, 0.3, 0.34, _glass.shade(-0.1))
    ..box(x + w, y + 0.54, z, 0.16, 0.46, 0.06, _pavement)
    ..box(x + 0.2, y + 0.3, z + h, 0.22, 0.22, 0.75, _slate.shade(0.1))
    ..roof(x, y, z + h, w, d, 0.55, _slate, alongX: false);
  _cat(s, x + w + 0.09, y + 0.92, z + 0.06);
}

/// A ginger cat sitting at [x], [y], [z], looking down the road.
void _cat(IsoStage s, double x, double y, double z) {
  final grow = s.pop(0.7, 0.84);
  if (grow <= 0) return;
  final head = s.at(x, y, z + 0.2 * grow);
  final r = 0.055 * s.unit * grow;
  s
    ..sphere(x, y, z + 0.08 * grow, 0.075 * grow, _ginger)
    ..sphere(x, y, z + 0.2 * grow, 0.055 * grow, _ginger.shade(0.04));
  final tailFoot = s.at(x, y - 0.06, z + 0.02);
  final tailBend = s.at(x, y - 0.22, z + 0.04);
  final tailTip = s.at(x, y - 0.2, z + 0.16 * grow);
  s.canvas
    ..drawPath(
      Path()
        ..moveTo(head.dx - r * 0.95, head.dy - r * 0.3)
        ..lineTo(head.dx - r * 0.75, head.dy - r * 1.55)
        ..lineTo(head.dx - r * 0.15, head.dy - r * 0.9)
        ..close()
        ..moveTo(head.dx + r * 0.95, head.dy - r * 0.3)
        ..lineTo(head.dx + r * 0.75, head.dy - r * 1.55)
        ..lineTo(head.dx + r * 0.15, head.dy - r * 0.9)
        ..close(),
      s.fill(_ginger),
    )
    ..drawPath(
      Path()
        ..moveTo(tailFoot.dx, tailFoot.dy)
        ..quadraticBezierTo(tailBend.dx, tailBend.dy, tailTip.dx, tailTip.dy),
      s.stroke(_ginger.shade(-0.06), 0.03)..style = PaintingStyle.stroke,
    );
}

/// A pedestrian standing at [x], [y]: legs, a coat with its arms, a head -
/// a little taller than the car, so they read as a person, not a bollard.
void _walker(IsoStage s, double x, double y) {
  final grow = s.pop(0.7, 0.84);
  final sleeve = s.stroke(_coat.shade(-0.1), 0.04);
  s.scaled(s.at(x, y), grow, () {
    s
      ..shadow(x, y, 0.12, _pavement)
      ..cylinder(x, y, 0, 0.05, 0.3, _iron.shade(0.1))
      ..cylinder(x, y, 0.28, 0.09, 0.32, _coat)
      ..canvas.drawLine(
        s.at(x - 0.07, y + 0.07, 0.56),
        s.at(x - 0.085, y + 0.085, 0.36),
        sleeve,
      )
      ..canvas.drawLine(
        s.at(x + 0.07, y - 0.07, 0.56),
        s.at(x + 0.085, y - 0.085, 0.36),
        sleeve,
      )
      ..sphere(x, y, 0.71, 0.09, _skin);
  });
}

/// A street lamp at [x], [y].
void _streetLamp(IsoStage s, double x, double y) {
  final grow = s.pop(0.5, 0.66);
  s.scaled(s.at(x, y), grow, () {
    s
      ..shadow(x, y, 0.14, _pavement)
      ..cylinder(x, y, 0, 0.045, 1.75, _iron)
      ..sphere(x, y, 1.66, 0.11, _hub.shade(0.1))
      ..cone(x, y, 1.7, 0.14, 0.16, _iron);
  });
}

/// The traffic light on the corner, [grow] of the way up. [stage] is which
/// lamp is lit - none, green, amber, red; each one's glow spreads as it
/// comes on. A sparrow drops onto it at the end.
void _signal(IsoStage s, {required double grow, required int stage}) {
  const x = _poleX;
  const y = _poleY;
  const h = _poleH;
  const half = 0.13;
  const face = x + half;
  const top = h + _headH;
  const pitch = 0.46;
  const r = 0.18;
  final glows = [s.pop(0.5, 0.58), s.pop(0.68, 0.75), s.pop(0.76, 0.88)];
  double lampZ(int i) => h + 0.29 + i * pitch;
  s.scaled(s.at(x, y), grow, () {
    s
      ..shadow(x, y, 0.24, _pavement)
      ..cylinder(x, y, 0, 0.065, h + 0.1, _iron)
      // The pedestrians' button box.
      ..box(x + 0.06, y - 0.08, 0.56, 0.1, 0.16, 0.2, _gold, edge: false)
      ..box(x - half, y - 0.3, h, 2 * half, 0.6, _headH, _iron);
    // The backplate round the lamps, with its bright border.
    final outer = s.face([
      (x: face, y: y - 0.4, z: h - 0.1),
      (x: face, y: y + 0.4, z: h - 0.1),
      (x: face, y: y + 0.4, z: top + 0.1),
      (x: face, y: y - 0.4, z: top + 0.1),
    ]);
    s.canvas
      ..drawPath(
        Path.from(outer)
          ..addPath(
            s.face([
              (x: face, y: y - 0.3, z: h),
              (x: face, y: y + 0.3, z: h),
              (x: face, y: y + 0.3, z: top),
              (x: face, y: y - 0.3, z: top),
            ]),
            Offset.zero,
          )
          ..fillType = PathFillType.evenOdd,
        s.fill(_iron.shade(0.06)),
      )
      ..drawPath(outer, s.stroke(_gold, 0.03));
    // The lit lamp's glow first, deepening outwards, so the lamps either
    // side of it still sit on top.
    final on = stage - 1;
    if (on == 2) {
      final glow = glows[2];
      s.canvas
        ..drawPath(
          _roundRight(s, face, y, lampZ(2), r * (1 + 0.5 * glow)),
          s.fill(_redHalo),
        )
        ..drawPath(
          _roundRight(s, face, y, lampZ(2), r * (1 + 0.22 * glow)),
          s.fill(_redRing),
        );
    } else if (on >= 0) {
      s.canvas.drawPath(
        _roundRight(s, face, y, lampZ(on), r * (1 + 0.3 * glows[on])),
        s.fill(_lamps[on].at(0.5)),
      );
    }
    for (var i = 0; i < 3; i++) {
      final lit = on == i;
      final tint = lit ? _lamps[i] : Tint(_lamps[i].hue, 0.35, 0.14);
      s.canvas.drawPath(_roundRight(s, face, y, lampZ(i), r), s.fill(tint));
      if (lit) {
        s.canvas.drawPath(
          _roundRight(s, face, y + 0.05, lampZ(i) + 0.05, r * 0.42),
          s.fill(i == 2 ? _redHot : tint.shade(0.25)),
        );
      }
    }
    // A hood curving over each lamp - the archetypal traffic-light cue -
    // with a crisp rim along its front edge.
    for (var i = 0; i < 3; i++) {
      final hood = _hoodRight(s, face, y, lampZ(i), r + 0.025, 0.06);
      s.canvas
        ..drawPath(hood.shell, s.fill(_iron.shade(0.04)))
        ..drawPath(hood.rim, s.stroke(_iron.shade(0.24), 0.025));
    }
  });
  // The sparrow lands on top once the car has stopped.
  s.dropping(
    0.86,
    0.98,
    (lift) => _sparrow(s, face, y + 0.12, top + 0.1 + lift),
    from: 2,
  );
}

/// A sparrow perched at [x], [y], [z], facing the viewer's left.
void _sparrow(IsoStage s, double x, double y, double z) {
  final tail = s.at(x, y - 0.26, z + 0.27);
  s
    ..canvas.drawLine(
      s.at(x, y - 0.08, z + 0.14),
      tail,
      s.stroke(_bird.shade(-0.08), 0.07),
    )
    ..sphere(x, y, z + 0.14, 0.14, _bird)
    // The folded wing along its side.
    ..canvas.drawLine(
      s.at(x + 0.08, y + 0.05, z + 0.2),
      s.at(x + 0.08, y - 0.13, z + 0.15),
      s.stroke(_bird.shade(-0.2), 0.06),
    )
    ..sphere(x, y + 0.13, z + 0.31, 0.095, _bird.shade(0.06));
  final cheek = s.at(x + 0.04, y + 0.16, z + 0.29);
  final beak = s.at(x, y + 0.25, z + 0.3);
  s.canvas
    ..drawCircle(cheek, 0.035 * s.unit, s.fill(_cheek))
    ..drawCircle(beak, 0.035 * s.unit, s.fill(_gold.shade(-0.1)));
}

/// The red car with its nose at [nose], [lift] tiles above the road, its
/// body rocked [bob] on its springs and its wheels turned through [roll].
/// [speed] draws streaks behind it; [braking] lights its brake lights.
void _car(
  IsoStage s, {
  required double nose,
  required double lift,
  required double roll,
  required double bob,
  required double speed,
  required bool braking,
}) {
  const y = _carY;
  const w = _carW;
  const l = _carL;
  final z = lift + bob;
  if (lift < 0.2) s.patch(nose + 0.08, y + 0.1, l, w, _asphalt.shade(-0.1));
  final tail = braking ? _redLamp : _carRed.shade(0.18);
  s
    ..box(nose, y, z + 0.12, l, w, 0.34, _carRed)
    ..box(nose + 0.36, y + 0.06, z + 0.46, 0.64, w - 0.12, 0.3, _carRed)
    // Windows down the near side and across the back.
    ..onLeft(y + w - 0.06, nose + 0.42, z + 0.5, 0.24, 0.21, _glass)
    ..onLeft(y + w - 0.06, nose + 0.72, z + 0.5, 0.24, 0.21, _glass)
    ..onRight(nose + 1, y + 0.14, z + 0.5, w - 0.28, 0.21, _glass)
    // Brake lights, number plate, bumper.
    ..onRight(nose + l, y + 0.05, z + 0.33, 0.14, 0.09, tail)
    ..onRight(nose + l, y + w - 0.19, z + 0.33, 0.14, 0.09, tail)
    ..onRight(nose + l, y + w / 2 - 0.11, z + 0.18, 0.22, 0.08, _paint)
    ..box(
      nose + l - 0.02,
      y + 0.02,
      z + 0.1,
      0.06,
      w - 0.04,
      0.06,
      _hub,
      edge: false,
    );
  // The door seam and handle.
  final seam = nose + 0.7;
  s.canvas
    ..drawLine(
      s.at(seam, y + w, z + 0.16),
      s.at(seam, y + w, z + 0.46),
      s.stroke(_carRed.shade(-0.2), 0.015),
    )
    ..drawLine(
      s.at(seam - 0.16, y + w, z + 0.39),
      s.at(seam - 0.07, y + w, z + 0.39),
      s.stroke(_hub, 0.02),
    );
  for (final cx in [nose + 0.3, nose + l - 0.3]) {
    _wheel(s, y + w + 0.01, cx, lift + _wheelR, roll);
  }
  // Speed streaks trailing behind while it moves, kept over the road rather
  // than out past the island's edge.
  const from = 0.1;
  final start = nose + l + from;
  final end = math.min(start + 0.5 * math.min(speed, 1.5), IsoStage.span);
  if (speed > 0.05 && lift < 0.05 && end - start > 0.05) {
    for (final (dz, dy) in const [(0.24, 0.18), (0.42, 0.42), (0.6, 0.3)]) {
      s.canvas.drawLine(
        s.at(start, y + dy, z + dz),
        s.at(end, y + dy, z + dz),
        s.stroke(_paint, 0.03),
      );
    }
  }
}

/// A wheel on the car's near side.
void _wheel(IsoStage s, double y, double x, double z, double roll) {
  const r = _wheelR;
  final spoke = Offset(math.cos(roll), math.sin(roll)) * (r * 0.5);
  s.canvas
    ..drawPath(_roundLeft(s, y, x, z, r), s.fill(_tyre))
    ..drawPath(_roundLeft(s, y + 0.004, x, z, r * 0.55), s.fill(_hub))
    ..drawLine(
      s.at(x - spoke.dx, y + 0.008, z - spoke.dy),
      s.at(x + spoke.dx, y + 0.008, z + spoke.dy),
      s.stroke(_tyre.shade(0.2), 0.02),
    );
}

/// A park bench at [x], [y], facing the road.
void _bench(IsoStage s, double x, double y) {
  final grow = s.pop(0.6, 0.78);
  s.scaled(s.at(x, y), grow, () {
    s
      ..box(x - 0.3, y - 0.02, 0, 0.04, 0.04, 0.2, _iron)
      ..box(x + 0.26, y - 0.02, 0, 0.04, 0.04, 0.2, _iron)
      ..box(x - 0.34, y + 0.06, 0.24, 0.68, 0.06, 0.2, _wood, edge: false)
      ..box(x - 0.34, y - 0.12, 0.18, 0.68, 0.22, 0.05, _wood);
  });
}
