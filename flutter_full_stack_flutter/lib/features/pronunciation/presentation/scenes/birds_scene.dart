import 'dart:math' as math;

import 'package:flutter/animation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_full_stack_flutter/features/pronunciation/presentation/scenes/iso_stage.dart';

// The palette: first light. A dawn sky from periwinkle down to peach, a
// dewy meadow green, warm wood, the teal of still water, and one accent -
// the coral of the robins' breasts - for the birds the sentence is about.
const _skyTop = Tint(234, 0.66, 0.5);
const _skyLow = Tint(24, 0.85, 0.83);
const _sunBody = Tint(37, 0.85, 0.98);
const _sunHalo = Tint(35, 0.75, 0.76);
const _cloud = Tint(345, 0.22, 0.95);
const _mist = Tint(20, 0.4, 0.9);
const _farHill = Tint(256, 0.36, 0.68);
const _nearHill = Tint(176, 0.34, 0.56);
const _grass = Tint(100, 0.48, 0.36);
const _earth = Tint(22, 0.62, 0.3);
const _stone = Tint(255, 0.14, 0.18);
const _water = Tint(192, 0.72, 0.46);
const _pebble = Tint(250, 0.16, 0.58);
const _leaves = Tint(126, 0.52, 0.28);
const _leavesLight = Tint(92, 0.5, 0.42);
const _needles = Tint(164, 0.45, 0.24);
const _bark = Tint(22, 0.45, 0.2);
const _wood = Tint(28, 0.6, 0.42);
const _cream = Tint(40, 0.62, 0.86);
const _roof = Tint(192, 0.6, 0.32);
const _reed = Tint(84, 0.5, 0.3);
const _cattail = Tint(22, 0.55, 0.2);
const _skin = Tint(26, 0.6, 0.7);
const _mustard = Tint(42, 0.8, 0.44);
const _teal = Tint(194, 0.62, 0.34);
const _denim = Tint(228, 0.36, 0.22);
const _khaki = Tint(40, 0.4, 0.62);
const _hair = Tint(20, 0.45, 0.14);
const _lens = Tint(232, 0.2, 0.08);
const _breast = Tint(12, 0.85, 0.4);
const _slate = Tint(222, 0.7, 0.2);
const _dusk = Tint(246, 0.45, 0.16);
const _beak = Tint(40, 0.85, 0.56);
const _eye = Tint(232, 0.3, 0.02);
const _flockTint = Tint(236, 0.8, 0);
const _ginger = Tint(24, 0.7, 0.36);
const _duck = Tint(36, 0.36, 0.88);
const _mallard = Tint(156, 0.6, 0.28);
const _egg = Tint(186, 0.55, 0.78);
const _seed = Tint(36, 0.5, 0.5);
const _petalGold = Tint(44, 0.85, 0.62);
const _petalRose = Tint(342, 0.75, 0.56);
const _petalLilac = Tint(266, 0.8, 0.58);
const _stem = Tint(110, 0.55, 0.26);

/// "They were watching the birds this morning": a meadow island at sunrise.
/// The sun comes up as the island rises, the oak and the trees grow, the
/// bench, the birdhouse and the stone bird bath drop into place, two
/// watchers pop onto the bench, and then the birds fly in one after another
/// - a flock across the sun, robins onto the oak, one to the birdhouse roof,
/// two to the bath (one of them splashing), two to the seeds on the lawn in
/// front of it - wings folding as they land. Last, the binoculars come up, a
/// finger points at the robins on the oak, and the cat by the bush settles
/// down to watch them too.
void paintBirds(IsoStage s) {
  s.sky(_skyTop, _skyLow);

  // The sun climbs out of the morning haze while the island rises.
  final climb = s.phase(0, 0.7);
  s
    ..sun(_sunX, _sunY + 0.14 * (1 - climb), _sunSize, _sunBody, _sunHalo)
    // Morning mist lifting off the hills, half behind the far ridge.
    ..cloud(s.screen(0.12, 0.72), 4, _mist)
    ..cloud(s.screen(0.88, 0.71), 3.4, _mist)
    ..ridge(0.74, 1.5, _farHill, seed: 3)
    ..ridge(0.84, 1.05, _nearHill, seed: 6);

  final drift = s.phase(0.1, 0.95);
  s
    ..cloud(s.screen(0.16 - 0.45 * (1 - drift), 0.31), 2.6, _cloud)
    ..cloud(s.screen(0.95 + 0.45 * (1 - drift), 0.44), 1.9, _cloud)
    ..cloud(s.screen(0.08 - 0.3 * (1 - drift), 0.58), 1.4, _cloud);

  _flock(s);

  s.rising(0, 0.42, () {
    s.island(grass: _grass, earth: _earth, stone: _stone);
    _ground(s);

    // The back corner stays low, under the record button; the trees stand
    // along the back right edge, beside the birdhouse.
    s
      ..bush(0.9, 1, _leaves, size: 1.2, grow: s.pop(0.3, 0.48))
      ..pine(
        2.55,
        0.55,
        needles: _needles,
        bark: _bark,
        ground: _grass,
        h: 1.65,
        grow: s.pop(0.34, 0.54),
      )
      ..tree(
        3.4,
        0.35,
        leaves: _leavesLight,
        bark: _bark,
        ground: _grass,
        h: 1.6,
        grow: s.pop(0.38, 0.58),
      );
    _flowers(s, 0, 5);

    _oak(s, s.pop(0.32, 0.58));
    _landedOn(s, _Perch.oak);

    s
      ..dropping(0.36, 0.58, (lift) => _bench(s, lift))
      ..pine(
        5.3,
        0.35,
        needles: _needles.shade(0.04),
        bark: _bark,
        ground: _grass,
        grow: s.pop(0.4, 0.6),
      );
    _reeds(s);
    s.dropping(0.42, 0.64, (lift) => _birdhouse(s, lift));
    _landedOn(s, _Perch.birdhouse);
    _flowers(s, 5, 7.6);

    _ducks(s);
    s
      ..bush(2.75, 5.35, _leaves, grow: s.pop(0.5, 0.68))
      ..bush(5.7, 2.45, _leavesLight, size: 0.95, grow: s.pop(0.52, 0.7));
    _flowers(s, 7.6, 8.8);
    _cat(s, s.pop(0.8, 0.95));

    s.dropping(0.44, 0.68, (lift) => _bath(s, lift));
    _landedOn(s, _Perch.bath);
    _flowers(s, 8.8, 10.3);
    _landedOn(s, _Perch.lawn);
    _flowers(s, 10.3, double.infinity);

    // Whoever is still on the wing flies over everything else.
    for (final bird in _arrivals) {
      _flying(s, bird);
    }
  });
}

// ----------------------------------------------------------------- the sun --

/// Where the sun comes to rest, in screen fractions, and how big it is.
const _sunX = 0.8;
const _sunY = 0.16;
const _sunSize = 0.7;

// ------------------------------------------------------------------ ground --

const _pondX = 1.5;
const _pondY = 5.12;
const _pondR = 0.62;

/// Flat things: the pond by the left edge with its pebble bank, stepping
/// stones across the meadow from the bench to the pond, and seed scattered
/// on the lawn in front of the bath.
void _ground(IsoStage s) {
  const x = _pondX;
  const y = _pondY;
  const r = _pondR;
  s.canvas
    ..drawOval(s.disc(x, y, 0.003, r + 0.1), s.fill(_pebble.shade(-0.06)))
    ..drawOval(s.disc(x, y, 0.004, r), s.fill(_water.shade(-0.08)))
    ..drawOval(s.disc(x - 0.06, y - 0.06, 0.005, r - 0.13), s.fill(_water))
    ..drawOval(
      s.disc(x - 0.22, y - 0.17, 0.006, 0.16),
      s.fill(_water.shade(0.18)),
    )
    // A lily pad.
    ..drawOval(s.disc(x + 0.2, y + 0.18, 0.007, 0.11), s.fill(_leavesLight));
  for (final (sx, sy) in const [
    (3.45, 2.75),
    (3.15, 3.16),
    (2.85, 3.58),
    (2.55, 3.99),
    (2.25, 4.4),
  ]) {
    s.canvas.drawOval(s.disc(sx, sy, 0.004, 0.17), s.fill(_pebble));
  }
  for (final (sx, sy) in const [
    (5.0, 5.3),
    (5.12, 5.2),
    (5.06, 5.42),
    (5.24, 5.36),
    (4.94, 5.16),
    (5.3, 5.12),
    (5.18, 5.5),
  ]) {
    s.canvas.drawOval(s.disc(sx, sy, 0.004, 0.035), s.fill(_seed));
  }
}

/// Cattails round the far end of the pond, by the edge of the island.
void _reeds(IsoStage s) {
  final grow = s.pop(0.48, 0.68);
  if (grow <= 0) return;
  for (final (dx, dy, h) in const [
    (-0.6, -0.4, 0.6),
    (-0.72, -0.12, 0.78),
    (-0.7, 0.16, 0.56),
    (-0.6, 0.4, 0.7),
  ]) {
    final x = _pondX + dx;
    final y = _pondY + dy;
    final foot = s.at(x, y);
    final top = s.at(x, y, h * grow);
    s.canvas
      ..drawLine(foot, top, s.stroke(_reed, 0.03))
      ..drawLine(
        foot,
        s.at(x + 0.12, y - 0.1, h * 0.55 * grow),
        s.stroke(_reed.shade(0.08), 0.025),
      )
      ..drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset.lerp(foot, top, 0.8)!,
            width: 0.075 * s.unit * grow,
            height: 0.2 * s.unit * grow,
          ),
          Radius.circular(0.04 * s.unit),
        ),
        s.fill(_cattail),
      );
  }
}

/// Flowers in the meadow, back to front by `x + y`, so each can be drawn at
/// its own depth among the things that stand.
const List<({double x, double y, Tint tint})> _beds = [
  (x: 1.6, y: 2.6, tint: _petalLilac),
  (x: 2.1, y: 3.3, tint: _petalGold),
  (x: 2.75, y: 2.85, tint: _petalRose),
  (x: 2.0, y: 3.85, tint: _petalLilac),
  (x: 2.95, y: 4.45, tint: _petalGold),
  (x: 4.95, y: 3.0, tint: _petalRose),
  (x: 2.3, y: 5.75, tint: _petalLilac),
  (x: 3.25, y: 5.5, tint: _petalRose),
  (x: 3.8, y: 5.3, tint: _petalGold),
  (x: 4.05, y: 5.8, tint: _petalLilac),
  (x: 5.85, y: 4.15, tint: _petalRose),
  (x: 5.8, y: 5.35, tint: _petalGold),
];

/// The flowers whose `x + y` is from [from] up to [to]. They open one after
/// another from the back, whichever group they are drawn in.
void _flowers(IsoStage s, double from, double to) {
  for (var i = 0; i < _beds.length; i++) {
    final bed = _beds[i];
    final depth = bed.x + bed.y;
    if (depth < from || depth >= to) continue;
    s.flower(
      bed.x,
      bed.y,
      bed.tint,
      _stem,
      grow: s.pop(0.58 + i * 0.02, 0.76 + i * 0.02),
    );
  }
}

// ----------------------------------------------------------------- the oak --

const _oakX = 0.85;
const _oakY = 4.1;

/// Where along the oak's long limb, `0` at the trunk and `1` at its tip.
V3 _limb(double along) => (
  x: _oakX + 1.4 * along,
  y: _oakY - 0.26 * along,
  z: 0.85 + 0.56 * along,
);

/// The big oak behind the pond, [grow] of the way grown: a long bare limb
/// reaching out over the meadow below the crown for the robins to land on,
/// and a nest of blue eggs in the fork.
void _oak(IsoStage s, double grow) {
  if (grow <= 0) return;
  s.scaled(s.at(_oakX, _oakY), grow, () {
    s
      ..shadow(_oakX + 0.15, _oakY - 0.05, 0.75, _grass)
      ..cylinder(_oakX, _oakY, 0, 0.13, 1.3, _bark);
    final base = _limb(0);
    final tip = _limb(1);
    final fork = _limb(0.55);
    s.canvas
      ..drawLine(
        s.at(base.x, base.y, base.z),
        s.at(tip.x, tip.y, tip.z),
        s.stroke(_bark, 0.07),
      )
      ..drawLine(
        s.at(fork.x, fork.y, fork.z),
        s.at(fork.x + 0.15, fork.y - 0.3, fork.z + 0.45),
        s.stroke(_bark, 0.035),
      )
      ..drawLine(
        s.at(_oakX, _oakY, 0.95),
        s.at(_oakX - 0.5, _oakY + 0.75, 1.2),
        s.stroke(_bark, 0.06),
      );
    s
      ..sphere(_oakX + 0.25, _oakY - 0.3, 1.85, 0.55, _leaves.shade(-0.04))
      ..sphere(_oakX, _oakY, 2, 0.78, _leaves)
      ..sphere(_oakX - 0.25, _oakY + 0.3, 1.8, 0.52, _leaves.shade(0.03))
      ..sphere(_oakX - 0.1, _oakY + 0.05, 2.55, 0.5, _leavesLight);
    _nest(s, s.at(_oakX + 0.12, _oakY + 0.02, 1.32));
  });
}

/// A twig nest with three robin's-egg blue eggs, its rim at [rim].
void _nest(IsoStage s, Offset rim) {
  final u = s.unit;
  s.canvas.drawOval(
    Rect.fromCenter(
      center: rim.translate(0, 0.05 * u),
      width: 0.5 * u,
      height: 0.2 * u,
    ),
    s.fill(_bark.shade(0.06)),
  );
  for (final dx in const [-0.1, 0.02, 0.13]) {
    s.canvas.drawOval(
      Rect.fromCenter(
        center: rim.translate(dx * u, -0.01 * u),
        width: 0.11 * u,
        height: 0.13 * u,
      ),
      s.fill(_egg),
    );
  }
  s.canvas.drawPath(
    Path()
      ..moveTo(rim.dx - 0.25 * u, rim.dy + 0.02 * u)
      ..quadraticBezierTo(rim.dx, rim.dy + 0.2 * u, rim.dx + 0.25 * u, rim.dy)
      ..lineTo(rim.dx + 0.2 * u, rim.dy + 0.1 * u)
      ..quadraticBezierTo(
        rim.dx,
        rim.dy + 0.25 * u,
        rim.dx - 0.2 * u,
        rim.dy + 0.12 * u,
      )
      ..close(),
    s.fill(_bark.shade(0.12)),
  );
}

// --------------------------------------------------------------- the bench --

const _benchX = 3.3;
const _benchY = 1.9;
const _seat = 0.45;

/// The bench, [lift] tiles above its place, and the two watchers on it.
void _bench(IsoStage s, double lift) {
  const x = _benchX;
  const y = _benchY;
  const w = 1.55;
  const d = 0.5;
  final z = lift;
  if (lift < 0.05) {
    // Its shadow: just its footprint, a little forward of it.
    s.canvas.drawPath(
      s.face(const [
        (x: x + 0.05, y: y + 0.1, z: 0.002),
        (x: x + w + 0.1, y: y + 0.1, z: 0.002),
        (x: x + w + 0.1, y: y + d + 0.12, z: 0.002),
        (x: x + 0.05, y: y + d + 0.12, z: 0.002),
      ]),
      s.fill(_grass.shade(-0.1)),
    );
  }
  final leg = _wood.shade(-0.18);
  const legs = _seat - 0.08;
  s
    ..box(x + 0.1, y + 0.05, z, 0.09, 0.09, legs, leg)
    ..box(x + w - 0.19, y + 0.05, z, 0.09, 0.09, legs, leg)
    ..box(x + 0.1, y + d - 0.14, z, 0.09, 0.09, legs, leg)
    ..box(x + w - 0.19, y + d - 0.14, z, 0.09, 0.09, legs, leg)
    ..box(x, y, z + legs, w, d, 0.08, _wood)
    // The backrest: two posts and two slats.
    ..box(x + 0.1, y, z + _seat, 0.08, 0.07, 0.54, leg)
    ..box(x + w - 0.18, y, z + _seat, 0.08, 0.07, 0.54, leg)
    ..box(x, y, z + _seat + 0.17, w, 0.07, 0.12, _wood)
    ..box(x, y, z + _seat + 0.37, w, 0.07, 0.12, _wood);

  // Both look the same way, at the robins on the oak: the one on the left
  // points them out, the one on the right has the binoculars.
  final arrive = s.pop(0.54, 0.7);
  const sit = y + 0.27;
  for (final (at, binoculars) in const [(3.65, false), (4.4, true)]) {
    s.scaled(s.at(at, sit, z + _seat), arrive, () {
      _watcher(s, at, sit, z + _seat, binoculars: binoculars);
    });
  }
}

/// A watcher sitting at [x], [y] on a seat at [seat], facing the meadow and
/// looking at the oak: one in a bucket hat raising binoculars, the other
/// pointing.
void _watcher(
  IsoStage s,
  double x,
  double y,
  double seat, {
  required bool binoculars,
}) {
  final u = s.unit;
  final jacket = binoculars ? _mustard : _teal;
  s
    // Shins down in front of the seat, then the thighs along it.
    ..box(x - 0.125, y + 0.25, seat - _seat, 0.25, 0.1, _seat + 0.075, _denim)
    ..box(x - 0.125, y - 0.1, seat, 0.25, 0.45, 0.125, _denim)
    ..cylinder(x, y, seat + 0.12, 0.18, 0.46, jacket);
  final head = seat + 0.76;
  if (!binoculars) s.sphere(x + 0.03, y - 0.06, head + 0.04, 0.19, _hair);
  s.sphere(x, y, head, 0.175, _skin);

  if (binoculars) {
    // A bucket hat.
    s
      ..canvas.drawOval(
        s.disc(x, y, head + 0.09, 0.21),
        s.fill(_khaki.shade(-0.1)),
      )
      ..cylinder(x, y, head + 0.09, 0.13, 0.1, _khaki);
    // Up to the eyes once the birds are in, aimed left at the oak.
    final shoulder = s.at(x, y + 0.1, seat + 0.5);
    final raise = s.phase(0.76, 0.9);
    final face = s.at(x, y, head).translate(-0.21 * u, 0.03 * u);
    final lap = s.at(x, y + 0.32, seat + 0.24);
    final c = Offset.lerp(lap, face, raise)!;
    final tilt = Offset(0.1 * u, 0.025 * u * (1 - raise));
    final back = c.translate(0.04 * u, -0.06 * u);
    s.canvas
      ..drawLine(shoulder, c + tilt, s.stroke(jacket.shade(-0.06), 0.075))
      ..drawLine(back - tilt, back + tilt, s.stroke(_lens.shade(0.06), 0.095))
      ..drawLine(c - tilt, c + tilt, s.stroke(_lens, 0.1));
  } else {
    // Pointing up and to the left, at the robins on the oak's long limb.
    final shoulder = s.at(x, y + 0.12, seat + 0.5);
    final raise = s.phase(0.84, 0.96);
    final rest = s.at(x + 0.08, y + 0.3, seat + 0.22);
    final robins = _limb(0.7);
    final toward = s.at(robins.x, robins.y, robins.z) - shoulder;
    final point = shoulder + toward / toward.distance * (0.5 * u);
    final hand = Offset.lerp(rest, point, raise)!;
    s.canvas
      ..drawLine(shoulder, hand, s.stroke(jacket.shade(-0.06), 0.075))
      ..drawCircle(hand, 0.05 * u, s.fill(_skin));
  }
}

// ------------------------------------------------------ birdhouse and bath --

const _houseX = 5.2;
const _houseY = 1.1;
const _houseEaves = 1.6;

/// The birdhouse on its post, [lift] tiles above its place.
void _birdhouse(IsoStage s, double lift) {
  const x = _houseX;
  const y = _houseY;
  final z = lift;
  if (lift < 0.05) s.shadow(x + 0.1, y, 0.3, _grass);
  s
    ..box(
      x - 0.05,
      y - 0.05,
      z,
      0.1,
      0.1,
      _houseEaves - 0.4,
      _wood.shade(-0.14),
    )
    ..box(x - 0.22, y - 0.2, z + _houseEaves - 0.4, 0.44, 0.4, 0.4, _cream);
  s.canvas
    ..drawOval(
      Rect.fromCenter(
        center: s.at(x, y + 0.2, z + _houseEaves - 0.17),
        width: 0.13 * s.unit,
        height: 0.16 * s.unit,
      ),
      s.fill(_bark),
    )
    ..drawLine(
      s.at(x, y + 0.2, z + _houseEaves - 0.3),
      s.at(x, y + 0.34, z + _houseEaves - 0.3),
      s.stroke(_wood.shade(-0.14), 0.03),
    );
  s.roof(
    x - 0.22,
    y - 0.2,
    z + _houseEaves,
    0.44,
    0.4,
    0.3,
    _roof,
    alongX: false,
    overhang: 0.07,
  );
}

const _bathX = 4.55;
const _bathY = 4.55;
const _bowl = 0.68;
const _bathRim = 0.72;

/// The stone bird bath at the front of the meadow, [lift] tiles above its
/// place: a square plinth, a pedestal, a wide shallow bowl of water.
void _bath(IsoStage s, double lift) {
  const x = _bathX;
  const y = _bathY;
  final z = lift;
  if (lift < 0.05) s.shadow(x + 0.08, y + 0.02, 0.62, _grass);
  s
    ..box(x - 0.26, y - 0.26, z, 0.52, 0.52, 0.1, _pebble.shade(-0.1))
    ..cylinder(x, y, z + 0.1, 0.11, 0.4, _pebble.shade(-0.04))
    ..cylinder(x, y, z + 0.48, 0.26, 0.06, _pebble.shade(-0.08))
    ..cylinder(x, y, z + 0.54, _bowl, _bathRim - 0.54, _pebble);
  s.canvas
    ..drawOval(
      s.disc(x, y, z + _bathRim, _bowl - 0.09),
      s.fill(_water.shade(0.04)),
    )
    ..drawOval(
      s.disc(x - 0.2, y - 0.2, z + _bathRim, 0.2),
      s.fill(_water.shade(0.2)),
    );
}

/// The ring on the water round the bathing robin, whose waterline is at
/// [at], [grow] of the way out. Drawn before the robin, so it hides the
/// back of the ring.
void _ripple(IsoStage s, Offset at, double grow) {
  if (grow <= 0) return;
  s.canvas.drawOval(
    Rect.fromCenter(
      center: at,
      width: 0.85 * s.unit * grow,
      height: 0.28 * s.unit * grow,
    ),
    s.stroke(_water.shade(0.3), 0.025),
  );
}

/// The drops the bathing robin throws up, [grow] of the way out from its
/// waterline at [at].
void _drops(IsoStage s, Offset at, double grow) {
  if (grow <= 0) return;
  final u = s.unit;
  for (final (dx, dy, r) in const [
    (-0.54, -0.16, 0.045),
    (-0.66, -0.4, 0.04),
    (-0.54, -0.64, 0.035),
    (-0.3, -0.78, 0.03),
  ]) {
    s.canvas.drawCircle(
      at.translate(dx * u * grow, dy * u * grow),
      r * u * grow,
      s.fill(_water.shade(0.26)),
    );
  }
}

// --------------------------------------------------------------------- cat --

/// A ginger cat by the bush on the right, its eye on the robins at the seed
/// too: it pops up, [grow] of the way, and curls its tail round its paws.
void _cat(IsoStage s, double grow) {
  if (grow <= 0) return;
  const x = 5.5;
  const y = 3.35;
  final foot = s.at(x, y);
  final curl = s.phase(0.86, 1);
  s
    ..shadow(x, y, 0.36, _grass)
    ..scaled(foot, grow, () {
      final k = 0.22 * s.unit;
      final tail = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.38
        ..strokeCap = StrokeCap.round
        ..color = s.colour(_ginger.shade(-0.08));
      final ear = s.fill(_ginger.shade(-0.04));
      s.canvas
        ..save()
        ..translate(foot.dx, foot.dy)
        // Facing left, toward the bath.
        ..scale(-k, k)
        ..drawPath(
          Path()
            ..moveTo(-0.5, -0.25)
            ..quadraticBezierTo(
              -1.9,
              -0.3 + 0.2 * curl,
              -1.7 + 2.4 * curl,
              -1.6 + 1.45 * curl,
            ),
          tail,
        )
        ..drawOval(
          Rect.fromCenter(
            center: const Offset(0, -1),
            width: 1.7,
            height: 2,
          ),
          s.fill(_ginger),
        )
        ..drawOval(
          Rect.fromCenter(
            center: const Offset(0.35, -0.95),
            width: 0.7,
            height: 1.3,
          ),
          s.fill(_ginger.shade(0.14)),
        )
        ..drawPath(
          Path()
            ..moveTo(-0.15, -2.6)
            ..lineTo(-0.05, -3.4)
            ..lineTo(0.42, -2.9)
            ..close(),
          ear,
        )
        ..drawPath(
          Path()
            ..moveTo(0.55, -2.95)
            ..lineTo(1.05, -3.35)
            ..lineTo(1.1, -2.55)
            ..close(),
          ear,
        )
        ..drawCircle(const Offset(0.4, -2.3), 0.72, s.fill(_ginger.shade(0.05)))
        ..drawCircle(const Offset(0.82, -2.42), 0.11, s.fill(_eye))
        ..restore();
    });
}

// ------------------------------------------------------------------- ducks --

/// Two ducks paddling out onto the pond.
void _ducks(IsoStage s) {
  for (final (i, (dx, dy, facing)) in const [
    (0.18, -0.24, 1.0),
    (-0.22, 0.14, -1.0),
  ].indexed) {
    final x = _pondX + dx;
    final y = _pondY + dy;
    final p = s.phase(0.5 + i * 0.08, 0.86 + i * 0.06, Curves.easeInOutSine);
    if (p <= 0) continue;
    final from = (x: x - 0.34 * facing, y: y + 0.14 * facing);
    final at = s.at(
      from.x + (x - from.x) * p,
      from.y + (y - from.y) * p,
      0.008,
    );
    // The ring the duck sits in, then the duck.
    s.canvas.drawOval(
      Rect.fromCenter(
        center: at,
        width: 0.7 * s.unit,
        height: 0.27 * s.unit,
      ),
      s.stroke(_water.shade(0.2), 0.025),
    );
    _duckAt(s, at, facing);
  }
}

void _duckAt(IsoStage s, Offset at, double facing) {
  s.canvas
    ..save()
    ..translate(at.dx, at.dy)
    ..scale(facing * 0.13 * s.unit, 0.13 * s.unit)
    ..drawPath(
      Path()
        ..moveTo(-0.9, -0.8)
        ..lineTo(-1.7, -1.35)
        ..lineTo(-1.2, -0.3)
        ..close(),
      s.fill(_duck.shade(-0.1)),
    )
    ..drawOval(
      Rect.fromCenter(center: const Offset(0, -0.5), width: 2.6, height: 1.1),
      s.fill(_duck),
    )
    ..drawOval(
      Rect.fromCenter(
        center: const Offset(-0.3, -0.62),
        width: 1.4,
        height: 0.55,
      ),
      s.fill(_duck.shade(-0.14)),
    )
    ..drawLine(
      const Offset(0.75, -0.7),
      const Offset(0.9, -1.45),
      Paint()
        ..color = s.colour(_mallard)
        ..strokeWidth = 0.5
        ..strokeCap = StrokeCap.round,
    )
    ..drawCircle(const Offset(0.95, -1.6), 0.48, s.fill(_mallard))
    ..drawPath(
      Path()
        ..moveTo(1.3, -1.7)
        ..lineTo(1.9, -1.5)
        ..lineTo(1.3, -1.35)
        ..close(),
      s.fill(_beak),
    )
    ..drawCircle(const Offset(1.08, -1.72), 0.1, s.fill(_eye))
    ..restore();
}

// ------------------------------------------------------------------- birds --

/// How big a robin is, in tiles per unit of its drawing: deliberately large
/// for the island, since the robins are what the sentence is about.
const _robinSize = 0.31;

enum _Perch { oak, birdhouse, bath, lawn }

/// A robin that flies in from [from] (screen fractions) between [begin] and
/// [end] and lands on [spot], settling into its pose: [spread] wings and
/// [flap] for one that bathes, [peck] (radians, head down) for one that
/// drinks or eats. One that is [bathing] sits in the water up to its
/// breast, [spot] being its waterline.
class _Arrival {
  const _Arrival({
    required this.at,
    required this.spot,
    required this.from,
    required this.begin,
    required this.end,
    required this.plume,
    this.spread = 0,
    this.flap = 0,
    this.peck = 0,
    this.bathing = false,
  });

  final _Perch at;
  final V3 spot;
  final Offset from;
  final double begin;
  final double end;
  final Tint plume;
  final double spread;
  final double flap;
  final double peck;
  final bool bathing;
}

/// How far below the water a bathing robin's feet are, in tiles.
const _soak = 0.26;

/// The birds that land, in the order they arrive: each flies in from `from`
/// along an arc and lands on `spot`.
final List<_Arrival> _arrivals = [
  _Arrival(
    at: _Perch.oak,
    spot: _limb(0.97),
    from: const Offset(-0.1, 0.42),
    begin: 0.5,
    end: 0.74,
    plume: _slate,
  ),
  _Arrival(
    at: _Perch.oak,
    spot: _limb(0.42),
    from: const Offset(-0.12, 0.62),
    begin: 0.54,
    end: 0.78,
    plume: _dusk,
  ),
  const _Arrival(
    at: _Perch.oak,
    spot: (x: _oakX - 0.45, y: _oakY + 0.68, z: 1.18),
    from: Offset(0.3, 0.3),
    begin: 0.58,
    end: 0.82,
    plume: _slate,
  ),
  const _Arrival(
    at: _Perch.birdhouse,
    spot: (x: _houseX, y: _houseY + 0.02, z: _houseEaves + 0.3),
    from: Offset(1.12, 0.38),
    begin: 0.61,
    end: 0.85,
    plume: _dusk,
  ),
  // One drinks from the far rim, one splashes in the bowl.
  const _Arrival(
    at: _Perch.bath,
    spot: (x: _bathX + 0.47, y: _bathY - 0.47, z: _bathRim),
    from: Offset(1.1, 0.5),
    begin: 0.64,
    end: 0.88,
    plume: _dusk,
    peck: 0.42,
  ),
  const _Arrival(
    at: _Perch.bath,
    spot: (x: _bathX - 0.22, y: _bathY + 0.14, z: _bathRim),
    from: Offset(1.12, 0.44),
    begin: 0.67,
    end: 0.9,
    plume: _slate,
    spread: 0.75,
    flap: 0.55,
    bathing: true,
  ),
  // Two at the seed on the lawn in front of the bath, facing each other.
  const _Arrival(
    at: _Perch.lawn,
    spot: (x: 4.78, y: 5.6, z: 0),
    from: Offset(-0.12, 0.66),
    begin: 0.7,
    end: 0.94,
    plume: _slate,
  ),
  const _Arrival(
    at: _Perch.lawn,
    spot: (x: 5.6, y: 4.82, z: 0),
    from: Offset(1.14, 0.7),
    begin: 0.73,
    end: 0.97,
    plume: _dusk,
    peck: 0.6,
  ),
];

/// Where [bird]'s feet are once it has landed.
Offset _feet(IsoStage s, _Arrival bird) => s.at(
  bird.spot.x,
  bird.spot.y,
  bird.spot.z - (bird.bathing ? _soak : 0),
);

/// The birds that land on [perch], once they have.
void _landedOn(IsoStage s, _Perch perch) {
  for (final bird in _arrivals) {
    if (bird.at != perch || s.t < bird.end) continue;
    final feet = _feet(s, bird);
    final waterline = s.at(bird.spot.x, bird.spot.y, bird.spot.z);
    final splash = s.pop(bird.end, bird.end + 0.06);
    if (bird.bathing) _ripple(s, waterline, splash);
    _songbird(
      s,
      feet,
      _facing(s, bird, feet),
      bird.plume,
      spread: bird.spread,
      flap: bird.flap,
      peck: bird.peck,
      waterline: bird.bathing ? waterline.dy : null,
    );
    if (bird.bathing) _drops(s, waterline, splash);
  }
}

/// [bird] on the wing, while it is.
void _flying(IsoStage s, _Arrival bird) {
  if (s.t <= bird.begin || s.t >= bird.end) return;
  final p = s.phase(bird.begin, bird.end, Curves.easeOutSine);
  final feet = _feet(s, bird);
  final start = s.screen(bird.from.dx, bird.from.dy);
  final via = Offset.lerp(start, feet, 0.5)!.translate(0, -2.4 * s.unit);
  // Wings beat, slower as it glides in, and settle in the last stretch.
  final open = 1 - s.phase(bird.end - (bird.end - bird.begin) * 0.2, bird.end);
  final beat = math.sin((s.t - bird.begin) * math.pi * 2 * 14);
  final waterline = s.at(bird.spot.x, bird.spot.y, bird.spot.z).dy;
  _songbird(
    s,
    _bezier(start, via, feet, p),
    _facing(s, bird, feet),
    bird.plume,
    spread: open + (1 - open) * bird.spread,
    flap: (0.25 + 0.85 * beat * (1 - 0.6 * p)) * open + (1 - open) * bird.flap,
    peck: (1 - open) * bird.peck,
    waterline: bird.bathing ? waterline : null,
  );
}

double _facing(IsoStage s, _Arrival bird, Offset spot) =>
    spot.dx >= s.screen(bird.from.dx, bird.from.dy).dx ? 1 : -1;

Offset _bezier(Offset a, Offset b, Offset c, double p) {
  final q = 1 - p;
  return a * (q * q) + b * (2 * q * p) + c * (p * p);
}

/// A robin standing on [feet] (a screen point), looking right if [facing]
/// is `1`, left if `-1`. [spread] opens the wings from folded (`0`) to in
/// flight (`1`); [flap] is their angle, in radians, up positive; [peck]
/// tips it forward from the hips, head down, by that many radians. Below
/// [waterline] (a screen y), if there is one, nothing of it shows.
void _songbird(
  IsoStage s,
  Offset feet,
  double facing,
  Tint plume, {
  double spread = 0,
  double flap = 0,
  double peck = 0,
  double? waterline,
}) {
  final b = _robinSize * s.unit;
  const folded = Offset(-1.15, -0.75);
  Offset tip(double reach, double lift) => Offset.lerp(
    folded,
    Offset(-0.5 - 0.3 * math.cos(flap), -1.3 - lift * math.sin(flap)),
    spread,
  )!.scale(reach, 1);
  Path wing(Offset tip) => Path()
    ..moveTo(0.45, -1.35)
    ..quadraticBezierTo(
      (0.45 + tip.dx) / 2 + 0.4,
      (-1.35 + tip.dy) / 2,
      tip.dx,
      tip.dy,
    )
    ..quadraticBezierTo(
      (tip.dx - 0.55) / 2 - 0.1,
      (tip.dy - 1.3) / 2 + 0.1,
      -0.55,
      -1.3,
    )
    ..close();

  final c = s.canvas..save();
  if (waterline != null) {
    c.clipRect(
      Rect.fromLTRB(
        feet.dx - 4 * b,
        math.min(feet.dy - 4 * b, waterline),
        feet.dx + 4 * b,
        waterline,
      ),
    );
  }
  c
    ..translate(feet.dx, feet.dy)
    ..scale(facing * b, b);
  if (spread < 0.6) {
    final legs = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.14
      ..color = s.colour(_beak.shade(-0.25));
    c
      ..drawLine(const Offset(-0.1, -0.5), Offset.zero, legs)
      ..drawLine(const Offset(0.25, -0.5), const Offset(0.3, 0), legs);
  }
  if (peck != 0) {
    c
      ..translate(0.1, -0.5)
      ..rotate(peck)
      ..translate(-0.1, 0.5);
  }
  if (spread > 0.05) c.drawPath(wing(tip(0.8, 1.5)), s.fill(plume.shade(-0.1)));
  c
    ..drawPath(
      Path()
        ..moveTo(-0.7, -1.2)
        ..lineTo(-1.9, -0.55 - 0.45 * spread)
        ..lineTo(-1.75, -0.3 - 0.5 * spread)
        ..lineTo(-0.6, -0.75)
        ..close(),
      s.fill(plume.shade(-0.06)),
    )
    ..drawOval(
      Rect.fromCenter(center: const Offset(0, -1.05), width: 2.1, height: 1.4),
      s.fill(plume),
    )
    ..drawOval(
      Rect.fromCenter(
        center: const Offset(0.38, -0.88),
        width: 1.2,
        height: 0.95,
      ),
      s.fill(_breast),
    )
    ..drawCircle(const Offset(0.85, -1.75), 0.55, s.fill(plume.shade(0.04)))
    ..drawPath(
      Path()
        ..moveTo(1.3, -1.88)
        ..lineTo(1.85, -1.72)
        ..lineTo(1.3, -1.58)
        ..close(),
      s.fill(_beak),
    )
    ..drawCircle(const Offset(1.05, -1.85), 0.11, s.fill(_eye))
    ..drawPath(wing(tip(1, 2.1)), s.fill(plume.shade(-0.04)))
    ..restore();
}

// ------------------------------------------------------------------- flock --

/// Five birds far off, crossing the sun: they beat in from the left one
/// after another and glide to a stop in a loose V across the lower half of
/// the sun, under the subtitle and above the buttons on a phone. Placed in
/// tiles from where the sun comes to rest, so they cross it on any screen.
void _flock(IsoStage s) {
  const birds = [
    (dx: 1.25, dy: 0.98, span: 0.7, begin: 0.4),
    (dx: 0.5, dy: 0.76, span: 0.62, begin: 0.43),
    (dx: 0.56, dy: 1.24, span: 0.64, begin: 0.45),
    (dx: -0.24, dy: 0.62, span: 0.56, begin: 0.48),
    (dx: -0.14, dy: 1.44, span: 0.58, begin: 0.5),
  ];
  final sun = s.screen(_sunX, _sunY);
  final w = s.size.width;
  final h = s.size.height;
  for (final bird in birds) {
    final p = s.phase(bird.begin, bird.begin + 0.4, Curves.easeOutQuad);
    if (p <= 0) continue;
    final rest = sun.translate(bird.dx * s.unit, bird.dy * s.unit);
    final at = _bezier(
      rest.translate(-0.8 * w, 0.16 * h),
      rest.translate(-0.35 * w, -0.06 * h),
      rest,
      p,
    );
    final beat = math.sin((s.t - bird.begin) * math.pi * 2 * 7) * (1 - p);
    final half = bird.span * s.unit / 2;
    final lift = half * (0.1 + 0.6 * beat);
    s.canvas.drawPath(
      Path()
        ..moveTo(at.dx - half, at.dy - lift)
        ..quadraticBezierTo(
          at.dx - half * 0.45,
          at.dy - half * 0.4 - lift * 0.3,
          at.dx,
          at.dy,
        )
        ..quadraticBezierTo(
          at.dx + half * 0.45,
          at.dy - half * 0.4 - lift * 0.3,
          at.dx + half,
          at.dy - lift,
        ),
      s.stroke(_flockTint, 0.085),
    );
  }
}
