import 'dart:math' as math;

import 'package:flutter/animation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_full_stack_flutter/core/audio/sound.dart';
import 'package:flutter_full_stack_flutter/features/pronunciation/presentation/scenes/iso_stage.dart';
import 'package:flutter_full_stack_flutter/features/pronunciation/presentation/scenes/script.dart';

// The palette: a Korean temple at a spring dawn. A lavender sky going to
// peach, layered blue mountains with mist between them and Namsan's tower
// on one; on the island, a bell pavilion on a stone platform - red posts,
// green-painted beams, a dark tiled roof with its eaves swept up - a bronze
// bell gone green, a stone lantern, a pine, and a cherry tree in flower.
const _skyTop = Tint(256, 0.3, 0.72);
const _skyLow = Tint(18, 0.62, 0.92);
const _sunBody = Tint(24, 0.8, 0.98);
const _sunHalo = Tint(14, 0.62, 0.86);
const _mountainFar = Tint(250, 0.2, 0.76);
const _mountainMid = Tint(234, 0.24, 0.62);
const _mountainNear = Tint(170, 0.2, 0.62);
const _mist = Tint(250, 0.3, 0.97);
const _grass = Tint(104, 0.42, 0.52);
const _earth = Tint(22, 0.45, 0.36);
const _stone = Tint(30, 0.12, 0.24);
const _granite = Tint(36, 0.1, 0.74);
const _paving = Tint(34, 0.12, 0.64);
const _red = Tint(4, 0.6, 0.42);
const _beam = Tint(166, 0.44, 0.42);
const _tile = Tint(220, 0.14, 0.3);
const _bronze = Tint(158, 0.22, 0.46);
const _bronzeLight = Tint(150, 0.3, 0.66);
const _pit = Tint(30, 0.14, 0.3);
const _log = Tint(28, 0.42, 0.42);
const _rope = Tint(36, 0.3, 0.7);
const _blossom = Tint(342, 0.56, 0.82);
const _petal = Tint(338, 0.7, 0.72);
const _bark = Tint(18, 0.32, 0.26);
const _pine = Tint(148, 0.36, 0.32);
const _pineBark = Tint(12, 0.45, 0.36);
const _lamp = Tint(42, 0.8, 0.82);
const _ring = Tint(44, 0.7, 0.92);
const _tower = Tint(232, 0.16, 0.5);

/// The pavilion's posts stand at these corners, tall enough that the bell
/// hangs in view under the eaves, a little forward of the middle and to the
/// left, with the log beside it. A Korean bell hangs low, just over the
/// hollow in the floor that it rings into.
const _x0 = 1.35;
const _x1 = 3.85;
const _y0 = 1.15;
const _y1 = 2.95;
const _floor = 0.24;
const _postTop = 1.82;
const _bellX = 2.3;
const _bellY = 2.3;
const _bellTop = 1.12;
const _bellBottom = 0.42;
const _bellBottomR = 0.4;

/// The striking log hangs beside the bell, along x, its near end this far
/// from the bell's side at rest.
const double _logFrom = _bellX + _bellBottomR + 0.08;
const _logLength = 0.85;
const _logZ = 0.66;

/// A temple bell pavilion in Korea, in two acts.
///
/// The temple assembles first: the island rises at dawn in front of misty
/// mountains, the platform and the pavilion land with the bell hung in it,
/// the pine and the cherry tree grow and the stone lantern is set down.
/// Then the story, in the light: the log is drawn back on its ropes and
/// swung into the bell, the bell rings out in widening rings, the lantern
/// glows, and cherry petals come drifting down. At rest the log hangs still
/// and the petals lie on the grass.
const templeBellScene = SceneScript(
  paintTempleBell,
  cues: [],
  sounds: [SceneSound(Sound.templeBell, _strike)],
);

// The story's beats, on the arrival's clock.
const _drawBack = 0.4;
const _swing = 0.52;
const _strike = 0.55;
const _settled = 0.9;

/// Paints [templeBellScene].
void paintTempleBell(IsoStage s) {
  s.setting(() {
    // The backdrop is placed from the horizon behind the island, in tiles,
    // so it stands where it should behind it on any canvas.
    double down(double tiles) => (s.horizon + tiles * s.unit) / s.size.height;
    s
      ..sky(_skyTop, _skyLow)
      ..sun(
        (s.origin.dx - 3.3 * s.unit) / s.size.width,
        down(-4.2),
        0.8,
        _sunBody,
        _sunHalo,
        rings: 2,
      )
      ..ridge(down(-0.9), 2.6, _mountainFar, seed: 5)
      ..ridge(down(0.3), 1.8, _mountainMid, seed: 11);
    _namsanTower(s, down(0.3));
    _mistBand(s, down(0.1));
    s.ridge(down(1.4), 1, _mountainNear, seed: 1);

    s.rising(0, 0.42, () {
      s.island(grass: _grass, earth: _earth, stone: _stone);
      _paths(s);
      s.pine(
        5.15,
        0.85,
        needles: _pine,
        bark: _pineBark,
        ground: _grass,
        h: 1.9,
        grow: s.pop(0.42, 0.62),
      );
      final swing = s.story(() => _swingAt(s));
      s.dropping(0.18, 0.46, (lift) => _pavilion(s, lift, swing));
      s.dropping(0.48, 0.66, (lift) => _lantern(s, lift));
      s.tree(
        1.05,
        4.55,
        leaves: _blossom,
        bark: _bark,
        ground: _grass,
        h: 2.05,
        grow: s.pop(0.5, 0.72),
      );
      _petals(s);
      _rings(s);
      s.spotlight(
        s.at(_bellX, _bellY, 0.8),
        radius: 2.4,
        strength: s.storyLight * 0.6,
      );
    });
  });
}

/// How far the log hangs from where it rests, in tiles along x: drawn back,
/// swung through into the bell, rebounding, and settling.
double _swingAt(IsoStage s) {
  if (s.t < _drawBack) return 0;
  if (s.t < _swing) return 0.42 * s.phase(_drawBack, _swing, Curves.easeOut);
  if (s.t < _strike) {
    return 0.42 - 0.5 * s.phase(_swing, _strike, Curves.easeIn);
  }
  final rebound = s.phase(_strike, _strike + 0.07, Curves.easeOut);
  final settle = s.phase(_strike + 0.07, _settled, Curves.easeInOut);
  return (-0.08 + 0.3 * rebound) * (1 - settle);
}

/// A band of morning mist lying across the mountains at [fy]: thickest in
/// its middle, and nothing at its edges, so it is a haze rather than a
/// stripe.
void _mistBand(IsoStage s, double fy) {
  final y = s.size.height * fy;
  final band = Rect.fromLTRB(
    0,
    y - s.unit * 1.3,
    s.size.width,
    y + s.unit * 1.3,
  );
  final c = s.colour(_mist);
  s.canvas.drawRect(
    band,
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          c.withValues(alpha: 0),
          c.withValues(alpha: 0.42),
          c.withValues(alpha: 0),
        ],
      ).createShader(band),
  );
}

/// The tower on Namsan, small on the middle ridge - the one whose base is
/// at [baseline] - to the right: a mast on a slender shaft, with its round
/// observation deck.
void _namsanTower(IsoStage s, double baseline) {
  // To the right of the island, wherever the page puts it.
  final fx = (s.origin.dx + 4.6 * s.unit) / s.size.width;
  final base = Offset(
    s.size.width * fx,
    s.ridgeTop(fx, baseline, 1.8, seed: 11) + s.unit * 0.1,
  );
  final u = s.unit;
  final paint = s.fill(_tower);
  final deck = base.translate(0, -u * 1.7);
  s.canvas
    ..drawRect(
      Rect.fromLTRB(base.dx - u * 0.1, deck.dy, base.dx + u * 0.1, base.dy),
      paint,
    )
    ..drawOval(
      Rect.fromCenter(center: deck, width: u * 0.6, height: u * 0.34),
      paint,
    )
    ..drawOval(
      Rect.fromCenter(
        center: deck.translate(0, u * 0.3),
        width: u * 0.42,
        height: u * 0.2,
      ),
      paint,
    )
    ..drawLine(deck, deck.translate(0, -u * 0.9), s.stroke(_tower, 0.06));
}

/// A paved court under the pavilion, and stepping stones to it across the
/// grass from the front.
void _paths(IsoStage s) {
  s.patch(_x0 - 0.45, _y0 - 0.45, _x1 - _x0 + 0.9, _y1 - _y0 + 1.2, _paving);
  final stone = s.fill(_granite);
  for (final (x, y, at) in const [
    (2.55, 4.35, 0.3),
    (2.75, 4.95, 0.34),
    (2.5, 5.55, 0.38),
  ]) {
    final grow = s.pop(at, at + 0.14);
    if (grow > 0) s.canvas.drawOval(s.disc(x, y, 0.01, 0.2 * grow), stone);
  }
}

/// The bell pavilion, [lift] tiles above its place as it lands, its log
/// [swing] tiles from rest: the platform, the posts and the bell behind the
/// front ones, the log on its ropes, the painted beams, and the roof.
void _pavilion(IsoStage s, double lift, double swing) {
  final z = lift;
  s
    ..box(
      _x0 - 0.2,
      _y0 - 0.2,
      z,
      _x1 - _x0 + 0.4,
      _y1 - _y0 + 0.4,
      _floor,
      _granite,
    )
    ..box(_bellX - 0.35, _y1 + 0.2, z, 0.7, 0.32, _floor * 0.5, _granite);
  // The hollow under the bell that it rings into.
  s.canvas.drawOval(
    s.disc(_bellX, _bellY, z + _floor + 0.004, 0.3),
    s.fill(_pit),
  );
  final top = z + _postTop;
  _post(s, _x0, _y0, z);
  _post(s, _x1, _y0, z);
  _bell(s, z);
  _striker(s, z, swing);
  _post(s, _x0, _y1, z);
  _post(s, _x1, _y1, z);
  // The beams across the two sides in view, painted green with a red line.
  s
    ..onLeft(_y1 + 0.07, _x0 - 0.05, top - 0.14, _x1 - _x0 + 0.17, 0.16, _beam)
    ..onRight(
      _x1 + 0.07,
      _y0 - 0.05,
      top - 0.14,
      _y1 - _y0 + 0.17,
      0.16,
      _beam.shade(-0.12),
    )
    ..onLeft(_y1 + 0.072, _x0 - 0.05, top - 0.14, _x1 - _x0 + 0.17, 0.03, _red)
    ..onRight(
      _x1 + 0.072,
      _y0 - 0.05,
      top - 0.14,
      _y1 - _y0 + 0.17,
      0.03,
      _red,
    );
  _roof(s, top);
}

/// One red post at [x], [y], on the platform.
void _post(IsoStage s, double x, double y, double z) =>
    s.box(x - 0.07, y - 0.07, z + _floor, 0.14, 0.14, _postTop - _floor, _red);

/// The bell: a bronze gone green, narrow at the shoulder and widening to its
/// lip, with raised bands at top and bottom and the lotus it is struck on;
/// hung from the beam by its loop.
void _bell(IsoStage s, double z) {
  final top = s.at(_bellX, _bellY, z + _bellTop);
  final bottom = s.at(_bellX, _bellY, z + _bellBottom);
  final u = s.unit;
  const topR = 0.24;
  final hook = s.at(_bellX, _bellY, z + _postTop - 0.05);
  s.canvas.drawLine(hook, top, s.stroke(_bronze.shade(-0.1), 0.06));
  final body = Path()
    ..moveTo(top.dx - topR * u, top.dy)
    ..quadraticBezierTo(
      top.dx - topR * u * 1.1,
      (top.dy + bottom.dy) / 2,
      bottom.dx - _bellBottomR * u,
      bottom.dy,
    )
    ..quadraticBezierTo(
      bottom.dx,
      bottom.dy + u * 0.12,
      bottom.dx + _bellBottomR * u,
      bottom.dy,
    )
    ..quadraticBezierTo(
      top.dx + topR * u * 1.1,
      (top.dy + bottom.dy) / 2,
      top.dx + topR * u,
      top.dy,
    )
    ..quadraticBezierTo(top.dx, top.dy - u * 0.16, top.dx - topR * u, top.dy)
    ..close();
  s.canvas.drawPath(
    body,
    Paint()
      ..shader = LinearGradient(
        colors: [
          s.colour(_bronzeLight),
          s.colour(_bronze),
          s.colour(_bronze.shade(-0.16)),
        ],
        stops: const [0, 0.45, 1],
      ).createShader(body.getBounds()),
  );
  final band = s.stroke(_bronzeLight, 0.035);
  s.canvas
    ..drawLine(
      Offset(top.dx - topR * u * 1.04, top.dy + u * 0.1),
      Offset(top.dx + topR * u * 1.04, top.dy + u * 0.1),
      band,
    )
    ..drawLine(
      Offset(bottom.dx - _bellBottomR * u * 0.92, bottom.dy - u * 0.1),
      Offset(bottom.dx + _bellBottomR * u * 0.92, bottom.dy - u * 0.1),
      band,
    )
    ..drawCircle(
      Offset(bottom.dx + u * 0.1, bottom.dy - u * 0.28),
      u * 0.06,
      s.fill(_bronzeLight),
    );
}

/// The log the bell is struck with, [swing] tiles back from rest, hung on
/// two ropes from the beam. It rises a little as it swings back, as a
/// pendulum does.
void _striker(IsoStage s, double z, double swing) {
  final rise = 0.35 * swing.abs();
  final from = s.at(_logFrom + swing, _bellY, z + _logZ + rise);
  final to = s.at(_logFrom + swing + _logLength, _bellY, z + _logZ + rise);
  final rope = s.stroke(_rope, 0.025);
  for (final f in const [0.25, 0.75]) {
    final along = _logFrom + _logLength * f;
    s.canvas.drawLine(
      s.at(along, _bellY, z + _postTop - 0.06),
      s.at(along + swing, _bellY, z + _logZ + rise),
      rope,
    );
  }
  s.canvas
    ..drawLine(from, to, s.stroke(_log, 0.16))
    ..drawCircle(from, s.unit * 0.08, s.fill(_log.shade(0.16)));
}

/// The roof: tiled slopes on all four sides up to a short ridge, its eaves
/// curving down between corners swept up - the line a Korean roof is known
/// by - with the ridge's ends turned up too.
void _roof(IsoStage s, double eaves) {
  const over = 0.28;
  const ax = _x0 - over;
  const bx = _x1 + over;
  const ay = _y0 - over;
  const by = _y1 + over;
  const sweep = 0.2;
  final ridge = eaves + 0.62;
  const r0 = _x0 + 0.55;
  const r1 = _x1 - 0.55;
  const ym = (_y0 + _y1) / 2;

  Offset corner(double x, double y) => s.at(x, y, eaves + sweep);
  Offset middle(double x, double y) => s.at(x, y, eaves - 0.04);
  // An eave from [a] to [b] that dips through [m] between them.
  Path slope(Offset a, Offset m, Offset b, List<Offset> up) {
    final control = m * 2 - (a + b) / 2;
    final path = Path()
      ..moveTo(a.dx, a.dy)
      ..quadraticBezierTo(control.dx, control.dy, b.dx, b.dy);
    for (final p in up) {
      path.lineTo(p.dx, p.dy);
    }
    return path..close();
  }

  final ridge0 = s.at(r0, ym, ridge);
  final ridge1 = s.at(r1, ym, ridge);
  // Back to front: the far slope and the far hip, then the near hip and the
  // near slope, each lit as the kit lights things, from the upper left.
  s.canvas
    ..drawPath(
      slope(corner(ax, ay), middle((ax + bx) / 2, ay), corner(bx, ay), [
        ridge1,
        ridge0,
      ]),
      s.fill(_tile.shade(0.12)),
    )
    ..drawPath(
      slope(corner(ax, by), middle(ax, ym), corner(ax, ay), [ridge0]),
      s.fill(_tile.shade(0.08)),
    )
    ..drawPath(
      slope(corner(bx, ay), middle(bx, ym), corner(bx, by), [ridge1]),
      s.fill(_tile.shade(-0.12)),
    );
  final near = slope(
    corner(ax, by),
    middle((ax + bx) / 2, by),
    corner(bx, by),
    [ridge1, ridge0],
  );
  s.canvas.drawPath(near, s.fill(_tile));
  // Rows of tiles running down the near slope.
  final rows = s.stroke(_tile.shade(-0.08), 0.02);
  for (var i = 1; i < 8; i++) {
    final f = i / 8;
    final x = ax + (bx - ax) * f;
    final top = s.at(r0 + (r1 - r0) * f, ym, ridge);
    final dip = 1 - math.pow(2 * f - 1, 2).toDouble();
    s.canvas.drawLine(
      top,
      s.at(x, by, eaves + sweep - (sweep + 0.04) * dip),
      rows,
    );
  }
  // The ridge, its ends turned up.
  final crest = s.stroke(_tile.shade(-0.16), 0.09);
  s.canvas
    ..drawLine(ridge0, ridge1, crest)
    ..drawLine(ridge0, s.at(r0 - 0.12, ym, ridge + 0.16), crest)
    ..drawLine(ridge1, s.at(r1 + 0.12, ym, ridge + 0.16), crest);
}

/// A stone lantern at the front right: a base, a post, the light box with
/// its window - glowing warm from the strike on - and a little roof.
void _lantern(IsoStage s, double lift) {
  const x = 4.75;
  const y = 4.3;
  final z = lift;
  final lit = s.story(() => s.phase(_strike, _strike + 0.08));
  s
    ..shadow(x + 0.16, y + 0.16, 0.3, _grass)
    ..box(x, y, z, 0.32, 0.32, 0.12, _granite)
    ..box(x + 0.09, y + 0.09, z + 0.12, 0.14, 0.14, 0.34, _granite)
    ..box(x - 0.02, y - 0.02, z + 0.46, 0.36, 0.36, 0.24, _granite);
  final window = s.at(x + 0.16, y + 0.34, z + 0.58);
  s
    ..glow(window, 0.55, strength: lit, light: _lamp)
    ..onLeft(y + 0.343, x + 0.08, z + 0.5, 0.18, 0.15, lit > 0 ? _lamp : _pit)
    ..roof(x - 0.02, y - 0.02, z + 0.7, 0.36, 0.36, 0.2, _tile, overhang: 0.08);
}

/// The rings the bell's note spreads in after the strike, widening and
/// fading, and a flash on the bell as it is struck.
void _rings(IsoStage s) {
  final flash = s.story(
    () =>
        s.phase(_strike - 0.004, _strike + 0.01) *
        (1 - s.phase(_strike + 0.03, _strike + 0.14, Curves.easeInOut)),
  );
  final centre = s.at(_bellX, _bellY, (_bellTop + _bellBottom) / 2);
  s.glow(centre, 1, strength: flash, light: _ring);
  for (var k = 0; k < 3; k++) {
    final from = _strike + k * 0.05;
    final spread = s.story(() => s.phase(from, from + 0.24, Curves.easeOut));
    if (spread <= 0 || spread >= 1) continue;
    final paint = s.stroke(_ring, 0.05)
      ..color = s.colour(_ring).withValues(alpha: 0.8 * (1 - spread));
    s.canvas.drawOval(
      Rect.fromCenter(
        center: centre,
        width: s.unit * (0.9 + 3.4 * spread),
        height: s.unit * (0.6 + 2 * spread),
      ),
      paint,
    );
  }
}

/// Cherry petals shaken loose by the bell: each leaves the tree at its own
/// moment, drifts to the right and down, rocking as it falls, and lies on
/// the grass once it lands.
void _petals(IsoStage s) {
  final random = math.Random(7);
  for (var i = 0; i < 10; i++) {
    final start = _strike - 0.04 + random.nextDouble() * 0.2;
    final length = 0.18 + random.nextDouble() * 0.12;
    final fall = s.story(() => s.phase(start, start + length, Curves.easeIn));
    final sx = 0.7 + random.nextDouble() * 0.8;
    final sy = 4.2 + random.nextDouble() * 0.7;
    final drift = 0.6 + random.nextDouble() * 1.1;
    final sway = random.nextDouble() * math.pi * 2;
    if (fall <= 0) continue;
    final x = sx + drift * fall;
    final y = sy + 0.25 * drift * fall;
    final z = 1.35 * (1 - fall) + 0.004;
    final rock = math.sin(fall * math.pi * 4 + sway);
    final c = s.at(x + 0.08 * rock * (1 - fall), y, z);
    s.canvas
      ..save()
      ..translate(c.dx, c.dy)
      ..rotate(fall < 1 ? rock * 0.8 : 0)
      ..drawOval(
        Rect.fromCenter(
          center: Offset.zero,
          width: s.unit * 0.13,
          height: s.unit * (fall < 1 ? 0.08 : 0.06),
        ),
        s.fill(_petal),
      )
      ..restore();
  }
}
