import 'dart:math' as math;

import 'package:flutter/animation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_full_stack_flutter/core/audio/sound.dart';
import 'package:flutter_full_stack_flutter/features/pronunciation/presentation/scenes/iso_stage.dart';
import 'package:flutter_full_stack_flutter/features/pronunciation/presentation/scenes/script.dart';

// The palette: a clear summer day. A sky-blue wash, meadow greens, the
// cottage's cream and terracotta, and one accent - the coral of the parasol,
// the deck chair and the shirt on the line - for the sunny day itself.
const _skyTop = Tint(210, 0.75, 0.52);
const _skyLow = Tint(190, 0.6, 0.96);
const _sunBody = Tint(44, 1, 0.84);
const _sunHalo = Tint(48, 0.95, 0.78);
const _cloud = Tint(210, 0.5, 1);
const _farHill = Tint(165, 0.4, 0.74);
const _nearHill = Tint(150, 0.34, 0.62);
const _grass = Tint(104, 0.46, 0.4);
const _earth = Tint(24, 0.6, 0.3);
const _stone = Tint(28, 0.18, 0.16);
const _gravel = Tint(36, 0.55, 0.7);
const _flag = Tint(32, 0.24, 0.84);
const _pebble = Tint(30, 0.14, 0.62);
const _water = Tint(196, 0.85, 0.42);
const _lily = Tint(112, 0.5, 0.4);
const _wall = Tint(36, 0.6, 0.86);
const _tile = Tint(8, 0.78, 0.36);
const _trim = Tint(205, 0.5, 0.28);
const _glass = Tint(196, 0.75, 0.55);
const _wood = Tint(28, 0.5, 0.42);
const _leaves = Tint(128, 0.55, 0.3);
const _leavesLight = Tint(92, 0.5, 0.44);
const _bark = Tint(22, 0.45, 0.18);
const _petalPink = Tint(338, 0.9, 0.5);
const _petalGold = Tint(44, 1, 0.66);
const _petalLilac = Tint(272, 0.7, 0.54);
const _stem = Tint(110, 0.55, 0.28);
const _vane = Tint(220, 0.3, 0.12);
const _coral = Tint(8, 0.68, 0.58);
const _cream = Tint(40, 0.55, 0.94);
const _sheet = Tint(200, 0.5, 0.88);
const _towel = Tint(44, 0.8, 0.66);
const _lavender = Tint(272, 0.4, 0.78);
const _gingham = Tint(206, 0.55, 0.62);
const _wicker = Tint(34, 0.55, 0.5);
const _apple = Tint(4, 0.72, 0.5);
const _lemonade = Tint(52, 0.75, 0.72);
const _skin = Tint(26, 0.6, 0.7);
const _swimsuit = Tint(196, 0.6, 0.42);
const _straw = Tint(42, 0.62, 0.76);
const _wingBlue = Tint(206, 0.7, 0.62);
const _hose = Tint(140, 0.5, 0.34);
// The grey the island stands in while the clouds are over the sun, and the
// streaks of the wind that blows them away.
const _overcast = Tint(218, 0.22, 0.4);
const _gust = Tint(206, 0.4, 0.74);

/// "The weather is beautiful today", in two acts.
///
/// The meadow assembles first, under a sky that is clouding over: the island
/// rises, the cottage drops onto it, the trees spring up, the washing is
/// pegged out, the deck chair and the furled parasol land by the pond, the
/// sprinkler starts, and two clouds drift together over the sun. Then the
/// story, while the rest of the island sinks back: the wind gets up - the
/// weathervane on the roof spins round, the washing flaps and the clouds
/// start rolling apart (*weather*); the sun breaks through with a glow, its
/// light floods the garden, the flowers burst open and a little rainbow
/// arcs in the sprinkler's spray (*beautiful*); and the day gets going -
/// someone in a sun hat settles into the deck chair as the parasol opens
/// beside it (*today*), two butterflies arrive and the glass goes up to the
/// weather.
const weatherScene = SceneScript(
  paintWeather,
  cues: [
    Cue('weather', _windUp),
    Cue('beautiful', _sunOut),
    Cue('today', _dayOn),
  ],
  sounds: [
    SceneSound(Sound.wind, _windUp),
    SceneSound(Sound.sparkle, _sunOut),
  ],
);

// The story's beats, on the arrival's clock, in the order the sentence says
// them - which is also the order they cause each other: the wind clears the
// sky, the sun comes out into it, and then the day can be enjoyed.
const _windUp = 0.42;
const _sunOut = 0.56;
const _dayOn = 0.72;
// The wind has rolled the clouds clear of the sun as it breaks through.
const double _cleared = _sunOut + 0.02;
// The glass goes up last, a toast to the weather.
const double _toast = _dayOn + 0.12;

// Where the sun stands, in screen fractions: on the right, and under the
// card rather than behind it, since this time it is what the story is about.
const _sunX = 0.78;
const _sunY = 0.365;

/// Paints [weatherScene].
void paintWeather(IsoStage s) {
  s.setting(() {
    s.sky(_skyTop, _skyLow);

    // The sun climbs to its place while two clouds drift together over it;
    // breaking through them is the story's.
    final climb = s.phase(0.1, 0.8);
    final drift = s.phase(0.2, 1);
    s.story(() {
      _sun(
        s,
        s.screen(_sunX, _sunY + 0.06 * (1 - climb)),
        burst: s.pop(_sunOut - 0.01, _sunOut + 0.05),
        settle: s.phase(_sunOut + 0.06, _sunOut + 0.26),
      );
    });
    s
      ..ridge(0.78, 1.3, _farHill, seed: 2)
      ..ridge(0.86, 1, _nearHill, seed: 5)
      ..cloud(s.screen(0.12 - 0.4 * (1 - drift), 0.56), 1.6, _cloud);
    // The wind gets them moving apart, and they roll clear of the sun just
    // as it breaks through: one to rest on the left, the other blown away
    // off the right.
    s.story(() {
      final part =
          0.1 * s.phase(_windUp - 0.01, _windUp + 0.1) +
          0.9 * s.phase(_sunOut - 0.05, _cleared, Curves.easeInOutCubic);
      double go(double from, double to) => from + (to - from) * part;
      s
        ..cloud(
          s.screen(go(0.8 - 0.9 * (1 - drift), 0.13), go(0.382, 0.335)),
          2.5,
          _cloud,
        )
        ..cloud(
          s.screen(go(0.88 + 0.5 * (1 - drift), 1.3), go(0.355, 0.32)),
          2,
          _cloud,
        );
    });

    s.rising(0, 0.42, () {
      s.island(grass: _grass, earth: _earth, stone: _stone);
      // Flat on the ground, so before anything that stands.
      _path(s);
      _pond(s);
      _rug(s);
      // The stage: the garden in front of the cottage, dark while the
      // clouds are over it. The sun's light floods out across it as it
      // breaks through, and stays.
      s.story(() {
        final flood = s.phase(_sunOut - 0.01, _sunOut + 0.08);
        s.pool(4.55, 3.35, 0.9 + 1.3 * flood, strength: s.storyLight * flood);
      });

      // A bush tucked behind the cottage's left side, so the cottage lands
      // in front of it.
      s.bush(0.35, 2.55, _leavesLight, size: 1.1, grow: s.pop(0.5, 0.7));
      s.dropping(0.28, 0.66, (lift) => _cottage(s, lift));

      s
        ..tree(
          4.6,
          0.9,
          leaves: _leavesLight,
          bark: _bark,
          ground: _grass,
          h: 1.9,
          grow: s.pop(0.44, 0.66),
        )
        ..tree(
          5.6,
          0.6,
          leaves: _leaves,
          bark: _bark,
          ground: _grass,
          h: 1.4,
          grow: s.pop(0.52, 0.74),
        );

      s.pine(
        0.42,
        5.15,
        needles: _leaves,
        bark: _bark,
        ground: _grass,
        h: 2,
        grow: s.pop(0.44, 0.66),
      );
      _clothesline(s);
      // The parasol stands just behind the chair, so whoever sits in it is
      // seen under it rather than behind it.
      _parasol(s, 5.4, 1.5);
      s.dropping(0.46, 0.64, (lift) => _deckChair(s, lift));
      s.bush(5.75, 4.05, _leaves, size: 0.8, grow: s.pop(0.6, 0.8));
      _flowers(s);
      _picnic(s);
      _sprinkler(s, 5.55, 5.45);

      s.story(() {
        _butterflies(s);
        _wind(s);

        // While the clouds are over the sun the whole island stands in their
        // grey; the sun breaking through lifts it.
        final grey = 1 - s.phase(_sunOut - 0.01, _sunOut + 0.06);
        if (grey > 0) {
          s.canvas.drawPaint(
            Paint()..color = s.colour(_overcast).withValues(alpha: 0.3 * grey),
          );
        }

        // The rest of the island steps back: round the weathervane while
        // the wind gets up, then round the garden once the sun is on it.
        s.spotlight(
          Offset.lerp(
            s.at(3.1, 1.5, 2.4),
            s.at(4.5, 3.3, 0.5),
            s.phase(_sunOut - 0.03, _sunOut + 0.1, Curves.easeInOut),
          )!,
          radius: 2.5,
          strength: s.storyLight,
        );
      });
    });
  });
}

// --------------------------------------------------------------------- sky --

/// The sun at [c], in its halo. Once it has broken through - [burst] - a glow
/// spreads round it and its rays shoot out, then [settle] to a gentler
/// shine.
void _sun(
  IsoStage s,
  Offset c, {
  required double burst,
  required double settle,
}) {
  const r = 0.55;
  final shine = burst.clamp(0.0, 1.0);
  s.glow(c, 2.6, strength: shine * (1 - 0.45 * settle));
  s.sun(
    c.dx / s.size.width,
    c.dy / s.size.height,
    r,
    _sunBody,
    _sunHalo,
    rings: 2,
  );
  if (burst <= 0) return;
  final ray = s.stroke(_sunBody, 0.08);
  for (var i = 0; i < 10; i++) {
    final a = i * math.pi / 5 + 0.3 * settle;
    final d = Offset(math.cos(a), math.sin(a));
    s.canvas.drawLine(
      c + d * (r * 2 * s.unit),
      c + d * ((r * 2 + 0.45 * burst) * s.unit),
      ray,
    );
  }
}

/// The wind getting up: streaks blowing across the roof, past the
/// weathervane, each a beat after the one before.
void _wind(IsoStage s) {
  final u = s.unit;
  final anchor = s.at(2.66, 2.05, 2.7);
  for (final (i, dy) in const [-0.55, 0.05, 0.6].indexed) {
    final p = s.phase(
      _windUp - 0.02 + i * 0.012,
      _windUp + 0.12 + i * 0.012,
      Curves.easeOutSine,
    );
    final fade = math.sin(p * math.pi);
    if (fade <= 0.01) continue;
    final length = (1.4 - 0.25 * i) * u;
    final curl = 0.13 * u;
    final a = anchor.translate((-2.8 + 4.2 * p + 0.3 * i) * u, dy * u);
    s.canvas.drawPath(
      Path()
        ..moveTo(a.dx, a.dy)
        ..cubicTo(
          a.dx + length * 0.35,
          a.dy - 0.1 * u,
          a.dx + length * 0.65,
          a.dy + 0.08 * u,
          a.dx + length,
          a.dy,
        )
        ..arcTo(
          Rect.fromCircle(
            center: Offset(a.dx + length, a.dy - curl),
            radius: curl,
          ),
          math.pi / 2,
          -1.5 * math.pi,
          false,
        ),
      s.stroke(_gust, 0.055)..color = s.colour(_gust).withValues(alpha: fade),
    );
  }
}

// ------------------------------------------------------------------ ground --

/// The gravel path from the door to the front edge, with flagstones in it.
void _path(IsoStage s) {
  s.patch(1.96, 3.1, 0.5, 2.9, _gravel);
  for (var i = 0; i < 6; i++) {
    final x = 2.21 + (i.isEven ? -0.05 : 0.06);
    final y = 3.42 + i * 0.47;
    s.canvas
      ..drawOval(s.disc(x, y, 0.003, 0.17), s.fill(_gravel.shade(-0.1)))
      ..drawOval(s.disc(x - 0.01, y - 0.01, 0.02, 0.155), s.fill(_flag));
  }
}

const _pondX = 4.75;
const _pondY = 4.55;

/// The pond: water in a ring of stones, with lily pads, and a bloom that
/// opens when the sun comes out.
void _pond(IsoStage s) {
  const x = _pondX;
  const y = _pondY;
  s.canvas
    ..drawOval(s.disc(x, y, 0.003, 0.92), s.fill(_grass.shade(-0.08)))
    ..drawOval(s.disc(x, y, 0.004, 0.78), s.fill(_water.shade(-0.1)))
    ..drawOval(s.disc(x - 0.05, y - 0.05, 0.005, 0.66), s.fill(_water))
    ..drawOval(
      s.disc(x - 0.3, y - 0.22, 0.006, 0.2),
      s.fill(_water.shade(0.22)),
    );

  // The stone rim, from the back of the ring round to the front.
  const n = 18;
  final angles = [for (var i = 0; i < n; i++) (i + 0.5) * 2 * math.pi / n]
    ..sort(
      (a, b) =>
          (math.cos(a) + math.sin(a)).compareTo(math.cos(b) + math.sin(b)),
    );
  for (final a in angles) {
    final px = x + 0.82 * math.cos(a);
    final py = y + 0.82 * math.sin(a);
    final r = 0.11 + 0.025 * math.sin(a * 5);
    s.canvas
      ..drawOval(s.disc(px, py, 0.006, r), s.fill(_pebble.shade(-0.16)))
      ..drawOval(
        s.disc(px - 0.015, py - 0.015, 0.045, r * 0.86),
        s.fill(_pebble.shade(0.05 * math.cos(a * 3))),
      );
  }

  _lilyPad(s, x + 0.24, y + 0.2, 0.17, 1.1, s.pop(0.56, 0.7));
  _lilyPad(s, x + 0.36, y - 0.2, 0.11, 2.6, s.pop(0.6, 0.74));
  s.story(() {
    final bloom = s.pop(_sunOut + 0.01, _sunOut + 0.09);
    if (bloom <= 0) return;
    final c = s.at(x + 0.21, y + 0.17, 0.05);
    s.canvas
      ..drawCircle(c, 0.075 * s.unit * bloom, s.fill(_petalPink.shade(0.26)))
      ..drawCircle(c, 0.03 * s.unit * bloom, s.fill(_petalGold));
  });
}

/// A lily pad of radius [r] at [x], [y], its notch facing [notch] radians,
/// [grow] of the way open.
void _lilyPad(
  IsoStage s,
  double x,
  double y,
  double r,
  double notch,
  double grow,
) {
  if (grow <= 0) return;
  s.canvas.drawArc(
    s.disc(x, y, 0.008, r * grow),
    notch + 0.3,
    2 * math.pi - 0.6,
    true,
    s.fill(_lily),
  );
}

const _rugX = 2.75;
const _rugY = 4.95;
const _rugW = 0.85;
const _rugD = 0.8;

/// The picnic rug, unrolling from its back edge: blue gingham, its bands
/// one shade down and the crossings two.
void _rug(IsoStage s) {
  final open = s.phase(0.5, 0.62);
  if (open <= 0) return;
  final reach = _rugY + _rugD * open;
  final band = _gingham.at(0.74);
  void cell(double x0, double y0, double x1, double y1, Tint tint) {
    final y2 = math.min(y1, reach);
    if (y2 <= y0) return;
    s.patch(x0, y0, x1 - x0, y2 - y0, tint, z: 0.005);
  }

  cell(_rugX, _rugY, _rugX + _rugW, _rugY + _rugD, _gingham.at(0.94));
  for (final f in const [0.2, 0.6]) {
    cell(
      _rugX,
      _rugY + _rugD * f,
      _rugX + _rugW,
      _rugY + _rugD * f + 0.16,
      band,
    );
    cell(
      _rugX + _rugW * f,
      _rugY,
      _rugX + _rugW * f + 0.17,
      _rugY + _rugD,
      band,
    );
  }
  for (final fx in const [0.2, 0.6]) {
    for (final fy in const [0.2, 0.6]) {
      cell(
        _rugX + _rugW * fx,
        _rugY + _rugD * fy,
        _rugX + _rugW * fx + 0.17,
        _rugY + _rugD * fy + 0.16,
        _gingham.at(0.52),
      );
    }
  }
}

// ----------------------------------------------------------------- cottage --

const _stepTop = 0.07;

/// The cottage, [lift] tiles above where it will stand.
void _cottage(IsoStage s, double lift) {
  const x = 1.0;
  const y = 1.1;
  const w = 2.3;
  const d = 1.9;
  const h = 1.15;
  final z = lift;
  if (lift < 0.05) s.shadow(x + w / 2, y + d / 2, 1.5, _grass);

  s
    ..box(x, y, z, w, d, h, _wall)
    // The door on the left face, with a step; windows either side of it and
    // along the right face.
    ..onLeft(y + d, x + 1, z, 0.42, 0.72, _trim)
    ..onLeft(y + d, x + 0.25, z + 0.4, 0.4, 0.4, _glass)
    ..onLeft(y + d, x + 1.65, z + 0.4, 0.4, 0.4, _glass)
    ..onRight(x + w, y + 0.3, z + 0.4, 0.45, 0.4, _glass.shade(-0.1))
    ..onRight(x + w, y + 1.15, z + 0.4, 0.45, 0.4, _glass.shade(-0.1))
    ..box(x + 0.75, y + d, z, 0.8, 0.24, _stepTop, _gravel)
    // Window boxes under the front windows.
    ..box(x + 0.22, y + d, z + 0.3, 0.46, 0.1, 0.1, _wood)
    ..box(x + 1.62, y + d, z + 0.3, 0.46, 0.1, 0.1, _wood)
    // A chimney through the back slope, then the roof over everything.
    ..box(x + 0.4, y + 0.3, z + h, 0.32, 0.32, 0.95, _tile.shade(-0.08))
    ..roof(x, y, z + h, w, d, 0.85, _tile);

  s.story(() {
    // The window boxes flower with the rest of the garden when the sun
    // comes out.
    for (final (i, bx) in const [1.3, 1.45, 1.6, 2.7, 2.85, 3.0].indexed) {
      final bloom = s.pop(_sunOut + i * 0.006, _sunOut + 0.08 + i * 0.006);
      if (bloom <= 0) continue;
      s.canvas.drawCircle(
        s.at(bx, y + d + 0.05, z + 0.44),
        0.055 * s.unit * bloom,
        s.fill(i.isEven ? _petalPink : _petalGold),
      );
    }

    // The weathervane on the ridge points one way while the sky clouds
    // over; when the wind gets up it spins round and settles into it.
    final spin = s.phase(_windUp - 0.01, _windUp + 0.16, Curves.easeOutQuad);
    _weathervane(
      s,
      x + w * 0.72,
      y + d / 2,
      z + h + 0.85,
      0.6 + (1 - spin) * (math.pi * 4 + 1.9),
    );
  });
}

/// A weathervane standing on the ridge at [x], [y], [z]: a mast, the fixed
/// arms of the compass, and the arrow turned to [turn] radians.
void _weathervane(IsoStage s, double x, double y, double z, double turn) {
  final u = s.unit;
  final iron = s.stroke(_vane, 0.035);
  final mast = s.at(x, y, z + 0.76);
  s.canvas.drawLine(s.at(x, y, z), mast, iron);
  // The compass arms, fixed, a little below the arrow.
  const arm = 0.3;
  for (final (ax, ay) in const [(arm, 0.0), (0.0, arm)]) {
    s.canvas.drawLine(
      s.at(x - ax, y - ay, z + 0.48),
      s.at(x + ax, y + ay, z + 0.48),
      s.stroke(_vane, 0.025),
    );
  }

  // The arrow swings in the horizontal plane; its head and its tail fin are
  // upright plates, so they show whichever way it points.
  final along = Offset(math.cos(turn), math.sin(turn) * 0.5);
  final tip = mast + along * (0.6 * u);
  final tail = mast - along * (0.52 * u);
  final neck = tip - along * (0.24 * u);
  final fin = tail + along * (0.24 * u);
  s.canvas
    ..drawLine(tail, tip, s.stroke(_vane, 0.04))
    ..drawPath(
      Path()
        ..moveTo(tip.dx, tip.dy)
        ..lineTo(neck.dx, neck.dy - 0.13 * u)
        ..lineTo(neck.dx, neck.dy + 0.13 * u)
        ..close(),
      s.fill(_vane),
    )
    ..drawPath(
      Path()
        ..moveTo(tail.dx, tail.dy - 0.2 * u)
        ..lineTo(fin.dx, fin.dy - 0.05 * u)
        ..lineTo(fin.dx, fin.dy + 0.03 * u)
        ..lineTo(tail.dx, tail.dy + 0.06 * u)
        ..close(),
      s.fill(_vane),
    )
    ..drawCircle(mast, 0.06 * u, s.fill(_petalGold));
}

// ------------------------------------------------------------- clothesline --

// The washing line runs beside the path, from near the step to near the
// front edge, so the washing hangs against the grass and faces the path.
const _lineX = 1.45;
const _lineFrom = 3.7;
const _lineTo = 5.5;
const _lineZ = 1.12;

/// How high the line hangs at [y]: it sags in the middle.
double _sag(double y) {
  final f = (y - _lineFrom) / (_lineTo - _lineFrom);
  return _lineZ - 0.56 * f * (1 - f);
}

/// What hangs on the line: where along it, how wide and how long, and its
/// outline in fractions of that (`dx` along the line, `dy` down from it).
const List<({double y, double w, double hang, Tint tint, List<Offset> shape})>
_wash = [
  (
    y: 3.84,
    w: 0.52,
    hang: 0.66,
    tint: _sheet,
    shape: [Offset.zero, Offset(1, 0), Offset(1, 1), Offset(0, 1)],
  ),
  (
    y: 4.5,
    w: 0.3,
    hang: 0.5,
    tint: _coral,
    shape: [
      Offset.zero,
      Offset(1, 0),
      Offset(1.24, 0.28),
      Offset(1, 0.42),
      Offset(0.96, 1),
      Offset(0.04, 1),
      Offset(0, 0.42),
      Offset(-0.24, 0.28),
    ],
  ),
  (
    y: 4.94,
    w: 0.26,
    hang: 0.38,
    tint: _towel,
    shape: [
      Offset.zero,
      Offset(1, 0),
      Offset(1.04, 1),
      Offset(0.58, 1),
      Offset(0.5, 0.42),
      Offset(0.42, 1),
      Offset(-0.04, 1),
    ],
  ),
  (
    y: 5.26,
    w: 0.17,
    hang: 0.3,
    tint: _lavender,
    shape: [Offset.zero, Offset(1, 0), Offset(1, 1), Offset(0, 1)],
  ),
];

/// The washing line: the posts come up, the line is strung and the washing
/// is pegged out one piece after another. When the wind gets up it lifts the
/// washing and lets it settle.
void _clothesline(IsoStage s) {
  void post(double y, double grow) {
    if (grow <= 0) return;
    s.box(
      _lineX - 0.04,
      y - 0.04,
      0,
      0.08,
      0.08,
      (_lineZ + 0.08) * grow,
      _wood,
    );
  }

  post(_lineFrom, s.pop(0.46, 0.58));

  final strung = s.phase(0.56, 0.64);
  if (strung > 0) {
    final line = Path();
    for (var i = 0; i <= 12; i++) {
      final y = _lineFrom + (_lineTo - _lineFrom) * strung * i / 12;
      final p = s.at(_lineX, y, _sag(y));
      i == 0 ? line.moveTo(p.dx, p.dy) : line.lineTo(p.dx, p.dy);
    }
    s.canvas.drawPath(line, s.stroke(_pebble.shade(-0.2), 0.018));
  }

  final pegged = [
    for (var i = 0; i < _wash.length; i++)
      s.pop(0.62 + i * 0.05, 0.74 + i * 0.05),
  ];
  s.story(() {
    for (var i = 0; i < _wash.length; i++) {
      final item = _wash[i];
      final unfurl = pegged[i];
      if (unfurl <= 0) continue;
      // The gust: a swing out and back that dies away, each piece a beat
      // after the one before.
      final gust = s.phase(
        _windUp - 0.01 + i * 0.012,
        _windUp + 0.2 + i * 0.012,
        Curves.linear,
      );
      final swing = 0.75 * math.sin(gust * math.pi * 5) * (1 - gust);
      final hang = item.hang * unfurl;
      V3 point(Offset o) {
        final y = item.y + o.dx * item.w;
        return (
          x: _lineX + o.dy * hang * math.sin(swing),
          y: y,
          z: _sag(y) - o.dy * hang * math.cos(swing),
        );
      }

      s.canvas.drawPath(
        s.face([for (final o in item.shape) point(o)]),
        s.fill(item.tint.shade(-0.04 + 0.06 * math.sin(swing))),
      );
      if (i == 0) {
        // A stripe across the sheet.
        s.canvas.drawPath(
          s.face([
            point(const Offset(0, 0.74)),
            point(const Offset(1, 0.74)),
            point(const Offset(1, 0.86)),
            point(const Offset(0, 0.86)),
          ]),
          s.fill(_gingham.at(0.68)),
        );
      }
      // The pegs.
      for (final u in const [0.12, 0.88]) {
        final y = item.y + u * item.w;
        s.canvas.drawCircle(
          s.at(_lineX, y, _sag(y)),
          0.03 * s.unit,
          s.fill(_wood.shade(0.1)),
        );
      }
    }
  });

  post(_lineTo, s.pop(0.5, 0.62));
}

// --------------------------------------------------------------- deck chair --

const _chairX = 4.75;
const _chairY = 1.95;
const _seat = 0.3;

/// The deck chair, [lift] tiles above its place, facing the pond. Once the
/// day gets going, someone in a sun hat settles into it.
void _deckChair(IsoStage s, double lift) {
  const x = _chairX;
  const y = _chairY;
  const half = 0.25;
  final z = lift;
  if (lift < 0.05) {
    s.canvas.drawPath(
      s.face(const [
        (x: x - half, y: y, z: 0.002),
        (x: x + half + 0.1, y: y, z: 0.002),
        (x: x + half + 0.1, y: y + 1.02, z: 0.002),
        (x: x - half, y: y + 1.02, z: 0.002),
      ]),
      s.fill(_grass.shade(-0.1)),
    );
  }

  final frame = s.stroke(_wood.shade(-0.04), 0.04);
  void rail(double rx) {
    Offset p(double py, double pz) => s.at(rx, y + py, z + pz);
    final back = p(-0.02, 1);
    final crease = p(0.34, _seat);
    final front = p(0.96, _seat - 0.06);
    final strut = p(0.08, 0.82);
    final path = Path()
      ..moveTo(back.dx, back.dy)
      ..lineTo(crease.dx, crease.dy)
      ..lineTo(front.dx, front.dy)
      ..lineTo(p(0.98, 0).dx, p(0.98, 0).dy)
      ..moveTo(crease.dx, crease.dy)
      ..lineTo(p(0.12, 0).dx, p(0.12, 0).dy)
      ..moveTo(strut.dx, strut.dy)
      ..lineTo(p(-0.18, 0).dx, p(-0.18, 0).dy);
    s.canvas.drawPath(path, frame);
  }

  rail(x - half);
  // The canvas, in coral and cream stripes, slung from the back to the
  // front: the backrest a shade darker than the seat.
  for (var i = 0; i < 4; i++) {
    final x0 = x - half + 2 * half * i / 4;
    final x1 = x0 + 2 * half / 4;
    final tint = i.isEven ? _coral : _cream;
    s.canvas
      ..drawPath(
        s.face([
          (x: x0, y: y, z: z + 0.98),
          (x: x1, y: y, z: z + 0.98),
          (x: x1, y: y + 0.34, z: z + _seat),
          (x: x0, y: y + 0.34, z: z + _seat),
        ]),
        s.fill(tint.shade(-0.04)),
      )
      ..drawPath(
        s.face([
          (x: x0, y: y + 0.34, z: z + _seat),
          (x: x1, y: y + 0.34, z: z + _seat),
          (x: x1, y: y + 0.94, z: z + _seat - 0.05),
          (x: x0, y: y + 0.94, z: z + _seat - 0.05),
        ]),
        s.fill(tint.shade(0.06)),
      );
  }

  // They drop into the seat with a bounce as the day begins.
  s.story(() {
    s.dropping(
      _dayOn - 0.015,
      _dayOn + 0.08,
      (fall) => _sunbather(s, z + fall),
      from: 0.9,
    );
  });
  rail(x + half);
}

/// Someone in a swimsuit and sunglasses, legs out along the seat, [z] tiles
/// above it; the sun hat drops onto their head, and last they raise a glass
/// of lemonade.
void _sunbather(IsoStage s, double z) {
  const x = _chairX;
  const y = _chairY;
  const seat = _seat;
  final u = s.unit;
  final head = s.at(x, y + 0.28, z + seat + 0.52);

  // The far arm, resting on the frame.
  s.canvas.drawLine(
    s.at(x - 0.14, y + 0.3, z + seat + 0.34),
    s.at(x - 0.22, y + 0.58, z + seat + 0.08),
    s.stroke(_skin.shade(-0.06), 0.06),
  );
  s
    ..cylinder(x, y + 0.3, z + seat - 0.02, 0.14, 0.38, _swimsuit)
    ..box(x - 0.13, y + 0.4, z + seat - 0.06, 0.11, 0.52, 0.09, _skin)
    ..box(x + 0.02, y + 0.4, z + seat - 0.06, 0.11, 0.52, 0.09, _skin)
    ..sphere(x, y + 0.28, z + seat + 0.52, 0.12, _skin);
  // Sunglasses.
  s.canvas.drawLine(
    s.at(x - 0.07, y + 0.39, z + seat + 0.54),
    s.at(x + 0.07, y + 0.39, z + seat + 0.54),
    s.stroke(_vane, 0.045),
  );

  // The hat drops on and bounces to rest.
  if (s.t >= _dayOn + 0.04) {
    final lift = s.drop(_dayOn + 0.04, _dayOn + 0.15, from: 0.8);
    final brim = z + seat + 0.6 + lift;
    s.canvas.drawOval(
      s.disc(x, y + 0.28, brim, 0.24),
      s.fill(_straw.shade(-0.06)),
    );
    s
      ..cylinder(x, y + 0.28, brim, 0.12, 0.1, _straw)
      ..cylinder(x, y + 0.28, brim, 0.122, 0.035, _coral);
  }

  // The near arm comes up with the glass, a toast to the weather.
  final raise = s.phase(_toast, _toast + 0.07, Curves.easeInOutCubic);
  final shoulder = s.at(x + 0.14, y + 0.3, z + seat + 0.34);
  final rest = s.at(x + 0.22, y + 0.6, z + seat + 0.1);
  final up = head.translate(0.32 * u, 0.02 * u);
  final hand = Offset.lerp(rest, up, raise)!;
  s.canvas
    ..drawLine(shoulder, hand, s.stroke(_skin, 0.065))
    ..drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: hand.translate(0, -0.06 * u),
          width: 0.09 * u,
          height: 0.15 * u,
        ),
        Radius.circular(0.02 * u),
      ),
      s.fill(_lemonade),
    );
}

/// The striped parasol beside the chair: the pole drops in furled, and it
/// pops open as the day gets going.
void _parasol(IsoStage s, double x, double y) {
  if (s.t < 0.5) return;
  final lift = s.drop(0.5, 0.64, from: 3);
  const pole = 1.2;
  s.story(() {
    final open = s.pop(_dayOn - 0.01, _dayOn + 0.07);
    final apexZ = lift + pole + 0.1;
    s
      ..shadow(x - 0.15, y + 0.25, 0.08 + 0.42 * open, _grass)
      ..canvas.drawLine(
        s.at(x, y, lift),
        s.at(x, y, lift + pole + 0.08),
        s.stroke(_wood.shade(0.1), 0.035),
      );
    // Furled: the canopy wrapped round the top of the pole.
    final furled = 1 - open;
    if (furled > 0) {
      s.cone(x, y, apexZ - 0.62 * furled, 0.07, 0.62 * furled, _coral);
    }
    if (open <= 0) return;
    const n = 10;
    final r = 0.62 * open;
    final rimZ = apexZ - 0.26 * open;
    final apex = s.at(x, y, apexZ);
    double angle(double i) => i * 2 * math.pi / n + 0.2;
    Offset rim(double i, [double drop = 0]) => s.at(
      x + r * math.cos(angle(i)),
      y + r * math.sin(angle(i)),
      rimZ - drop,
    );
    for (var i = 0; i < n; i++) {
      final m = angle(i + 0.5);
      final tint = (i.isEven ? _coral : _cream).shade(
        0.04 - 0.1 * math.cos(m) - 0.02 * math.sin(m),
      );
      final a = rim(i.toDouble());
      final b = rim(i + 1.0);
      final sag = rim(i + 0.5, 0.1 * open);
      final control = sag * 2 - (a + b) / 2;
      s.canvas.drawPath(
        Path()
          ..moveTo(apex.dx, apex.dy)
          ..lineTo(a.dx, a.dy)
          ..quadraticBezierTo(control.dx, control.dy, b.dx, b.dy)
          ..close(),
        s.fill(tint),
      );
    }
    s.sphere(x, y, apexZ + 0.03, 0.04, _cream);
  });
}

// ----------------------------------------------------------------- flowers --

/// Flowers about the meadow, most of them round the garden in front of the
/// cottage, where the sun lands.
const List<({double x, double y, Tint tint})> _beds = [
  // Off to the side of the picnic basket, clear of the cat behind it.
  (x: 3.0, y: 4.1, tint: _petalGold),
  (x: 2.75, y: 3.35, tint: _petalPink),
  (x: 3.6, y: 3.5, tint: _petalLilac),
  (x: 3.95, y: 3.75, tint: _petalGold),
  (x: 3.85, y: 4.2, tint: _petalPink),
  (x: 5.6, y: 3.45, tint: _petalGold),
  (x: 5.85, y: 4.3, tint: _petalLilac),
  (x: 0.95, y: 5.75, tint: _petalLilac),
  (x: 1.2, y: 5.6, tint: _petalPink),
  (x: 5.8, y: 5.0, tint: _petalPink),
  (x: 4.05, y: 5.4, tint: _petalLilac),
  (x: 4.35, y: 5.6, tint: _petalGold),
  (x: 5.3, y: 5.45, tint: _petalLilac),
];

/// The flowers: their stems come up as buds while the meadow assembles, and
/// they burst open, one after another, as the sun breaks through.
void _flowers(IsoStage s) {
  final ordered = [..._beds]..sort((a, b) => (a.x + a.y).compareTo(b.x + b.y));
  final grown = [
    for (var i = 0; i < ordered.length; i++)
      s.pop(0.5 + i * 0.025, 0.68 + i * 0.025),
  ];
  s.story(() {
    for (var i = 0; i < ordered.length; i++) {
      final bed = ordered[i];
      _flower(
        s,
        bed.x,
        bed.y,
        bed.tint,
        grow: grown[i],
        open: s.pop(_sunOut - 0.01 + i * 0.005, _sunOut + 0.07 + i * 0.005),
      );
    }
  });
}

/// A flower at [x], [y], its stem [grow] of the way up: a green bud until
/// it is [open], then a head of [petals].
void _flower(
  IsoStage s,
  double x,
  double y,
  Tint petals, {
  required double grow,
  required double open,
}) {
  if (grow <= 0) return;
  final u = s.unit;
  final head = s.at(x, y, 0.28 * grow);
  s.canvas.drawLine(s.at(x, y), head, s.stroke(_stem, 0.035));
  if (open < 0.4) {
    s.canvas.drawOval(
      Rect.fromCenter(
        center: head.translate(0, -0.025 * u * grow),
        width: 0.07 * u * grow,
        height: 0.11 * u * grow,
      ),
      s.fill(_stem.shade(0.14)),
    );
  }
  if (open <= 0) return;
  s.canvas
    ..drawCircle(head, 0.1 * u * open, s.fill(petals))
    ..drawCircle(head, 0.04 * u * open, s.fill(petals.shade(0.3)));
}

// ------------------------------------------------------------------ picnic --

/// On the rug: the basket drops in, a jug and two plates pop out, and an
/// apple last.
void _picnic(IsoStage s) {
  for (final (i, (px, py)) in const [(2.98, 5.42), (3.3, 5.5)].indexed) {
    final grow = s.pop(0.72 + i * 0.04, 0.84 + i * 0.04);
    if (grow <= 0) continue;
    s.canvas
      ..drawOval(s.disc(px, py, 0.008, 0.12 * grow), s.fill(_cream.shade(-0.1)))
      ..drawOval(s.disc(px, py, 0.01, 0.08 * grow), s.fill(_cream));
  }

  final jug = s.pop(0.78, 0.9);
  if (jug > 0) {
    s.scaled(s.at(2.95, 5.1), jug, () {
      s
        ..cylinder(2.95, 5.1, 0, 0.07, 0.2, _lemonade)
        ..cylinder(2.95, 5.1, 0.2, 0.045, 0.04, _cream.shade(-0.06));
    });
  }

  s.dropping(0.64, 0.8, (lift) => _basket(s, 3.18, 5, lift), from: 2.5);

  final apple = s.pop(0.86, 0.96);
  if (apple > 0) {
    const ax = 3.15;
    const ay = 5.36;
    s.scaled(s.at(ax, ay), apple, () {
      s.sphere(ax, ay, 0.065, 0.065, _apple);
      s.canvas.drawLine(
        s.at(ax, ay, 0.12),
        s.at(ax + 0.02, ay - 0.02, 0.17),
        s.stroke(_bark, 0.02),
      );
    });
  }
}

/// A wicker basket with a lid and a handle, [lift] tiles above the rug.
void _basket(IsoStage s, double x, double y, double lift) {
  const w = 0.36;
  const d = 0.24;
  const h = 0.17;
  final z = lift;
  if (lift < 0.05) s.shadow(x + w / 2, y + d / 2, 0.2, _gingham.at(0.94));
  s
    ..box(x, y, z, w, d, h, _wicker)
    ..box(
      x - 0.02,
      y - 0.02,
      z + h,
      w + 0.04,
      d + 0.04,
      0.035,
      _wicker.shade(0.1),
    );
  // The weave, on the face towards us.
  for (final f in const [0.35, 0.68]) {
    s.canvas.drawLine(
      s.at(x, y + d, z + h * f),
      s.at(x + w, y + d, z + h * f),
      s.stroke(_wicker.shade(-0.12), 0.015),
    );
  }
  // The cat behind it: after the basket, and before the handle, which is in
  // front of it.
  _cat(s, (x: x - 0.02, y: y - 0.02, z: z + h + 0.035), w + 0.04, d + 0.04);
  final a = s.at(x + 0.06, y + d / 2, z + h + 0.035);
  final b = s.at(x + w - 0.06, y + d / 2, z + h + 0.035);
  final top = s.at(x + w / 2, y + d / 2, z + h + 0.44);
  s.canvas.drawPath(
    Path()
      ..moveTo(a.dx, a.dy)
      ..quadraticBezierTo(top.dx, top.dy, b.dx, b.dy),
    s.stroke(_wicker.shade(-0.14), 0.03),
  );
}

/// The set's black cat, hiding behind the picnic basket: crouched on the
/// grass behind it, only the tips of its ears show over the lid. It sits up
/// to look over the basket, and ducks back down. [lid] is the back corner of
/// the lid's top, which is [w] by [d].
void _cat(IsoStage s, V3 lid, double w, double d) {
  // Only once the basket has landed.
  if (s.t < 0.8) return;
  final back = s.at(lid.x, lid.y, lid.z);
  final up = back.translate(0, -s.unit);
  s.hidingCat(
    hidden: back.translate(0, 0.72 * s.unit),
    // Sitting up, it is on the grass just behind the basket - the ground
    // that the lid's back corner stands in front of on screen - and seen
    // whole over it.
    out: back,
    reveal: Path.combine(
      PathOperation.union,
      s.beyond(s.at(lid.x, lid.y + d, lid.z), back, of: up),
      s.beyond(back, s.at(lid.x + w, lid.y, lid.z), of: up),
    ),
  );
}

// --------------------------------------------------------------- sprinkler --

/// The rainbow's bands, outside in.
const _bands = [
  Tint(8, 0.7, 0.62),
  Tint(44, 0.85, 0.7),
  Tint(120, 0.5, 0.6),
  Tint(206, 0.65, 0.64),
];

/// A sprinkler watering the front flowers: it pops up and the jets arc out
/// while the meadow assembles, and when the sun breaks through, a small
/// rainbow opens in the spray.
void _sprinkler(IsoStage s, double x, double y) {
  final grow = s.pop(0.68, 0.8);
  if (grow <= 0) return;
  // The hose, back along the grass and over the edge.
  final hose = Path();
  final from = s.at(x, y);
  final bend = s.at(x + 0.35, y - 0.55);
  final end = s.at(6, y - 0.9);
  hose
    ..moveTo(from.dx, from.dy)
    ..quadraticBezierTo(bend.dx, bend.dy, end.dx, end.dy);
  s.canvas.drawPath(hose, s.stroke(_hose, 0.04 * grow));

  // The jets: arcs of droplets thrown out all round, each a little
  // parabola from the head to the grass.
  final spray = s.phase(0.78, 0.9);
  if (spray > 0) {
    final drop = s.fill(_water.shade(0.3));
    for (var i = 0; i < 6; i++) {
      final a = i * math.pi / 3 + 0.5;
      final reach = 0.6 * spray;
      for (final f in const [0.3, 0.52, 0.74, 0.94]) {
        s.canvas.drawCircle(
          s.at(
            x + reach * f * math.cos(a),
            y + reach * f * math.sin(a),
            0.14 + 1.6 * spray * f * (1 - f),
          ),
          (0.018 + 0.012 * f) * s.unit,
          drop,
        );
      }
    }
  }

  s.scaled(from, grow, () {
    s
      ..cylinder(x, y, 0, 0.08, 0.06, _hose.shade(-0.06))
      ..cylinder(x, y, 0.06, 0.025, 0.06, _vane.shade(0.3))
      ..sphere(x, y, 0.14, 0.035, _petalGold);
  });

  // The rainbow, opening from left to right across the spray as the sun
  // comes out on it.
  s.story(() {
    final arc = s.phase(_sunOut - 0.005, _sunOut + 0.07);
    if (arc <= 0) return;
    final c = s.at(x, y, 0.05);
    for (var i = 0; i < _bands.length; i++) {
      final r = (0.7 - i * 0.055) * s.unit;
      s.canvas.drawArc(
        Rect.fromCircle(center: c, radius: r),
        math.pi,
        math.pi * arc,
        false,
        s.stroke(_bands[i], 0.055)..strokeCap = StrokeCap.butt,
      );
    }
  });
}

// -------------------------------------------------------------- butterflies --

/// Two butterflies flutter in from off the island once the day is going,
/// and settle on flowers.
void _butterflies(IsoStage s) {
  for (final (i, b) in const [
    (from: (x: -1.6, y: 2.8, z: 2.4), to: (x: 1.2, y: 5.6), tint: _petalGold),
    (from: (x: 7.4, y: 1.4, z: 2.6), to: (x: 5.8, y: 5.0), tint: _wingBlue),
  ].indexed) {
    final p = s.phase(
      _dayOn + 0.03 + i * 0.03,
      _dayOn + 0.15 + i * 0.03,
      Curves.easeInOutSine,
    );
    if (p <= 0) continue;
    final rest = (x: b.to.x, y: b.to.y, z: 0.34);
    final x = b.from.x + (rest.x - b.from.x) * p;
    final y = b.from.y + (rest.y - b.from.y) * p;
    final z =
        b.from.z +
        (rest.z - b.from.z) * p +
        0.5 * math.sin(p * math.pi) +
        0.18 * math.sin(p * math.pi * 6) * (1 - p);
    // Wings beat in flight and fold half shut on landing.
    final flap = 0.55 + 0.45 * math.cos(p * math.pi * 14);
    final open = flap + (0.7 - flap) * p * p;
    _butterfly(s, s.at(x, y, z), open, b.tint);
  }
}

void _butterfly(IsoStage s, Offset c, double open, Tint tint) {
  final u = s.unit;
  for (final side in const [-1.0, 1.0]) {
    s.canvas
      ..drawOval(
        Rect.fromCenter(
          center: c.translate(side * 0.1 * u * open, -0.05 * u),
          width: 0.21 * u * open,
          height: 0.17 * u,
        ),
        s.fill(tint),
      )
      ..drawOval(
        Rect.fromCenter(
          center: c.translate(side * 0.07 * u * open, 0.03 * u),
          width: 0.14 * u * open,
          height: 0.11 * u,
        ),
        s.fill(tint.shade(-0.12)),
      );
  }
  s.canvas.drawLine(
    c.translate(0, -0.07 * u),
    c.translate(0, 0.06 * u),
    s.stroke(_vane, 0.025),
  );
}
