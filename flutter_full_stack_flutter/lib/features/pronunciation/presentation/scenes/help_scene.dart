import 'dart:math' as math;

import 'package:flutter/animation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_full_stack_flutter/core/audio/sound.dart';
import 'package:flutter_full_stack_flutter/features/pronunciation/presentation/scenes/iso_stage.dart';
import 'package:flutter_full_stack_flutter/features/pronunciation/presentation/scenes/script.dart';

// The palette: a rose-and-blue late afternoon over a building site where
// the job is a giant jigsaw.
const _skyTop = Tint(214, 0.6, 0.56);
const _skyLow = Tint(335, 0.55, 0.92);
const _sunBody = Tint(40, 0.95, 0.74);
const _sunHalo = Tint(42, 0.9, 0.9);
const _cloud = Tint(220, 0.45, 1);
const _farHill = Tint(300, 0.26, 0.78);
const _nearHill = Tint(250, 0.45, 0.6);
const _meadowHill = Tint(158, 0.38, 0.56);
const _grass = Tint(100, 0.4, 0.42);
const _earth = Tint(22, 0.55, 0.3);
const _stone = Tint(26, 0.16, 0.16);
const _seam = Tint(225, 0.35, 0.2);
const _pieceBlue = Tint(210, 0.64, 0.5);
const _pieceLilac = Tint(268, 0.52, 0.56);
const _pieceAqua = Tint(176, 0.6, 0.46);
const _pieceCream = Tint(42, 0.64, 0.78);
const _keyPiece = Tint(10, 0.85, 0.4);
const _spark = Tint(44, 1, 0.74);
const _crane = Tint(44, 0.72, 0.64);
const _brace = Tint(34, 0.5, 0.34);
const _concrete = Tint(30, 0.08, 0.6);
const _gravel = Tint(36, 0.4, 0.6);
const _glass = Tint(196, 0.6, 0.5);
const _cable = Tint(220, 0.2, 0.15);
const _leaves = Tint(128, 0.5, 0.32);
const _leavesLight = Tint(92, 0.45, 0.46);
const _bark = Tint(22, 0.45, 0.18);
const _stem = Tint(110, 0.5, 0.28);
// Forget-me-nots, not pink: coral is kept for the piece, the pennant and
// the heart, so it always means the help.
const _petalBlue = Tint(205, 0.6, 0.58);
const _petalGold = Tint(44, 0.95, 0.68);
const _petalLilac = Tint(272, 0.6, 0.58);
const _skin = Tint(26, 0.55, 0.74);
const _hair = Tint(24, 0.45, 0.2);
const _shirt = Tint(204, 0.55, 0.4);
const _overalls = Tint(168, 0.45, 0.4);
const _metal = Tint(212, 0.45, 0.42);
const _bubble = Tint(220, 0.3, 1);
const _ink = Tint(225, 0.4, 0.22);

// The jigsaw: four by four pieces, each [_p] tiles square, its back corner
// at [_px], [_py], [_th] tiles thick. The piece at [_slotI], [_slotJ] is
// the one the crane brings.
const _n = 4;
const _p = 0.9;
const _px = 1.5;
const _py = 1.35;
const _th = 0.2;
const _slotI = 2;
const _slotJ = 2;
// How far the key piece sits proud of the board once it is in, so its
// darker side shows as a band and it reads as the piece that arrived.
const _proud = 0.06;
const double _slotX = _px + (_slotI + 0.5) * _p;
const double _slotY = _py + (_slotJ + 0.5) * _p;

// Which way each tab points: across the seam to the right of column `i` in
// row `j` (`1` is a tab into the next column, `-1` a blank), and across the
// seam below row `j` in column `i`. The key piece gets tabs on its two front
// edges, so it reads as a jigsaw piece while it hangs.
const List<List<int>> _across = [
  [1, -1, 1],
  [-1, 1, -1],
  [-1, 1, 1],
  [1, -1, 1],
];
const List<List<int>> _down = [
  [-1, 1, -1, 1],
  [1, -1, 1, -1],
  [-1, 1, 1, -1],
];

const List<Tint> _quilt = [_pieceBlue, _pieceAqua, _pieceLilac, _pieceCream];

// The tower crane on the right corner, and where its jib ends up pointing.
const _mastX = 5.6;
const _mastY = 0.72;
const _mastH = 2.0;
const _jib = 3.9;
const _tail = 0.95;
final double _reach = math.sqrt(
  (_slotX - _mastX) * (_slotX - _mastX) + (_slotY - _mastY) * (_slotY - _mastY),
);
final double _aim = math.atan2(_slotY - _mastY, _slotX - _mastX);

// Who asks, and who helps. The one asking stands at the front edge of the
// board, near enough to the gap to point at it.
const _askerX = 3.1;
const _askerY = 5.45;
const _helperX = 5.6;
const _helperY = 2.65;

// Where the crane's jib points while it waits: back over the far edge of
// the island, so the piece it holds swings in towards us, into the light.
const double _idle = math.pi + 0.12;

/// "Can you help me with this problem", in two acts.
///
/// The building site assembles first: the island rises with the giant
/// jigsaw on it, one piece missing, the trees spring up round it and the
/// tower crane lands in its corner, the missing piece hanging from its hook
/// over the back of the island. Then the story, in a pool of light at the
/// gap while the rest of the meadow sinks back: the one asking points at
/// the empty slot, which pulses, and a question pops up over their head
/// (*this problem*); the crane hand raises an arm and the crane swings the
/// piece round over the board (*help*), lets it settle and lowers it; it
/// clicks into place with a burst, the one asking cheers and jumps, and the
/// question becomes a heart (*me*).
const helpScene = SceneScript(
  paintHelp,
  cues: [
    Cue('this problem', _problem),
    Cue('help', _help),
    Cue('me', _solved),
  ],
  sounds: [
    SceneSound(Sound.click, _solved),
    SceneSound(Sound.sparkle, _solved),
  ],
  catWalks: true,
);

// The story's beats, on the arrival's clock: the problem shown, the help
// coming, and the piece in. The crane swings at its fastest just after the
// word lights, then lowers the piece so that it clicks in on *me*.
const _problem = 0.42;
const _help = 0.56;
const _solved = 0.74;
const double _slewFrom = _help - 0.02;
const double _slewTo = _help + 0.1;

/// Paints [helpScene].
void paintHelp(IsoStage s) {
  s.setting(() {
    s.sky(_skyTop, _skyLow);

    final climb = s.phase(0.1, 0.8);
    s
      ..sun(0.8, 0.17 - 0.05 * climb, 0.7, _sunBody, _sunHalo)
      // The dusk steps down from rose through mauve and periwinkle to the
      // sage meadows under the island.
      ..ridge(0.76, 1.4, _farHill, seed: 3)
      ..ridge(0.85, 1, _nearHill, seed: 7)
      ..ridge(0.93, 0.7, _meadowHill, seed: 11);

    final drift = s.phase(0.2, 1);
    s
      ..cloud(s.screen(0.2 - 0.5 * (1 - drift), 0.22), 2.4, _cloud)
      ..cloud(s.screen(0.74 + 0.5 * (1 - drift), 0.36), 1.8, _cloud)
      ..cloud(s.screen(0.1 - 0.4 * (1 - drift), 0.5), 1.4, _cloud);

    s.rising(0, 0.42, () {
      s
        ..island(grass: _grass, earth: _earth, stone: _stone)
        // The crane's yard, a patch of gravel in the right corner.
        ..patch(5.02, 0.2, 0.9, 1.08, _gravel);
      // The one asking stands in the light too, on the grass in front of
      // the board - under it, so the board's edge covers the pool's back.
      _islandPool(s, _askerX + 0.1, _askerY - 0.1, 0.8);
      _jigsaw(s);
      // The stage: the gap. Lit once the story starts, and it stays lit.
      s.story(() => _gapLight(s));

      // The back row, behind the crane. Only low things at the back corner,
      // which on a phone sits behind the record button; the pine frames the
      // puzzle from the left corner, opposite the crane.
      s
        ..bush(0.8, 1.2, _leaves, size: 1.1, grow: s.pop(0.42, 0.62))
        ..bush(2.3, 0.6, _leavesLight, grow: s.pop(0.48, 0.66))
        ..tree(
          0.75,
          3,
          leaves: _leavesLight,
          bark: _bark,
          ground: _grass,
          h: 1.6,
          grow: s.pop(0.46, 0.66),
        )
        ..tree(
          3.6,
          0.5,
          leaves: _leaves,
          bark: _bark,
          ground: _grass,
          grow: s.pop(0.5, 0.7),
        )
        ..pine(
          0.4,
          4.9,
          needles: _leaves,
          bark: _bark,
          ground: _grass,
          grow: s.pop(0.52, 0.72),
        );

      // The crane lands with the piece already on its hook, the jib turned
      // away; what it does with it is the story's.
      late double turn;
      late double sway;
      late double lift;
      late double release;
      s.story(() {
        final slew = s.phase(_slewFrom, _slewTo, Curves.easeInOutCubic);
        turn = _idle + (_aim - _idle) * slew;
        // The load swings on a little as the jib stops, and has settled
        // before it goes down.
        final settle = s.phase(_slewTo - 0.01, _slewTo + 0.07, Curves.linear);
        sway = settle >= 1
            ? 0
            : 0.26 * math.sin(math.pi * settle) * (1 - settle);
        // Lowered steadily, then the last of it drops in: the click.
        lift = 0.8 * (1 - s.phase(_slewTo, _solved, Curves.easeInCubic));
        release = s.phase(_solved + 0.06, _solved + 0.16);
      });
      s.dropping(
        0.36,
        0.7,
        (drop) => _craneAndLoad(s, drop, turn, sway, lift, release),
      );
      _cat(s);

      s.story(() {
        _burst(s, s.phase(_solved - 0.005, _solved + 0.14, Curves.linear));
        _twinkles(s, s.pop(_solved + 0.03, _solved + 0.13));
      });

      _toolbox(s, 1.5, 5.15, s.pop(0.58, 0.72));

      _asker(s, s.pop(0.46, 0.58));
      // The crane hand: when asked, an arm goes up - lift it - and the
      // crane swings.
      final grow = s.pop(0.5, 0.62);
      s.story(() {
        final wave = s.phase(_help - 0.02, _help + 0.03, Curves.easeOutBack);
        _person(
          s,
          _helperX,
          _helperY,
          grow: grow,
          body: _overalls,
          hat: _crane,
          left: 0.4,
          right: 0.45 + 2.35 * wave,
        );
      });

      s
        ..bush(5.45, 5.5, _leavesLight, size: 0.9, grow: s.pop(0.6, 0.78))
        ..bush(1.1, 5.55, _leavesLight, size: 0.7, grow: s.pop(0.62, 0.8));

      const beds = [
        (x: 5.55, y: 3.55, tint: _petalGold),
        (x: 5.8, y: 4.15, tint: _petalBlue),
        (x: 5.5, y: 4.7, tint: _petalLilac),
        (x: 4.4, y: 5.55, tint: _petalBlue),
        (x: 4.95, y: 5.75, tint: _petalGold),
        (x: 1.6, y: 5.75, tint: _petalLilac),
        (x: 0.6, y: 5.3, tint: _petalGold),
        (x: 5.75, y: 2.0, tint: _petalLilac),
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
          grow: s.pop(0.6 + i * 0.025, 0.78 + i * 0.025),
        );
      }

      // The rest of the meadow steps back while the gap, the one asking and
      // the piece coming have the stage.
      s.spotlight(
        s.at(_slotX - 0.3, _slotY + 0.8, 0.7),
        radius: 2.3,
        strength: s.storyLight,
      );
    });
  });
}

/// A pool of the key light on the grass at [x], [y], [r] tiles across,
/// kept to the island's top so none of it spills down the soil.
void _islandPool(IsoStage s, double x, double y, double r) {
  s.canvas
    ..save()
    ..clipPath(
      s.face([
        (x: 0, y: 0, z: 0),
        (x: IsoStage.span, y: 0, z: 0),
        (x: IsoStage.span, y: IsoStage.span, z: 0),
        (x: 0, y: IsoStage.span, z: 0),
      ]),
    );
  s
    ..pool(x, y, r, strength: s.storyLight)
    ..canvas.restore();
}

/// The light on the gap: a pool on the board round it, and, as it becomes
/// *this problem*, the empty slot lighting up from inside, its rim pulsing
/// twice. The piece covers it all once it is in.
void _gapLight(IsoStage s) {
  // The board's top is [_th] above the ground, so its pool is the ground's
  // raised by as much.
  s.canvas
    ..save()
    ..translate(0, -_th * s.unit);
  s
    ..pool(_slotX, _slotY, 1.35, strength: s.storyLight)
    ..canvas.restore();

  final lit = s.phase(_problem - 0.015, _problem + 0.03);
  if (lit <= 0 || s.t >= _solved) return;
  final beat = s.phase(_problem - 0.015, _problem + 0.15, Curves.linear);
  final pulse = (1 - math.cos(beat * 4 * math.pi)) / 2;
  final gap = _outline(_slotI, _slotJ, (x, y) => s.at(x, y, _th));
  s.canvas
    ..save()
    ..clipPath(gap);
  s
    ..glow(
      s.at(_slotX, _slotY),
      0.8,
      strength: lit * (0.65 + 0.35 * pulse),
    )
    ..canvas.restore()
    ..canvas.drawPath(gap, s.stroke(_spark, lit * (0.03 + 0.05 * pulse)));
}

// ------------------------------------------------------------------ jigsaw --

/// The tab sign on each edge of piece [i], [j]: top (towards -y), right
/// (+x), bottom (+y), left (-x). `0` is a straight border edge.
({int top, int right, int bottom, int left}) _tabs(int i, int j) => (
  top: j > 0 ? -_down[j - 1][i] : 0,
  right: i < _n - 1 ? _across[j][i] : 0,
  bottom: j < _n - 1 ? _down[j][i] : 0,
  left: i > 0 ? -_across[j][i - 1] : 0,
);

/// The outline of piece [i], [j] through [to], which maps a world point on
/// the piece's own plane to the screen: so the same outline serves the piece
/// in place and the piece swinging on the crane.
Path _outline(int i, int j, Offset Function(double x, double y) to) {
  final x0 = _px + i * _p;
  final y0 = _py + j * _p;
  final x1 = x0 + _p;
  final y1 = y0 + _p;
  final tabs = _tabs(i, j);
  final start = to(x0, y0);
  final path = Path()..moveTo(start.dx, start.dy);
  _edge(path, to, x0, y0, x1, y0, 0, -1, tabs.top);
  _edge(path, to, x1, y0, x1, y1, 1, 0, tabs.right);
  _edge(path, to, x1, y1, x0, y1, 0, 1, tabs.bottom);
  _edge(path, to, x0, y1, x0, y0, -1, 0, tabs.left);
  return path..close();
}

/// One edge from ([ax], [ay]) to ([bx], [by]), with a round tab bulging
/// along the outward normal ([nx], [ny]) if [tab] is `1`, a blank cut in if
/// `-1`. The projection is affine, so the curve's control points can be
/// projected as they are.
void _edge(
  Path path,
  Offset Function(double x, double y) to,
  double ax,
  double ay,
  double bx,
  double by,
  double nx,
  double ny,
  int tab,
) {
  Offset p(double a, double b) => to(
    ax + (bx - ax) * a + nx * _p * b * tab,
    ay + (by - ay) * a + ny * _p * b * tab,
  );
  void curve(Offset c1, Offset c2, Offset end) =>
      path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, end.dx, end.dy);
  if (tab != 0) {
    final neck = p(0.35, 0);
    path.lineTo(neck.dx, neck.dy);
    curve(p(0.41, 0), p(0.43, 0.06), p(0.39, 0.1));
    curve(p(0.33, 0.17), p(0.38, 0.28), p(0.5, 0.28));
    curve(p(0.62, 0.28), p(0.67, 0.17), p(0.61, 0.1));
    curve(p(0.57, 0.06), p(0.59, 0), p(0.65, 0));
  }
  final end = p(1, 0);
  path.lineTo(end.dx, end.dy);
}

/// The jigsaw lying on the grass, with the key piece's gap in it.
void _jigsaw(IsoStage s) {
  const w = _n * _p;
  s.patch(_px + 0.05, _py + 0.05, w + 0.1, w + 0.1, _grass.shade(-0.1));

  // The two edges facing us, each piece's own colour running down its side.
  for (var k = 0; k < _n; k++) {
    final front = _quilt[(k + 2 * (_n - 1)) % 4];
    final side = _quilt[(_n - 1 + 2 * k) % 4];
    s
      ..onLeft(_py + w, _px + k * _p, 0, _p, _th, front.shade(-0.16))
      ..onRight(_px + w, _py + k * _p, 0, _p, _th, side.shade(-0.3));
  }

  Offset flat(double x, double y) => s.at(x, y, _th);
  final paths = <Path>[];
  for (var j = 0; j < _n; j++) {
    for (var i = 0; i < _n; i++) {
      if (i == _slotI && j == _slotJ) continue;
      final path = _outline(i, j, flat);
      paths.add(path);
      s.canvas.drawPath(path, s.fill(_quilt[(i + 2 * j) % 4]));
    }
  }
  final seam = s.stroke(_seam, 0.024);
  for (final path in paths) {
    s.canvas.drawPath(path, seam);
  }

  // The gap: its far walls, then the grass at the bottom of it.
  final gap = _outline(_slotI, _slotJ, flat);
  s.canvas
    ..drawPath(gap, s.fill(_seam.shade(0.1)))
    ..save()
    ..clipPath(gap)
    ..drawPath(
      _outline(_slotI, _slotJ, s.at),
      s.fill(_grass.shade(-0.18)),
    )
    ..restore();
}

/// The key piece, its top [lift] tiles above where it belongs, turned by
/// [turn] and moved by ([dx], [dy]) from its place.
void _keyPieceAt(IsoStage s, double lift, double turn, double dx, double dy) {
  final c = math.cos(turn);
  final n = math.sin(turn);
  Offset Function(double x, double y) on(double z) => (x, y) {
    final ux = x - _slotX;
    final uy = y - _slotY;
    return s.at(
      _slotX + dx + ux * c - uy * n,
      _slotY + dy + ux * n + uy * c,
      z,
    );
  };

  final top = _th + lift;
  if (lift > 0.004) {
    // Its edge, as thick as the piece but no deeper than the board top.
    final under = math.max(top - _th, _th);
    final side = s.fill(_keyPiece.shade(-0.2));
    s.canvas
      ..drawPath(_outline(_slotI, _slotJ, on(under)), side)
      ..drawPath(_outline(_slotI, _slotJ, on((under + top) / 2)), side);
  }
  final face = _outline(_slotI, _slotJ, on(top));
  // A light rim like a box's crisp edge: lighter reads as a highlight on
  // both themes, where a dark seam would sink it into its neighbours.
  s.canvas
    ..drawPath(face, s.fill(_keyPiece))
    ..drawPath(face, s.stroke(_keyPiece.shade(0.28), 0.03));
}

/// The click: a ring running out across the board from the key piece and
/// gold rays shooting out with it, at [p] of their way. Both thin out to
/// nothing, so nothing of it is left at rest.
void _burst(IsoStage s, double p) {
  if (p <= 0 || p >= 1) return;
  s.canvas.drawOval(
    s.disc(_slotX, _slotY, _th, 0.55 + 1.5 * p),
    s.stroke(_spark.shade(-0.12), 0.09 * (1 - p)),
  );
  final head = 0.6 + 1.5 * Curves.easeOutCubic.transform(p);
  final tail = 0.6 + 1.5 * Curves.easeInCubic.transform(p);
  final paint = s.stroke(_spark, 0.1 * (1 - p) + 0.01);
  for (var k = 0; k < 10; k++) {
    final a = k * math.pi / 5 + 0.3;
    final ca = math.cos(a);
    final sa = math.sin(a);
    s.canvas.drawLine(
      s.at(_slotX + ca * tail, _slotY + sa * tail, _th + 0.3 * p),
      s.at(_slotX + ca * head, _slotY + sa * head, _th + 0.3 * p),
      paint,
    );
  }
}

/// Three small stars that stay over the key piece once it is in, [grow] of
/// the way popped out.
void _twinkles(IsoStage s, double grow) {
  if (grow <= 0) return;
  const stars = [
    (x: _slotX - 0.6, y: _slotY + 0.1, z: 0.8, r: 0.19),
    (x: _slotX + 0.5, y: _slotY - 0.55, z: 0.6, r: 0.14),
    (x: _slotX + 0.62, y: _slotY + 0.4, z: 0.42, r: 0.11),
  ];
  final paint = s.fill(_spark);
  for (final star in stars) {
    final c = s.at(star.x, star.y, star.z);
    final r = star.r * s.unit * grow;
    final w = r * 0.28;
    s.canvas.drawPath(
      Path()
        ..moveTo(c.dx, c.dy - r)
        ..quadraticBezierTo(c.dx + w, c.dy - w, c.dx + r, c.dy)
        ..quadraticBezierTo(c.dx + w, c.dy + w, c.dx, c.dy + r)
        ..quadraticBezierTo(c.dx - w, c.dy + w, c.dx - r, c.dy)
        ..quadraticBezierTo(c.dx - w, c.dy - w, c.dx, c.dy - r)
        ..close(),
      paint,
    );
  }
}

// ------------------------------------------------------------------- crane --

/// The black cat, behind the crane - the scene's easter egg (see
/// `HidingCat`). It sits on the crane's footing in the lee of the mast, the
/// tip of its tail showing past the mast's edge, and when it has a reason
/// it pads out along the footing to its corner, and back.
void _cat(IsoStage s) {
  // Only once the crane has landed.
  if (s.t < 0.7) return;
  // The mast is 0.34 tiles square and stands on a footing 0.16 tall (see
  // [_craneAndLoad]); its left edge, from the footing up.
  const top = 0.16;
  final edge = s.at(_mastX - 0.17, _mastY + 0.17, top);
  // Along the footing's left strip, beside the mast: from behind it, down
  // towards us to the footing's corner.
  const x = _mastX - 0.3;
  s.hidingCat(
    hidden: s.at(x, _mastY - 0.22, top),
    out: s.at(x, _mastY + 0.3, top),
    reveal: s.beyond(edge, edge.translate(0, -1), of: edge.translate(-1, 0)),
    flip: true,
  );
}

/// A box turned [turn] radians about the vertical through ([cx], [cy]),
/// [len] long along its turn and [wid] across, from [z] up [h]: the faces
/// that look our way, shaded by how much they face the light.
void _turnedBox(
  IsoStage s,
  double cx,
  double cy,
  double z,
  double len,
  double wid,
  double h,
  double turn,
  Tint tint,
) {
  final ux = math.cos(turn);
  final uy = math.sin(turn);
  V3 corner(double a, double b, double zz) => (
    x: cx + ux * a * len / 2 - uy * b * wid / 2,
    y: cy + uy * a * len / 2 + ux * b * wid / 2,
    z: zz,
  );
  const signs = [(1.0, -1.0), (1.0, 1.0), (-1.0, 1.0), (-1.0, -1.0)];
  for (var k = 0; k < 4; k++) {
    final a = signs[k];
    final b = signs[(k + 1) % 4];
    // The outward normal of the face from corner a to corner b.
    final mx = (a.$1 + b.$1) / 2;
    final my = (a.$2 + b.$2) / 2;
    final nx = ux * mx - uy * my;
    final ny = uy * mx + ux * my;
    if (nx + ny <= 0) continue;
    final shade = (-0.16 * ((nx - ny) + 1) / 2).clamp(-0.2, 0.0);
    s.canvas.drawPath(
      s.face([
        corner(a.$1, a.$2, z),
        corner(b.$1, b.$2, z),
        corner(b.$1, b.$2, z + h),
        corner(a.$1, a.$2, z + h),
      ]),
      s.fill(tint.shade(shade)),
    );
  }
  s.canvas.drawPath(
    s.face([
      for (final c in signs) corner(c.$1, c.$2, z + h),
    ]),
    s.fill(tint.shade(0.14)),
  );
}

/// A lattice arm from the mast top along [turn], [length] tiles out, its
/// chords [depth] apart at the root and narrowing to the tip.
void _truss(IsoStage s, double z, double turn, double length, double depth) {
  final ux = math.cos(turn);
  final uy = math.sin(turn);
  Offset at(double r, double up) =>
      s.at(_mastX + ux * r, _mastY + uy * r, z + up);
  double height(double r) => depth * (1 - 0.55 * r / length);

  s.canvas.drawPath(
    Path()
      ..moveTo(at(0, 0).dx, at(0, 0).dy)
      ..lineTo(at(length, 0).dx, at(length, 0).dy)
      ..lineTo(at(length, height(length)).dx, at(length, height(length)).dy)
      ..lineTo(at(0, depth).dx, at(0, depth).dy)
      ..close(),
    s.fill(_crane.shade(-0.06)),
  );
  final steps = (length / 0.28).round();
  final zig = Path()..moveTo(at(0, 0).dx, at(0, 0).dy);
  for (var k = 1; k <= steps; k++) {
    final r = length * k / steps;
    final p = k.isOdd ? at(r, height(r)) : at(r, 0);
    zig.lineTo(p.dx, p.dy);
  }
  s.canvas
    ..drawPath(zig, s.stroke(_brace, 0.022))
    ..drawLine(at(0, 0), at(length, 0), s.stroke(_crane.shade(-0.12), 0.04))
    ..drawLine(
      at(0, depth),
      at(length, height(length)),
      s.stroke(_crane.shade(0.1), 0.035),
    );
}

/// The tower crane, [drop] tiles above where it stands, its jib along
/// [turn], with the key piece hanging [lift] tiles above its gap and swung
/// [sway] tiles on past its trolley the way the jib was turning - or, once
/// it is in, the hook [release] of the way back up, its slings let go.
void _craneAndLoad(
  IsoStage s,
  double drop,
  double turn,
  double sway,
  double lift,
  double release,
) {
  const half = 0.17;
  final z = drop;
  if (drop < 0.05) s.shadow(_mastX, _mastY, 0.55, _grass);

  // Footing and mast: a box with cross-bracing down the two faces we see.
  s.box(_mastX - 0.35, _mastY - 0.35, z, 0.7, 0.7, 0.16, _concrete);
  const x0 = _mastX - half;
  const y0 = _mastY - half;
  const x1 = _mastX + half;
  const y1 = _mastY + half;
  final foot = z + 0.16;
  final head = z + _mastH;
  s.box(x0, y0, foot, 2 * half, 2 * half, head - foot, _crane, edge: false);
  final left = Path();
  final right = Path();
  const rungs = 7;
  for (var k = 0; k <= rungs; k++) {
    final zz = foot + (head - foot) * k / rungs;
    final l = s.at(k.isEven ? x0 : x1, y1, zz);
    final r = s.at(x1, k.isEven ? y1 : y0, zz);
    k == 0 ? left.moveTo(l.dx, l.dy) : left.lineTo(l.dx, l.dy);
    k == 0 ? right.moveTo(r.dx, r.dy) : right.lineTo(r.dx, r.dy);
  }
  s.canvas
    ..drawPath(left, s.stroke(_brace, 0.022))
    ..drawPath(right, s.stroke(_brace, 0.022));

  // The slewing deck and the cab on it, the tower head above. Whichever
  // arm points away from us - the jib while it waits turned to the back,
  // the counter-jib once the jib is over the board - goes behind them.
  final back = turn + math.pi;
  final ux = math.cos(turn);
  final uy = math.sin(turn);
  final peak = s.at(_mastX, _mastY, head + 0.75);
  void jib() {
    final tie = s.at(
      _mastX + ux * _jib * 0.72,
      _mastY + uy * _jib * 0.72,
      head + 0.16,
    );
    _truss(s, head, turn, _jib, 0.24);
    s.canvas.drawLine(peak, tie, s.stroke(_cable, 0.018));
  }

  void counter() {
    final tie = s.at(
      _mastX + math.cos(back) * _tail,
      _mastY + math.sin(back) * _tail,
      head + 0.12,
    );
    _truss(s, head, back, _tail, 0.2);
    _turnedBox(
      s,
      _mastX + math.cos(back) * (_tail - 0.2),
      _mastY + math.sin(back) * (_tail - 0.2),
      head - 0.18,
      0.36,
      0.4,
      0.36,
      turn,
      _concrete.shade(-0.06),
    );
    s.canvas.drawLine(tie, peak, s.stroke(_cable, 0.018));
  }

  final jibToUs = ux + uy > 0;
  jibToUs ? counter() : jib();

  s.cylinder(_mastX, _mastY, head, 0.24, 0.1, _crane.shade(-0.1));
  final side = turn + math.pi / 2;
  final cabX = _mastX + math.cos(side) * 0.3 + ux * 0.1;
  final cabY = _mastY + math.sin(side) * 0.3 + uy * 0.1;
  s.canvas
    ..drawLine(s.at(_mastX, _mastY, head), peak, s.stroke(_crane, 0.07))
    // A pennant on the tower head, in the colour of the piece it brings.
    ..drawPath(
      Path()
        ..moveTo(peak.dx, peak.dy)
        ..lineTo(peak.dx + 0.42 * s.unit, peak.dy + 0.1 * s.unit)
        ..lineTo(peak.dx, peak.dy + 0.22 * s.unit)
        ..close(),
      s.fill(_keyPiece),
    );
  _turnedBox(s, cabX, cabY, head - 0.42, 0.34, 0.3, 0.38, turn, _crane);
  // The cab's window, on the face that looks along the jib - when that
  // face looks our way.
  if (jibToUs) {
    V3 pane(double b, double zz) => (
      x: cabX + ux * 0.171 - uy * b,
      y: cabY + uy * 0.171 + ux * b,
      z: zz,
    );
    s.canvas.drawPath(
      s.face([
        pane(-0.11, head - 0.26),
        pane(0.11, head - 0.26),
        pane(0.11, head - 0.1),
        pane(-0.11, head - 0.1),
      ]),
      s.fill(_glass),
    );
  }
  jibToUs ? jib() : counter();

  // The trolley, the cable down to the hook block, and the load.
  final tx = _mastX + math.cos(turn) * _reach;
  final ty = _mastY + math.sin(turn) * _reach;
  s.box(tx - 0.1, ty - 0.1, head - 0.12, 0.2, 0.2, 0.12, _brace);

  // Where the load hangs: under the trolley, or swung on past it.
  final lx = tx + sway * uy;
  final ly = ty - sway * ux;
  final hookZ = z + _th + _proud + lift + 0.6 + 0.7 * release;
  final hook = s.at(lx, ly, hookZ);
  s.canvas.drawLine(s.at(tx, ty, head - 0.12), hook, s.stroke(_cable, 0.02));

  if (release <= 0) {
    _keyPieceAt(s, lift + z + _proud, turn - _aim, lx - _slotX, ly - _slotY);
    // Four slings from the hook to the corners of the piece.
    final slings = s.stroke(_cable, 0.014);
    for (final (a, b) in const [(-1, -1), (1, -1), (1, 1), (-1, 1)]) {
      final ox = 0.26 * a;
      final oy = 0.26 * b;
      final c = math.cos(turn - _aim);
      final n = math.sin(turn - _aim);
      s.canvas.drawLine(
        hook,
        s.at(
          lx + ox * c - oy * n,
          ly + ox * n + oy * c,
          z + _th + _proud + lift,
        ),
        slings,
      );
    }
  } else {
    _keyPieceAt(s, _proud, 0, 0, 0);
    final slings = s.stroke(_cable, 0.014);
    s.canvas
      ..drawLine(hook, s.at(tx - 0.08, ty + 0.08, hookZ - 0.3), slings)
      ..drawLine(hook, s.at(tx + 0.08, ty - 0.08, hookZ - 0.3), slings);
  }
  s.canvas
    ..drawRect(
      Rect.fromCenter(
        center: hook.translate(0, -0.04 * s.unit),
        width: 0.14 * s.unit,
        height: 0.12 * s.unit,
      ),
      s.fill(_crane.shade(-0.1)),
    )
    ..drawArc(
      Rect.fromCircle(
        center: hook.translate(0, 0.08 * s.unit),
        radius: 0.06 * s.unit,
      ),
      -math.pi / 2,
      math.pi * 1.4,
      false,
      s.stroke(_cable, 0.022),
    );
}

// ------------------------------------------------------------------ people --

/// A small figure at [x], [y], [grow] of the way popped up and [jump] tiles
/// off the ground: a body, a head, two arms at [left] and [right] radians
/// out from hanging straight down, and [hair] or a hard hat ([hat]) if it
/// has them.
void _person(
  IsoStage s,
  double x,
  double y, {
  required double grow,
  required Tint body,
  Tint? hat,
  Tint? hair,
  double left = 0.3,
  double right = 0.3,
  double jump = 0,
}) {
  s.scaled(s.at(x, y), grow, () {
    s
      ..shadow(x, y, 0.3 * (1 - 0.3 * jump), _grass)
      ..canvas.save()
      ..canvas.translate(0, -jump * s.unit)
      ..cylinder(x, y, 0, 0.17, 0.62, body);
    final shoulder = s.at(x, y, 0.57);
    final out = 0.15 * s.unit;
    final arm = 0.37 * s.unit;
    final sleeve = s.stroke(body.shade(-0.06), 0.085);
    final l = shoulder.translate(-out, 0);
    final r = shoulder.translate(out, 0);
    s.canvas
      ..drawLine(
        l,
        l + Offset(-math.sin(left), math.cos(left)) * arm,
        sleeve,
      )
      ..drawLine(
        r,
        r + Offset(math.sin(right), math.cos(right)) * arm,
        sleeve,
      );
    s.sphere(x, y, 0.82, 0.16, _skin);
    if (hair != null) {
      s.canvas.drawArc(
        Rect.fromCenter(
          center: s.at(x, y, 0.85),
          width: 0.38 * s.unit,
          height: 0.34 * s.unit,
        ),
        math.pi * 0.95,
        math.pi * 1.1,
        true,
        s.fill(hair),
      );
    }
    if (hat != null) {
      final crown = s.at(x, y, 0.88);
      s.canvas
        ..drawOval(
          Rect.fromCenter(
            center: crown,
            width: 0.48 * s.unit,
            height: 0.15 * s.unit,
          ),
          s.fill(hat.shade(-0.08)),
        )
        ..drawArc(
          Rect.fromCenter(
            center: crown,
            width: 0.36 * s.unit,
            height: 0.39 * s.unit,
          ),
          math.pi,
          math.pi,
          true,
          s.fill(hat),
        );
    }
    s.canvas.restore();
  });
}

/// The one asking, [grow] of the way popped up. As the story turns to
/// *this problem* they point at the gap, the other hand on their head, and
/// a question pops up over them; when the piece clicks in - the help is
/// for *me* - both arms go up, they jump, and the question becomes a heart.
void _asker(IsoStage s, double grow) {
  s.story(() {
    final point = s.phase(
      _problem - 0.015,
      _problem + 0.035,
      Curves.easeOutBack,
    );
    final cheer = s.phase(_solved - 0.005, _solved + 0.05, Curves.easeOutBack);
    // Up and down once, and exactly on the ground again once it is over.
    final leap = s.phase(_solved - 0.005, _solved + 0.08, Curves.linear);
    _person(
      s,
      _askerX,
      _askerY,
      grow: grow,
      body: _shirt,
      hair: _hair,
      // The far hand goes to the head, the near one points across at the
      // gap; both go up when it clicks.
      left: 0.3 + 2.45 * point - 0.3 * cheer,
      right: 0.3 + 1.32 * point + 0.83 * cheer,
      jump: leap >= 1 ? 0 : 0.22 * math.sin(math.pi * leap),
    );

    final over = s.at(_askerX, _askerY, 1.85);
    // The bubble pops up with the problem, and gives a little hop when the
    // piece clicks. Exactly still once it is over, not a hair off.
    final bounce = s.phase(_solved, _solved + 0.1, Curves.linear);
    final hop = bounce >= 1 ? 0.0 : math.sin(math.pi * bounce);
    final popped = s.pop(_problem - 0.012, _problem + 0.05);
    s.scaled(over, popped * (1 + 0.16 * hop), () {
      _bubbleAt(s, over);
      final ask =
          1 - s.phase(_solved - 0.01, _solved + 0.02, Curves.easeInBack);
      s
        ..scaled(over, ask, () => _question(s, over))
        ..scaled(over, s.pop(_solved, _solved + 0.06), () => _heart(s, over));
    });
  });
}

/// How big the asker's bubble is, in tiles.
const _bubbleR = 0.5;

/// A round thought bubble centred on [c], its dots leading down to the
/// asker's head.
void _bubbleAt(IsoStage s, Offset c) {
  final r = _bubbleR * s.unit;
  final bubble = s.fill(_bubble);
  s.canvas
    ..drawCircle(c.translate(r * 0.14, r * 1.42), r * 0.12, bubble)
    ..drawCircle(c.translate(r * 0.08, r * 1.12), r * 0.2, bubble)
    ..drawCircle(c, r, bubble);
}

/// A question mark drawn with a pen, centred on [c].
void _question(IsoStage s, Offset c) {
  final r = _bubbleR * s.unit;
  final hook = Path()
    ..addArc(
      Rect.fromCircle(center: c.translate(0, -r * 0.22), radius: r * 0.32),
      math.pi * 1.05,
      math.pi * 1.45,
    );
  final end = c.translate(0, r * 0.25);
  hook.lineTo(end.dx, end.dy);
  s.canvas
    ..drawPath(hook, s.stroke(_ink, 0.06))
    ..drawCircle(c.translate(0, r * 0.55), r * 0.08, s.fill(_ink));
}

/// A heart centred on [c], in the key piece's colour.
void _heart(IsoStage s, Offset c) {
  final w = 0.32 * s.unit;
  final x = c.dx;
  final y = c.dy + w * 0.08;
  s.canvas.drawPath(
    Path()
      ..moveTo(x, y + w * 0.85)
      ..cubicTo(
        x - w * 1.5,
        y - w * 0.05,
        x - w * 0.85,
        y - w * 1.2,
        x,
        y - w * 0.45,
      )
      ..cubicTo(
        x + w * 0.85,
        y - w * 1.2,
        x + w * 1.5,
        y - w * 0.05,
        x,
        y + w * 0.85,
      )
      ..close(),
    s.fill(_keyPiece),
  );
}

// --------------------------------------------------------------- furniture --

/// A toolbox on the grass at [x], [y], [grow] of the way popped up.
void _toolbox(IsoStage s, double x, double y, double grow) {
  s.scaled(s.at(x, y), grow, () {
    s
      ..shadow(x + 0.25, y + 0.12, 0.38, _grass)
      ..box(x, y, 0, 0.5, 0.26, 0.2, _metal)
      ..box(x - 0.02, y - 0.02, 0.2, 0.54, 0.3, 0.05, _metal.shade(-0.06));
    final a = s.at(x + 0.12, y + 0.13, 0.25);
    final b = s.at(x + 0.38, y + 0.13, 0.25);
    final handle = Path()
      ..moveTo(a.dx, a.dy)
      ..cubicTo(
        a.dx,
        a.dy - 0.16 * s.unit,
        b.dx,
        b.dy - 0.16 * s.unit,
        b.dx,
        b.dy,
      );
    s.canvas
      ..drawPath(handle, s.stroke(_cable, 0.03))
      ..drawLine(
        s.at(x + 0.06, y + 0.26, 0.12),
        s.at(x + 0.44, y + 0.26, 0.12),
        s.stroke(_metal.shade(0.2), 0.02),
      );
  });
}
