import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/animation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_full_stack_flutter/core/audio/sound.dart';
import 'package:flutter_full_stack_flutter/features/pronunciation/presentation/scenes/iso_stage.dart';
import 'package:flutter_full_stack_flutter/features/pronunciation/presentation/scenes/script.dart';

// The palette: a corner café on a warm morning. Named for what they are, so
// the drawing below reads as a description of the place.
const _skyTop = Tint(214, 0.68, 0.5);
const _skyMid = Tint(262, 0.45, 0.8);
const _skyLow = Tint(26, 0.8, 0.88);
const _sunBody = Tint(44, 0.9, 0.96);
const _sunHalo = Tint(36, 0.8, 0.78);
const _cloud = Tint(262, 0.28, 1);
const _town = Tint(236, 0.22, 0.74);
const _hill = Tint(140, 0.24, 0.66);
const _grass = Tint(100, 0.42, 0.37);
const _earth = Tint(24, 0.5, 0.3);
const _stone = Tint(26, 0.16, 0.16);
const _paver = Tint(22, 0.5, 0.56);
const _wall = Tint(36, 0.32, 0.84);
const _roofSlate = Tint(214, 0.3, 0.4);
const _caramel = Tint(28, 0.55, 0.58);
const _terracotta = Tint(10, 0.5, 0.42);
const _cream = Tint(40, 0.3, 0.95);
const _espresso = Tint(20, 0.42, 0.14);
const _glassDim = Tint(34, 0.35, 0.34);
const _glow = Tint(42, 0.85, 0.8);
const _teal = Tint(176, 0.58, 0.36);
const _porcelain = Tint(36, 0.3, 0.97);
const _coffee = Tint(20, 0.5, 0.2);
const _crema = Tint(30, 0.62, 0.56);
const _foam = Tint(38, 0.45, 0.97);
const _steam = Tint(215, 0.1, 1);
const _leaves = Tint(122, 0.38, 0.32);
const _leavesLight = Tint(86, 0.4, 0.46);
const _bark = Tint(22, 0.4, 0.2);
const _slate = Tint(196, 0.16, 0.18);
const _chalk = Tint(40, 0.25, 0.97);
const _iron = Tint(210, 0.14, 0.2);
const _bulbOff = Tint(38, 0.3, 0.5);
const _bulbOn = Tint(46, 0.95, 0.9);
const _burlap = Tint(34, 0.36, 0.62);
const _skin = Tint(26, 0.5, 0.72);
// The guest's jumper: a cornflower blue that stands out on the terracotta.
const _jumper = Tint(222, 0.6, 0.52);
const _petalPink = Tint(344, 0.6, 0.62);
const _petalGold = Tint(44, 0.9, 0.66);
const _stem = Tint(110, 0.42, 0.3);

// The terrace: a low paved deck the café and its tables stand on.
const _deckX = 0.2;
const _deckY = 0.3;
const _deckW = 3.5;
const _deckD = 4.5;
const _deckH = 0.06;

// The café, at the back of the deck.
const _cafeX = 0.45;
const _cafeY = 0.5;
const _cafeW = 2.8;
const _cafeD = 1.85;
const _cafeH = 1.6;

// The giant cup, on the lawn to the right of the terrace. Its saucer is
// about 2.2 tiles across but is sorted by its centre, so keep anything that
// stands on the lawn at least 1.5 tiles from here, or it ends up on the
// porcelain.
const _cupX = 4.8;
const _cupY = 3.7;

// The guest's table, a table for one at the terrace's edge, looking out on
// the lawn where the coffee will land; and the chair the guest sits on.
const _tableX = 3.1;
const _tableY = 3.85;
const double _guestX = _tableX - 0.42;
const double _guestY = _tableY;

// The guest is drawn a size up from the furniture, so the sentence's "I"
// reads on a phone; and the seat they sit on, which they are scaled about.
const _guestSize = 1.3;
const double _seat = _deckH + 0.3;

// Where the story is lit: on the guest as they ask, then, once the coffee
// lands, between the guest and the cup.
const _askX = 2.95;
const _askY = 3.85;
const _stageX = 3.7;
const _stageY = 3.8;

// The lamp post at the terrace's front corner, and how tall it is.
const _lampX = 0.45;
const _lampY = 4.55;
const _lampH = 1.4;

typedef _Item = ({double depth, void Function() draw});

/// "I would like a cup of coffee please", in two acts.
///
/// The corner café assembles first: the island rises, the café drops onto
/// its terrace, lights its windows and unrolls its awnings, the tables, the
/// parasol and the string lights come up, the waiter steps out and a guest
/// sits down at a table by the lawn. Then the story, in a pool of light on
/// the guest while the rest of the café sinks back: the guest raises a hand
/// and a speech bubble with a cup in it pops up over them (*would like*);
/// a giant cup drops onto its saucer on the lawn beside them and fills with
/// coffee, the light widening to take it in and the steam curling up (*cup
/// of coffee*); and a heart joins the cup in the bubble as another blooms
/// in the crema, and the guest gives a happy little bounce (*please*). At
/// rest the guest
/// still has their bubble - a cup and a heart - beside the giant cup.
const coffeeScene = SceneScript(
  paintCoffee,
  cues: [
    Cue('would like', _asks),
    Cue('cup of coffee', _served),
    Cue('please', _please),
  ],
  sounds: [
    SceneSound(Sound.pop, _asks),
    SceneSound(Sound.clink, _served),
  ],
);

// The story's beats, on the arrival's clock, in the order the sentence
// says them, which is the order they happen in too: the asking, the
// coffee, the kind word. The cup lands on *cup of coffee* and is full a
// moment later; the hand comes down once it has landed.
const _asks = 0.42;
const _served = 0.56;
const _please = 0.72;

/// Paints [coffeeScene].
void paintCoffee(IsoStage s) {
  s.setting(() {
    _dawn(s);

    final climb = s.phase(0.08, 0.75);
    s.sun(0.8, 0.26 - 0.08 * climb, 0.8, _sunBody, _sunHalo);
    _birds(s, s.phase(0.25, 0.9));

    // Clouds drift in from either side and stop.
    final drift = s.phase(0.15, 0.95);
    s
      ..cloud(s.screen(0.2 - 0.5 * (1 - drift), 0.26), 2.4, _cloud)
      ..cloud(s.screen(0.86 + 0.4 * (1 - drift), 0.55), 1.8, _cloud)
      ..cloud(s.screen(0.1 - 0.4 * (1 - drift), 0.6), 1.3, _cloud);
    _skyline(s, 0.8, _town);
    s.ridge(0.88, 0.8, _hill, seed: 3);

    // How far the light has moved from the guest alone to the guest and
    // the coffee.
    final widen = s.story(
      () => s.phase(_served - 0.06, _served + 0.04, Curves.easeInOut),
    );
    s.rising(0, 0.4, () {
      s
        ..island(grass: _grass, earth: _earth, stone: _stone)
        ..box(_deckX, _deckY, 0, _deckW, _deckD, _deckH, _paver);
      _pavers(s);
      _steppingStones(s);
      // The stage: lit on the guest once the story starts, then widening
      // to take in the lawn beside them as the coffee lands. It stays lit.
      s
        ..pool(
          _askX + (_stageX - _askX) * widen,
          _askY + (_stageY - _askY) * widen,
          1.15 + 0.6 * widen,
          strength: s.storyLight,
        )
        ..dropping(0.22, 0.56, (lift) => _cafe(s, lift));

      final items = <_Item>[
        // The garden around the terrace.
        (
          depth: 5.3,
          draw: () => s.tree(
            4.6,
            0.7,
            leaves: _leaves,
            bark: _bark,
            ground: _grass,
            h: 2.1,
            grow: s.pop(0.4, 0.62),
          ),
        ),
        (
          depth: 7.4,
          draw: () => s.tree(
            5.5,
            1.9,
            leaves: _leavesLight,
            bark: _bark,
            ground: _grass,
            h: 1.45,
            grow: s.pop(0.46, 0.68),
          ),
        ),
        (
          depth: 6.2,
          draw: () => s.pine(
            0.5,
            5.6,
            needles: _leaves,
            bark: _bark,
            ground: _grass,
            h: 1.9,
            grow: s.pop(0.44, 0.66),
          ),
        ),
        (
          depth: 11,
          draw: () =>
              s.bush(5.5, 5.5, _leavesLight, size: 0.9, grow: s.pop(0.6, 0.8)),
        ),
        (
          depth: 9.2,
          draw: () =>
              s.bush(3.4, 5.8, _leaves, size: 0.7, grow: s.pop(0.62, 0.8)),
        ),
        // Clipped bay trees in pots either side of the door.
        (depth: 4.2, draw: () => _pot(s, 1.72, 2.48, s.pop(0.56, 0.7))),
        (depth: 4.98, draw: () => _pot(s, 2.5, 2.48, s.pop(0.58, 0.72))),
        // Box hedges along the front of the terrace, either side of the path.
        (depth: 6.1, draw: () => _hedge(s, 0.3, 1.75, 0.5)),
        (depth: 8.2, draw: () => _hedge(s, 2.78, 0.9, 0.56)),
        // The day's beans, delivered and waiting by the side wall.
        (depth: 4.8, draw: () => _beans(s, s.pop(0.52, 0.66))),
        // Someone's delivery bike, parked by the flowers.
        (depth: 9.95, draw: () => _bicycle(s, 4.1, 5.5, s.pop(0.64, 0.78))),
        // The menu, out by the path where passers-by will see it.
        (depth: 7.05, draw: () => _chalkboard(s, 2.45, 4.6, s.pop(0.6, 0.74))),
        // The waiter, out by the door with a tray, ready.
        _waiter(s, 1.5, 2.66, s.pop(0.6, 0.72)),
        // The tables, each with its chairs; the guest's is a table for one.
        ..._tableSet(s, 1, 3.2, 0.5, pastry: true),
        ..._tableSet(
          s,
          _tableX,
          _tableY,
          0.54,
          guest: true,
          opposite: false,
        ),
        ..._tableSet(s, 1.3, 4.3, 0.58, parasol: true),
        (depth: 5.0, draw: () => _lamp(s, s.pop(0.5, 0.66))),
        // The coffee: a saucer pops up, the cup drops onto it and fills.
        (depth: 8.5, draw: () => s.story(() => _centrepiece(s))),
      ];

      // Flowers in the lawn, opening one after another from the back.
      const beds = [
        (x: 1.1, y: 5.55, tint: _petalPink),
        (x: 1.8, y: 5.75, tint: _petalGold),
        (x: 3.05, y: 5.6, tint: _petalPink),
        (x: 5.0, y: 5.3, tint: _petalGold),
        (x: 4.85, y: 5.85, tint: _petalPink),
        (x: 3.3, y: 5.2, tint: _petalGold),
        (x: 5.85, y: 5.05, tint: _petalPink),
        (x: 5.75, y: 2.35, tint: _petalGold),
        (x: 5.9, y: 2.6, tint: _petalPink),
      ];
      final ordered = [...beds]
        ..sort((a, b) => (a.x + a.y).compareTo(b.x + b.y));
      for (var i = 0; i < ordered.length; i++) {
        final bed = ordered[i];
        final grow = s.pop(0.6 + i * 0.025, 0.78 + i * 0.025);
        items.add((
          depth: bed.x + bed.y,
          draw: () => s.flower(bed.x, bed.y, bed.tint, _stem, grow: grow),
        ));
      }
      items.sort((a, b) => a.depth.compareTo(b.depth));
      for (final item in items) {
        item.draw();
      }

      _stringLights(s);

      // What the guest says, over everything: it is speech, not a thing on
      // the terrace.
      s.story(() => _order(s));

      // The rest of the café steps back while the guest and the coffee have
      // the stage.
      s.spotlight(
        s.at(
          _askX + (_stageX - 0.1 - _askX) * widen,
          _askY + (_stageY - 0.1 - _askY) * widen,
          0.8,
        ),
        radius: 1.7 + 0.5 * widen,
        strength: s.storyLight,
      );
    });
  });
}

/// Mixes two tints of a similar hue, [f] of the way from [a] to [b].
Tint _mix(Tint a, Tint b, double f) => Tint(
  a.hue + (b.hue - a.hue) * f,
  a.saturation + (b.saturation - a.saturation) * f,
  a.level + (b.level - a.level) * f,
);

// ---------------------------------------------------------------- backdrop --

/// A dawn sky: blue overhead, through lilac, to a warm horizon - three stops
/// so the wash does not go grey between a blue and an orange.
void _dawn(IsoStage s) {
  final rect = Offset.zero & s.size;
  s.canvas.drawRect(
    rect,
    Paint()
      ..shader = ui.Gradient.linear(
        rect.topCenter,
        rect.bottomCenter,
        [s.colour(_skyTop), s.colour(_skyMid), s.colour(_skyLow)],
        [0, 0.5, 0.8],
      ),
  );
}

/// Three birds gliding in from the left, [arrive] of the way there.
void _birds(IsoStage s, double arrive) {
  final u = s.unit;
  final path = Path();
  const flock = [(x: 0.07, y: 0.205, w: 0.2), (x: 0.15, y: 0.19, w: 0.15)];
  for (final bird in [...flock, (x: 0.2, y: 0.215, w: 0.12)]) {
    final c = s.screen(bird.x - 0.4 * (1 - arrive), bird.y);
    final w = bird.w * u;
    path
      ..moveTo(c.dx - w, c.dy - w * 0.4)
      ..quadraticBezierTo(c.dx - w * 0.45, c.dy - w * 0.55, c.dx, c.dy)
      ..quadraticBezierTo(
        c.dx + w * 0.45,
        c.dy - w * 0.55,
        c.dx + w,
        c.dy - w * 0.4,
      );
  }
  s.canvas.drawPath(path, s.stroke(_iron.shade(0.2), 0.035));
}

/// A hazy town along the horizon behind the island: flat roofs, gables, a
/// dome and a spire, one silhouette with its base at screen fraction
/// [baseline].
void _skyline(IsoStage s, double baseline, Tint tint) {
  final u = s.unit;
  final base = s.size.height * baseline;
  final path = Path()..moveTo(0, s.size.height);
  var x = 0.0;
  for (var i = 0; x < s.size.width; i++) {
    final w = (0.55 + 0.4 * (0.5 + 0.5 * math.sin(i * 2.3 + 0.7))) * u;
    final h = (0.55 + 0.9 * (0.5 + 0.5 * math.sin(i * 1.7 + 0.4))) * u;
    final top = base - h;
    path.lineTo(x, top);
    switch (i % 6) {
      case 1:
        path.lineTo(x + w / 2, top - 0.32 * u);
      case 3:
        path.arcToPoint(
          Offset(x + w, top),
          radius: Radius.circular(w / 2),
        );
      case 4:
        path
          ..lineTo(x + w * 0.38, top)
          ..lineTo(x + w * 0.5, top - 0.9 * u)
          ..lineTo(x + w * 0.62, top);
    }
    path.lineTo(x + w, top);
    x += w;
  }
  path
    ..lineTo(x, s.size.height)
    ..close();
  s.canvas.drawPath(path, s.fill(tint));
}

// ------------------------------------------------------------------ ground --

/// The deck's paving: every other square a shade darker.
void _pavers(IsoStage s) {
  const z = _deckH + 0.002;
  const cell = 0.5;
  final path = Path();
  for (var i = 0; i < (_deckW / cell).round(); i++) {
    for (var j = 0; j < (_deckD / cell).round(); j++) {
      if ((i + j).isOdd) continue;
      final x = _deckX + i * cell;
      final y = _deckY + j * cell;
      path.addPolygon([
        s.at(x, y, z),
        s.at(x + cell, y, z),
        s.at(x + cell, y + cell, z),
        s.at(x, y + cell, z),
      ], true);
    }
  }
  s.canvas.drawPath(path, s.fill(_paver.shade(-0.08)));
}

/// Stepping stones from the front edge of the island up to the terrace.
void _steppingStones(IsoStage s) {
  final path = Path();
  const stones = [(x: 2.35, y: 5.05), (x: 2.5, y: 5.45), (x: 2.42, y: 5.82)];
  for (final stone in stones) {
    path.addOval(s.disc(stone.x, stone.y, 0.004, 0.16));
  }
  s.canvas.drawPath(path, s.fill(_paver.shade(-0.08)));
}

// ------------------------------------------------------------------- café --

/// The café, [lift] tiles above the deck it will stand on.
void _cafe(IsoStage s, double lift) {
  const x = _cafeX;
  const y = _cafeY;
  const w = _cafeW;
  const d = _cafeD;
  const h = _cafeH;
  const front = y + d;
  const side = x + w;
  final z = _deckH + lift;
  final landing = (1 - lift / 6).clamp(0.0, 1.0);
  final glass = _mix(_glassDim, _glow, s.phase(0.6, 0.8));

  s
    // Its shadow on the deck, a footprint that spreads as it comes down.
    ..patch(
      x,
      y,
      w + 0.28 * landing,
      d + 0.28 * landing,
      _paver.shade(-0.14),
      z: _deckH + 0.003,
    )
    ..box(x, y, z, w, d, h, _wall)
    ..onLeft(front, x, z, w, 0.12, _terracotta)
    ..onRight(side, y, z, d, 0.12, _terracotta.shade(-0.16))
    // The cornice; a chimney through the back of the roof, then the roof.
    ..box(x - 0.06, y - 0.06, z + h, w + 0.12, d + 0.12, 0.1, _caramel)
    ..box(x + 2.1, y + 0.2, z + h, 0.3, 0.3, 0.95, _terracotta.shade(-0.04))
    ..roof(x, y, z + h + 0.1, w, d, 0.62, _roofSlate, overhang: 0.1);
  // Courses of slate across the front slope.
  for (var i = 1; i < 4; i++) {
    final f = i / 4;
    final cy = front + 0.1 - (d / 2 + 0.1) * f;
    final cz = z + h + 0.1 + 0.62 * f;
    s.canvas.drawLine(
      s.at(x - 0.1, cy, cz),
      s.at(side + 0.1, cy, cz),
      s.stroke(_roofSlate.shade(-0.07), 0.02),
    );
  }
  // A wisp from the roaster's chimney.
  _steamCurl(
    s,
    s.at(x + 2.25, y + 0.35, z + h + 0.95),
    0.6,
    1,
    s.phase(0.62, 0.96, Curves.easeInOut),
    width: 0.06,
  );
  // A round window in the gable end.
  final oculus = Path();
  for (var k = 0; k <= 20; k++) {
    final a = k / 20 * 2 * math.pi;
    final o = s.at(
      side,
      y + d / 2 + 0.14 * math.cos(a),
      z + h + 0.32 + 0.14 * math.sin(a),
    );
    k == 0 ? oculus.moveTo(o.dx, o.dy) : oculus.lineTo(o.dx, o.dy);
  }
  s.canvas
    ..drawPath(oculus, s.fill(glass.shade(-0.12)))
    ..drawPath(oculus, s.stroke(_cream.shade(-0.16), 0.03));

  // Front: a window, the door with a step, another window.
  _windowLeft(s, front, x + 0.22, z + 0.24, 0.95, 0.86, glass);
  s
    ..onLeft(front, x + 1.38, z, 0.56, 1.1, _espresso)
    ..onLeft(front, x + 1.42, z, 0.48, 1.06, _roofSlate.shade(-0.08))
    ..onLeft(front, x + 1.49, z + 0.52, 0.34, 0.44, glass)
    ..canvas.drawCircle(
      s.at(x + 1.82, front, z + 0.4),
      0.035 * s.unit,
      s.fill(_petalGold),
    )
    ..box(x + 1.34, front, z, 0.6, 0.2, 0.07, _caramel);
  _windowLeft(s, front, x + 2.2, z + 0.24, 0.4, 0.86, glass);

  // Side: two windows.
  _windowRight(s, side, y + 0.22, z + 0.24, 0.6, 0.86, glass);
  _windowRight(s, side, y + 1.0, z + 0.24, 0.6, 0.86, glass);

  // The awnings unroll once the café has landed.
  _awningRight(s, side, y + 0.12, y + d - 0.3, z + 1.38, s.phase(0.54, 0.7));
  _awningFront(s, front, x + 0.1, x + w - 0.1, z + 1.38, s.phase(0.5, 0.66));
}

/// A window on a left-facing wall at plane [y]: a dark frame, [glass], a
/// café curtain over its lower part and a mullion down the middle.
void _windowLeft(
  IsoStage s,
  double y,
  double x,
  double z,
  double w,
  double h,
  Tint glass,
) {
  const f = 0.05;
  final sill = z + h * 0.38;
  s
    ..onLeft(y, x - f, z - f, w + 2 * f, h + 2 * f, _espresso)
    ..onLeft(y, x, z, w, h, glass)
    ..onLeft(y, x, z, w, h * 0.38, _cream.shade(-0.04))
    ..canvas.drawLine(
      s.at(x + w / 2, y, sill),
      s.at(x + w / 2, y, z + h),
      s.stroke(_espresso, 0.035),
    )
    ..canvas.drawLine(
      s.at(x, y, sill),
      s.at(x + w, y, sill),
      s.stroke(_caramel, 0.03),
    );
}

/// The same window on a right-facing wall at plane [x], in its shade.
void _windowRight(
  IsoStage s,
  double x,
  double y,
  double z,
  double d,
  double h,
  Tint glass,
) {
  const f = 0.05;
  final sill = z + h * 0.38;
  s
    ..onRight(x, y - f, z - f, d + 2 * f, h + 2 * f, _espresso.shade(-0.06))
    ..onRight(x, y, z, d, h, glass.shade(-0.12))
    ..onRight(x, y, z, d, h * 0.38, _cream.shade(-0.18))
    ..canvas.drawLine(
      s.at(x, y + d / 2, sill),
      s.at(x, y + d / 2, z + h),
      s.stroke(_espresso, 0.035),
    )
    ..canvas.drawLine(
      s.at(x, y, sill),
      s.at(x, y + d, sill),
      s.stroke(_caramel.shade(-0.16), 0.03),
    );
}

/// The striped awning over the front wall at plane [y], from [x0] to [x1],
/// hung at [z] and [unroll] of the way out, with a scalloped valance.
void _awningFront(
  IsoStage s,
  double y,
  double x0,
  double x1,
  double z,
  double unroll,
) {
  if (unroll <= 0) return;
  const stripes = 9;
  final out = y + 0.44 * unroll;
  final low = z - 0.17 * unroll;
  final hem = 0.12 * unroll;
  for (var i = 0; i < stripes; i++) {
    final a = x0 + (x1 - x0) * i / stripes;
    final b = x0 + (x1 - x0) * (i + 1) / stripes;
    final tint = i.isEven ? _terracotta : _cream;
    final p = s.at(b, out, low - hem);
    final q = s.at(a, out, low - hem);
    final c = s.at((a + b) / 2, out, low - hem * 2.2);
    s.canvas
      ..drawPath(
        s.face([
          (x: a, y: y, z: z),
          (x: b, y: y, z: z),
          (x: b, y: out, z: low),
          (x: a, y: out, z: low),
        ]),
        s.fill(tint.shade(0.06)),
      )
      ..drawPath(
        Path()
          ..moveTo(s.at(a, out, low).dx, s.at(a, out, low).dy)
          ..lineTo(s.at(b, out, low).dx, s.at(b, out, low).dy)
          ..lineTo(p.dx, p.dy)
          ..quadraticBezierTo(c.dx, c.dy, q.dx, q.dy)
          ..close(),
        s.fill(tint.shade(-0.04)),
      );
  }
}

/// The striped awning over the side wall at plane [x], from [y0] to [y1].
void _awningRight(
  IsoStage s,
  double x,
  double y0,
  double y1,
  double z,
  double unroll,
) {
  if (unroll <= 0) return;
  const stripes = 6;
  final out = x + 0.4 * unroll;
  final low = z - 0.16 * unroll;
  final hem = 0.12 * unroll;
  for (var i = 0; i < stripes; i++) {
    final a = y0 + (y1 - y0) * i / stripes;
    final b = y0 + (y1 - y0) * (i + 1) / stripes;
    final tint = i.isEven ? _terracotta : _cream;
    final p = s.at(out, b, low - hem);
    final q = s.at(out, a, low - hem);
    final c = s.at(out, (a + b) / 2, low - hem * 2.2);
    s.canvas
      ..drawPath(
        s.face([
          (x: x, y: a, z: z),
          (x: x, y: b, z: z),
          (x: out, y: b, z: low),
          (x: out, y: a, z: low),
        ]),
        s.fill(tint.shade(-0.02)),
      )
      ..drawPath(
        Path()
          ..moveTo(s.at(out, a, low).dx, s.at(out, a, low).dy)
          ..lineTo(s.at(out, b, low).dx, s.at(out, b, low).dy)
          ..lineTo(p.dx, p.dy)
          ..quadraticBezierTo(c.dx, c.dy, q.dx, q.dy)
          ..close(),
        s.fill(tint.shade(-0.16)),
      );
  }
}

// --------------------------------------------------------------- terrace --

/// A bistro table at [x], [y] with a chair either side - or, without an
/// [opposite] one, a table for one - popping up from [begin]: one may have
/// the [guest] in it, a croissant ([pastry]) or a [parasol] over it.
/// Returned as items to be sorted into the scene.
List<_Item> _tableSet(
  IsoStage s,
  double x,
  double y,
  double begin, {
  bool guest = false,
  bool pastry = false,
  bool parasol = false,
  bool opposite = true,
}) {
  final grow = s.pop(begin, begin + 0.16);
  final behind = s.pop(begin + 0.03, begin + 0.19);
  final before = s.pop(begin + 0.06, begin + 0.22);
  void at(double gx, double gy, double g, void Function() draw) =>
      s.scaled(s.at(gx, gy, _deckH), g, draw);
  return [
    (
      depth: x + y - 0.42,
      draw: () => at(x - 0.42, y, behind, () {
        _chair(s, x - 0.42, y, 1);
        if (guest) _guest(s, x - 0.42, y, s.pop(begin + 0.1, begin + 0.24));
      }),
    ),
    (
      depth: x + y,
      draw: () => at(x, y, grow, () {
        // The guest's table waits for their order.
        _table(s, x, y, pastry: pastry, set: !guest);
        if (parasol) _parasol(s, x, y, s.pop(0.68, 0.84));
      }),
    ),
    if (opposite)
      (
        depth: x + y + 0.42,
        draw: () => at(x + 0.42, y, before, () => _chair(s, x + 0.42, y, -1)),
      ),
  ];
}

/// A round marble-topped table on an iron stem, [set] with two cups.
void _table(
  IsoStage s,
  double x,
  double y, {
  bool pastry = false,
  bool set = true,
}) {
  const top = _deckH + 0.44;
  s
    ..canvas.drawOval(
      s.disc(x + 0.05, y + 0.05, _deckH + 0.003, 0.3),
      s.fill(_paver.shade(-0.12)),
    )
    ..canvas.drawOval(s.disc(x, y, _deckH + 0.004, 0.1), s.fill(_iron))
    ..cylinder(x, y, _deckH, 0.025, 0.4, _iron)
    ..cylinder(x, y, top - 0.04, 0.3, 0.04, _porcelain.shade(-0.06));
  if (!set) return;
  _smallCup(s, x - 0.1, y + 0.1, top);
  if (pastry) {
    // A croissant on a little plate.
    s.canvas.drawOval(
      s.disc(x + 0.1, y - 0.08, top + 0.004, 0.11),
      s.fill(_porcelain),
    );
    for (var i = 0; i < 3; i++) {
      s.sphere(
        x + 0.04 + i * 0.05,
        y - 0.1 + i * 0.01,
        top + 0.04,
        0.045,
        _caramel.shade(0.06 - 0.04 * (i - 1).abs()),
      );
    }
  } else {
    _smallCup(s, x + 0.1, y - 0.08, top);
  }
}

/// A teal cup on its saucer, at [x], [y] on a table top at [z].
void _smallCup(IsoStage s, double x, double y, double z) {
  s
    ..canvas.drawOval(s.disc(x, y, z + 0.004, 0.08), s.fill(_porcelain))
    ..cylinder(x, y, z, 0.05, 0.07, _teal)
    ..canvas.drawOval(s.disc(x, y, z + 0.07, 0.035), s.fill(_coffee));
}

/// A rattan bistro chair at [x], [y] whose sitter faces along x, [facing]
/// `1` or `-1`: the hoop of its back is on the other side.
void _chair(IsoStage s, double x, double y, double facing) {
  const seat = _deckH + 0.26;
  final bx = x - facing * 0.11;
  final back = Path();
  final foot = s.at(bx, y - 0.1, seat);
  back
    ..moveTo(foot.dx, foot.dy)
    ..lineTo(s.at(bx, y - 0.1, seat + 0.2).dx, s.at(bx, y - 0.1, seat + 0.2).dy)
    ..quadraticBezierTo(
      s.at(bx, y, seat + 0.4).dx,
      s.at(bx, y, seat + 0.4).dy,
      s.at(bx, y + 0.1, seat + 0.2).dx,
      s.at(bx, y + 0.1, seat + 0.2).dy,
    )
    ..lineTo(s.at(bx, y + 0.1, seat).dx, s.at(bx, y + 0.1, seat).dy);
  void legs() {
    for (final c in const [(-1, -1), (1, -1), (-1, 1), (1, 1)]) {
      s.canvas.drawLine(
        s.at(x + c.$1 * 0.09, y + c.$2 * 0.09, _deckH),
        s.at(x + c.$1 * 0.09, y + c.$2 * 0.09, seat),
        s.stroke(_iron, 0.025),
      );
    }
  }

  legs();
  if (facing > 0) s.canvas.drawPath(back, s.stroke(_caramel, 0.04));
  s.box(x - 0.12, y - 0.12, seat, 0.24, 0.24, 0.04, _caramel, edge: false);
  if (facing < 0) s.canvas.drawPath(back, s.stroke(_caramel, 0.04));
}

/// The waiter standing at [x], [y] with a cup on a tray, [grow] of the way
/// out. Returned as an item, to be sorted into the scene.
_Item _waiter(IsoStage s, double x, double y, double grow) {
  const z = _deckH;
  return (
    depth: x + y,
    draw: () {
      if (grow <= 0) return;
      s.scaled(s.at(x, y, z), grow, () {
        final tray = s.at(x - 0.06, y + 0.16, z + 0.56);
        s
          ..canvas.drawOval(
            s.disc(x + 0.03, y + 0.03, z + 0.003, 0.14),
            s.fill(_paver.shade(-0.14)),
          )
          ..cylinder(x, y, z, 0.07, 0.22, _iron.shade(0.06))
          ..cylinder(x, y, z + 0.2, 0.1, 0.36, _porcelain.shade(-0.04))
          ..cylinder(x, y, z + 0.16, 0.105, 0.24, _espresso.shade(0.1))
          ..sphere(x + 0.02, y - 0.03, z + 0.7, 0.08, _espresso)
          ..sphere(x, y, z + 0.67, 0.085, _skin)
          ..canvas.drawLine(
            s.at(x - 0.02, y + 0.08, z + 0.46),
            tray,
            s.stroke(_porcelain.shade(-0.1), 0.05),
          )
          ..canvas.drawOval(
            s.disc(x - 0.06, y + 0.16, z + 0.56, 0.13),
            s.fill(_iron.shade(0.16)),
          );
        _smallCup(s, x - 0.06, y + 0.16, z + 0.56);
      });
    },
  );
}

/// The guest on the chair at [x], [y], facing the table, [grow] of the way
/// there. On the story's clock they raise a hand to order, lower it to the
/// table once the coffee has landed, and give a happy little bounce at
/// *please*.
void _guest(IsoStage s, double x, double y, double grow) {
  if (grow <= 0) return;
  final (:raise, :hop) = s.story(
    () => (
      raise:
          s.phase(_asks - 0.02, _asks + 0.04, Curves.easeOutBack) *
          (1 - s.phase(_served + 0.05, _served + 0.11, Curves.easeInOut)),
      hop: _hop(s),
    ),
  );
  final z = _seat + hop;
  // The near arm, from the shoulder to a hand resting on the table, or
  // raised above the head to catch the waiter's eye.
  final shoulder = s.at(x + 0.01, y + 0.1, z + 0.27);
  final rest = s.at(x + 0.2, y + 0.1, z + 0.13);
  final up = s.at(x - 0.02, y + 0.21, z + 0.8);
  final hand = Offset.lerp(rest, up, raise)!;
  s.scaled(s.at(x, y, _seat), grow * _guestSize, () {
    s
      ..box(x, y - 0.08, z, 0.26, 0.16, 0.07, _iron.shade(0.12))
      ..cylinder(x, y, z, 0.11, 0.32, _jumper)
      ..sphere(x - 0.03, y - 0.02, z + 0.47, 0.085, _espresso)
      ..sphere(x, y, z + 0.44, 0.09, _skin)
      ..canvas.drawLine(
        shoulder,
        hand,
        s.stroke(_jumper.shade(0.06), 0.06),
      )
      ..canvas.drawCircle(hand, 0.05 * s.unit, s.fill(_skin));
  });
}

/// How high the guest bounces for joy at *please*, in tiles.
double _hop(IsoStage s) =>
    0.08 * math.sin(math.pi * s.phase(_please, _please + 0.1, Curves.linear));

/// The guest's order, in a speech bubble over their head: it pops up with a
/// cup in it as they ask, and a heart joins the cup as they say *please*,
/// the bubble widening to make room for it.
void _order(IsoStage s) {
  final grow = s.pop(_asks - 0.01, _asks + 0.06);
  if (grow <= 0) return;
  final kind = s.pop(_please - 0.01, _please + 0.06);
  final widen = kind.clamp(0.0, 1.0);
  // A size up from the world, like the guest, so it reads on a phone.
  final u = s.unit * 1.12;
  // The tail's point, at the guest's face, on the side they face, on their
  // scaled figure.
  final seat = s.at(_guestX, _guestY, _seat);
  final tip =
      seat +
      (s.at(_guestX + 0.07, _guestY - 0.07, _seat + 0.5 + _hop(s)) - seat) *
          _guestSize;
  final left = tip.dx - 0.2 * u;
  final bottom = tip.dy - 0.26 * u;
  final width = (0.94 + 0.46 * widen) * u;
  final height = 0.84 * u;
  final body = RRect.fromRectAndRadius(
    Rect.fromLTWH(left, bottom - height, width, height),
    Radius.circular(height / 2),
  );
  final tail = Path()
    ..moveTo(left + 0.2 * u, bottom - 0.04 * u)
    ..lineTo(tip.dx, tip.dy)
    ..lineTo(left + 0.48 * u, bottom - 0.04 * u)
    ..close();
  final cupAt = Offset(left + 0.47 * u, bottom - height / 2 + 0.05 * u);
  final heartAt = Offset(left + width - 0.36 * u, bottom - height / 2);

  s.scaled(tip, grow, () {
    // A rim round the whole bubble, then its paper over the rim's inside
    // half, so the tail joins the body without a seam.
    final rim = s.stroke(_espresso.shade(0.2), 0.06);
    final paper = s.fill(_porcelain);
    s.canvas
      ..drawRRect(body, rim)
      ..drawPath(tail, rim)
      ..drawRRect(body, paper)
      ..drawPath(tail, paper);
    _cupIcon(s, cupAt, u * 1.1);
    if (kind > 0) _heart(s, heartAt, 0.19 * u * kind, _petalPink);
  });
}

/// A little cup of coffee on its saucer, steaming, drawn flat at [c] - the
/// picture of one, for the speech bubble. [u] is the size of a tile.
void _cupIcon(IsoStage s, Offset c, double u) {
  Offset p(double dx, double dy) => c.translate(dx * u, dy * u);
  final body = Path()
    ..moveTo(p(-0.16, -0.06).dx, p(-0.16, -0.06).dy)
    ..lineTo(p(0.16, -0.06).dx, p(0.16, -0.06).dy)
    ..lineTo(p(0.12, 0.1).dx, p(0.12, 0.1).dy)
    ..quadraticBezierTo(
      p(0.1, 0.15).dx,
      p(0.1, 0.15).dy,
      p(0.05, 0.15).dx,
      p(0.05, 0.15).dy,
    )
    ..lineTo(p(-0.05, 0.15).dx, p(-0.05, 0.15).dy)
    ..quadraticBezierTo(
      p(-0.1, 0.15).dx,
      p(-0.1, 0.15).dy,
      p(-0.12, 0.1).dx,
      p(-0.12, 0.1).dy,
    )
    ..close();
  final handle = Path()
    ..moveTo(p(0.14, -0.01).dx, p(0.14, -0.01).dy)
    ..quadraticBezierTo(
      p(0.27, -0.01).dx,
      p(0.27, -0.01).dy,
      p(0.12, 0.09).dx,
      p(0.12, 0.09).dy,
    );
  Path wisp(double dx) => Path()
    ..moveTo(p(dx, -0.11).dx, p(dx, -0.11).dy)
    ..cubicTo(
      p(dx - 0.06, -0.16).dx,
      p(dx - 0.06, -0.16).dy,
      p(dx + 0.06, -0.2).dx,
      p(dx + 0.06, -0.2).dy,
      p(dx, -0.27).dx,
      p(dx, -0.27).dy,
    );
  final steam = s.stroke(_iron.shade(0.42), 0.035);
  s.canvas
    ..drawOval(
      Rect.fromCenter(center: p(0, 0.16), width: 0.46 * u, height: 0.08 * u),
      s.fill(_caramel.shade(0.1)),
    )
    ..drawPath(handle, s.stroke(_teal, 0.045))
    ..drawPath(body, s.fill(_teal))
    ..drawOval(
      Rect.fromCenter(center: p(0, -0.06), width: 0.32 * u, height: 0.08 * u),
      s.fill(_crema),
    )
    ..drawPath(wisp(-0.06), steam)
    ..drawPath(wisp(0.06), steam);
}

/// A heart drawn flat at [c], [size] from its middle to its sides.
void _heart(IsoStage s, Offset c, double size, Tint tint) {
  final path = Path();
  for (var k = 0; k <= 32; k++) {
    final a = k / 32 * 2 * math.pi;
    final hx = math.pow(math.sin(a), 3).toDouble();
    final hy =
        (13 * math.cos(a) -
            5 * math.cos(2 * a) -
            2 * math.cos(3 * a) -
            math.cos(4 * a)) /
        16;
    final o = c.translate(size * hx, -size * (hy + 0.2));
    k == 0 ? path.moveTo(o.dx, o.dy) : path.lineTo(o.dx, o.dy);
  }
  s.canvas.drawPath(path..close(), s.fill(tint));
}

/// A parasol over the table at [x], [y], [open] of the way open: striped
/// panels round a finial, their hems scalloped between the ribs.
void _parasol(IsoStage s, double x, double y, double open) {
  const z = _deckH + 1.05;
  s.canvas.drawLine(
    s.at(x, y, _deckH + 0.44),
    s.at(x, y, z + 0.1),
    s.stroke(_iron, 0.035),
  );
  if (open <= 0) return;
  final r = 0.72 * open;
  final apex = s.at(x, y, z + 0.3 * open);
  const panels = 12;
  for (var i = 0; i < panels; i++) {
    final a0 = 2 * math.pi * i / panels;
    final a1 = 2 * math.pi * (i + 1) / panels;
    final am = (a0 + a1) / 2;
    final p0 = s.at(x + r * math.cos(a0), y + r * math.sin(a0), z);
    final p1 = s.at(x + r * math.cos(a1), y + r * math.sin(a1), z);
    final c = s.at(x + r * math.cos(am), y + r * math.sin(am), z - 0.1);
    final tint = i.isEven ? _terracotta : _cream;
    s.canvas.drawPath(
      Path()
        ..moveTo(apex.dx, apex.dy)
        ..lineTo(p0.dx, p0.dy)
        ..quadraticBezierTo(c.dx, c.dy, p1.dx, p1.dy)
        ..close(),
      s.fill(tint.shade(0.04 - 0.08 * math.cos(am) - 0.02 * math.sin(am))),
    );
  }
  s.sphere(x, y, z + 0.32 * open, 0.04, _caramel);
}

/// A terracotta pot at [x], [y] with a clipped bay tree in it.
void _pot(IsoStage s, double x, double y, double grow) {
  if (grow <= 0) return;
  s.scaled(s.at(x, y, _deckH), grow, () {
    s.canvas.drawOval(
      s.disc(x + 0.04, y + 0.04, _deckH + 0.003, 0.2),
      s.fill(_paver.shade(-0.12)),
    );
    _frustum(s, x, y, _deckH, 0.1, 0.14, 0.22, _terracotta);
    s
      ..canvas.drawLine(
        s.at(x, y, _deckH + 0.2),
        s.at(x, y, _deckH + 0.36),
        s.stroke(_bark, 0.03),
      )
      ..sphere(x, y, _deckH + 0.42, 0.14, _leaves);
  });
}

/// The chalkboard sign at [x], [y], an A-frame facing the street.
void _chalkboard(IsoStage s, double x, double y, double grow) {
  if (grow <= 0) return;
  const w = 0.42;
  const h = 0.62;
  const lean = 0.16;
  const z = _deckH;
  Offset p(double u, double v) => s.at(x + u, y - lean * v, z + h * v);
  Path quad(double u0, double v0, double u1, double v1) => Path()
    ..moveTo(p(u0, v0).dx, p(u0, v0).dy)
    ..lineTo(p(u1, v0).dx, p(u1, v0).dy)
    ..lineTo(p(u1, v1).dx, p(u1, v1).dy)
    ..lineTo(p(u0, v1).dx, p(u0, v1).dy)
    ..close();

  s.scaled(s.at(x + w / 2, y, z), grow, () {
    final chalk = s.stroke(_chalk, 0.022);
    final cup = Path()
      ..moveTo(p(0.13, 0.62).dx, p(0.13, 0.62).dy)
      ..lineTo(p(0.15, 0.44).dx, p(0.15, 0.44).dy)
      ..lineTo(p(0.27, 0.44).dx, p(0.27, 0.44).dy)
      ..lineTo(p(0.29, 0.62).dx, p(0.29, 0.62).dy)
      ..moveTo(p(0.29, 0.58).dx, p(0.29, 0.58).dy)
      ..quadraticBezierTo(
        p(0.36, 0.54).dx,
        p(0.36, 0.54).dy,
        p(0.28, 0.49).dx,
        p(0.28, 0.49).dy,
      )
      ..moveTo(p(0.18, 0.68).dx, p(0.18, 0.68).dy)
      ..quadraticBezierTo(
        p(0.15, 0.75).dx,
        p(0.15, 0.75).dy,
        p(0.19, 0.82).dx,
        p(0.19, 0.82).dy,
      )
      ..moveTo(p(0.24, 0.68).dx, p(0.24, 0.68).dy)
      ..quadraticBezierTo(
        p(0.21, 0.75).dx,
        p(0.21, 0.75).dy,
        p(0.25, 0.82).dx,
        p(0.25, 0.82).dy,
      )
      ..moveTo(p(0.1, 0.3).dx, p(0.1, 0.3).dy)
      ..lineTo(p(0.32, 0.3).dx, p(0.32, 0.3).dy)
      ..moveTo(p(0.13, 0.2).dx, p(0.13, 0.2).dy)
      ..lineTo(p(0.27, 0.2).dx, p(0.27, 0.2).dy);
    s.canvas
      ..drawLine(
        s.at(x + w * 0.85, y - lean * 2, z),
        p(w * 0.85, 1),
        s.stroke(_caramel.shade(-0.16), 0.03),
      )
      ..drawPath(quad(0, 0.08, w, 1), s.fill(_caramel))
      ..drawPath(quad(0.04, 0.13, w - 0.04, 0.94), s.fill(_slate))
      ..drawPath(cup, chalk);
  });
}

/// A clipped box hedge along the front of the terrace, from [x] for [w]
/// tiles: it grows up out of the lawn from [begin], then flowers.
void _hedge(IsoStage s, double x, double w, double begin) {
  const y = _deckY + _deckD + 0.05;
  const d = 0.22;
  const h = 0.26;
  final grow = s.pop(begin, begin + 0.14);
  if (grow <= 0) return;
  s.box(x, y, 0, w, d, h * grow, _leaves.shade(0.04));
  final bloom = s.pop(begin + 0.12, begin + 0.26);
  if (bloom <= 0) return;
  final n = (w / 0.3).floor();
  for (var i = 0; i < n; i++) {
    s.canvas.drawCircle(
      s.at(x + (i + 0.5) * w / n, y + d * (i.isEven ? 0.3 : 0.7), h + 0.02),
      0.055 * s.unit * bloom,
      s.fill(i % 3 == 0 ? _petalGold : _petalPink),
    );
  }
}

/// A crate of beans and two sacks on the lawn by the café's side wall,
/// [grow] of the way there.
void _beans(IsoStage s, double grow) {
  if (grow <= 0) return;
  s.scaled(s.at(4, 1.2), grow, () {
    s
      ..shadow(4, 1.25, 0.5, _grass)
      ..box(3.8, 0.7, 0, 0.36, 0.36, 0.28, _caramel.shade(-0.08));
    for (var i = 0; i < 5; i++) {
      s.sphere(
        3.88 + (i % 3) * 0.1,
        0.8 + (i ~/ 3) * 0.12 + (i % 2) * 0.04,
        0.32,
        0.045,
        _coffee,
      );
    }
    s
      ..cylinder(4.1, 1.32, 0, 0.15, 0.22, _burlap)
      ..sphere(4.1, 1.32, 0.24, 0.13, _burlap.shade(0.04))
      ..cylinder(3.92, 1.58, 0, 0.14, 0.2, _burlap.shade(-0.04))
      ..sphere(3.92, 1.58, 0.22, 0.12, _burlap);
  });
}

/// A delivery bicycle parked side-on at [x], [y], a sack of beans in its
/// front basket, [grow] of the way there.
void _bicycle(IsoStage s, double x, double y, double grow) {
  if (grow <= 0) return;
  const r = 0.2;
  const base = 0.64;
  Offset p(double u, double v) => s.at(x + u, y, v);
  Path through(List<Offset> points) {
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final o in points.skip(1)) {
      path.lineTo(o.dx, o.dy);
    }
    return path;
  }

  Path wheel(double u) => through([
    for (var k = 0; k <= 20; k++)
      p(
        u + r * math.cos(k / 20 * 2 * math.pi),
        r + r * math.sin(k / 20 * 2 * math.pi),
      ),
  ]);

  // The basket on the front: where it starts along the bike, how long,
  // wide and deep it is, and how high its floor.
  const bu = 0.52;
  const bl = 0.24;
  const bw = 0.2;
  const bh = 0.15;
  const floor = 0.42;

  // A size up from life, so it still reads as a bicycle on a phone.
  final anchor = p(base / 2, 0);
  final size = grow * 1.25;
  s.scaled(anchor, size, () {
    final tyre = s.stroke(_iron, 0.035);
    final tube = s.stroke(_terracotta.shade(0.08), 0.04);
    s.canvas
      ..drawOval(
        s.disc(x + base / 2, y + 0.05, 0.002, 0.22),
        s.fill(_grass.shade(-0.14)),
      )
      ..drawPath(wheel(0), tyre)
      ..drawPath(wheel(base), tyre)
      ..drawPath(
        through([p(0, r), p(0.27, r), p(0.2, 0.46), p(0, r)]),
        tube,
      )
      ..drawPath(
        through([p(0.27, r), p(0.53, 0.44), p(0.2, 0.44)]),
        tube,
      )
      ..drawPath(through([p(0.53, 0.44), p(base, r)]), tube)
      ..drawPath(
        through([p(0.53, 0.44), p(0.51, 0.56), p(0.44, 0.58)]),
        s.stroke(_iron, 0.03),
      )
      ..drawLine(p(0.13, 0.5), p(0.25, 0.5), s.stroke(_espresso, 0.06));
    s
      ..box(x + bu, y - bw / 2, floor, bl, bw, bh, _caramel)
      ..sphere(x + 0.63, y, 0.62, 0.09, _caramel.shade(0.18));
  });

  // The cat, in the basket: drawn after the bike, at the bike's size-up.
  Offset sized(double u, double v, double z) =>
      anchor + (s.at(x + u, y + v, z) - anchor) * size;
  _cat(
    s,
    left: sized(bu, bw / 2, floor + bh),
    front: sized(bu + bl, bw / 2, floor + bh),
    right: sized(bu + bl, -bw / 2, floor + bh),
    // A little back from the middle of the floor, clear of the saucer.
    seat: sized(0.6, 0.02, floor),
  );
}

/// The black cat, in the delivery bike's basket - the scene's easter egg
/// (see `HidingCat`). It sits low in the basket, the tips of its ears over
/// the rim; when it has a reason it sits up in the basket, and settles back
/// down. [left], [front] and [right] are the corners of the basket's near
/// rim on the screen, and [seat] the spot on its floor the cat sits on.
void _cat(
  IsoStage s, {
  required Offset left,
  required Offset front,
  required Offset right,
  required Offset seat,
}) {
  // Only once the bike has popped up and settled.
  if (s.t < 0.8) return;
  final above = front.translate(0, -s.unit);
  s.hidingCat(
    hidden: seat.translate(0, 0.5 * s.unit),
    out: seat,
    reveal: Path.combine(
      PathOperation.intersect,
      s.beyond(left, front, of: above),
      s.beyond(front, right, of: above),
    ),
    // Its tail on the side away from the cup.
    flip: true,
  );
}

/// The lamp post at the terrace's corner: its lantern lights with the
/// string lights.
void _lamp(IsoStage s, double grow) {
  if (grow <= 0) return;
  const x = _lampX;
  const y = _lampY;
  const top = _deckH + _lampH;
  final lit = _mix(_bulbOff, _bulbOn, s.phase(0.7, 0.8));
  s.scaled(s.at(x, y, _deckH), grow, () {
    s
      ..canvas.drawOval(
        s.disc(x + 0.04, y + 0.04, _deckH + 0.003, 0.14),
        s.fill(_paver.shade(-0.12)),
      )
      ..cylinder(x, y, _deckH, 0.07, 0.1, _iron)
      ..cylinder(x, y, _deckH, 0.03, _lampH, _iron)
      ..box(x - 0.07, y - 0.07, top, 0.14, 0.14, 0.18, lit, edge: false)
      ..cone(x, y, top + 0.18, 0.13, 0.12, _iron);
  });
}

/// Festoon lights from the café's corner to the lamp post, coming on one
/// bulb after another.
void _stringLights(IsoStage s) {
  if (s.t < 0.6) return;
  const a = (x: _cafeX + 0.02, y: _cafeY + _cafeD + 0.02, z: _deckH + 1.3);
  const b = (x: _lampX, y: _lampY, z: _deckH + _lampH + 0.1);
  V3 along(double f) => (
    x: a.x + (b.x - a.x) * f,
    y: a.y + (b.y - a.y) * f,
    z: a.z + (b.z - a.z) * f - 0.35 * 4 * f * (1 - f),
  );
  final hang = s.phase(0.6, 0.7);
  final wire = Path();
  const steps = 16;
  for (var k = 0; k <= steps; k++) {
    final q = along(k / steps * hang);
    final o = s.at(q.x, q.y, q.z);
    k == 0 ? wire.moveTo(o.dx, o.dy) : wire.lineTo(o.dx, o.dy);
  }
  s.canvas.drawPath(wire, s.stroke(_iron, 0.015));
  const bulbs = 8;
  for (var i = 0; i < bulbs; i++) {
    final f = (i + 0.5) / bulbs;
    if (f > hang) break;
    final q = along(f);
    final on = s.phase(0.72 + i * 0.025, 0.76 + i * 0.025);
    final bulb = s.at(q.x, q.y, q.z - 0.05);
    if (on > 0) {
      s.canvas.drawCircle(
        bulb,
        0.12 * s.unit * on,
        s.fill(_bulbOn.shade(-0.1)),
      );
    }
    s.canvas.drawCircle(
      bulb,
      0.05 * s.unit,
      s.fill(_mix(_bulbOff, _bulbOn, on)),
    );
  }
}

// ------------------------------------------------------------- centrepiece --

/// The giant cup, on the story's clock: a saucer pops up on the lawn, the
/// cup drops onto it and fills with coffee, the steam curls up, and a heart
/// opens in the crema at *please*, the cup glowing warm round it.
void _centrepiece(IsoStage s) {
  const x = _cupX;
  const y = _cupY;
  final warm = s.phase(_please - 0.01, _please + 0.05);
  final settle = s.phase(_please + 0.06, _please + 0.2);
  s.glow(
    s.at(x, y, 1.15),
    1.6,
    strength: warm * (1 - 0.4 * settle) * s.storyLight,
  );
  final saucer = s.pop(_served - 0.04, _served + 0.01);
  if (saucer > 0) {
    s
      ..shadow(x + 0.1, y + 0.1, 1.25 * saucer, _grass)
      ..scaled(s.at(x, y), saucer, () {
        _frustum(s, x, y, 0, 0.85, 1.12, 0.12, _porcelain);
        s.canvas.drawOval(
          s.disc(x, y, 0.12, 0.72),
          s.stroke(_porcelain.shade(-0.1), 0.03),
        );
      });
  }
  // It lands on the *cup of coffee* beat, and is full a moment later.
  s.dropping(_served - 0.04, _served + 0.07, from: 4, (lift) {
    _giantCup(
      s,
      x,
      y,
      0.12 + lift,
      fill: s.phase(_served, _served + 0.07, Curves.easeInOut),
      heart: s.pop(_please, _please + 0.07),
    );
  });
  final steam = s.phase(_served + 0.03, _served + 0.2, Curves.easeInOut);
  if (steam > 0) {
    // From the back of the cup, so the heart in the crema stays clear.
    final from = s.at(x - 0.3, y - 0.3, 1.3);
    const curls = [(dx: -0.24, h: 1.7, ph: 0.0), (dx: 0.07, h: 2.2, ph: 2.1)];
    for (final c in [...curls, (dx: 0.36, h: 1.5, ph: 4.0)]) {
      _steamCurl(
        s,
        from.translate(c.dx * s.unit, 0),
        c.h,
        c.ph,
        steam,
        width: 0.11,
      );
    }
  }
}

/// The giant cup itself at [x], [y] from [z]: teal outside, porcelain
/// inside, [fill] of the way full, with a heart [heart] of the way open.
void _giantCup(
  IsoStage s,
  double x,
  double y,
  double z, {
  required double fill,
  required double heart,
}) {
  const rb = 0.6;
  const rt = 0.88;
  const h = 1.15;
  const wall = 0.07;
  double radius(double at) => rb + (rt - rb) * (at - z) / h;

  // The handle first, so the cup's side covers where it joins.
  const r2 = math.sqrt1_2;
  final handle = Path();
  for (var k = 0; k <= 16; k++) {
    final a = k / 16 * math.pi;
    final hz = z + h * 0.82 - h * 0.56 * (1 - math.cos(a)) / 2;
    final reach = radius(hz) - 0.06 + 0.4 * math.sin(a);
    final o = s.at(x + reach * r2, y - reach * r2, hz);
    k == 0 ? handle.moveTo(o.dx, o.dy) : handle.lineTo(o.dx, o.dy);
  }
  s.canvas
    ..drawPath(handle, s.stroke(_teal.shade(-0.1), 0.15))
    ..drawPath(handle, s.stroke(_teal.shade(0.06), 0.05));

  _frustum(s, x, y, z, rb, rt, h, _teal);
  // A cream band round the cup, near the top.
  _frustum(
    s,
    x,
    y,
    z + h * 0.72,
    radius(z + h * 0.72),
    radius(z + h * 0.84),
    h * 0.12,
    _cream,
    lid: false,
  );

  final top = z + h;
  final inner = s.disc(x, y, top, rt - wall);
  s.canvas
    ..drawOval(s.disc(x, y, top, rt), s.fill(_teal.shade(0.16)))
    ..drawOval(inner, s.fill(_porcelain.shade(-0.14)));
  if (fill <= 0) return;

  final level = z + 0.12 + (h - 0.26) * fill;
  final r = radius(level) - wall;
  s.canvas
    ..save()
    ..clipPath(Path()..addOval(inner))
    ..drawOval(s.disc(x, y, level, r), s.fill(_coffee))
    ..drawOval(s.disc(x, y, level, r * 0.84), s.fill(_crema));
  if (heart > 0) {
    // The heart lies flat on the coffee, its point toward the viewer.
    final size = r * 0.48 * heart;
    final path = Path();
    for (var k = 0; k <= 32; k++) {
      final a = k / 32 * 2 * math.pi;
      final hx = math.pow(math.sin(a), 3) * 16 / 17;
      final hy =
          (13 * math.cos(a) -
              5 * math.cos(2 * a) -
              2 * math.cos(3 * a) -
              math.cos(4 * a)) /
          17;
      // Screen right is world (1, -1), screen up is world (-1, -1).
      final u = size * hx * r2;
      final v = size * (hy + 0.15) * r2;
      final o = s.at(x + u - v, y - u - v, level);
      k == 0 ? path.moveTo(o.dx, o.dy) : path.lineTo(o.dx, o.dy);
    }
    s.canvas.drawPath(path..close(), s.fill(_foam));
  }
  s.canvas.restore();
}

/// One curl of steam rising [height] tiles from [from], drawn [progress] of
/// its length, swaying from [phase].
void _steamCurl(
  IsoStage s,
  Offset from,
  double height,
  double phase,
  double progress, {
  double width = 0.09,
}) {
  if (progress <= 0) return;
  final path = Path()..moveTo(from.dx, from.dy);
  const steps = 28;
  for (var k = 1; k <= steps; k++) {
    final f = k / steps;
    final sway = 0.16 * (0.4 + 0.6 * f) * math.sin(f * math.pi * 2.6 + phase);
    path.lineTo(from.dx + sway * s.unit, from.dy - height * s.unit * f);
  }
  final metric = path.computeMetrics().first;
  final drawn = metric.extractPath(0, metric.length * progress);
  // A soft rim under the curl, so it holds against pale walls too.
  s.canvas
    ..drawPath(drawn, s.stroke(_steam.at(0.84), width * 1.5))
    ..drawPath(drawn, s.stroke(_steam, width));
}

/// A frustum standing at [x], [y] from [z]: radius [rb] at the foot and
/// [rt] at the top, [h] tall, shaded across like the kit's cylinder. Without
/// a [lid] it is a band round something else.
void _frustum(
  IsoStage s,
  double x,
  double y,
  double z,
  double rb,
  double rt,
  double h,
  Tint tint, {
  bool lid = true,
}) {
  final base = s.disc(x, y, z, rb);
  final top = s.disc(x, y, z + h, rt);
  final side = Path()
    ..moveTo(base.left, base.center.dy)
    ..arcTo(base, math.pi, -math.pi, false)
    ..lineTo(top.right, top.center.dy);
  if (lid) {
    side.lineTo(top.left, top.center.dy);
  } else {
    side.arcTo(top, 0, math.pi, false);
  }
  side.close();
  s.canvas.drawPath(
    side,
    Paint()
      ..shader = ui.Gradient.linear(
        Offset(top.left, 0),
        Offset(top.right, 0),
        [
          s.colour(tint.shade(0.06)),
          s.colour(tint),
          s.colour(tint.shade(-0.18)),
        ],
        [0, 0.4, 1],
      ),
  );
  if (lid) s.canvas.drawOval(top, s.fill(tint.shade(0.14)));
}
