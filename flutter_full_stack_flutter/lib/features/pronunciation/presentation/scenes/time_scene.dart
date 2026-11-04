import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/animation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_full_stack_flutter/core/audio/sound.dart';
import 'package:flutter_full_stack_flutter/features/pronunciation/presentation/scenes/iso_stage.dart';
import 'package:flutter_full_stack_flutter/features/pronunciation/presentation/scenes/script.dart';

// The palette: a town square in the afternoon. Sandstone and verdigris for
// the clock tower, cool cobbles, pastel fronts and terracotta roofs around
// it, and one accent - the gold of the clocks, the lamps and the chimes.
const _skyTop = Tint(216, 0.66, 0.54);
const _skyLow = Tint(246, 0.42, 0.95);
// Amber, the body brighter than its halo: a glowing disc on both themes,
// not a dark core in a lighter ring.
const _sunBody = Tint(40, 0.75, 1);
const _sunHalo = Tint(36, 0.7, 0.66);
const _cloud = Tint(226, 0.4, 1);
const _farHill = Tint(244, 0.34, 0.72);
const _nearHill = Tint(166, 0.36, 0.6);
const _grass = Tint(100, 0.42, 0.42);
const _earth = Tint(22, 0.6, 0.3);
const _stone = Tint(25, 0.15, 0.17);
const _cobble = Tint(224, 0.32, 0.56);
const _curb = Tint(218, 0.14, 0.84);
const _inlay = Tint(14, 0.5, 0.56);
const _marker = Tint(220, 0.18, 0.84);
const _sand = Tint(32, 0.62, 0.58);
const _trim = Tint(36, 0.4, 0.84);
const _copper = Tint(168, 0.42, 0.44);
const _dial = Tint(46, 0.5, 0.98);
const _gold = Tint(40, 0.85, 0.6);
const _glow = Tint(46, 0.85, 0.88);
const _ink = Tint(222, 0.4, 0.14);
const _hollow = Tint(222, 0.3, 0.2);
const _window = Tint(38, 0.8, 0.62);
const _pane = Tint(210, 0.45, 0.5);
const _door = Tint(205, 0.38, 0.3);
const _tileRed = Tint(12, 0.66, 0.38);
const _tileSlate = Tint(226, 0.42, 0.34);
const _rose = Tint(6, 0.62, 0.6);
const _butter = Tint(44, 0.72, 0.64);
const _sage = Tint(156, 0.46, 0.56);
const _powder = Tint(208, 0.56, 0.6);
const _leaves = Tint(126, 0.42, 0.32);
const _leavesLight = Tint(92, 0.42, 0.46);
const _bark = Tint(22, 0.45, 0.18);
const _iron = Tint(222, 0.28, 0.16);
const _lampOff = Tint(40, 0.25, 0.5);
const _wood = Tint(24, 0.5, 0.42);
const _coat = Tint(205, 0.55, 0.42);
const _skin = Tint(26, 0.5, 0.74);
const _hat = Tint(12, 0.45, 0.3);
const _feathers = Tint(220, 0.22, 0.93);
const _petalPink = Tint(338, 0.75, 0.56);
const _petalGold = Tint(44, 0.9, 0.68);
const _petalLilac = Tint(272, 0.55, 0.6);
const _stem = Tint(110, 0.45, 0.3);
// The sitter's thought: a pale bubble with a crisp cool rim.
const _bubble = Tint(214, 0.3, 1);
const _rim = Tint(222, 0.3, 0.42);

// The clock tower's footprint: its back corner and its width. The square
// is a round plaza centred on it, laid out as a dial, 12 at the back.
const _tx = 2.3;
const _ty = 2.3;
const _tw = 1.5;
const double _mid = _tx + _tw / 2;
const _plaza = 2.42;

// Where the sitter sits, on the bench at seven.
const _sitX = 2.73;
const _sitY = 4.58;

typedef _House = ({
  double x,
  double y,
  double w,
  double d,
  double h,
  Tint wall,
  Tint roof,
  bool facesX,
});

// Two rows of narrow houses along the back edges, their fronts to the
// square: the left row looks down-right, the right row down-left. Each row
// back to front.
const _houses = <_House>[
  (
    x: 0.15,
    y: 1.45,
    w: 1.1,
    d: 1.1,
    h: 1.75,
    wall: _butter,
    roof: _tileRed,
    facesX: true,
  ),
  (
    x: 0.15,
    y: 2.55,
    w: 1.1,
    d: 1,
    h: 2.15,
    wall: _rose,
    roof: _tileSlate,
    facesX: true,
  ),
  (
    x: 0.15,
    y: 3.55,
    w: 1.1,
    d: 1.1,
    h: 1.55,
    wall: _sage,
    roof: _tileRed,
    facesX: true,
  ),
  (
    x: 1.45,
    y: 0.15,
    w: 1.1,
    d: 1.1,
    h: 1.6,
    wall: _powder,
    roof: _tileRed,
    facesX: false,
  ),
  (
    x: 2.55,
    y: 0.15,
    w: 1,
    d: 1.1,
    h: 2.05,
    wall: _butter,
    roof: _tileSlate,
    facesX: false,
  ),
  (
    x: 3.55,
    y: 0.15,
    w: 1.1,
    d: 1.1,
    h: 1.8,
    wall: _rose,
    roof: _tileRed,
    facesX: false,
  ),
];

/// "I think this is the third time", in two acts.
///
/// The town square assembles first: the island rises, the houses drop in
/// round the square, the clock tower lands in the middle of it showing
/// twelve, and someone sits down on the bench. Then the story, in a pool of
/// light at the foot of the tower while the rest of the town sinks back: a
/// thought bubble rises over the sitter (*think*), the clock faces light up
/// and the minute hand sets off (*time*), and it goes round three times.
/// Each time it comes up to twelve the bell strikes, one more lamp round the
/// square lights and one more stroke is counted in the bubble; the third
/// strike rings out widest and the gold III on the square glows with it
/// (*third*). At rest it is three o'clock: three lamps lit, III in the
/// bubble and III on the square, where the tower's shadow points.
const timeScene = SceneScript(
  paintTime,
  cues: [
    Cue('think', _thinks),
    Cue('time', _lights),
    Cue('third', _third),
  ],
  sounds: [
    SceneSound(Sound.clockBell, _first),
    SceneSound(Sound.clockBell, _second),
    SceneSound(Sound.clockBell, _third),
  ],
);

// The story's beats, on the arrival's clock. The sitter starts to count,
// the clock lights and sets off, and it strikes three times a beat apart -
// even, so the count can be followed - the third strike the sentence's.
const _thinks = 0.4;
const _lights = 0.5;
const _beat = 0.1;
const double _first = _lights + _beat;
const double _third = _first + 2 * _beat;
const double _second = _first + _beat;
const _strikes = <double>[_first, _second, _third];

// How long the minute hand takes over each turn after the first: it rests
// on twelve for the rest of the beat while the bell strikes.
const _turn = 0.08;

/// Paints [timeScene].
void paintTime(IsoStage s) {
  s.setting(() {
    s.sky(_skyTop, _skyLow);

    // The afternoon sun slides down its arc to the upper left, where the
    // light on every block comes from: above the headline, and its halo
    // wholly on screen on a phone, a phone on its side and a tablet alike.
    final arc = s.phase(0.05, 0.7);
    s
      ..sun(
        0.3 - 0.15 * arc,
        0.046 + 0.012 * math.sin(arc * math.pi / 2),
        0.5,
        _sunBody,
        _sunHalo,
        rings: 2,
      )
      ..ridge(0.77, 1.4, _farHill, seed: 3);
    _skyline(s);
    s.ridge(0.86, 1, _nearHill, seed: 7);

    // Clouds drift in and stop where no control sits on them: behind the
    // card, and in the calm band above the headline.
    final drift = s.phase(0.2, 1);
    s
      ..cloud(s.screen(0.88 + 0.3 * (1 - drift), 0.065), 1.4, _cloud)
      ..cloud(s.screen(0.8 + 0.4 * (1 - drift), 0.355), 2.4, _cloud)
      ..cloud(s.screen(0.58 + 0.6 * (1 - drift), 0.45), 1.6, _cloud);

    s.rising(0, 0.42, () {
      s.island(grass: _grass, earth: _earth, stone: _stone);
      _square(s);
      // The stage: the foot of the tower and the sitter. Lit once
      // the story starts, and it stays lit.
      s.pool(_mid + 0.5, _mid + 0.5, 2.3, strength: s.storyLight);
      s.faded(s.phase(0.56, 0.68), () => _gnomon(s));

      // The houses drop in turn, alternating sides, back first. The last of
      // each row keeps a shop, with an awning.
      const order = [0, 3, 1, 4, 2, 5];
      for (var i = 0; i < _houses.length; i++) {
        final at = 0.12 + order.indexOf(i) * 0.035;
        s.dropping(
          at,
          at + 0.26,
          (lift) => _house(s, _houses[i], lift, shop: i == 2 || i == 5),
        );
      }

      s
        ..tree(
          0.75,
          5.25,
          leaves: _leavesLight,
          bark: _bark,
          ground: _grass,
          h: 1.8,
          grow: s.pop(0.4, 0.6),
        )
        ..pine(
          5.25,
          0.75,
          needles: _leaves,
          bark: _bark,
          ground: _grass,
          h: 2.1,
          grow: s.pop(0.44, 0.64),
        );

      s.dropping(0.3, 0.62, (lift) => _tower(s, lift), from: 7);

      // Someone on a bench at seven, a dove come down on its back; bushes
      // at the edges.
      s
        ..dropping(0.5, 0.7, (lift) => _bench(s, 2.3, 4.45, lift))
        ..bush(1.7, 5.65, _leavesLight, size: 0.8, grow: s.pop(0.58, 0.76))
        ..bush(5.55, 2.75, _leaves, size: 0.8, grow: s.pop(0.6, 0.78));
      _dove(s, 2.42, 4.475, s.phase(0.66, 0.86), 0, z: 0.47);
      _sitter(s, _sitX, _sitY, s.pop(0.64, 0.76));

      // The lamps round the square, out on the grass clear of the III: they
      // stand up with the rest of the square and light one a strike, left,
      // front, then right - the third beside the III.
      _lamp(s, 5.6, 1.8, s.pop(0.53, 0.67), 2);
      _lamp(s, 2.15, 5.6, s.pop(0.5, 0.64), 0);

      // A low planter of flowers at half past four, clear of the shadow.
      final planter = _onDial(4.7, 1.75);
      s.dropping(
        0.48,
        0.68,
        (lift) => _planter(s, planter.x, planter.y, lift),
      );
      _cat(s, planter.x, planter.y);

      _dove(s, 3.35, 5.05, s.phase(0.6, 0.8), 2.6);
      _dove(s, 3.55, 5.45, s.phase(0.72, 0.92), 1.9);

      // Flowers along the front edges and round the foot of the front lamp.
      const beds = [
        (x: 1.2, y: 5.6, tint: _petalPink),
        (x: 5.6, y: 1.2, tint: _petalLilac),
        (x: 2.6, y: 5.75, tint: _petalGold),
        (x: 5.8, y: 2.2, tint: _petalPink),
        (x: 3.5, y: 5.8, tint: _petalLilac),
        (x: 5.8, y: 3.5, tint: _petalGold),
        (x: 4.95, y: 5.45, tint: _petalPink),
        (x: 5.5, y: 4.95, tint: _petalLilac),
        (x: 5.15, y: 5.8, tint: _petalGold),
      ];
      for (var i = 0; i < beds.length; i++) {
        final bed = beds[i];
        s.flower(
          bed.x,
          bed.y,
          bed.tint,
          _stem,
          grow: s.pop(0.62 + i * 0.025, 0.8 + i * 0.025),
        );
      }
      _lamp(s, 5.45, 5.6, s.pop(0.56, 0.7), 1);
      s.flower(5.8, 5.75, _petalPink, _stem, grow: s.pop(0.8, 0.98));

      // Over everything near it, the sitter's thought.
      _thought(s, _sitX, _sitY);

      // The rest of the town steps back while the clock, its lamps and the
      // one counting have the stage.
      s.spotlight(
        s.at(_mid + 0.3, _mid + 0.3, 1.2),
        radius: 2.8,
        strength: s.storyLight,
      );
    });
  });
}

/// The flare of a light switched on at [at]: up to `1` at once, held a
/// moment, then easing back to nothing - what stays on is the light's own.
/// Even the third strike's has died away by the time the scene is at rest.
double _flare(
  IsoStage s,
  double at, {
  double hold = 0.04,
  double fade = 0.14,
}) =>
    s.phase(at - 0.005, at + 0.025) *
    (1 - s.phase(at + hold, at + hold + fade, Curves.easeInOut));

/// The point on the plaza's dial at [hour], [r] tiles from the middle: 12
/// at the back corner, 3 to the right, 6 at the front, 9 to the left.
({double x, double y}) _onDial(double hour, double r) {
  final a = hour * math.pi / 6;
  final back = -math.cos(a) * r / math.sqrt2;
  final right = math.sin(a) * r / math.sqrt2;
  return (x: _mid + back + right, y: _mid + back - right);
}

/// The round plaza: a kerb, cobbles, a ring of inlay round the tower and
/// the hour stones, set one after another like a clock ticking - with a gold
/// III inlaid at three.
void _square(IsoStage s) {
  final course = s.stroke(_cobble.shade(-0.08), 0.025);
  s.canvas
    ..drawOval(s.disc(_mid, _mid, 0.002, _plaza + 0.14), s.fill(_curb))
    ..drawOval(s.disc(_mid, _mid, 0.004, _plaza), s.fill(_cobble))
    ..drawOval(s.disc(_mid, _mid, 0.005, 2.25), course)
    ..drawOval(s.disc(_mid, _mid, 0.005, 1.82), course)
    ..drawOval(s.disc(_mid, _mid, 0.006, 1.5), s.fill(_inlay))
    ..drawOval(s.disc(_mid, _mid, 0.008, 1.36), s.fill(_cobble.shade(0.06)));
  for (var hour = 0; hour < 12; hour++) {
    final at = 0.42 + hour * 0.012;
    if (hour == 3) {
      _three(s, at);
      continue;
    }
    final grow = s.pop(at, at + 0.08);
    if (grow <= 0) continue;
    final p = _onDial(hour.toDouble(), 2.05);
    final r = (hour % 3 == 0 ? 0.1 : 0.065) * grow;
    s.canvas.drawOval(s.disc(p.x, p.y, 0.01, r), s.fill(_marker));
  }
}

/// The gold III inlaid at three, its strokes set one after another from
/// [at]. They stand upright to the viewer, as the numerals on a clock face
/// do: along the line from twelve to six, one behind another going out. On
/// the third strike they light up, and stay glowing.
void _three(IsoStage s, double at) {
  final lit = s.story(() => s.phase(_third - 0.005, _third + 0.03));
  final flare = s.story(() => _flare(s, _third));
  final centre = _onDial(3, 2.04);
  s.glow(
    s.at(centre.x, centre.y, 0.05),
    0.75 + 0.35 * flare,
    strength: lit * (0.55 + 0.45 * flare),
  );
  // Half a stroke's length, in x and in y alike: the 12-6 line is diagonal.
  const half = 0.21 / math.sqrt2;
  final ink = s.stroke(_gold.shade(0.24 * lit), 0.07 + 0.015 * lit);
  for (var k = 0; k < 3; k++) {
    final from = at + k * 0.02;
    final grow = s.pop(from, from + 0.08);
    if (grow <= 0) continue;
    final p = _onDial(3, 1.9 + k * 0.14);
    final d = half * grow;
    s.canvas.drawLine(
      s.at(p.x - d, p.y - d, 0.01),
      s.at(p.x + d, p.y + d, 0.01),
      ink,
    );
  }
}

/// The tower's long shadow across the plaza, toward the gold III at three:
/// the light, as everywhere in the kit, comes from the upper left.
void _gnomon(IsoStage s) {
  // Toward three is straight to the right: +x and -y in equal parts. The
  // shaft's shadow is as wide as the tower seen from the sun, and the
  // spire's draws it out to a point just short of the gold III.
  const reach = 0.5 / math.sqrt2;
  final tip = _onDial(3, 1.8);
  const z = 0.012;
  s.canvas.drawPath(
    s.face([
      (x: _tx, y: _ty + _tw, z: z),
      (x: _tx, y: _ty, z: z),
      (x: _tx + reach, y: _ty - reach, z: z),
      (x: tip.x, y: tip.y, z: z),
      (x: _tx + _tw + reach, y: _ty + _tw - reach, z: z),
      (x: _tx + _tw, y: _ty + _tw, z: z),
    ]),
    s.fill(_cobble.shade(-0.24)),
  );
}

/// Runs [draw] in the plane of a wall, its origin at world [x], [y], [z]
/// and one unit to a tile: the first axis runs along the wall to the right,
/// the second straight up. [left] is a wall facing down-left (constant y);
/// otherwise it faces down-right (constant x).
void _onWall(
  IsoStage s,
  double x,
  double y,
  double z,
  void Function() draw, {
  required bool left,
}) {
  final o = s.at(x, y, z);
  final along = (left ? s.at(x + 1, y, z) : s.at(x, y - 1, z)) - o;
  final up = s.at(x, y, z + 1) - o;
  s.canvas
    ..save()
    ..transform(
      Float64List.fromList([
        along.dx,
        along.dy,
        0,
        0,
        up.dx,
        up.dy,
        0,
        0,
        0,
        0,
        1,
        0,
        o.dx,
        o.dy,
        0,
        1,
      ]),
    );
  draw();
  s.canvas.restore();
}

/// A stroke [width] tiles wide, for drawing inside [_onWall].
Paint _line(IsoStage s, Tint tint, double width) =>
    s.stroke(tint, width)..strokeWidth = width;

/// A square pyramid over [x], [y], [w] wide, from [z] up [h].
void _pyramid(
  IsoStage s,
  double x,
  double y,
  double z,
  double w,
  double h,
  Tint tint,
) {
  final apex = (x: x + w / 2, y: y + w / 2, z: z + h);
  s.canvas
    ..drawPath(
      s.face([(x: x, y: y + w, z: z), (x: x + w, y: y + w, z: z), apex]),
      s.fill(tint.shade(0.04)),
    )
    ..drawPath(
      s.face([(x: x + w, y: y + w, z: z), (x: x + w, y: y, z: z), apex]),
      s.fill(tint.shade(-0.12)),
    )
    ..drawLine(
      s.at(x + w, y + w, z),
      s.at(apex.x, apex.y, apex.z),
      s.stroke(tint.shade(0.2), 0.025),
    );
}

/// How far round the minute hand has gone, in turns, on the arrival's
/// clock: three of them, each ending on twelve at a strike. The first sets
/// off as the clock lights; the others wait on twelve while the bell rings.
double _turns(IsoStage s) {
  var turns = 0.0;
  for (final (i, end) in _strikes.indexed) {
    final from = i == 0 ? _lights + 0.01 : end - _turn;
    turns += s.phase(from, end, Curves.easeInOut);
  }
  return turns;
}

/// How hard the clock is striking, on the arrival's clock: a jolt at each
/// strike that dies away within its beat, the third the hardest.
double _ding(IsoStage s) {
  var ding = 0.0;
  for (final at in _strikes) {
    ding += _flare(s, at, hold: 0.01, fade: 0.07) * (at == _third ? 1 : 0.6);
  }
  return ding;
}

/// The strikes ringing out of the belfry at [c], on the arrival's clock:
/// arcs of sound spreading to either side - two for a strike, three wider
/// ones for the third - thinning out within their beat.
void _chimes(IsoStage s, Offset c) {
  for (final at in _strikes) {
    final third = at == _third;
    final p = s.phase(at - 0.005, at + (third ? 0.13 : 0.09), Curves.linear);
    if (p <= 0 || p >= 1) continue;
    final spread = Curves.easeOut.transform(p);
    final sound = s.stroke(_gold, (third ? 0.1 : 0.075) * (1 - p));
    for (var k = 0; k < (third ? 3 : 2); k++) {
      final r = 1.45 + (third ? 1.6 : 1.05) * spread - k * 0.3;
      if (r < 1.45) continue;
      final rect = Rect.fromCircle(center: c, radius: r * s.unit);
      for (final side in [0.0, math.pi]) {
        s.canvas.drawArc(rect, side - 0.55, 1.1, false, sound);
      }
    }
  }
}

/// The clock tower, [lift] tiles above where it will stand.
void _tower(IsoStage s, double lift) {
  const x = _tx;
  const y = _ty;
  const w = _tw;
  final z = lift;

  s
    // A step all round, the shaft, a string course and the cornice.
    ..box(x - 0.16, y - 0.16, z, w + 0.32, w + 0.32, 0.18, _trim)
    ..box(x, y, z + 0.18, w, w, 2.12, _sand);

  // Quoins up the three corners in sight, long and short in turn.
  for (var k = 0; k < 8; k++) {
    final at = z + 0.22 + k * 0.26;
    final a = k.isEven ? 0.22 : 0.12;
    final b = k.isEven ? 0.12 : 0.22;
    s
      ..onLeft(y + w, x, at, b, 0.13, _trim)
      ..onLeft(y + w, x + w - a, at, a, 0.13, _trim)
      ..onRight(x + w, y + w - b, at, b, 0.13, _trim.shade(-0.1))
      ..onRight(x + w, y, at, a, 0.13, _trim.shade(-0.1));
  }

  s
    ..box(x - 0.04, y - 0.04, z + 0.86, w + 0.08, w + 0.08, 0.06, _trim)
    ..box(x - 0.1, y - 0.1, z + 2.3, w + 0.2, w + 0.2, 0.14, _trim);

  // An arched door under the left clock.
  _onWall(s, x + w * 0.5, y + w, z + 0.18, left: true, () {
    s.canvas.drawRRect(
      RRect.fromLTRBAndCorners(
        -0.2,
        0,
        0.2,
        0.58,
        topLeft: const Radius.circular(0.2),
        topRight: const Radius.circular(0.2),
      ),
      s.fill(_door),
    );
  });

  // The clock on both faces - the story's own: dull until the clock lights
  // up and sets off, then a glow round each face that jolts brighter at
  // every strike.
  s.story(() {
    final turns = _turns(s);
    final lit = s.phase(_lights - 0.01, _lights + 0.035);
    final flash = math.max(_flare(s, _lights, hold: 0.03, fade: 0.1), _ding(s));
    for (final left in [true, false]) {
      final cx = left ? x + w / 2 : x + w;
      final cy = left ? y + w : y + w / 2;
      s.glow(
        s.at(cx, cy, z + 1.5),
        1 + 0.45 * flash,
        strength: lit * (0.45 + 0.55 * flash),
      );
    }
    for (final left in [true, false]) {
      final cx = left ? x + w / 2 : x + w;
      final cy = left ? y + w : y + w / 2;
      _onWall(s, cx, cy, z + 1.5, left: left, () => _clock(s, turns, lit));
    }
  });

  // The belfry: an open arch on each face with the bell hanging in it,
  // swinging when the clock strikes.
  final swing = s.story(() {
    var swing = 0.0;
    for (final at in _strikes) {
      final p = s.phase(at - 0.02, at + 0.09, Curves.linear);
      swing +=
          math.sin(p * math.pi * 3) * (at == _third ? 0.6 : 0.45) * (1 - p);
    }
    return swing;
  });
  s.box(x + 0.06, y + 0.06, z + 2.44, w - 0.12, w - 0.12, 0.86, _sand);
  for (final left in [true, false]) {
    final cx = left ? x + w / 2 : x + w - 0.06;
    final cy = left ? y + w - 0.06 : y + w / 2;
    _onWall(s, cx, cy, z + 2.44, left: left, () {
      s.canvas
        ..drawRRect(
          RRect.fromLTRBAndCorners(
            -0.36,
            0.1,
            0.36,
            0.74,
            topLeft: const Radius.circular(0.36),
            topRight: const Radius.circular(0.36),
          ),
          s.fill(_hollow),
        )
        ..save()
        ..translate(0, 0.62)
        ..rotate(left ? swing : -swing);
      final bell = Path()
        ..moveTo(-0.08, 0)
        ..quadraticBezierTo(-0.12, -0.2, -0.2, -0.3)
        ..lineTo(0.2, -0.3)
        ..quadraticBezierTo(0.12, -0.2, 0.08, 0)
        ..close();
      s.canvas
        ..drawPath(bell, s.fill(_gold))
        ..drawCircle(const Offset(0, -0.33), 0.05, s.fill(_gold.shade(-0.1)))
        ..restore();
    });
  }

  // The cap and the copper spire with a gold ball on top - kept low enough
  // on a phone to stay behind the record button rather than poke out of it.
  s.box(x - 0.08, y - 0.08, z + 3.3, w + 0.16, w + 0.16, 0.12, _trim);
  _pyramid(s, x - 0.08, y - 0.08, z + 3.42, w + 0.16, 0.88, _copper);
  s.canvas.drawCircle(
    s.at(x + w / 2, y + w / 2, z + 4.36),
    0.08 * s.unit,
    s.fill(_gold),
  );
  s.story(() => _chimes(s, s.at(x + w / 2, y + w / 2, z + 2.9)));
}

/// One clock face, drawn in its wall's plane: [turns] of the minute hand
/// since twelve o'clock, the hour hand following at a twelfth of the pace,
/// [lit] of the way lit up.
void _clock(IsoStage s, double turns, double lit) {
  const r = 0.56;
  final c = s.canvas;
  // A verdigris plaque behind the dial, as on a real clock tower: it frames
  // the face against the sandstone and brings the spire's copper down to
  // where the eye is, with a crisp lit rim like the kit's box edges.
  final plaque = RRect.fromRectAndRadius(
    Rect.fromCircle(center: Offset.zero, radius: 0.6),
    const Radius.circular(0.08),
  );
  c
    ..drawRRect(plaque, s.fill(_copper.shade(-0.08)))
    ..drawRRect(plaque, _line(s, _copper.shade(0.14), 0.03));
  if (lit > 0) {
    c.drawCircle(Offset.zero, r * (1 + 0.08 * lit), s.fill(_glow));
  }
  // Unlit, the dial is a shade of parchment; lit, it is the brightest thing
  // on the tower.
  c
    ..drawCircle(Offset.zero, r, s.fill(_gold.shade(0.1 * lit)))
    ..drawCircle(
      Offset.zero,
      r * 0.85,
      s.fill(Tint(_dial.hue, 0.2 + 0.3 * lit, 0.66 + 0.32 * lit)),
    );
  for (var i = 0; i < 12; i++) {
    final a = i * math.pi / 6;
    final dir = Offset(math.sin(a), math.cos(a));
    if (i == 3) {
      c.drawCircle(dir * r * 0.66, 0.075, s.fill(_gold));
    } else if (i % 3 == 0) {
      c.drawCircle(dir * r * 0.68, 0.045, s.fill(_ink));
    } else {
      c.drawCircle(dir * r * 0.7, 0.022, s.fill(_ink));
    }
  }
  final minute = turns * 2 * math.pi;
  final hour = turns * math.pi / 6;
  c
    ..drawLine(
      Offset.zero,
      Offset(math.sin(hour), math.cos(hour)) * r * 0.46,
      _line(s, _ink, 0.075),
    )
    ..drawLine(
      Offset.zero,
      Offset(math.sin(minute), math.cos(minute)) * r * 0.7,
      _line(s, _ink, 0.045),
    )
    ..drawCircle(Offset.zero, 0.055, s.fill(_gold));
}

/// A narrow house with a gable to the square, [lift] tiles above its place;
/// a [shop] has a striped awning over its ground floor.
void _house(IsoStage s, _House house, double lift, {bool shop = false}) {
  final (:x, :y, :w, :d, :h, :wall, :roof, :facesX) = house;
  final z = lift;
  final length = facesX ? d : w;

  // A panel on the front, [a] tiles from its left end and [b] up.
  void panel(double a, double b, double pw, double ph, Tint tint) => facesX
      ? s.onRight(x + w, y + d - a - pw, z + b, pw, ph, tint)
      : s.onLeft(y + d, x + a, z + b, pw, ph, tint);

  // Only the ground-floor window is warm; the upper ones are cool glass, so
  // the gold belongs to the clocks and the lamps.
  final pane = facesX ? _pane.shade(-0.1) : _pane;
  s.box(x, y, z, w, d, h, wall);
  panel(length * 0.16, 0, 0.3, 0.58, _door);
  panel(length * 0.6, 0.22, 0.28, 0.3, _window);
  for (var b = 0.8; b + 0.42 < h; b += 0.55) {
    panel(length * 0.16, b, 0.28, 0.34, pane);
    panel(length * 0.6, b, 0.28, 0.34, pane);
  }
  if (shop) {
    final stripe = facesX ? _tileRed : _copper;
    const n = 6;
    const from = 0.06;
    final step = (length - 2 * from) / n;
    for (var k = 0; k < n; k++) {
      final a = from + k * step;
      final b = a + step;
      final tint = k.isEven ? stripe : _trim;
      final strip = facesX
          ? [
              (x: x + w, y: y + d - a, z: z + 0.76),
              (x: x + w, y: y + d - b, z: z + 0.76),
              (x: x + w + 0.26, y: y + d - b, z: z + 0.56),
              (x: x + w + 0.26, y: y + d - a, z: z + 0.56),
            ]
          : [
              (x: x + a, y: y + d, z: z + 0.76),
              (x: x + b, y: y + d, z: z + 0.76),
              (x: x + b, y: y + d + 0.26, z: z + 0.56),
              (x: x + a, y: y + d + 0.26, z: z + 0.56),
            ];
      s.canvas.drawPath(
        s.face(strip),
        s.fill(tint.shade(facesX ? -0.06 : 0.04)),
      );
    }
  }
  s.roof(x, y, z + h, w, d, 0.62, roof, alongX: facesX);
}

/// A globe street lamp at [x], [y], [grow] of the way up, that lights at the
/// [count]th strike of the clock (from `0`): the globe flares, throwing a
/// little pool of light round its foot, and settles to a small steady halo.
/// The third flares widest.
void _lamp(IsoStage s, double x, double y, double grow, int count) {
  if (grow <= 0) return;
  const h = 1.15;
  final at = _strikes[count];
  final big = at == _third ? 1.3 : 1.0;
  final on = s.story(() => s.phase(at - 0.005, at + 0.015));
  final flare = s.story(() => _flare(s, at));
  final globe = s.at(x, y, h + 0.15);
  s.scaled(s.at(x, y), grow, () {
    s
      ..pool(x, y, 0.85 * big, strength: on * (0.45 + 0.35 * flare))
      ..shadow(x, y, 0.16, _cobble)
      ..cylinder(x, y, 0, 0.075, 0.12, _iron)
      ..cylinder(x, y, 0, 0.032, h, _iron)
      ..cylinder(x, y, h - 0.03, 0.07, 0.05, _iron);
    if (on > 0) {
      s
        ..glow(globe, (0.7 + 0.4 * flare) * big, strength: 0.5 + 0.5 * flare)
        ..canvas.drawCircle(
          globe,
          (0.2 + 0.14 * flare * big) * s.unit,
          s.fill(_glow.shade(0.08)),
        );
    }
    s.sphere(x, y, h + 0.15, 0.13, on > 0 ? _glow : _lampOff);
    s.canvas.drawCircle(s.at(x, y, h + 0.31), 0.035 * s.unit, s.fill(_iron));
  });
}

/// A bench along x, [lift] tiles above its place, its back to the far side.
void _bench(IsoStage s, double x, double y, double lift) {
  final z = lift;
  const long = 0.86;
  s
    ..box(x + 0.05, y + 0.04, z, 0.06, 0.22, 0.2, _iron, edge: false)
    ..box(x + 0.75, y + 0.04, z, 0.06, 0.22, 0.2, _iron, edge: false)
    ..box(x, y, z + 0.2, long, 0.3, 0.05, _wood)
    ..box(x, y, z + 0.25, long, 0.05, 0.22, _wood);
}

// The planter at half past four: how wide and tall it is, and what grows in
// it - tufts of leaves and blooms round its middle, back to front. The cat
// that hides in it is cut round them.
const _potR = 0.36;
const _potH = 0.3;
typedef _Tuft = ({
  double dx,
  double dy,
  double dz,
  double r,
  Tint tint,
  double shade,
});
typedef _Bloom = ({double dx, double dy, Tint tint});
const _tufts = <_Tuft>[
  (dx: -0.12, dy: -0.08, dz: 0.06, r: 0.16, tint: _leaves, shade: 0.0),
  (dx: 0.1, dy: -0.1, dz: 0.06, r: 0.15, tint: _leaves, shade: 0.04),
  (dx: -0.04, dy: 0.12, dz: 0.08, r: 0.17, tint: _leavesLight, shade: 0.0),
  (dx: 0.14, dy: 0.1, dz: 0.05, r: 0.13, tint: _leavesLight, shade: -0.04),
];
const _blooms = <_Bloom>[
  (dx: -0.14, dy: -0.04, tint: _petalPink),
  (dx: 0.1, dy: -0.12, tint: _petalGold),
  (dx: 0.0, dy: 0.16, tint: _petalLilac),
  (dx: 0.18, dy: 0.12, tint: _petalPink),
];
const _bloomZ = 0.22;
const _bloomR = 0.07;

/// A low round stone planter of flowers, [lift] tiles above its place.
void _planter(IsoStage s, double x, double y, double lift) {
  final top = lift + _potH;
  if (lift < 0.05) s.shadow(x, y, 0.44, _cobble);
  s.cylinder(x, y, lift, _potR, _potH, _curb.shade(-0.04));
  for (final tuft in _tufts) {
    s.sphere(
      x + tuft.dx,
      y + tuft.dy,
      top + tuft.dz,
      tuft.r,
      tuft.tint.shade(tuft.shade),
    );
  }
  for (final bloom in _blooms) {
    s.canvas.drawCircle(
      s.at(x + bloom.dx, y + bloom.dy, top + _bloomZ),
      _bloomR * s.unit,
      s.fill(bloom.tint),
    );
  }
}

/// The black cat, in the planter at [x], [y] - the scene's easter egg (see
/// `HidingCat`). It lies low among the flowers, only its ear tips showing
/// between the blooms, and when it has a reason it sits up out of them -
/// head, chest and paws over the leaves - and sinks back down.
void _cat(IsoStage s, double x, double y) {
  // Only once the planter has landed.
  if (s.t < 0.68) return;
  final base = s.disc(x, y, 0, _potR);
  final lid = s.disc(x, y, _potH, _potR);
  // All of the planter is in front of it: the pot, then every tuft and
  // bloom, so it comes up from behind the leaves with their bumps against
  // its chest. Clockwise, as the ovals added to it are, so that they add up.
  final cover = Path()
    ..moveTo(lid.left, lid.center.dy)
    ..arcTo(lid, math.pi, math.pi, false)
    ..lineTo(base.right, base.center.dy)
    ..arcTo(base, 0, math.pi, false)
    ..close();
  for (final tuft in _tufts) {
    cover.addOval(
      Rect.fromCircle(
        center: s.at(x + tuft.dx, y + tuft.dy, _potH + tuft.dz),
        // As the kit draws a ball.
        radius: tuft.r * s.unit * 1.15,
      ),
    );
  }
  for (final bloom in _blooms) {
    cover.addOval(
      Rect.fromCircle(
        center: s.at(x + bloom.dx, y + bloom.dy, _potH + _bloomZ),
        radius: _bloomR * s.unit,
      ),
    );
  }
  // Low, its ear tips just over the leaves; up, sitting tall in the pot,
  // its haunches still behind them.
  final feet = s.at(x, y);
  s.hidingCat(
    hidden: feet.translate(0, -0.03 * s.unit),
    out: feet.translate(0, -0.46 * s.unit),
    reveal: Path.combine(
      PathOperation.difference,
      s.beyond(base.centerLeft, base.centerRight, of: lid.center),
      cover,
    ),
  );
}

/// A far-off town along the hills, its windows lit: silhouettes standing on
/// the far ridge, their feet hidden by the near one. They are a clear step
/// darker than the hill and the sky behind them, with a lit face toward the
/// sun like every block on the island, so each window sits inside a house
/// that can be seen rather than floating as a speck.
void _skyline(IsoStage s) {
  const shaded = Tint(236, 0.32, 0.36);
  const lit = Tint(232, 0.28, 0.52);
  const buildings = [
    (fx: 0.025, w: 0.55, h: 1.3, kind: 1),
    (fx: 0.07, w: 0.36, h: 2.2, kind: 2),
    (fx: 0.11, w: 0.6, h: 1.05, kind: 0),
    (fx: 0.155, w: 0.48, h: 1.5, kind: 1),
    (fx: 0.835, w: 0.5, h: 1.2, kind: 1),
    (fx: 0.88, w: 0.62, h: 1.6, kind: 0),
    (fx: 0.925, w: 0.34, h: 2.4, kind: 2),
    (fx: 0.97, w: 0.5, h: 1.35, kind: 1),
  ];
  final base = s.size.height * 0.86;
  final u = s.unit;
  final shadedFill = s.fill(shaded);
  final litFill = s.fill(lit);
  final window = s.fill(_glow);
  for (var i = 0; i < buildings.length; i++) {
    final b = buildings[i];
    final cx = s.size.width * b.fx;
    final half = b.w * u / 2;
    final top = base - b.h * u;
    // How far above the eaves the roof peaks: a gable, a spire, or flat.
    final peak = switch (b.kind) {
      1 => half * 0.9,
      2 => half * 3,
      _ => 0.0,
    };
    // The lit face runs from the left wall to the ridge, or two fifths of
    // the way across a flat roof.
    final split = b.kind == 0 ? cx - half * 0.2 : cx;
    s.canvas
      ..drawPath(
        Path()
          ..moveTo(cx - half, base)
          ..lineTo(cx - half, top)
          ..lineTo(cx, top - peak)
          ..lineTo(cx + half, top)
          ..lineTo(cx + half, base)
          ..close(),
        shadedFill,
      )
      ..drawPath(
        Path()
          ..moveTo(cx - half, base)
          ..lineTo(cx - half, top)
          ..lineTo(split, top - (b.kind == 0 ? 0 : peak))
          ..lineTo(split, base)
          ..close(),
        litFill,
      );
    // Two or three lit windows, one a floor, alternating sides.
    final floors = b.h > 2 ? 3 : 2;
    for (var f = 0; f < floors; f++) {
      final left = (i + f).isEven;
      final wx = left ? cx - half * 0.5 : cx + half * 0.45;
      final wy = top + (0.22 + f * 0.36) * u;
      s.canvas.drawRect(
        Rect.fromCenter(
          center: Offset(wx, wy),
          width: 0.09 * u,
          height: 0.13 * u,
        ),
        window,
      );
    }
  }
}

/// Someone sitting on the bench, [grow] of the way there.
void _sitter(IsoStage s, double x, double y, double grow) {
  if (grow <= 0) return;
  const z = 0.25;
  s.scaled(s.at(x, y, z), grow, () {
    s
      ..cylinder(x, y, z, 0.11, 0.34, _coat)
      ..box(x - 0.1, y + 0.02, z, 0.2, 0.26, 0.08, _coat.shade(-0.12))
      ..sphere(x, y, z + 0.47, 0.1, _skin)
      ..cylinder(x, y, z + 0.52, 0.13, 0.015, _hat)
      ..cylinder(x, y, z + 0.52, 0.08, 0.09, _hat);
  });
}

/// The thought of the sitter at [x], [y], on the arrival's clock: a bubble
/// rising from their head at [_thinks], with the clock's strikes counted in
/// it, a stroke at a time.
void _thought(IsoStage s, double x, double y) {
  s.story(() {
    final u = s.unit;
    final head = s.at(x, y, 0.25 + 0.47);
    final open = s.pop(_thinks + 0.004, _thinks + 0.05);
    final rim = s.stroke(_rim, 0.05);
    final fill = s.fill(_bubble);

    // Two puffs, then the bubble, up and to the left, clear of the tower.
    final puffs = [
      (at: _thinks - 0.012, c: const Offset(-0.08, -0.26), r: 0.045),
      (at: _thinks - 0.004, c: const Offset(-0.18, -0.48), r: 0.07),
    ];
    for (final puff in puffs) {
      final grow = s.pop(puff.at, puff.at + 0.025);
      if (grow <= 0) continue;
      final c = head + puff.c * u;
      s.canvas
        ..drawCircle(c, puff.r * grow * u, rim)
        ..drawCircle(c, puff.r * grow * u, fill);
    }
    if (open <= 0) return;

    final c = head + const Offset(-0.36, -1) * u;
    s.scaled(c, open, () {
      // A cloud of overlapping lobes; the rim is stroked first, so the fill
      // covers its inner half and only the outline round the whole is left.
      Rect lobe(double dx, double dy, double r) =>
          Rect.fromCircle(center: c + Offset(dx, dy) * u, radius: r * u);
      final cloud = Path()
        ..addOval(
          Rect.fromCenter(center: c, width: 1.04 * u, height: 0.58 * u),
        )
        ..addOval(lobe(-0.28, -0.13, 0.22))
        ..addOval(lobe(0.02, -0.2, 0.25))
        ..addOval(lobe(0.3, -0.1, 0.2))
        ..addOval(lobe(-0.36, 0.1, 0.18))
        ..addOval(lobe(0.34, 0.12, 0.17))
        ..addOval(lobe(-0.02, 0.17, 0.2));
      s.canvas
        ..drawPath(cloud, rim)
        ..drawPath(cloud, fill);

      // The count: a stroke a strike, I, II, III.
      final ink = s.stroke(_ink, 0.075);
      for (final (k, at) in _strikes.indexed) {
        final grow = s.pop(at - 0.005, at + 0.045);
        if (grow <= 0) continue;
        final dx = (k - 1) * 0.2 * u;
        final half = 0.15 * grow * u;
        s.canvas.drawLine(
          c.translate(dx, 0.01 * u - half),
          c.translate(dx, 0.01 * u + half),
          ink,
        );
      }
    });
  });
}

/// A dove gliding down to [x], [y] - on the ground, or on something [z]
/// tall - [p] of the way there, facing [facing] (radians in the ground
/// plane). It comes in from the front left, over the tree, so it never
/// crosses the clocks.
///
/// At this size a bird is its silhouette, so it is drawn side on, in screen
/// space, turned to whichever side its heading points: a plump body, a tail
/// cocked up behind, a darker folded wing, a small head with an eye and a
/// gold beak.
void _dove(
  IsoStage s,
  double x,
  double y,
  double p,
  double facing, {
  double z = 0,
}) {
  if (p <= 0) return;
  final fall = 1 - p;
  final px = x - 2.2 * fall;
  final py = y + 0.4 * fall;
  final pz = z + 2.6 * fall;
  if (p > 0.6 && z == 0) s.shadow(px, py, 0.13 * p, _cobble);

  final heading = s.at(px + math.cos(facing), py + math.sin(facing));
  final ahead = heading.dx >= s.at(px, py).dx ? 1.0 : -1.0;
  final body = s.at(px, py, pz + 0.13);
  // In tiles once scaled, x toward the beak and y down the screen.
  final c = s.canvas
    ..save()
    ..translate(body.dx, body.dy)
    ..scale(ahead * s.unit, s.unit)
    ..drawPath(
      Path()
        ..moveTo(-0.08, -0.02)
        ..lineTo(-0.36, -0.16)
        ..lineTo(-0.33, -0.01)
        ..close(),
      s.fill(_feathers.shade(-0.24)),
    )
    ..drawOval(
      Rect.fromCenter(center: const Offset(0, 0.02), width: 0.36, height: 0.2),
      s.fill(_feathers.shade(-0.14)),
    )
    ..drawOval(
      Rect.fromCenter(center: Offset.zero, width: 0.36, height: 0.2),
      s.fill(_feathers),
    )
    ..drawPath(
      Path()
        ..moveTo(0.08, -0.05)
        ..quadraticBezierTo(-0.02, 0.06, -0.24, -0.04)
        ..quadraticBezierTo(-0.06, -0.1, 0.08, -0.05)
        ..close(),
      s.fill(_feathers.shade(-0.26)),
    )
    ..drawCircle(const Offset(0.15, -0.11), 0.075, s.fill(_feathers))
    ..drawPath(
      Path()
        ..moveTo(0.21, -0.13)
        ..lineTo(0.29, -0.1)
        ..lineTo(0.21, -0.08)
        ..close(),
      s.fill(_gold),
    )
    ..drawCircle(const Offset(0.17, -0.125), 0.022, s.fill(_ink));
  // In flight, the wings beat over the body, slowing as it comes down.
  if (p < 1) {
    final flap = math.sin(p * math.pi * 7) * fall;
    final wing = _line(s, _feathers.shade(-0.1), 0.06);
    c
      ..drawLine(
        const Offset(-0.02, -0.04),
        Offset(-0.3, -0.04 - 0.36 * flap),
        wing,
      )
      ..drawLine(
        const Offset(-0.02, -0.04),
        Offset(0.26, -0.04 - 0.36 * flap),
        wing,
      );
  }
  c.restore();
}
