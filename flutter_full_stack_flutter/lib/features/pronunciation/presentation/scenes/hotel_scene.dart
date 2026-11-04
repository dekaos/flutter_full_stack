import 'dart:math' as math;

import 'package:flutter/animation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_full_stack_flutter/core/audio/sound.dart';
import 'package:flutter_full_stack_flutter/features/pronunciation/presentation/scenes/iso_stage.dart';
import 'package:flutter_full_stack_flutter/features/pronunciation/presentation/scenes/script.dart';

// The palette: golden hour at a small hotel. A dusky rose facade under a
// verdigris roof, with the house colour - plum, trimmed in gold - on the
// awning, the sign and the bellboy's jacket, so the eye finds the hotel and
// its people first; a true red for the carpet he stands on.
const _skyTop = Tint(234, 0.58, 0.56);
const _skyLow = Tint(30, 0.72, 0.86);
// The family's amber sun: amber keeps its warmth at the top of a dark band,
// where a yellow would turn olive, and the body is brighter than every ring
// of its halo, so it reads as a light, not a hole.
const _sunBody = Tint(40, 0.85, 0.97);
const _sunHalo = Tint(36, 0.7, 0.76);
const _cloud = Tint(330, 0.16, 0.97);
const _farHill = Tint(306, 0.28, 0.76);
const _nearHill = Tint(262, 0.3, 0.6);
const _grass = Tint(98, 0.42, 0.4);
const _lawnLit = Tint(78, 0.48, 0.5);
const _earth = Tint(22, 0.55, 0.3);
const _stone = Tint(28, 0.18, 0.16);
const _gravel = Tint(36, 0.45, 0.7);
const _deck = Tint(30, 0.4, 0.74);
const _tiles = Tint(192, 0.45, 0.7);
const _water = Tint(190, 0.65, 0.5);
const _stucco = Tint(358, 0.46, 0.6);
const _cream = Tint(38, 0.55, 0.92);
const _copper = Tint(172, 0.44, 0.42);
const _plum = Tint(342, 0.55, 0.3);
const _carpet = Tint(354, 0.66, 0.34);
const _gold = Tint(44, 0.9, 0.68);
const _glow = Tint(48, 1, 0.9);
const _unlit = Tint(44, 0.3, 0.46);
const _glass = Tint(226, 0.4, 0.44);
const _iron = Tint(232, 0.22, 0.16);
const _clay = Tint(16, 0.6, 0.44);
const _leaves = Tint(128, 0.42, 0.3);
const _leavesLight = Tint(88, 0.44, 0.42);
const _bark = Tint(22, 0.45, 0.18);
const _skin = Tint(26, 0.55, 0.72);
const _teal = Tint(194, 0.5, 0.42);
const _mustard = Tint(40, 0.75, 0.58);
const _stem = Tint(110, 0.5, 0.28);
const _petalPink = Tint(340, 0.7, 0.6);
const _petalGold = Tint(44, 0.95, 0.66);

// The hotel's footprint: the facade with the door faces the viewer's left
// (the plane y = _front), its side the viewer's right (x = _side).
const _hx = 1.2;
const _hy = 1.2;
const _hw = 2.6;
const _hd = 1.8;
const double _front = _hy + _hd;
const double _side = _hx + _hw;
const _eaves = 1.5;

/// The two storeys under the attic: where each starts and how tall it is.
const List<({double z, double h})> _storeys = [
  (z: 0, h: 0.8),
  (z: 0.8, h: 0.7),
];

/// A window: on the `front` or the side, from `along` for `w` tiles, from
/// `z` above its storey's floor for `h`, and the turn its light comes on in
/// (`-1` for a room nobody has checked into yet).
typedef _Pane = ({
  bool front,
  double along,
  double z,
  double w,
  double h,
  int light,
});

const _panes = <List<_Pane>>[
  [
    (front: true, along: 1.38, z: 0.13, w: 0.6, h: 0.48, light: 0),
    (front: true, along: 3.02, z: 0.13, w: 0.6, h: 0.48, light: 1),
    (front: false, along: 1.43, z: 0.16, w: 0.34, h: 0.42, light: 3),
    (front: false, along: 1.93, z: 0.16, w: 0.34, h: 0.42, light: -1),
    (front: false, along: 2.43, z: 0.16, w: 0.34, h: 0.42, light: 2),
  ],
  [
    (front: true, along: 1.4, z: 0.14, w: 0.34, h: 0.38, light: 5),
    (front: true, along: 2.02, z: 0.08, w: 0.34, h: 0.46, light: 4),
    (front: true, along: 2.64, z: 0.08, w: 0.34, h: 0.46, light: -1),
    (front: true, along: 3.26, z: 0.14, w: 0.34, h: 0.38, light: 7),
    (front: false, along: 1.43, z: 0.14, w: 0.34, h: 0.38, light: 8),
    (front: false, along: 1.93, z: 0.14, w: 0.34, h: 0.38, light: 6),
    (front: false, along: 2.43, z: 0.14, w: 0.34, h: 0.38, light: -1),
  ],
];

/// "My brother works at a small hotel", in two acts.
///
/// The grounds assemble first: the island rises and the hotel is stacked
/// onto it - two storeys, then the dormered roof - while the pool fills;
/// the garden springs up, the awning unfolds over the door, the red carpet
/// rolls down the path and an empty luggage trolley lands on the lawn
/// beside it. Then the story, in a pool of light at the entrance while the
/// rest of the garden sinks back: the sign swings out from the wall and
/// spells HOTEL in light as the windows warm, one after another - this is
/// the place (*small hotel*); the door brightens and the bellboy - the
/// brother - steps out onto the carpet, into the light, and waves
/// (*brother*); then he gets to work, pushing the trolley along while the
/// guests' cases drop onto it (*works*). As the story ends, the lamps and
/// the string of bulbs by the pool come on with the dusk.
const hotelScene = SceneScript(
  paintHotel,
  cues: [
    Cue('small hotel', _signOut),
    Cue('brother', _stepsOut),
    Cue('works', _pushes),
  ],
  sounds: [SceneSound(Sound.deskBell, _signOut)],
  catWalks: true,
);

// The story's beats, on the arrival's clock: the place, then the man, then
// what he does there. The lamps come on once the work is done.
const _signOut = 0.42;
const _stepsOut = 0.56;
const _pushes = 0.7;
const double _dusk = _pushes + 0.12;

// The luggage trolley: where its back end is parked, a little way along the
// lawn from the carpet so the brother waves clear of it, how big it is, and
// how far he pushes it. He pushes from [_reach] behind its back end.
const _cartX = 3.0;
const _cartY = 4.5;
const _cartW = 0.62;
const _cartD = 0.4;
const _shove = 0.4;
const _reach = 0.28;

/// The middle of the door and of the carpet that runs down from it.
const _aisle = 2.5;

/// Paints [hotelScene].
void paintHotel(IsoStage s) {
  s.setting(() {
    s.sky(_skyTop, _skyLow);

    final sink = s.phase(0.05, 0.95);
    s
      ..sun(0.81, 0.11 + 0.06 * sink, 0.7, _sunBody, _sunHalo)
      ..ridge(0.77, 1.4, _farHill, seed: 3)
      ..ridge(0.86, 1, _nearHill, seed: 7);

    // The clouds keep to the sides of the sky, beside the island, so
    // nothing busy sits just under the card and its page dots.
    final drift = s.phase(0.15, 1);
    s
      ..cloud(s.screen(0.08 - 0.45 * (1 - drift), 0.41), 2.2, _cloud)
      ..cloud(s.screen(0.9 + 0.5 * (1 - drift), 0.44), 1.7, _cloud)
      ..cloud(s.screen(0.1 - 0.4 * (1 - drift), 0.58), 1.4, _cloud);

    s.rising(0, 0.42, () {
      s.island(grass: _grass, earth: _earth, stone: _stone);
      _grounds(s);

      s.pine(
        0.55,
        2.4,
        needles: _leaves,
        bark: _bark,
        ground: _grass,
        h: 2.3,
        grow: s.pop(0.46, 0.68),
      );

      _hotel(s);
      _festoon(s);
      _cat(s);

      s
        ..tree(
          5.6,
          0.3,
          leaves: _leavesLight,
          bark: _bark,
          ground: _grass,
          h: 1.6,
          grow: s.pop(0.5, 0.72),
        )
        ..pine(
          0.55,
          4.3,
          needles: _leaves,
          bark: _bark,
          ground: _grass,
          h: 2,
          grow: s.pop(0.52, 0.74),
        )
        ..bush(1.45, 4.05, _leavesLight, size: 0.8, grow: s.pop(0.6, 0.8));

      _poolside(s);

      // The brother steps out onto the carpet, then pushes the trolley
      // along the lawn ahead of him: he is always behind it, so first.
      final cart = s.story(
        () =>
            _cartX +
            _shove *
                s.phase(_pushes - 0.01, _pushes + 0.13, Curves.easeOutQuad),
      );
      s.story(() => _bellboy(s, cart));
      _trolley(s, cart);

      s.tree(
        0.85,
        5.35,
        leaves: _leaves,
        bark: _bark,
        ground: _grass,
        h: 1.4,
        grow: s.pop(0.56, 0.78),
      );
      _lamp(s, 2.02, 5.6, 0);
      _lamp(s, 2.98, 5.6, 1);

      // The flower bed on the lawn, opening from the back.
      const beds = [
        (x: 4.3, y: 4.5, tint: _petalPink),
        (x: 4.95, y: 4.5, tint: _petalGold),
        (x: 4.6, y: 4.85, tint: _cream),
        (x: 4.25, y: 5.2, tint: _petalGold),
        (x: 5.02, y: 5.05, tint: _petalPink),
        (x: 4.7, y: 5.25, tint: _petalPink),
      ];
      final ordered = [...beds]
        ..sort((a, b) => (a.x + a.y).compareTo(b.x + b.y));
      for (var i = 0; i < ordered.length; i++) {
        final bed = ordered[i];
        s.flower(
          bed.x,
          bed.y,
          bed.tint,
          _stem,
          grow: s.pop(0.64 + i * 0.03, 0.82 + i * 0.03),
        );
      }

      // Low planting at the front right, so the entrance is framed, not
      // hidden.
      s
        ..bush(5.45, 4.9, _leavesLight, size: 0.8, grow: s.pop(0.58, 0.8))
        ..bush(5.7, 5.65, _leaves, size: 0.8, grow: s.pop(0.66, 0.86));

      // The rest of the grounds step back while the brother and his hotel
      // have the stage.
      s.spotlight(
        s.at(3.15, 3.95, 0.6),
        radius: 2.2,
        strength: s.storyLight,
      );
    });
  });
}

/// The black cat, behind the hotel - the scene's easter egg (see
/// `HidingCat`). It sits behind the far corner, the tip of its tail showing
/// past the wall, and when it has a reason it steps out round the corner
/// onto the lawn, and back.
void _cat(IsoStage s) {
  // Only once the hotel has been built round it.
  if (s.t < 0.7) return;
  final corner = s.at(_side, _hy);
  // On the lawn behind the corner, a stride further back than the wall.
  final ground = s.at(_side - 0.15, _hy - 0.3).dy;
  s.hidingCat(
    hidden: Offset(corner.dx - 0.24 * s.unit, ground),
    out: Offset(corner.dx + 0.48 * s.unit, ground),
    reveal: s.beyond(
      corner,
      corner.translate(0, -1),
      of: corner.translate(1, 0),
    ),
  );
}

/// Everything flat on the ground: the path, the red carpet unrolling down
/// it from the door to the lamps, the flower bed, the pool deck with its
/// basin filling - and the stage light on the lawn at the entrance, which
/// brightens as the brother steps into it.
void _grounds(IsoStage s) {
  final carpet = s.phase(0.62, 0.8);
  s.patch(2.25, _front, 0.5, 6 - _front, _gravel);
  if (carpet > 0) {
    s.patch(2.32, _front, 0.36, 2.35 * carpet, _carpet, z: 0.006);
  }
  s
    ..patch(4.1, 4.35, 1.15, 1.05, _earth.shade(0.16))
    ..box(4.1, 0.55, 0, 1.8, 2.7, 0.04, _deck, edge: false);
  _pool(s, s.phase(0.48, 0.76));
  s.story(() {
    final arrives = s.phase(_stepsOut - 0.03, _stepsOut + 0.02);
    s.pool(2.85, 4.65, 1.05, strength: s.storyLight * (0.5 + 0.5 * arrives));
  });
}

/// The pool, sunk into the deck: its far walls, then the water rising in it
/// to [fill].
void _pool(IsoStage s, double fill) {
  const x0 = 4.5;
  const y0 = 0.85;
  const x1 = 5.6;
  const y1 = 2.25;
  const rim = 0.04;
  const depth = 0.3;
  const bottom = rim - depth;
  s.canvas
    ..save()
    ..clipPath(
      s.face([
        (x: x0, y: y0, z: rim),
        (x: x1, y: y0, z: rim),
        (x: x1, y: y1, z: rim),
        (x: x0, y: y1, z: rim),
      ]),
    );
  s
    ..patch(x0, y0, x1 - x0, y1 - y0, _tiles.shade(-0.1), z: bottom)
    ..onLeft(y0, x0, bottom, x1 - x0, depth, _tiles)
    ..onRight(x0, y0, bottom, y1 - y0, depth, _tiles.shade(-0.14));
  if (fill > 0) {
    final z = bottom + (depth - 0.04) * fill;
    s.patch(x0, y0, x1 - x0, y1 - y0, _water, z: z);
    // Two glints on the surface.
    final glint = s.stroke(_water.shade(0.3), 0.03);
    s.canvas
      ..drawLine(s.at(4.8, 1.2, z), s.at(5.15, 1.2, z), glint)
      ..drawLine(s.at(5, 1.75, z), s.at(5.3, 1.75, z), glint);
  }
  s.canvas.restore();
  // The ladder over the far rim.
  final rail = s.stroke(_iron.shade(0.3), 0.025);
  for (final x in [5.2, 5.38]) {
    s.canvas.drawLine(
      s.at(x, y0 + 0.04, rim - 0.12),
      s.at(x, y0, rim + 0.2),
      rail,
    );
  }
}

/// The hotel, stacked: two storeys drop onto each other, then the roof. Its
/// shadow spreads as the ground floor comes down.
void _hotel(IsoStage s) {
  final land = s.phase(0.3, 0.48);
  if (land > 0) s.shadow(_hx + _hw / 2, _hy + _hd / 2, 1.55 * land, _grass);
  for (var i = 0; i < _storeys.length; i++) {
    final begin = 0.24 + i * 0.08;
    s.dropping(begin, begin + 0.24, (lift) => _storey(s, i, lift));
  }
  s.dropping(0.44, 0.68, (lift) => _roof(s, lift));

  // The lobby's light spilling out of the door as the brother comes out
  // of it, under the awning.
  s.story(() {
    final open = s.phase(_stepsOut - 0.05, _stepsOut - 0.02);
    final close = s.phase(_stepsOut + 0.03, _stepsOut + 0.14);
    s.glow(
      s.at(_aisle, _front, 0.3),
      0.8,
      strength: open * (1 - 0.75 * close) * s.storyLight,
    );
  });

  // The entrance, which arrives once the hotel stands: a bay tree by the
  // door, the awning over it, and a second bay tree at the corner, clear
  // of the sign and the trolley's lane.
  final topiary = s.pop(0.62, 0.78);
  _topiary(s, 1.82, 3.28, topiary);
  _awning(s, s.pop(0.56, 0.72));

  // The sign is the story's: it swings out from the wall and blazes as its
  // letters come on, then settles to a steady glow - this is the hotel.
  s.story(() {
    final blaze = s.phase(_signOut, _signOut + 0.06);
    final settle = s.phase(_signOut + 0.1, _signOut + 0.24);
    s.glow(
      s.at(3.76, _front + 0.3, 0.85),
      1.1,
      strength: blaze * (1 - 0.45 * settle) * s.storyLight,
    );
    _sign(s, s.pop(_signOut - 0.02, _signOut + 0.03));
  });
  _topiary(s, 4.25, 3.4, topiary);
}

/// Storey [i], [lift] tiles above where it will sit.
void _storey(IsoStage s, int i, double lift) {
  final storey = _storeys[i];
  final z = storey.z + lift;
  final h = storey.h;
  s
    ..box(_hx, _hy, z, _hw, _hd, h, _stucco)
    // A cream cornice along its top.
    ..box(
      _hx - 0.04,
      _hy - 0.04,
      z + h - 0.07,
      _hw + 0.08,
      _hd + 0.08,
      0.07,
      _cream,
    );
  for (final pane in _panes[i]) {
    _window(s, pane, z);
  }
  if (i == 0) {
    // The door, in the house colour, with the lobby lit behind it.
    final lit = _light(s, 0);
    s
      ..onLeft(_front, 2.23, z, 0.54, 0.66, _plum)
      ..onLeft(_front, 2.3, z, 0.4, 0.6, _glass)
      ..onLeft(_front, 2.3, z, 0.4, 0.6 * lit, _glow);
    s.canvas.drawLine(
      s.at(2.5, _front, z),
      s.at(2.5, _front, z + 0.6),
      s.stroke(_plum, 0.025),
    );
  } else {
    _balcony(s, z);
  }
}

/// How far window number [turn] has come on: the hotel warms as its sign
/// lights, the lobby first and the attic dormer (turn 9) last, all of them
/// before the brother steps out.
double _light(IsoStage s, int turn) => turn < 0
    ? 0
    : s.story(
        () => s.pop(_signOut + turn * 0.008, _signOut + 0.04 + turn * 0.008),
      );

/// A window of a storey whose floor is at [floor].
void _window(IsoStage s, _Pane pane, double floor) {
  final z = floor + pane.z;
  final lit = _light(s, pane.light);
  final inset = 0.84 * lit;
  if (pane.front) {
    s
      ..onLeft(
        _front,
        pane.along - 0.035,
        z - 0.035,
        pane.w + 0.07,
        pane.h + 0.07,
        _cream,
      )
      ..onLeft(_front, pane.along, z, pane.w, pane.h, _glass);
    if (lit > 0) {
      s.onLeft(
        _front,
        pane.along + pane.w * (1 - inset) / 2,
        z + pane.h * (1 - inset) / 2,
        pane.w * inset,
        pane.h * inset,
        _glow,
      );
    }
  } else {
    s
      ..onRight(
        _side,
        pane.along - 0.035,
        z - 0.035,
        pane.w + 0.07,
        pane.h + 0.07,
        _cream.shade(-0.1),
      )
      ..onRight(_side, pane.along, z, pane.w, pane.h, _glass.shade(-0.1));
    if (lit > 0) {
      s.onRight(
        _side,
        pane.along + pane.w * (1 - inset) / 2,
        z + pane.h * (1 - inset) / 2,
        pane.w * inset,
        pane.h * inset,
        _glow.shade(-0.06),
      );
    }
  }
}

/// A path of straight strokes between world points, one per pair in
/// [segments].
Path _strokes(IsoStage s, List<(V3, V3)> segments) {
  final path = Path();
  for (final (a, b) in segments) {
    final p = s.at(a.x, a.y, a.z);
    final q = s.at(b.x, b.y, b.z);
    path
      ..moveTo(p.dx, p.dy)
      ..lineTo(q.dx, q.dy);
  }
  return path;
}

/// The balcony across the two middle windows of an upper storey whose floor
/// is at [floor]: a slab, an iron railing, and geraniums along it.
void _balcony(IsoStage s, double floor) {
  const x0 = 1.94;
  const x1 = 3.06;
  const y1 = _front + 0.24;
  final z = floor + 0.03;
  s.box(x0, _front, z, x1 - x0, y1 - _front, 0.04, _cream);
  final foot = z + 0.04;
  final top = foot + 0.19;
  s.canvas.drawPath(
    _strokes(s, [
      for (var i = 0; i <= 9; i++)
        (
          (x: x0 + (x1 - x0) * i / 9, y: y1, z: foot),
          (x: x0 + (x1 - x0) * i / 9, y: y1, z: top),
        ),
      ((x: x1, y: _front + 0.12, z: foot), (x: x1, y: _front + 0.12, z: top)),
      ((x: x0, y: _front, z: top), (x: x0, y: y1, z: top)),
      ((x: x0, y: y1, z: top), (x: x1, y: y1, z: top)),
      ((x: x1, y: y1, z: top), (x: x1, y: _front, z: top)),
    ]),
    s.stroke(_iron, 0.022),
  );

  for (var i = 0; i < 5; i++) {
    final c = s.at(x0 + 0.12 + i * 0.22, y1, top + 0.03);
    s.canvas
      ..drawCircle(c, 0.055 * s.unit, s.fill(_leaves.shade(0.08)))
      ..drawCircle(
        c.translate(0.02 * s.unit, -0.03 * s.unit),
        0.035 * s.unit,
        s.fill(i.isEven ? _petalPink : _petalGold),
      );
  }
}

/// The roof, [lift] tiles above the eaves: verdigris copper, with a
/// chimney, two dormers - one of them lit - and a pennant on the gable.
void _roof(IsoStage s, double lift) {
  final z = _eaves + lift;
  const h = 0.52;
  s
    ..box(_hx + 0.35, _hy + 0.4, z, 0.28, 0.28, 0.78, _stucco.shade(-0.06))
    ..box(_hx + 0.32, _hy + 0.37, z + 0.78, 0.34, 0.34, 0.06, _cream)
    ..roof(_hx, _hy, z, _hw, _hd, h, _copper, overhang: 0.1);
  _dormer(s, 1.6, z, h, 9);
  _dormer(s, 2.84, z, h, -1);

  // The pennant on the gable, unfurling once the roof is on.
  final mast = s.at(_side, _hy + _hd / 2, z + h);
  final head = s.at(_side, _hy + _hd / 2, z + h + 0.5);
  final unfurl = s.pop(0.74, 0.92);
  s.canvas.drawLine(mast, head, s.stroke(_iron, 0.03));
  if (unfurl > 0) {
    final tip = head.translate(0.42 * s.unit * unfurl, 0.1 * s.unit);
    s.canvas.drawPath(
      Path()
        ..moveTo(head.dx, head.dy)
        ..lineTo(tip.dx, tip.dy)
        ..lineTo(head.dx, head.dy + 0.2 * s.unit)
        ..close(),
      s.fill(_plum),
    );
  }
}

/// A dormer from [x] along the front slope of a roof with its eaves at
/// [eaves] and its ridge [rise] above them, its window lit at [turn]. Its
/// cheek and its two little slopes run back until they meet the roof, so
/// it sits in the slate rather than on it.
void _dormer(IsoStage s, double x, double eaves, double rise, int turn) {
  const w = 0.36;
  const face = _front - 0.08;
  const lip = 0.04;
  // The roof's front slope climbs from the eaves' overhang to the ridge
  // over the middle; [meets] is how far back it reaches a height.
  const foot = _front + 0.1;
  const run = _hd / 2 + 0.1;
  double slope(double y) => eaves + rise * (foot - y) / run;
  double meets(double z) => foot - (z - eaves) * run / rise;
  final sill = slope(face);
  final wall = sill + 0.24;
  final ridge = wall + 0.14;
  final eave = meets(wall);
  final valley = meets(ridge);
  final mid = x + w / 2;
  final lit = 0.84 * _light(s, turn);
  s.canvas.drawPath(
    s.face([
      (x: x + w, y: face, z: sill),
      (x: x + w, y: face, z: wall),
      (x: x + w, y: eave, z: wall),
    ]),
    s.fill(_stucco.shade(-0.16)),
  );
  s
    ..onLeft(face, x, sill, w, wall - sill, _stucco)
    ..onLeft(face, x + 0.08, sill + 0.04, w - 0.16, 0.17, _glass)
    ..onLeft(
      face,
      x + 0.08 + (w - 0.16) * (1 - lit) / 2,
      sill + 0.04 + 0.17 * (1 - lit) / 2,
      (w - 0.16) * lit,
      0.17 * lit,
      _glow,
    );
  s.canvas
    ..drawPath(
      s.face([
        (x: x, y: face, z: wall),
        (x: x + w, y: face, z: wall),
        (x: mid, y: face, z: ridge),
      ]),
      s.fill(_cream),
    )
    ..drawPath(
      s.face([
        (x: x, y: face + lip, z: wall),
        (x: mid, y: face + lip, z: ridge),
        (x: mid, y: valley, z: ridge),
        (x: x, y: eave, z: wall),
      ]),
      s.fill(_copper.shade(0.12)),
    )
    ..drawPath(
      s.face([
        (x: x + w, y: face + lip, z: wall),
        (x: mid, y: face + lip, z: ridge),
        (x: mid, y: valley, z: ridge),
        (x: x + w, y: eave, z: wall),
      ]),
      s.fill(_copper.shade(-0.14)),
    );
}

/// The awning over the door, [open] of the way unfolded: plum, with brass
/// poles at its front corners and a gold edge.
void _awning(IsoStage s, double open) {
  if (open <= 0) return;
  const x0 = 2.05;
  const x1 = 2.95;
  const z = 0.62;
  final y1 = _front + 0.76 * open;
  final pole = s.stroke(_gold, 0.03);
  s.canvas
    ..drawLine(s.at(x0 + 0.04, y1 - 0.04), s.at(x0 + 0.04, y1 - 0.04, z), pole)
    ..drawLine(s.at(x1 - 0.04, y1 - 0.04), s.at(x1 - 0.04, y1 - 0.04, z), pole);
  s.box(x0, _front, z, x1 - x0, y1 - _front, 0.12, _plum);
  final a = s.at(x0, y1, z);
  final b = s.at(x1, y1, z);
  final c = s.at(x1, _front, z);
  s.canvas.drawPath(
    Path()
      ..moveTo(a.dx, a.dy)
      ..lineTo(b.dx, b.dy)
      ..lineTo(c.dx, c.dy),
    s.stroke(_gold, 0.03),
  );
}

/// The blade sign at the facade's corner, [out] of the way swung out from
/// the wall, its letters coming on one by one as it does. Drawn on the
/// arrival's clock.
void _sign(IsoStage s, double out) {
  if (out <= 0) return;
  const x = 3.68;
  const w = 0.08;
  const z0 = 0.28;
  const z1 = 1.42;
  final depth = 0.56 * out;
  final bracket = s.stroke(_iron, 0.025);
  s.canvas
    ..drawLine(
      s.at(x, _front, z1 - 0.1),
      s.at(x, _front + depth, z1 - 0.1),
      bracket,
    )
    ..drawLine(
      s.at(x, _front, z0 + 0.1),
      s.at(x, _front + depth, z0 + 0.1),
      bracket,
    );
  s.box(x, _front + 0.04, z0, w, depth - 0.04, z1 - z0, _plum);
  if (out < 0.98) return;

  // The face the viewer sees is the plane x + w; reading left to right runs
  // toward the wall, so a letter's u runs against y.
  const face = x + w;
  const y0 = _front + 0.04;
  final y1 = _front + depth;
  s.canvas.drawPath(
    s.face([
      (x: face, y: y0 + 0.05, z: z0 + 0.05),
      (x: face, y: y1 - 0.05, z: z0 + 0.05),
      (x: face, y: y1 - 0.05, z: z1 - 0.05),
      (x: face, y: y0 + 0.05, z: z1 - 0.05),
    ]),
    s.stroke(_gold.shade(-0.1), 0.02),
  );
  const letters = 'HOTEL';
  const lh = 0.15;
  const gap = 0.045;
  const lw = 0.24;
  final left = (y0 + y1) / 2 + lw / 2;
  for (var i = 0; i < letters.length; i++) {
    final top = z1 - 0.13 - i * (lh + gap);
    final on = s.phase(
      _signOut + 0.005 + i * 0.014,
      _signOut + 0.035 + i * 0.014,
    );
    final path = Path();
    for (final stroke in _glyphs[letters[i]]!) {
      for (var j = 0; j < stroke.length; j++) {
        final (u, v) = stroke[j];
        final p = s.at(face, left - u * lw, top - (1 - v) * lh);
        j == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
      }
    }
    s.canvas.drawPath(path, s.stroke(_mix(_unlit, _glow, on), 0.04));
  }
}

/// Block letters as strokes in a unit square, u to the right and v up.
const _glyphs = <String, List<List<(double, double)>>>{
  'H': [
    [(0, 0), (0, 1)],
    [(1, 0), (1, 1)],
    [(0, 0.5), (1, 0.5)],
  ],
  'O': [
    [
      (0.3, 0),
      (0.7, 0),
      (1, 0.25),
      (1, 0.75),
      (0.7, 1),
      (0.3, 1),
      (0, 0.75),
      (0, 0.25),
      (0.3, 0),
    ],
  ],
  'T': [
    [(0, 1), (1, 1)],
    [(0.5, 1), (0.5, 0)],
  ],
  'E': [
    [(1, 1), (0, 1), (0, 0), (1, 0)],
    [(0, 0.5), (0.75, 0.5)],
  ],
  'L': [
    [(0, 1), (0, 0), (1, 0)],
  ],
};

/// A tint [p] of the way from [a] to [b] - for one material brightening, so
/// both share a hue.
Tint _mix(Tint a, Tint b, double p) => Tint(
  a.hue + (b.hue - a.hue) * p,
  a.saturation + (b.saturation - a.saturation) * p,
  a.level + (b.level - a.level) * p,
);

/// A clipped bay tree in a clay pot at [x], [y], [grow] of the way grown.
void _topiary(IsoStage s, double x, double y, double grow) {
  if (grow <= 0) return;
  s.scaled(s.at(x, y), grow, () {
    s
      ..shadow(x, y, 0.16, _grass)
      ..cylinder(x, y, 0, 0.13, 0.22, _clay);
    s.canvas.drawLine(
      s.at(x, y, 0.22),
      s.at(x, y, 0.5),
      s.stroke(_bark, 0.03),
    );
    s
      ..sphere(x, y, 0.5, 0.17, _leaves)
      ..sphere(x, y, 0.76, 0.11, _leaves.shade(0.05));
  });
}

/// The pool's furniture: two loungers with towels and a parasol opening
/// between them.
void _poolside(IsoStage s) {
  final arrive = s.pop(0.62, 0.8);
  if (arrive <= 0) return;
  void lounger(double x, Tint towel) {
    s
      ..box(x, 2.5, 0.04, 0.3, 0.62, 0.08, _cream)
      ..box(x, 2.5, 0.12, 0.3, 0.14, 0.2, _cream)
      ..patch(x + 0.04, 2.72, 0.22, 0.36, towel, z: 0.125);
  }

  s.scaled(s.at(5, 2.8), arrive, () => lounger(4.55, _teal));
  final open = s.pop(0.7, 0.86);
  if (open > 0) {
    s
      ..cylinder(5, 2.62, 0.04, 0.022, 0.86, _iron.shade(0.2))
      ..cone(5, 2.62, 0.74, 0.44 * open, 0.2, _mustard)
      ..sphere(5, 2.62, 0.95, 0.025, _gold);
  }
  s.scaled(s.at(5, 2.8), arrive, () => lounger(5.15, _petalPink));
}

/// A string of bulbs swagged from the hotel's side wall, under the upper
/// cornice, across the back of the pool deck to the round tree, where its
/// crown hides the knot. It unreels from the wall, then its bulbs come on
/// one after another. Drawn before that tree, so the crown covers its end.
void _festoon(IsoStage s) {
  final reach = s.phase(0.7, 0.82);
  if (reach <= 0) return;
  final from = s.at(_side, 1.3, 1.34);
  final to = s.at(5.45, 0.4, 0.95);
  final sag = Offset(
    (from.dx + to.dx) / 2,
    (from.dy + to.dy) / 2 + 0.36 * s.unit,
  );
  Offset along(double f) =>
      from * ((1 - f) * (1 - f)) + sag * (2 * (1 - f) * f) + to * (f * f);
  // The part of the curve already out: a quadratic cut at [reach] is the
  // quadratic through the start, a control point [reach] of the way to the
  // middle one, and the point it has reached.
  final control = Offset.lerp(from, sag, reach)!;
  final end = along(reach);
  s.canvas.drawPath(
    Path()
      ..moveTo(from.dx, from.dy)
      ..quadraticBezierTo(control.dx, control.dy, end.dx, end.dy),
    s.stroke(_iron, 0.028),
  );
  for (var i = 0; i < 7; i++) {
    final f = 0.1 + i * 0.112;
    if (f > reach) break;
    final on = s.story(
      () => s.phase(_dusk - 0.02 + i * 0.012, _dusk + 0.02 + i * 0.012),
    );
    s.canvas.drawCircle(
      along(f).translate(0, 0.05 * s.unit),
      0.07 * s.unit,
      s.fill(_mix(_unlit, _glow, on)),
    );
  }
}

/// The bellboy - the brother - a step behind the trolley whose back end is
/// at [cart]: jacket and pillbox cap in the house colour, a cream
/// shirt-front and gold epaulettes and buttons. He steps out of the door
/// onto the carpet and waves; then he takes the trolley's post in both
/// hands, leans in and pushes it along. Drawn on the arrival's clock.
void _bellboy(IsoStage s, double cart) {
  const begin = _stepsOut - 0.04;
  if (s.t < begin) return;
  // Out from under the awning, down the carpet to the trolley's side.
  const from = _front + 0.82;
  const to = _cartY + _cartD / 2;
  final y = from + (to - from) * s.phase(begin, _stepsOut + 0.02);
  // The wave: the arm flies up as he arrives, waves, and comes down to
  // the trolley as he gets to work.
  final up = s.phase(_stepsOut + 0.005, _stepsOut + 0.035);
  final wave = s.phase(_stepsOut + 0.035, _pushes - 0.05, Curves.linear);
  final grab = s.phase(_pushes - 0.05, _pushes - 0.01);
  // He waves on the carpet, then steps across to the trolley's back end.
  final x = _aisle + (cart - _reach - _aisle) * grab;
  // A little bob in his step while he pushes, and none once he stands.
  final walk = s.phase(_pushes - 0.01, _pushes + 0.13, Curves.linear);
  final bob = walk > 0 && walk < 1
      ? 0.03 * math.sin(walk * math.pi * 3).abs()
      : 0.0;
  final u = s.unit;
  final foot = s.at(x, y);
  // A touch over life size, so the brother still reads at phone scale.
  const scale = 1.2;
  // Where his hands go on the trolley's back post, in his own frame: the
  // point that lands on the post once he is scaled.
  final post = s.at(cart + 0.04, to, 0.55);
  final handle = foot + (post - foot) / scale;
  s.faded(s.phase(begin, begin + 0.015), () {
    s.scaled(foot, scale, () {
      s.shadow(x, y, 0.21, x < 2.7 ? _carpet : _grass);
      s.canvas
        ..save()
        ..translate(0, -bob * u);
      s
        ..cylinder(x, y, 0, 0.07, 0.3, _iron)
        ..cylinder(x, y, 0.3, 0.12, 0.32, _plum);

      // The shirt-front: a cream V under the collar, on the near side of
      // the jacket, which hangs this far below its axis on screen.
      final near = 0.12 * math.sqrt2 * 0.5 * u;
      final collar = s.at(x, y, 0.62).translate(0, near);
      final gold = s.fill(_gold);
      s.canvas
        ..drawPath(
          Path()
            ..moveTo(collar.dx - 0.05 * u, collar.dy - 0.015 * u)
            ..lineTo(collar.dx + 0.05 * u, collar.dy - 0.015 * u)
            ..lineTo(collar.dx, collar.dy + 0.14 * u)
            ..close(),
          s.fill(_cream),
        )
        ..drawCircle(collar.translate(0, 0.19 * u), 0.022 * u, gold)
        ..drawCircle(collar.translate(0, 0.25 * u), 0.022 * u, gold);

      // Both arms hang at his sides; the right one flies up and waves,
      // swinging about a hand held clear above the cap; then both reach
      // forward to the post.
      final shoulder = s.at(x, y, 0.6);
      final r = 0.12 * u * scale;
      final angle = 1.32 + 0.4 * math.sin(wave * math.pi * 2) * (1 - wave);
      final waving =
          shoulder.translate(r, 0) +
          Offset(math.cos(angle), -math.sin(angle)) * (0.4 * u);
      final right = Offset.lerp(
        Offset.lerp(shoulder.translate(r * 1.15, 0.26 * u), waving, up),
        handle.translate(0, -0.03 * u),
        grab,
      )!;
      final left = Offset.lerp(
        shoulder.translate(-r * 1.15, 0.26 * u),
        handle.translate(-0.02 * u, 0.03 * u),
        grab,
      )!;
      final sleeve = s.stroke(_plum.shade(-0.04), 0.06);
      final skin = s.fill(_skin);
      s.canvas
        ..drawLine(shoulder.translate(-r, 0), left, sleeve)
        ..drawLine(shoulder.translate(r, 0), right, sleeve)
        ..drawCircle(left, 0.04 * u, skin)
        ..drawCircle(right, 0.045 * u, skin)
        ..drawCircle(shoulder.translate(-r * 0.92, 0), 0.04 * u, gold)
        ..drawCircle(shoulder.translate(r * 0.92, 0), 0.04 * u, gold);

      // His head leans in over the work.
      final lean = 0.04 * grab;
      s
        ..sphere(x + lean, y, 0.71, 0.1, _skin)
        ..cylinder(x + lean, y, 0.77, 0.08, 0.08, _plum);
      // The cap's gold band, round its near side.
      s.canvas
        ..drawArc(
          s.disc(x + lean, y, 0.8, 0.08),
          0,
          math.pi,
          false,
          s.stroke(_gold, 0.02),
        )
        ..restore();
    });
  });
}

/// The luggage trolley, its back end at [x]: a brass deck on castors, and a
/// gold post at each end with a rail arching between them. It lands on the
/// lawn beside the carpet with the rest of the grounds, empty, and is
/// pushed along once the story gets there.
void _trolley(IsoStage s, double x) =>
    s.dropping(0.66, 0.86, (lift) => _cart(s, x, lift), from: 3);

/// The trolley at [x], [lift] tiles above the lawn, with the guests' cases
/// dropping onto it one after another as the brother pushes it.
void _cart(IsoStage s, double x, double lift) {
  const y = _cartY;
  const w = _cartW;
  const d = _cartD;
  final z = lift;
  final brass = _gold.shade(-0.1);
  final wheel = s.fill(_iron);
  s.shadow(x + w / 2, y + d / 2, 0.42, _grass);
  for (final (dx, dy) in [(0.08, 0.06), (w - 0.08, 0.06), (0.08, d - 0.06)]) {
    s.canvas.drawCircle(s.at(x + dx, y + dy, z + 0.05), 0.05 * s.unit, wheel);
  }
  s.box(x, y, z + 0.07, w, d, 0.05, brass);
  s.canvas.drawCircle(
    s.at(x + w - 0.08, y + d - 0.06, z + 0.05),
    0.05 * s.unit,
    wheel,
  );
  s.cylinder(x + 0.04, y + d / 2, z + 0.12, 0.022, 0.9, _gold);
  s.story(() {
    s
      ..dropping(_pushes - 0.03, _pushes + 0.02, (fall) {
        s.box(x + 0.08, y + 0.05, z + 0.12 + fall, 0.3, 0.3, 0.17, _teal);
      }, from: 2)
      ..dropping(_pushes + 0.01, _pushes + 0.06, (fall) {
        s.box(x + 0.4, y + 0.07, z + 0.12 + fall, 0.15, 0.26, 0.38, _mustard);
      }, from: 2)
      ..dropping(_pushes + 0.05, _pushes + 0.1, (fall) {
        s
          ..box(x + 0.1, y + 0.09, z + 0.29 + fall, 0.25, 0.22, 0.13, _cream)
          ..cylinder(
            x + 0.225,
            y + 0.2,
            z + 0.42 + fall,
            0.09,
            0.08,
            _petalPink,
          );
      }, from: 2);
  });
  s.cylinder(x + w - 0.04, y + d / 2, z + 0.12, 0.022, 0.9, _gold);
  final back = s.at(x + 0.04, y + d / 2, z + 1.02);
  final front = s.at(x + w - 0.04, y + d / 2, z + 1.02);
  final arch = Offset(
    (back.dx + front.dx) / 2,
    (back.dy + front.dy) / 2,
  ).translate(0, -0.14 * s.unit);
  s.canvas
    ..drawPath(
      Path()
        ..moveTo(back.dx, back.dy)
        ..quadraticBezierTo(arch.dx, arch.dy, front.dx, front.dy),
      s.stroke(_gold, 0.03),
    )
    ..drawCircle(back, 0.03 * s.unit, s.fill(_gold.shade(0.1)))
    ..drawCircle(front, 0.03 * s.unit, s.fill(_gold.shade(0.1)));
}

/// A street lamp at [x], [y]: it springs up, then its lantern comes on and
/// throws a pool of warm light on the lawn - [order] of the pair.
void _lamp(IsoStage s, double x, double y, int order) {
  final grow = s.pop(0.6 + order * 0.04, 0.78 + order * 0.04);
  if (grow <= 0) return;
  final on = s.story(
    () => s.phase(_dusk + order * 0.03, _dusk + 0.06 + order * 0.03),
  );
  s.scaled(s.at(x, y), grow, () {
    if (on > 0) {
      s.canvas.drawOval(
        s.disc(x, y, 0.003, 0.45 * on),
        s.fill(_mix(_grass, _lawnLit, on)),
      );
    }
    s
      ..shadow(x, y, 0.08, _grass)
      ..cylinder(x, y, 0, 0.03, 0.88, _iron)
      ..box(x - 0.07, y - 0.07, 0.88, 0.14, 0.14, 0.17, _mix(_unlit, _glow, on))
      ..cone(x, y, 1.05, 0.11, 0.1, _iron);
  });
}
