import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/animation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_full_stack_flutter/core/audio/sound.dart';
import 'package:flutter_full_stack_flutter/features/pronunciation/presentation/scenes/iso_stage.dart';
import 'package:flutter_full_stack_flutter/features/pronunciation/presentation/scenes/script.dart';

// The palette: a still, warm afternoon. Periwinkle sky over a blush haze,
// violet distance, sage grass, a teal armchair, and gold for what lights up.
// The thought is lilac: white on a light theme, a glow in the dark one's dusk.
const _skyTop = Tint(228, 0.74, 0.42);
const _skyLow = Tint(338, 0.4, 0.93);
const _sunBody = Tint(40, 0.95, 0.74);
const _sunHalo = Tint(34, 0.85, 0.88);
const _cloud = Tint(330, 0.3, 1);
const _farHill = Tint(262, 0.3, 0.7);
const _nearHill = Tint(165, 0.36, 0.6);
const _grass = Tint(100, 0.4, 0.4);
const _earth = Tint(20, 0.5, 0.3);
const _stone = Tint(250, 0.14, 0.17);
const _gravel = Tint(34, 0.35, 0.74);
const _water = Tint(196, 0.6, 0.46);
const _rug = Tint(266, 0.36, 0.5);
const _rugHem = Tint(40, 0.55, 0.78);
const _velvet = Tint(184, 0.5, 0.4);
const _wood = Tint(24, 0.45, 0.28);
const _dress = Tint(8, 0.62, 0.48);
const _skin = Tint(26, 0.55, 0.74);
const _hair = Tint(18, 0.45, 0.2);
const _leaves = Tint(132, 0.42, 0.32);
const _leavesLight = Tint(96, 0.42, 0.46);
const _bark = Tint(22, 0.4, 0.2);
const _stem = Tint(110, 0.45, 0.3);
const _petalRose = Tint(348, 0.7, 0.56);
const _petalGold = Tint(44, 0.9, 0.68);
const _petalLilac = Tint(272, 0.55, 0.58);
const _china = Tint(200, 0.2, 0.92);
const _thoughtTint = Tint(256, 0.3, 1);
const _cover = Tint(190, 0.6, 0.38);
const _page = Tint(40, 0.45, 0.96);
const _ink = Tint(220, 0.25, 0.5);
const _glass = Tint(42, 0.9, 0.76);
const _glow = Tint(44, 0.9, 0.9);
const _metal = Tint(220, 0.12, 0.45);
const _starTint = Tint(10, 0.72, 0.54);

// Where things stand, in tiles. The armchair's seat sits near the front left
// edge, facing down the x axis, the lamp at its side; the thought floats up
// and to the right of her head, over the back of the island and clear of the
// card above it; [_step] is how far apart the three things in it are.
const _seatX = 3.15;
const _seatY = 4.5;
const _seat = 0.9;
const _seatZ = 0.32;
const _lampX = 2.95;
const _lampY = 5.72;
// Her head, sat in the chair: where the thought comes from.
const double _headX = _seatX + 0.38;
const double _headY = _seatY + _seat / 2;
const _headZ = 1.08;
const _cloudX = 4.62;
const _cloudY = 2.38;
const _cloudZ = 3.25;
const _cloudWidth = 4.8;
const _step = 0.82;

/// "She thought about three things", in two acts.
///
/// The reading nook assembles first: the island rises, the armchair, the
/// lamp and the books drop onto it, the garden grows round it and she
/// appears in the chair, chin on her hand. Then the
/// story, in the lamp's warm light while the garden sinks back: the lamp
/// comes on over her, and a thought bubbles up out of her head and swells
/// into a cloud (*thought*). The things she is thinking of arrive in it one
/// at a time, a count's beat apart and each with a little burst of
/// sparkles, so that they can be counted: a book (*three*), a light bulb
/// that lights up, and a star that spins in and settles (*things*).
const thinkingScene = SceneScript(
  paintThinking,
  cues: [
    Cue('thought', _thinks),
    Cue('three', _first),
    Cue('things', _third),
  ],
  sounds: [
    SceneSound(Sound.pop, _thinks),
    SceneSound(Sound.countOne, _first),
    SceneSound(Sound.countTwo, _second),
    SceneSound(Sound.countThree, _third),
  ],
);

// The story's beats, on the arrival's clock. The lamp comes on as the story
// opens; the thought rises; then the three things land evenly, [_beat]
// apart, so the count reads one - two - three: the *three* beat is the
// first landing and the *things* beat the last.
const double _lampOn = Act.setting + 0.01;
const _thinks = 0.42;
const _first = 0.54;
const _beat = 0.12;
const double _second = _first + _beat;
const double _third = _first + 2 * _beat;

/// Paints [thinkingScene].
void paintThinking(IsoStage s) {
  s.setting(() {
    s.sky(_skyTop, _skyLow);

    // The sun sinks a little as the scene settles, towards evening.
    final sink = s.phase(0.1, 0.8);
    s
      ..sun(0.86, 0.12 + 0.07 * sink, 0.62, _sunBody, _sunHalo)
      ..ridge(0.76, 1.5, _farHill, seed: 3)
      ..ridge(0.85, 1.1, _nearHill, seed: 7);

    // Two weather clouds drift in at the edges, well away from where the
    // thought will rise, so the sky never holds two clouds side by side.
    final drift = s.phase(0.2, 1);
    s
      ..cloud(s.screen(0.16 - 0.45 * (1 - drift), 0.27), 2.4, _cloud)
      ..cloud(s.screen(0.08 - 0.4 * (1 - drift), 0.55), 1.4, _cloud);

    s.rising(0, 0.42, () {
      s.island(grass: _grass, earth: _earth, stone: _stone);
      _ground(s);
      // The stage: her corner, lit by the lamp once the story starts, and
      // it stays lit.
      s.pool(_headX - 0.1, _headY + 0.25, 1.45, strength: s.storyLight);

      // Everything standing on the island, gathered first and then drawn
      // back to front, by x + y, so nothing paints over what is before it.
      final props = <(double, void Function())>[];
      void place(double x, double y, void Function(double x, double y) draw) =>
          props.add((x + y, () => draw(x, y)));

      // A grove behind her corner, and one tree on the far corner: the
      // middle of the back is left open, for the thought to rise into.
      place(
        0.5,
        2.25,
        (x, y) => s.pine(
          x,
          y,
          needles: _leaves,
          bark: _bark,
          ground: _grass,
          h: 2.4,
          grow: s.pop(0.38, 0.6),
        ),
      );
      for (final tree in const [
        (x: 0.85, y: 4.55, h: 2.1, leaves: _leavesLight, at: 0.42),
        (x: 5.6, y: 0.55, h: 1.7, leaves: _leaves, at: 0.46),
        (x: 1.5, y: 3.6, h: 2.6, leaves: _leaves, at: 0.32),
      ]) {
        place(
          tree.x,
          tree.y,
          (x, y) => s.tree(
            x,
            y,
            leaves: tree.leaves,
            bark: _bark,
            ground: _grass,
            h: tree.h,
            grow: s.pop(tree.at, tree.at + 0.22),
          ),
        );
      }
      for (final bush in const [
        (x: 5.75, y: 2.75, size: 1.0, leaves: _leavesLight, at: 0.5),
        (x: 0.8, y: 5.3, size: 0.9, leaves: _leaves, at: 0.52),
      ]) {
        place(
          bush.x,
          bush.y,
          (x, y) => s.bush(
            x,
            y,
            bush.leaves,
            size: bush.size,
            grow: s.pop(bush.at, bush.at + 0.2),
          ),
        );
      }

      // Her corner: the armchair, the lamp beside it, the table in front
      // with her tea and her books.
      place(_seatX + _seat / 2, _seatY + _seat / 2, (_, _) => _nook(s));
      place(
        _lampX,
        _lampY,
        (x, y) => s.dropping(0.26, 0.52, (lift) => _lamp(s, x, y, lift)),
      );
      place(4.6, 4.3, (x, y) => _table(s, x, y));
      place(4.55, 4.95, (x, y) {
        for (var i = 0; i < 3; i++) {
          final at = 0.34 + i * 0.05;
          s.dropping(at, at + 0.16, (lift) => _book(s, x, y, lift, i));
        }
        _cat(s, x, y);
      });

      // Bulrushes at the far side of the pond.
      final reeds = s.pop(0.54, 0.7);
      for (final reed in const [
        (x: 5.5, y: 3.3, h: 0.45),
        (x: 5.66, y: 3.42, h: 0.58),
        (x: 5.62, y: 3.62, h: 0.42),
      ]) {
        place(reed.x, reed.y, (x, y) => _bulrush(s, x, y, reed.h, reeds));
      }

      // Flowers, opening from the back of the island to the front.
      const beds = [
        (x: 5.75, y: 3.95, tint: _petalRose),
        (x: 5.5, y: 4.3, tint: _petalGold),
        (x: 0.6, y: 4.5, tint: _petalLilac),
        (x: 1.3, y: 5.5, tint: _petalRose),
        (x: 5.6, y: 5.1, tint: _petalLilac),
      ];
      final ordered = [...beds]
        ..sort((a, b) => (a.x + a.y).compareTo(b.x + b.y));
      for (var i = 0; i < ordered.length; i++) {
        final bed = ordered[i];
        final grow = s.pop(0.5 + i * 0.025, 0.68 + i * 0.025);
        place(
          bed.x,
          bed.y,
          (x, y) => s.flower(x, y, bed.tint, _stem, grow: grow),
        );
      }

      // Two butterflies over the flowers, one by the pond, one on the left.
      place(
        5.55,
        4.6,
        (x, y) => _butterfly(
          s,
          s.at(x, y, 0.62),
          _petalLilac,
          s.pop(0.66, 0.78),
        ),
      );
      place(
        0.9,
        4.9,
        (x, y) => _butterfly(s, s.at(x, y, 0.72), _petalGold, s.pop(0.7, 0.82)),
      );

      props.sort((a, b) => a.$1.compareTo(b.$1));
      for (final (_, draw) in props) {
        draw();
      }

      // The thought floats over all of it; it is the story.
      s.story(() => _thought(s));

      // The garden steps back while she and her thought have the stage.
      final head = s.at(_headX, _headY, _headZ);
      final cloud = s.at(_cloudX, _cloudY, _cloudZ);
      s.spotlight(
        Offset.lerp(head, cloud, 0.45)!,
        radius: 2.8,
        strength: s.storyLight,
      );
    });
  });
}

/// A bulrush at [x], [y], [h] tiles tall once grown, [grow] of the way:
/// a stem and a brown head.
void _bulrush(IsoStage s, double x, double y, double h, double grow) {
  if (grow <= 0) return;
  final foot = s.at(x, y);
  final head = s.at(x, y, h * grow);
  s.canvas
    ..drawLine(foot, head, s.stroke(_stem, 0.04))
    ..drawOval(
      Rect.fromCenter(
        center: head.translate(0, 0.07 * s.unit),
        width: 0.08 * s.unit,
        height: 0.2 * s.unit * grow,
      ),
      s.fill(_bark.shade(0.06)),
    );
}

/// A butterfly at screen point [c], wings open, [grow] of the way there.
void _butterfly(IsoStage s, Offset c, Tint wings, double grow) {
  if (grow <= 0) return;
  final r = 0.13 * s.unit * grow;
  Rect wing(double dx, double dy, double size) => Rect.fromCenter(
    center: c.translate(dx * r, dy * r),
    width: size * r,
    height: size * r * 0.8,
  );
  final upper = s.fill(wings);
  final lower = s.fill(wings.shade(-0.1));
  s.canvas
    ..drawOval(wing(-0.4, 0.35, 0.75), lower)
    ..drawOval(wing(0.4, 0.35, 0.75), lower)
    ..drawOval(wing(-0.5, -0.25, 1), upper)
    ..drawOval(wing(0.5, -0.25, 1), upper)
    ..drawLine(
      c.translate(0, -0.5 * r),
      c.translate(0, 0.55 * r),
      s.stroke(_hair, 0.025),
    );
}

/// What lies flat: the rug under the armchair, the pond, and the stepping
/// stones between them.
void _ground(IsoStage s) {
  // The rug spreads out just before the armchair lands on it.
  final spread = s.phase(0.16, 0.3);
  if (spread > 0) {
    s.canvas
      ..drawOval(s.disc(3.7, 4.95, 0.004, 1.06 * spread), s.fill(_rugHem))
      ..drawOval(s.disc(3.7, 4.95, 0.006, 0.94 * spread), s.fill(_rug))
      ..drawOval(
        s.disc(3.7, 4.95, 0.008, 0.62 * spread),
        s.fill(_rug.shade(0.08)),
      );
  }
  s.canvas
    ..drawOval(s.disc(5.15, 3.75, 0.004, 0.5), s.fill(_water))
    ..drawOval(s.disc(5.05, 3.65, 0.006, 0.22), s.fill(_water.shade(0.2)))
    ..drawOval(s.disc(5.3, 3.9, 0.008, 0.1), s.fill(_leavesLight));
  const stones = [(4.75, 5.72), (5.2, 5.8), (5.65, 5.86)];
  for (final (x, y) in stones) {
    s.canvas.drawOval(s.disc(x, y, 0.004, 0.17), s.fill(_gravel));
  }
}

/// The armchair, and her in it once it has landed.
void _nook(IsoStage s) {
  final appear = s.pop(0.48, 0.6);
  s.dropping(0.2, 0.48, (lift) {
    const x = _seatX;
    const y = _seatY;
    const w = _seat;
    final z = lift;
    if (lift < 0.05) s.shadow(x + w / 2, y + w / 2, 0.8, _rug);
    s
      // The back, then the far arm, then the seat.
      ..box(x - 0.22, y - 0.04, z, 0.24, w + 0.08, 1.02, _velvet)
      ..box(x, y - 0.04, z, w, 0.2, 0.56, _velvet)
      ..box(x, y + 0.16, z, w, w - 0.32, _seatZ, _velvet.shade(0.04))
      // A cushion against the back.
      ..box(x + 0.02, y + 0.22, z + _seatZ, 0.12, 0.46, 0.36, _rug.shade(0.1));
    if (appear > 0) {
      s.scaled(
        s.at(x + w / 2, y + w / 2, z + _seatZ),
        appear,
        () => _reader(s, x + 0.4, y + w / 2, z + _seatZ),
      );
    }
    s.box(x, y + w - 0.16, z, w, 0.2, 0.56, _velvet);
  });
}

/// The little table at [x], [y] in front of her, with her tea on it.
void _table(IsoStage s, double x, double y) {
  s.dropping(0.3, 0.56, (lift) {
    if (lift < 0.05) s.shadow(x, y, 0.3, _grass);
    s
      ..cylinder(x, y, lift, 0.05, 0.42, _wood)
      ..cylinder(x, y, lift + 0.42, 0.26, 0.05, _wood.shade(0.1))
      ..cylinder(x + 0.04, y + 0.06, lift + 0.47, 0.08, 0.09, _china)
      ..canvas.drawArc(
        Rect.fromCircle(
          center: s.at(x + 0.14, y + 0.06, lift + 0.52),
          radius: 0.05 * s.unit,
        ),
        -math.pi / 2,
        math.pi,
        false,
        s.stroke(_china.shade(-0.1), 0.025),
      );
  });
}

/// Her: sitting at [x], [y] on a seat at [z], facing down the x axis, chin on
/// her hand, looking up at what she is thinking of.
void _reader(IsoStage s, double x, double y, double z) {
  const lap = 0.14;
  const body = 0.42;
  const r = 0.2;
  final head = z + lap + body + r;
  final shin = _skin.shade(-0.06);
  s
    // Shins down to the ground in front of the seat, then the lap over them.
    ..box(x + 0.4, y - 0.13, 0, 0.1, 0.1, z + 0.02, shin)
    ..box(x + 0.4, y + 0.03, 0, 0.1, 0.1, z + 0.02, shin)
    ..box(x + 0.42, y - 0.14, 0, 0.15, 0.12, 0.06, _hair)
    ..box(x + 0.42, y + 0.02, 0, 0.15, 0.12, 0.06, _hair)
    ..box(x - 0.12, y - 0.16, z, 0.62, 0.32, lap, _dress)
    // The body, then her bun and the back of her head, then her face, back
    // to front.
    ..cylinder(x - 0.07, y, z + lap, 0.17, body, _dress)
    ..sphere(x - 0.32, y + 0.02, head + 0.14, 0.085, _hair)
    ..sphere(x - 0.12, y + 0.01, head + 0.05, r * 0.9, _hair)
    ..sphere(x - 0.02, y, head, r, _skin);
  // A fringe over her brow.
  s.canvas.drawArc(
    Rect.fromCircle(center: s.at(x - 0.02, y, head), radius: r * 1.15 * s.unit),
    math.pi * 1.05,
    math.pi * 0.6,
    false,
    s.stroke(_hair, 0.06),
  );
  // The arm: a sleeve from her shoulder to her elbow on her knee, then a
  // bare forearm up to her hand under her chin.
  final shoulder = s.at(x - 0.05, y + 0.16, z + lap + body - 0.07);
  final elbow = s.at(x + 0.28, y + 0.14, z + lap + 0.05);
  final hand = s.at(x + 0.08, y + 0.07, head - r);
  s.canvas
    ..drawLine(shoulder, elbow, s.stroke(_dress.shade(-0.2), 0.085))
    ..drawLine(elbow, hand, s.stroke(_skin.shade(-0.06), 0.07))
    ..drawCircle(hand, 0.07 * s.unit, s.fill(_skin));
}

/// The floor lamp at [x], [y], [lift] tiles above the ground. It comes on as
/// the story opens - the light she thinks in - its shade brightening and
/// its glow spreading over her.
void _lamp(IsoStage s, double x, double y, double lift) {
  var lit = 0.0;
  s.story(() => lit = s.phase(_lampOn, _lampOn + 0.05));
  if (lift < 0.05) s.shadow(x, y, 0.22, _grass);
  s
    ..glow(
      s.at(x, y, lift + 1.32),
      1.1,
      strength: lit * s.storyLight,
    )
    ..cylinder(x, y, lift, 0.16, 0.04, _wood)
    ..cylinder(x, y, lift + 0.04, 0.025, 1.3, _wood);
  _frustum(
    s,
    (x: x, y: y, z: lift + 1.18),
    0.27,
    0.15,
    0.32,
    _glass.at(0.58 + 0.38 * lit),
  );
}

/// A lampshade: an upright cone cut short, from radius [r0] at [base] to
/// [r1] at [h] tiles above it, shaded across like the kit's cylinder.
void _frustum(IsoStage s, V3 base, double r0, double r1, double h, Tint tint) {
  final foot = s.disc(base.x, base.y, base.z, r0);
  final lid = s.disc(base.x, base.y, base.z + h, r1);
  final side = Path()
    ..moveTo(foot.left, foot.center.dy)
    ..arcTo(foot, math.pi, -math.pi, false)
    ..lineTo(lid.right, lid.center.dy)
    ..arcTo(lid, 0, -math.pi, false)
    ..close();
  s.canvas
    ..drawPath(
      side,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(foot.left, 0),
          Offset(foot.right, 0),
          [
            s.colour(tint.shade(0.08)),
            s.colour(tint),
            s.colour(tint.shade(-0.18)),
          ],
          [0, 0.4, 1],
        ),
    )
    ..drawOval(lid, s.fill(tint.shade(0.12)));
}

/// The [i]th book from the bottom of the stack at [x], [y], [lift] tiles
/// above its place, each a little askew of the one under it.
void _book(IsoStage s, double x, double y, double lift, int i) {
  const covers = [_cover, _rug, _dress];
  final dx = const [0.0, 0.05, -0.03][i];
  final dy = const [0.0, -0.04, 0.03][i];
  final z = lift + i * 0.12;
  if (i == 0 && lift < 0.05) s.shadow(x + 0.25, y + 0.18, 0.35, _grass);
  s
    ..box(x + dx, y + dy, z, 0.5, 0.36, 0.12, covers[i])
    ..onLeft(y + dy + 0.36, x + dx + 0.04, z + 0.02, 0.44, 0.08, _page);
}

/// The black cat, behind her books - the scene's easter egg (see
/// `HidingCat`). It lies low in the grass behind the stack at [x], [y], the
/// tips of its ears showing over the top book, and when it has a reason it
/// hops up onto the books and sits on them - where a cat sits when someone
/// is reading - and hops back down behind them.
void _cat(IsoStage s, double x, double y) {
  // Only once the last book has landed.
  if (s.t < 0.6) return;
  // The top book's top: its back corner and the far ends of its two back
  // edges. While the cat is behind the stack, only what of it is over those
  // edges shows.
  const top = 0.36;
  final back = s.at(x - 0.03, y + 0.03, top);
  final left = s.at(x - 0.03, y + 0.39, top);
  final right = s.at(x + 0.47, y + 0.03, top);
  final up = back.translate(0, -s.unit);
  final behind = Path.combine(
    PathOperation.union,
    s.beyond(left, back, of: up),
    s.beyond(back, right, of: up),
  );
  // Crouched just right of the back corner, low enough that only its ear
  // tips clear the top book; sat on that book, clear of her feet.
  final crouch = back.translate(0.05 * s.unit, 0.7 * s.unit);
  final seat = s.at(x + 0.3, y + 0.15, top);
  // The hop: the straight way from one to the other, lifted in an arc that
  // takes it over the back edge. At the top of the arc it is clear of the
  // books, and from there on it is on them, so nothing is in front of it.
  final height = 0.52 * s.unit;
  final apex = 0.5 + (crouch.dy - seat.dy) / (8 * height);
  final p = s.cat.out;
  final lift = Offset(0, -4 * height * p * (1 - p));
  s.hidingCat(
    hidden: crouch + lift,
    out: seat + lift,
    reveal: p < apex ? behind : (Path()..addRect(Offset.zero & s.size)),
  );
}

/// A four-pointed twinkle centred on [c], [r] pixels to its points.
void _twinkle(IsoStage s, Offset c, double r, Tint tint) {
  s.canvas.drawPath(
    Path()
      ..moveTo(c.dx, c.dy - r)
      ..quadraticBezierTo(c.dx, c.dy, c.dx + r * 0.7, c.dy)
      ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy + r)
      ..quadraticBezierTo(c.dx, c.dy, c.dx - r * 0.7, c.dy)
      ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy - r)
      ..close(),
    s.fill(tint),
  );
}

/// The thought, on the story's clock: bubbles rising from her head and
/// swelling into a cloud, then the three things arriving in it one at a
/// time.
void _thought(IsoStage s) {
  final cloud = s.at(_cloudX, _cloudY, _cloudZ);
  final w = _cloudWidth * s.unit;

  // From just above her head, rising in a gentle curve to just short of the
  // cloud's lower left, each bubble a little bigger than the one before.
  final from = s.at(_headX + 0.08, _headY - 0.1, _headZ + 0.56);
  final to = cloud.translate(-w * 0.5, w * 0.28);
  final bend = Offset(
    from.dx + (to.dx - from.dx) * 0.2,
    from.dy + (to.dy - from.dy) * 0.7,
  );
  const bubbles = [(0.0, 0.1), (0.5, 0.15), (1.0, 0.2)];
  for (var i = 0; i < bubbles.length; i++) {
    final (f, r) = bubbles[i];
    final begin = _thinks - 0.01 + i * 0.015;
    final grow = s.pop(begin, begin + 0.04);
    if (grow <= 0) continue;
    final at =
        from * ((1 - f) * (1 - f)) + bend * (2 * f * (1 - f)) + to * (f * f);
    s.canvas
      ..drawCircle(
        at.translate(0, r * 0.25 * s.unit),
        r * s.unit * grow,
        s.fill(_thoughtTint.shade(-0.12)),
      )
      ..drawCircle(at, r * s.unit * grow, s.fill(_thoughtTint));
  }

  // The cloud swells out of the last bubble, in a warm light of its own.
  final swell = s.pop(_thinks + 0.02, _thinks + 0.08);
  s
    ..glow(cloud, 2.8, strength: swell.clamp(0, 1) * s.storyLight * 0.7)
    ..scaled(to, swell, () => _cloudOfThought(s, cloud, w));

  // The three things, left to right in the order they come: a book, a bulb
  // that lights up, a star that spins in. Each pops up a little above its
  // place and bobs down onto it. The bulb's glow goes down first, so the
  // book beside it is never covered by it.
  ({double grow, double lift}) arrive(double at) => (
    grow: s.pop(at - 0.01, at + 0.05),
    lift: s.drop(at - 0.01, at + 0.06, from: 0.45),
  );
  const bookX = _cloudX - _step;
  const bookY = _cloudY + _step;
  const starX = _cloudX + _step;
  const starY = _cloudY - _step;

  // A warm flash where each one lands, under it.
  _flash(s, s.at(bookX, bookY, _cloudZ), _first);
  _flash(s, s.at(_cloudX, _cloudY, _cloudZ + 0.1), _second);
  _flash(s, s.at(starX, starY, _cloudZ), _third);

  final bulb = arrive(_second);
  final bulbZ = _cloudZ - 0.34 + bulb.lift;
  final bulbAt = s.at(_cloudX, _cloudY, bulbZ);
  final light = s.phase(_second + 0.015, _second + 0.06);
  if (light > 0) {
    s.scaled(bulbAt, bulb.grow, () => _halo(s, _cloudX, _cloudY, bulbZ, light));
  }
  final book = arrive(_first);
  if (book.grow > 0) {
    final z = _cloudZ - 0.18 + book.lift;
    s.scaled(
      s.at(bookX, bookY, z),
      book.grow,
      () => _openBook(s, bookX, bookY, z),
    );
  }
  s.scaled(
    bulbAt,
    bulb.grow,
    () => _bulb(s, _cloudX, _cloudY, bulbZ, light),
  );
  final star = arrive(_third);
  if (star.grow > 0) {
    final c = s.at(starX, starY, _cloudZ + 0.02 + star.lift);
    final spin = (1 - s.phase(_third - 0.01, _third + 0.08)) * math.pi * 3;
    s.scaled(c, star.grow, () => _star(s, c, 0.48 * s.unit, spin));
  }

  // And a little burst of sparkles over it: one, two, three.
  _sparkles(s, s.at(bookX, bookY, _cloudZ), _first);
  _sparkles(s, s.at(_cloudX, _cloudY, _cloudZ + 0.1), _second);
  _sparkles(s, s.at(starX, starY, _cloudZ), _third);

  // Two twinkles that come with the cloud and stay with it.
  const twinkles = [(-0.5, -0.14, 0.18), (0.53, -0.02, 0.14)];
  for (var i = 0; i < twinkles.length; i++) {
    final (dx, dy, r) = twinkles[i];
    final begin = _thinks + 0.05 + i * 0.02;
    final shine = s.pop(begin, begin + 0.05);
    if (shine <= 0) continue;
    _twinkle(s, cloud.translate(w * dx, w * dy), r * s.unit * shine, _glass);
  }
}

/// How far through the moment of something landing at [at] the stage is:
/// `0` before it and again once it is over, so nothing is left of it at
/// rest.
double _landing(IsoStage s, double at) {
  final p = s.phase(at - 0.005, at + 0.08, Curves.linear);
  return p <= 0 || p >= 1 ? 0 : p;
}

/// A soft warm flash at [c] as something lands there at [at]. Draw it before
/// what lands.
void _flash(IsoStage s, Offset c, double at) {
  final p = _landing(s, at);
  if (p <= 0) return;
  s.glow(c, 0.85, strength: 0.8 * math.sin(math.pi * math.sqrt(p)));
}

/// A little burst of sparkles over [c] as something lands there at [at]:
/// they fly out and wink away, so that each arrival is a beat of its own.
void _sparkles(IsoStage s, Offset c, double at) {
  final p = _landing(s, at);
  if (p <= 0) return;
  final out = (0.4 + 0.42 * Curves.easeOutCubic.transform(p)) * s.unit;
  final r = 0.17 * s.unit * math.sin(math.pi * p);
  for (var i = 0; i < 5; i++) {
    final a = math.pi * (1.1 + i * 0.2);
    _twinkle(s, c + Offset(math.cos(a), math.sin(a)) * out, r, _glass);
  }
}

/// The thought cloud centred on [c], [w] pixels wide: rounder and fuller
/// than a weather cloud, with a shaded underside.
void _cloudOfThought(IsoStage s, Offset c, double w) {
  Path body(double dy) {
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: c.translate(0, w * 0.07 + dy),
            width: w,
            height: w * 0.4,
          ),
          Radius.circular(w * 0.2),
        ),
      );
    const lobes = [
      (-0.3, -0.04, 0.17),
      (-0.12, -0.14, 0.21),
      (0.11, -0.15, 0.22),
      (0.31, -0.05, 0.17),
      (-0.16, 0.14, 0.16),
      (0.14, 0.14, 0.17),
    ];
    for (final (dx, ly, r) in lobes) {
      path.addOval(
        Rect.fromCircle(
          center: c.translate(w * dx, w * ly + dy),
          radius: w * r,
        ),
      );
    }
    return path;
  }

  s.canvas
    ..drawPath(body(w * 0.035), s.fill(_thoughtTint.shade(-0.14)))
    ..drawPath(body(0), s.fill(_thoughtTint));
}

/// An open book on the cloud at [x], [y], [z], its spine running towards
/// the viewer and its far end propped up.
void _openBook(IsoStage s, double x, double y, double z) {
  const a = 0.32;
  const w = 0.4;
  const prop = 0.32;
  const rise = 0.08;
  const lip = 0.05;
  V3 p(double sx, double sy, double sz) => (x: x + sx, y: y + sy, z: z + sz);
  // The cover, a little larger than the pages and seen from its edge.
  for (final (dz, tint) in [(-0.07, _cover.shade(-0.14)), (-0.02, _cover)]) {
    s.canvas.drawPath(
      s.face([
        p(-a - lip, -a - lip, prop + dz),
        p(-a + w + lip, -a - w - 2 * lip, prop + dz),
        p(a + w + 2 * lip, a - w - lip, dz),
        p(a + lip, a + lip, dz),
        p(a - w - lip, a + w + 2 * lip, dz),
        p(-a - w - 2 * lip, -a + w + lip, prop + dz),
      ]),
      s.fill(tint),
    );
  }
  // The two pages, curling up from the spine.
  s.canvas
    ..drawPath(
      s.face([
        p(-a, -a, prop),
        p(-a + w, -a - w, prop + rise),
        p(a + w, a - w, rise),
        p(a, a, 0),
      ]),
      s.fill(_page.shade(-0.06)),
    )
    ..drawPath(
      s.face([
        p(-a, -a, prop),
        p(-a - w, -a + w, prop + rise),
        p(a - w, a + w, rise),
        p(a, a, 0),
      ]),
      s.fill(_page),
    );
  // Lines of print across each page: [u] along the spine from its far end,
  // [v] out from the spine to the page's edge, [side] which page.
  Offset on(double u, double v, double side) => s.at(
    x - a + 2 * a * u + side * w * v,
    y - a + 2 * a * u - side * w * v,
    z + prop * (1 - u) + rise * v,
  );
  final ink = s.stroke(_ink, 0.022);
  for (final u in [0.25, 0.45, 0.65]) {
    for (final side in [-1.0, 1.0]) {
      s.canvas.drawLine(on(u, 0.18, side), on(u, 0.82, side), ink);
    }
  }
}

/// The glow round the globe of the bulb standing at [x], [y], [z], [glow]
/// of the way lit: warm at the glass, fading out into the cloud.
void _halo(IsoStage s, double x, double y, double z, double glow) {
  final globe = s.at(x, y, z + 0.46);
  final r = 0.34 * s.unit * 1.15;
  final reach = r * (1 + 0.75 * glow);
  final edge = r / reach;
  s.canvas.drawCircle(
    globe,
    reach,
    Paint()
      ..shader = ui.Gradient.radial(
        globe,
        reach,
        [
          s.colour(_glow.shade(-0.08)),
          s.colour(_glow.shade(-0.14)),
          s.colour(_thoughtTint),
        ],
        [edge, edge + (1 - edge) * 0.4, 1],
      ),
  );
}

/// The light bulb standing at [x], [y], [z]: a screw base and a glass globe
/// that lights up, [glow] of the way, with a fan of rays over it.
void _bulb(IsoStage s, double x, double y, double z, double glow) {
  final globe = s.at(x, y, z + 0.46);
  final r = 0.34 * s.unit * 1.15;
  if (glow > 0) {
    // Upwards only, clear of the book and the star either side.
    final rays = s.stroke(_glass.shade(-0.06), 0.05);
    for (var i = 0; i < 5; i++) {
      final a = math.pi * (1.25 + i * 0.125);
      final dir = Offset(math.cos(a), math.sin(a));
      s.canvas.drawLine(
        globe + dir * (r * 1.9),
        globe + dir * (r * (1.9 + 0.6 * glow)),
        rays,
      );
    }
  }
  s
    ..cylinder(x, y, z, 0.14, 0.26, _metal)
    ..sphere(x, y, z, 0.06, _metal.shade(-0.12));
  final band = s.stroke(_metal.shade(-0.14), 0.02);
  for (final dz in [0.08, 0.16]) {
    s.canvas.drawArc(s.disc(x, y, z + dz, 0.14), 0, math.pi, false, band);
  }
  // The globe ends as the lightest thing in the scene, above its own halo.
  s.sphere(x, y, z + 0.46, 0.34, _glass.at(0.54 + 0.44 * glow));
  // The filament.
  final f = s.at(x, y, z + 0.42);
  s.canvas.drawPath(
    Path()
      ..moveTo(f.dx - r * 0.3, f.dy + r * 0.3)
      ..lineTo(f.dx - r * 0.15, f.dy - r * 0.1)
      ..lineTo(f.dx, f.dy + r * 0.1)
      ..lineTo(f.dx + r * 0.15, f.dy - r * 0.1)
      ..lineTo(f.dx + r * 0.3, f.dy + r * 0.3),
    s.stroke(_glass.shade(-0.3), 0.025),
  );
}

/// A chunky five-pointed star centred on [c], [r] pixels to its points,
/// turned [spin] radians about its upright axis.
void _star(IsoStage s, Offset c, double r, double spin) {
  Path shape(double radius) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final a = -math.pi / 2 + i * math.pi / 5;
      final d = i.isEven ? radius : radius * 0.46;
      final p = Offset(math.cos(a) * d, math.sin(a) * d);
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    return path..close();
  }

  final outline = shape(r);
  s.canvas
    ..save()
    ..translate(c.dx, c.dy)
    ..scale(math.cos(spin).abs().clamp(0.08, 1), 1);
  // Its thickness, stepped out behind it to the lower right, then the face
  // and a raised bevel.
  for (var i = 3; i > 0; i--) {
    s.canvas.drawPath(
      outline.shift(Offset(0.035 * i, 0.03 * i) * s.unit),
      s.fill(_starTint.shade(-0.18)),
    );
  }
  s.canvas
    ..drawPath(outline, s.fill(_starTint))
    ..drawPath(
      shape(r * 0.5).shift(const Offset(-0.02, -0.02) * s.unit),
      s.fill(_starTint.shade(0.12)),
    )
    ..restore();
}
