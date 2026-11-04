import 'dart:math' as math;

import 'package:flutter/animation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_full_stack_flutter/core/audio/sound.dart';
import 'package:flutter_full_stack_flutter/features/pronunciation/presentation/scenes/iso_stage.dart';
import 'package:flutter_full_stack_flutter/features/pronunciation/presentation/scenes/script.dart';

// The palette: Seville in the late sun. A warm Andalusian sky, the
// Guadalquivir with the Torre del Oro on its bank and the Torre Sevilla
// beyond; on the island, the Plaza de España - its half-ring of red brick
// trimmed in white, the canal round it under tiled bridges, the fountain in
// the middle - orange trees, and a flamenco dancer in red.
const _skyTop = Tint(210, 0.6, 0.6);
const _skyLow = Tint(34, 0.66, 0.9);
const _sunBody = Tint(44, 0.88, 1);
const _sunHalo = Tint(36, 0.78, 0.82);
const _river = Tint(196, 0.5, 0.5);
const _riverLight = Tint(36, 0.6, 0.78);
const _hills = Tint(44, 0.3, 0.6);
const _gold = Tint(40, 0.6, 0.7);
const _goldTop = Tint(46, 0.86, 0.62);
const _glass = Tint(212, 0.32, 0.6);
const _paving = Tint(34, 0.26, 0.76);
const _earth = Tint(24, 0.44, 0.36);
const _stone = Tint(28, 0.14, 0.24);
const _brick = Tint(12, 0.56, 0.54);
const _trim = Tint(40, 0.2, 0.95);
const _roof = Tint(16, 0.48, 0.42);
const _arch = Tint(16, 0.4, 0.26);
const _canal = Tint(194, 0.56, 0.54);
const _tile = Tint(214, 0.62, 0.5);
const _fountain = Tint(36, 0.14, 0.86);
const _jet = Tint(196, 0.5, 0.88);
const _leaves = Tint(128, 0.42, 0.32);
const _orange = Tint(30, 0.92, 0.6);
const _bark = Tint(22, 0.4, 0.24);
const _hull = Tint(24, 0.5, 0.36);
const _rower = Tint(214, 0.5, 0.42);
const _dress = Tint(356, 0.76, 0.5);
const _dots = Tint(40, 0.2, 0.98);
const _skin = Tint(26, 0.5, 0.74);
const _hair = Tint(20, 0.3, 0.16);

/// The middle of the plaza: the half-ring of the building, the canal and
/// the fountain all centre on it. The half-ring runs round the back of the
/// island, from the left corner to the right.
const _cx = 3.4;
const _cy = 3.4;
const _inner = 2.0;
const _outer = 2.55;
const _storeys = 0.85;
const double _from = math.pi * 3 / 4;
const double _to = math.pi * 7 / 4;

/// The canal, inside the building, and the bridges over it.
const _canalIn = 1.4;
const _canalOut = 1.78;
const List<double> _bridges = [
  math.pi * 0.92,
  math.pi * 1.16,
  math.pi * 1.34,
  math.pi * 1.58,
];

/// Where the dancer dances: out on the plaza to the right of the fountain,
/// clear of it.
const _dancerX = 4.75;
const _dancerY = 3.6;

/// Seville, in two acts.
///
/// The plaza assembles first: the island rises in the late sun over the
/// Guadalquivir, the Plaza de España's half-ring of brick rises round the
/// back of it with its towers at either end, the canal fills, the bridges
/// are laid over it, the fountain and the orange trees come up, and a
/// flamenco dancer steps into the middle. Then the story, everyday life in
/// the square: a rowing boat sets off along the canal and under the
/// bridges, the fountain leaps, and the dancer spins - her ruffled skirt
/// flaring - and strikes her pose as the guitar strums, her fan open.
const sevilleScene = SceneScript(
  paintSeville,
  cues: [],
  sounds: [SceneSound(Sound.guitarStrum, _pose)],
);

// The story's beats, on the arrival's clock.
const _spins = 0.38;
const _pose = 0.54;
const _rows = 0.36;

/// Paints [sevilleScene].
void paintSeville(IsoStage s) {
  s.setting(() {
    // The backdrop is placed from the horizon behind the island, in tiles,
    // so it stands where it should behind it on any canvas.
    double down(double tiles) => (s.horizon + tiles * s.unit) / s.size.height;
    s
      ..sky(_skyTop, _skyLow)
      ..sun(
        (s.origin.dx - 3.5 * s.unit) / s.size.width,
        down(-4.4),
        0.6,
        _sunBody,
        _sunHalo,
        rings: 2,
      )
      ..ridge(down(-0.2), 1.1, _hills, seed: 8);
    _landmarks(s, s.phase(0.08, 0.5));
    _guadalquivir(s);

    s.rising(0, 0.42, () {
      s.island(grass: _paving, earth: _earth, stone: _stone);
      _building(s, s.phase(0.12, 0.5, Curves.easeOutBack));
      _towers(s, s.phase(0.28, 0.6, Curves.easeOutBack));
      _waterway(s, s.phase(0.4, 0.62));
      _boat(s);
      _bridgesOver(s, s.pop(0.5, 0.7));
      _fountainAt(s, s.pop(0.46, 0.66));
      _dancer(s, s.pop(0.6, 0.78));
      for (final (x, y, at) in const [
        (2.1, 5.6, 0.5),
        (5.6, 2.1, 0.54),
        (3.4, 5.55, 0.56),
        (5.4, 5.4, 0.6),
      ]) {
        _orangeTree(s, x, y, s.pop(at, at + 0.2));
      }
      s.spotlight(
        s.at(_dancerX, _dancerY, 0.5),
        radius: 2.4,
        strength: s.storyLight * 0.5,
      );
    });
  });
}

/// The Torre del Oro on the river bank to the left - its tiers and its
/// golden top - and the Torre Sevilla's glass far off to the right, both
/// rising as [rise] goes to one.
void _landmarks(IsoStage s, double rise) {
  if (rise <= 0) return;
  final u = s.unit;
  final base = s.horizon + u * 0.3;
  // Placed from the island, not the screen: wherever the page puts it,
  // they stand either side of it.
  final oro = s.origin.dx - u * 4.6;
  final body = s.fill(_gold);
  for (final (half, bottom, top) in const [
    (0.5, 0.0, 1.1),
    (0.3, 1.1, 1.6),
    (0.18, 1.6, 1.9),
  ]) {
    s.canvas.drawRect(
      Rect.fromLTRB(
        oro - half * u,
        base - top * u * rise,
        oro + half * u,
        base - bottom * u * rise,
      ),
      body,
    );
  }
  s.canvas.drawCircle(
    Offset(oro, base - 1.95 * u * rise),
    u * 0.16 * rise,
    s.fill(_goldTop),
  );

  final sevilla = s.origin.dx + u * 4.6;
  final height = u * 3.4 * rise;
  final half = u * 0.3;
  s.canvas.drawPath(
    Path()
      ..moveTo(sevilla - half, base)
      ..lineTo(sevilla - half * 0.8, base - height * 0.9)
      ..quadraticBezierTo(
        sevilla,
        base - height * 1.04,
        sevilla + half * 0.8,
        base - height * 0.9,
      )
      ..lineTo(sevilla + half, base)
      ..close(),
    s.fill(_glass),
  );
}

/// The Guadalquivir along the bottom of the sky, the island floating over
/// it, the sun lying on it in streaks.
void _guadalquivir(IsoStage s) {
  final top = s.horizon + s.unit * 0.3;
  s.canvas.drawRect(
    Rect.fromLTRB(0, top, s.size.width, s.size.height),
    s.fill(_river),
  );
  final shine = s.stroke(_riverLight, 0.06);
  for (final (fx, tiles, w) in const [
    (0.2, 0.7, 0.9),
    (0.16, 1.5, 0.6),
    (0.8, 2.2, 0.7),
    (0.4, 3.6, 0.5),
  ]) {
    final c = Offset(s.size.width * fx, top + tiles * s.unit);
    s.canvas.drawLine(
      c.translate(-w * s.unit / 2, 0),
      c.translate(w * s.unit / 2, 0),
      shine,
    );
  }
}

/// The point at [angle] round the plaza's middle, [r] tiles out, [z] up.
V3 _round(double angle, double r, [double z = 0]) =>
    (x: _cx + r * math.cos(angle), y: _cy + r * math.sin(angle), z: z);

/// The half-ring of the building, [grow] of the way up: its arcaded front
/// to the plaza in red brick, white trim along the top, and the roof - in
/// short straight lengths, back to front, each lit as it faces.
void _building(IsoStage s, double grow) {
  if (grow <= 0) return;
  final h = _storeys * grow;
  const pieces = 16;
  final order = List.generate(pieces, (i) => i)
    ..sort((a, b) {
      double depth(int i) {
        final m = _from + (_to - _from) * (i + 0.5) / pieces;
        return math.cos(m) + math.sin(m);
      }

      return depth(a).compareTo(depth(b));
    });
  for (final i in order) {
    final a = _from + (_to - _from) * i / pieces;
    final b = _from + (_to - _from) * (i + 1) / pieces;
    final m = (a + b) / 2;
    // Facing the plaza's middle: lit as it turns towards the left.
    final light = 0.1 * (-math.sin(m) + math.cos(m)) / math.sqrt2;
    s.canvas
      ..drawPath(
        s.face([
          _round(a, _inner),
          _round(b, _inner),
          _round(b, _inner, h),
          _round(a, _inner, h),
        ]),
        s.fill(_brick.shade(light)),
      )
      ..drawPath(
        s.face([
          _round(a, _inner, h),
          _round(b, _inner, h),
          _round(b, _outer, h),
          _round(a, _outer, h),
        ]),
        s.fill(_roof),
      )
      ..drawLine(
        s.at(_round(a, _inner, h).x, _round(a, _inner, h).y, h),
        s.at(_round(b, _inner, h).x, _round(b, _inner, h).y, h),
        s.stroke(_trim, 0.05),
      );
    if (grow < 1) continue;
    // An arch of the arcade below, a window above.
    final a1 = a + (b - a) * 0.28;
    final b1 = a + (b - a) * 0.72;
    s.canvas
      ..drawPath(
        s.face([
          _round(a1, _inner - 0.004),
          _round(b1, _inner - 0.004),
          _round(b1, _inner - 0.004, 0.36),
          _round(a1, _inner - 0.004, 0.36),
        ]),
        s.fill(_arch),
      )
      ..drawPath(
        s.face([
          _round(a1, _inner - 0.004, 0.52),
          _round(b1, _inner - 0.004, 0.52),
          _round(b1, _inner - 0.004, 0.7),
          _round(a1, _inner - 0.004, 0.7),
        ]),
        s.fill(_trim),
      );
  }
}

/// The two towers at the ends of the half-ring, [grow] of the way up: brick
/// shafts with white corners, a lantern stage, and a pointed top.
void _towers(IsoStage s, double grow) {
  if (grow <= 0) return;
  for (final angle in const [_to, _from]) {
    final p = _round(angle, (_inner + _outer) / 2);
    final h = 2.1 * grow;
    s
      ..box(p.x - 0.3, p.y - 0.3, 0, 0.6, 0.6, h, _brick)
      ..box(p.x - 0.22, p.y - 0.22, h, 0.44, 0.44, 0.35 * grow, _trim)
      ..cone(p.x, p.y, h + 0.35 * grow, 0.28, 0.6 * grow, _roof);
  }
}

/// The canal following the half-ring, [fill] of the way filled - water
/// between two stone edges.
void _waterway(IsoStage s, double fill) {
  if (fill <= 0) return;
  const pieces = 24;
  final edge = s.fill(_fountain);
  final water = s.fill(_canal.shade(0.06 * (1 - fill)));
  for (var i = 0; i < pieces; i++) {
    final a = _from + (_to - _from) * i / pieces;
    final b = _from + (_to - _from) * (i + 1) / pieces;
    Path band(double r0, double r1) => s.face([
      _round(a, r0, 0.004),
      _round(b, r0, 0.004),
      _round(b, r1, 0.004),
      _round(a, r1, 0.004),
    ]);
    s.canvas
      ..drawPath(band(_canalIn - 0.08, _canalOut + 0.08), edge)
      ..drawPath(band(_canalIn, _canalOut), water);
  }
}

/// The rowing boat on the canal: it sets off from the right as the story
/// starts and rows round under the bridges to the left, where it rests.
void _boat(IsoStage s) {
  final along = s.story(() => s.phase(_rows, 0.9, Curves.easeInOut));
  final angle = _to - 0.25 - (_to - _from - 0.5) * along;
  final p = _round(angle, (_canalIn + _canalOut) / 2, 0.01);
  final at = s.at(p.x, p.y, p.z);
  final u = s.unit;
  final stroke = math.sin(along * math.pi * 14);
  s.canvas
    ..drawOval(
      Rect.fromCenter(center: at, width: u * 0.42, height: u * 0.16),
      s.fill(_hull),
    )
    ..drawLine(
      at.translate(-u * 0.24, u * 0.04 * stroke),
      at.translate(u * 0.24, -u * 0.04 * stroke),
      s.stroke(_hull.shade(0.2), 0.025),
    )
    ..drawCircle(at.translate(0, -u * 0.12), u * 0.07, s.fill(_rower));
}

/// The tiled bridges over the canal, [grow] of the way laid: a stone deck
/// across the water, its balustrade picked out in blue azulejos.
void _bridgesOver(IsoStage s, double grow) {
  if (grow <= 0) return;
  for (final angle in _bridges) {
    final half = 0.09 * grow;
    final a = angle - half;
    final b = angle + half;
    s.canvas
      ..drawPath(
        s.face([
          _round(a, _canalIn - 0.12, 0.08),
          _round(b, _canalIn - 0.12, 0.08),
          _round(b, _canalOut + 0.12, 0.08),
          _round(a, _canalOut + 0.12, 0.08),
        ]),
        s.fill(_fountain),
      )
      ..drawLine(
        s.at(
          _round(b, _canalIn - 0.1, 0.16).x,
          _round(b, _canalIn - 0.1).y,
          0.16,
        ),
        s.at(
          _round(b, _canalOut + 0.1, 0.16).x,
          _round(b, _canalOut + 0.1).y,
          0.16,
        ),
        s.stroke(_tile, 0.05),
      );
  }
}

/// The fountain in the middle of the plaza, [grow] of the way up: a round
/// basin, and its jet - leaping up as the story starts and settling.
void _fountainAt(IsoStage s, double grow) {
  if (grow <= 0) return;
  s
    ..cylinder(_cx, _cy, 0, 0.55 * grow, 0.14, _fountain)
    ..canvas.drawOval(
      s.disc(_cx, _cy, 0.145, 0.45 * grow),
      s.fill(_canal),
    );
  final leap = s.story(
    () =>
        s.phase(_spins, _pose, Curves.easeOut) *
        (1 - 0.6 * s.phase(_pose + 0.06, 0.9, Curves.easeInOut)),
  );
  final height = (0.35 + 0.65 * leap) * grow;
  final base = s.at(_cx, _cy, 0.15);
  final top = s.at(_cx, _cy, 0.15 + height);
  final jet = s.stroke(_jet, 0.05);
  s.canvas.drawLine(base, top, jet);
  for (final side in const [-1.0, 1.0]) {
    s.canvas.drawPath(
      Path()
        ..moveTo(top.dx, top.dy)
        ..quadraticBezierTo(
          top.dx + side * s.unit * 0.25,
          top.dy - s.unit * 0.05,
          top.dx + side * s.unit * 0.32,
          base.dy,
        ),
      jet,
    );
  }
}

/// An orange tree at [x], [y], [grow] of the way grown, its crown dotted
/// with Seville oranges.
void _orangeTree(IsoStage s, double x, double y, double grow) {
  if (grow <= 0) return;
  s.tree(
    x,
    y,
    leaves: _leaves,
    bark: _bark,
    ground: _paving,
    h: 1.1,
    grow: grow,
  );
  final crown = s.at(x, y, 1.1 * grow * 0.62);
  final random = math.Random((x * 10 + y).round());
  for (var k = 0; k < 6; k++) {
    final a = random.nextDouble() * math.pi * 2;
    final r = random.nextDouble() * 0.22 * s.unit * grow;
    s.canvas.drawCircle(
      crown + Offset(math.cos(a), math.sin(a) * 0.8) * r,
      s.unit * 0.045 * grow,
      s.fill(_orange),
    );
  }
}

/// The flamenco dancer, [grow] of the way stepped out: a red dress with
/// white spots and a ruffled hem, her hair in a bun with a flower, her
/// arms raised. As the story starts she spins - the skirt flaring out and
/// its spots going round - and as the guitar strums she stops in her pose,
/// her fan open over her head.
void _dancer(IsoStage s, double grow) {
  if (grow <= 0) return;
  // Drawn larger than the plaza would have her: she is the story.
  final u = s.unit * 1.45;
  final foot = s.at(_dancerX, _dancerY);
  Offset p(double x, double y) => foot.translate(x * u, -y * u * grow);
  final spin = s.story(() => s.phase(_spins, _pose, Curves.easeInOut));
  final flare =
      math.sin(spin * math.pi) *
      (1 - s.story(() => s.phase(_pose, _pose + 0.1)));
  final posed = s.story(
    () => s.phase(_pose - 0.02, _pose + 0.06, Curves.easeOutBack),
  );

  s.shadow(_dancerX, _dancerY, 0.28, _paving);
  // The skirt: from the waist out to a ruffled hem, wider as she spins.
  final hem = 0.3 + 0.24 * flare;
  final skirt = Path()
    ..moveTo(p(-0.07, 0.56).dx, p(-0.07, 0.56).dy)
    ..quadraticBezierTo(
      p(-hem * 0.6, 0.3).dx,
      p(-hem * 0.6, 0.3).dy,
      p(-hem, 0.06 + 0.06 * flare).dx,
      p(-hem, 0.06 + 0.06 * flare).dy,
    );
  const ruffles = 6;
  for (var k = 0; k < ruffles; k++) {
    final x0 = -hem + 2 * hem * k / ruffles;
    final x1 = -hem + 2 * hem * (k + 1) / ruffles;
    final y = 0.06 + 0.06 * flare * (1 - ((x0 + x1) / (2 * hem)).abs());
    skirt.quadraticBezierTo(
      p((x0 + x1) / 2, y - 0.07).dx,
      p((x0 + x1) / 2, y - 0.07).dy,
      p(x1, y).dx,
      p(x1, y).dy,
    );
  }
  skirt
    ..quadraticBezierTo(
      p(hem * 0.6, 0.3).dx,
      p(hem * 0.6, 0.3).dy,
      p(0.07, 0.56).dx,
      p(0.07, 0.56).dy,
    )
    ..close();
  s.canvas
    ..drawPath(skirt, s.fill(_dress))
    ..save()
    ..clipPath(skirt);
  // The spots, going round with her.
  for (var row = 0; row < 3; row++) {
    for (var k = 0; k < 5; k++) {
      final x = ((k / 5 + spin * 1.5 + row * 0.1) % 1) * 2 - 1;
      s.canvas.drawCircle(
        p(x * hem * (0.5 + row * 0.2), 0.42 - row * 0.13),
        u * 0.022,
        s.fill(_dots),
      );
    }
  }
  s.canvas.restore();

  // The bodice, the arms - one raised high, one curved at her side - the
  // head, the bun and its flower.
  final skin = s.stroke(_skin, 0.035);
  final hand = p(0.16, 1.02 + 0.08 * posed);
  s.canvas
    ..drawPath(
      Path()
        ..moveTo(p(-0.07, 0.56).dx, p(-0.07, 0.56).dy)
        ..lineTo(p(-0.06, 0.8).dx, p(-0.06, 0.8).dy)
        ..lineTo(p(0.06, 0.8).dx, p(0.06, 0.8).dy)
        ..lineTo(p(0.07, 0.56).dx, p(0.07, 0.56).dy)
        ..close(),
      s.fill(_dress.shade(-0.06)),
    )
    ..drawPath(
      Path()
        ..moveTo(p(0.05, 0.78).dx, p(0.05, 0.78).dy)
        ..quadraticBezierTo(
          p(0.2, 0.86).dx,
          p(0.2, 0.86).dy,
          hand.dx,
          hand.dy,
        ),
      skin,
    )
    ..drawPath(
      Path()
        ..moveTo(p(-0.05, 0.78).dx, p(-0.05, 0.78).dy)
        ..quadraticBezierTo(
          p(-0.24, 0.74 + 0.1 * posed).dx,
          p(-0.24, 0.74 + 0.1 * posed).dy,
          p(-0.12, 0.62 + 0.3 * posed).dx,
          p(-0.12, 0.62 + 0.3 * posed).dy,
        ),
      skin,
    )
    ..drawCircle(p(0, 0.9), u * 0.065, s.fill(_skin))
    ..drawCircle(p(-0.03, 0.95), u * 0.045, s.fill(_hair))
    ..drawCircle(p(0.04, 0.96), u * 0.025, s.fill(_dress));

  // Her fan, opening over her head as she strikes the pose.
  if (posed > 0) {
    final open = posed.clamp(0.0, 1.0);
    final fan = Path()..moveTo(hand.dx, hand.dy);
    final spread = math.pi * 0.7 * open;
    const steps = 8;
    for (var k = 0; k <= steps; k++) {
      final a = -math.pi / 2 - spread / 2 + spread * k / steps;
      fan.lineTo(
        hand.dx + math.cos(a) * u * 0.2,
        hand.dy + math.sin(a) * u * 0.2,
      );
    }
    fan.close();
    s.canvas
      ..drawPath(fan, s.fill(_hair))
      ..drawPath(fan, s.stroke(_dress, 0.02));
  }
}
