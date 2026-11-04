import 'dart:math' as math;

import 'package:flutter/animation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_full_stack_flutter/core/audio/sound.dart';
import 'package:flutter_full_stack_flutter/features/pronunciation/presentation/scenes/iso_stage.dart';
import 'package:flutter_full_stack_flutter/features/pronunciation/presentation/scenes/script.dart';

// The palette: New York harbour at dusk. A violet sky going to peach over
// the sun setting behind Manhattan, the skyline with its windows coming on,
// the water catching the last light; on Liberty Island, the granite of the
// star fort and the pedestal, and the statue in her verdigris, torch alight.
const _skyTop = Tint(234, 0.42, 0.56);
const _skyLow = Tint(22, 0.72, 0.88);
const _sunBody = Tint(30, 0.86, 0.98);
const _sunHalo = Tint(18, 0.72, 0.8);
const _city = Tint(236, 0.24, 0.36);
const _cityFar = Tint(240, 0.2, 0.5);
const _windowLit = Tint(44, 0.86, 0.84);
const _harbour = Tint(216, 0.44, 0.44);
const _glint = Tint(28, 0.66, 0.78);
const _grass = Tint(108, 0.4, 0.48);
const _earth = Tint(26, 0.42, 0.34);
const _stone = Tint(28, 0.14, 0.22);
const _wall = Tint(36, 0.2, 0.7);
const _court = Tint(40, 0.16, 0.8);
const _granite = Tint(32, 0.16, 0.72);
const _opening = Tint(30, 0.18, 0.4);
const _copper = Tint(166, 0.34, 0.58);
const _flame = Tint(40, 0.95, 0.64);
const _flameLight = Tint(48, 1, 0.92);
const _leaves = Tint(132, 0.38, 0.34);
const _leavesLight = Tint(112, 0.38, 0.44);
const _bark = Tint(22, 0.4, 0.22);
const _heart = Tint(350, 0.82, 0.64);
const _sparkGold = Tint(44, 0.92, 0.78);
const _sparkBlue = Tint(206, 0.72, 0.74);

/// The middle of the star fort, where the pedestal stands.
const _cx = 3.0;
const _cy = 3.0;

/// How high the fort's walls stand, and where the statue's feet are: on top
/// of the pedestal on top of them.
const _walls = 0.3;
const double _feet = _walls + 1.32;

/// How much bigger than the pedestal would have her the statue is drawn:
/// she is the subject, and a true-to-scale figure would be a speck.
const _heroic = 1.35;

/// New York, in two acts.
///
/// The harbour assembles first: the island rises at dusk in front of the
/// Manhattan skyline, the star fort spreads out on it, the pedestal lands in
/// the middle of it and the statue on top, torch alight. Then the story, the
/// joke of the piece: the torch flares, and fires a rocket - whistling up
/// over the harbour to burst into a heart, and two smaller bursts after it,
/// over the city, to a Broadway brass fanfare. At rest the sky is clear
/// again and the torch burns on.
const newYorkScene = SceneScript(
  paintNewYork,
  cues: [],
  sounds: [SceneSound(Sound.fanfare, _burst)],
);

// The story's beats, on the arrival's clock.
const _flare = 0.37;
const _launch = 0.41;
const _burst = 0.56;
const _second = 0.62;
const _third = 0.68;

/// Paints [newYorkScene].
void paintNewYork(IsoStage s) {
  s.setting(() {
    // The backdrop is placed from the horizon behind the island, in tiles,
    // so it stands where it should behind it on any canvas.
    double down(double tiles) => (s.horizon + tiles * s.unit) / s.size.height;
    s
      ..sky(_skyTop, _skyLow)
      ..sun(
        s.origin.dx / s.size.width,
        down(-1.1),
        1,
        _sunBody,
        _sunHalo,
        rings: 2,
      );
    _skyline(s, s.phase(0.05, 0.55));
    _harbourWater(s);

    s.rising(0, 0.42, () {
      s.island(grass: _grass, earth: _earth, stone: _stone);
      _trees(s, front: false);
      _fort(s, s.pop(0.14, 0.4));
      s
        ..patch(_cx - 0.22, _cy + 2.05, 0.44, 0.95, _court)
        ..dropping(0.24, 0.48, (lift) => _pedestal(s, lift))
        ..dropping(0.4, 0.66, (lift) => _statue(s, lift), from: 5);
      _trees(s, front: true);
      s.spotlight(
        s.at(_cx, _cy, _feet + 1),
        radius: 2.4,
        strength: s.storyLight * 0.5,
      );
    });
    // Over the spotlight's veil, so the sky's show is never dimmed.
    _fireworks(s);
  });
}

/// Manhattan along the horizon behind the island: a row of towers with
/// their windows coming on, One World Trade Center on the left and the
/// Empire State on the right, all rising into place as [rise] goes to one.
void _skyline(IsoStage s, double rise) {
  if (rise <= 0) return;
  final u = s.unit;
  final base = s.horizon + u * 0.3;
  final random = math.Random(3);
  final body = s.fill(_city);
  final far = s.fill(_cityFar);
  final lit = s.fill(_windowLit);

  // A farther, paler row first, then the near one in front of it.
  for (final (paint, tall, seed) in [(far, 1.0, 5), (body, 1.6, 3)]) {
    final rows = math.Random(seed);
    var x = -u * 0.3;
    while (x < s.size.width) {
      final w = u * (0.42 + rows.nextDouble() * 0.5);
      final h = u * (0.7 + rows.nextDouble() * tall) * rise;
      s.canvas.drawRect(
        Rect.fromLTRB(x, base - h, x + w - u * 0.05, base),
        paint,
      );
      if (paint == body) {
        for (var wy = base - h + u * 0.18; wy < base - u * 0.1; wy += u * 0.2) {
          for (var wx = x + u * 0.08; wx < x + w - u * 0.12; wx += u * 0.14) {
            if (random.nextDouble() < 0.3) {
              s.canvas.drawRect(
                Rect.fromLTWH(wx, wy, u * 0.06, u * 0.07),
                lit,
              );
            }
          }
        }
      }
      x += w;
    }
  }

  // One World Trade Center: a square shaft tapering to a point, its spire.
  // Placed from the island, not the screen: wherever the page puts it,
  // they stand either side of it.
  final wtc = s.origin.dx - u * 4.3;
  final wtcTop = base - u * 4.4 * rise;
  s.canvas
    ..drawPath(
      Path()
        ..moveTo(wtc - u * 0.45, base)
        ..lineTo(wtc - u * 0.45, base - u * 0.9 * rise)
        ..lineTo(wtc - u * 0.12, wtcTop)
        ..lineTo(wtc + u * 0.12, wtcTop)
        ..lineTo(wtc + u * 0.45, base - u * 0.9 * rise)
        ..lineTo(wtc + u * 0.45, base)
        ..close(),
      body,
    )
    ..drawLine(
      Offset(wtc, wtcTop),
      Offset(wtc, wtcTop - u * 0.9 * rise),
      s.stroke(_city, 0.05),
    );

  // The Empire State: set back and set back again, the mast on top.
  final esb = s.origin.dx + u * 4.3;
  for (final (half, top) in const [
    (0.5, 2.6),
    (0.36, 3.3),
    (0.22, 3.75),
    (0.12, 4.05),
  ]) {
    s.canvas.drawRect(
      Rect.fromLTRB(
        esb - u * half,
        base - u * top * rise,
        esb + u * half,
        base,
      ),
      body,
    );
  }
  s.canvas.drawLine(
    Offset(esb, base - u * 4.05 * rise),
    Offset(esb, base - u * 4.9 * rise),
    s.stroke(_city, 0.06),
  );
}

/// The harbour along the bottom of the sky, the island floating over it,
/// with the sunset lying on the water in streaks.
void _harbourWater(IsoStage s) {
  final top = s.horizon + s.unit * 0.3;
  s.canvas.drawRect(
    Rect.fromLTRB(0, top, s.size.width, s.size.height),
    s.fill(_harbour),
  );
  final shine = s.stroke(_glint, 0.06);
  for (final (fx, tiles, w) in const [
    (0.5, 0.5, 1.6),
    (0.46, 1.1, 1.1),
    (0.55, 1.8, 0.8),
    (0.12, 2.6, 0.6),
    (0.88, 3.4, 0.7),
    (0.3, 4.4, 0.5),
  ]) {
    final c = Offset(s.size.width * fx, top + tiles * s.unit);
    s.canvas.drawLine(
      c.translate(-w * s.unit / 2, 0),
      c.translate(w * s.unit / 2, 0),
      shine,
    );
  }
}

/// The trees round the edge of the island, clear of the fort: the ones
/// behind it, or the ones in front.
void _trees(IsoStage s, {required bool front}) {
  // None at the back corner: it is straight behind the statue.
  for (final (x, y, h, at) in const [
    (0.55, 3.4, 1.15, 0.34),
    (3.4, 0.55, 1.25, 0.38),
    (0.75, 5.3, 1.15, 0.42),
    (5.55, 1.6, 0.95, 0.46),
    (1.6, 5.55, 0.95, 0.5),
  ]) {
    if ((x + y > IsoStage.span) != front) continue;
    s.tree(
      x,
      y,
      leaves: x > y ? _leaves : _leavesLight,
      bark: _bark,
      ground: _grass,
      h: h,
      grow: s.pop(at, at + 0.2),
    );
  }
}

/// Fort Wood, the eleven-pointed star the statue stands in: its granite
/// walls, the court inside them, spreading out from the middle as [grow]
/// goes to one.
void _fort(IsoStage s, double grow) {
  if (grow <= 0) return;
  Path star(double z, double outer, double inner) {
    final path = Path();
    for (var k = 0; k < 22; k++) {
      final r = (k.isEven ? outer : inner) * grow;
      final a = -math.pi * 3 / 4 + k * math.pi / 11;
      final p = s.at(_cx + r * math.cos(a), _cy + r * math.sin(a), z);
      k == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    return path..close();
  }

  // The walls are the star at the foot and at the top: the band between
  // them, along the front, is the wall's face.
  s.canvas
    ..drawPath(star(0.002, 2.05, 1.45), s.fill(_wall.shade(-0.2)))
    ..drawPath(star(_walls * grow, 2.05, 1.45), s.fill(_wall))
    ..drawPath(star(_walls * grow + 0.003, 1.7, 1.2), s.fill(_court));
}

/// The pedestal, [lift] tiles above the fort as it lands: a plinth, the
/// shaft with its arched openings, the cornice and the block the statue
/// stands on.
void _pedestal(IsoStage s, double lift) {
  final z = _walls + lift;
  s
    ..box(_cx - 0.55, _cy - 0.55, z, 1.1, 1.1, 0.22, _granite.shade(-0.04))
    ..box(_cx - 0.4, _cy - 0.4, z + 0.22, 0.8, 0.8, 0.82, _granite)
    ..onLeft(_cy + 0.403, _cx - 0.12, z + 0.5, 0.24, 0.32, _opening)
    ..onRight(_cx + 0.403, _cy - 0.12, z + 0.5, 0.24, 0.32, _opening)
    ..box(_cx - 0.48, _cy - 0.48, z + 1.04, 0.96, 0.96, 0.1, _granite)
    ..box(_cx - 0.34, _cy - 0.34, z + 1.14, 0.68, 0.68, 0.18, _granite);
}

/// Where the top of the torch is, the statue standing [lift] tiles above
/// her place: where the flame burns and the rocket leaves from.
Offset _torch(IsoStage s, [double lift = 0]) => s
    .at(_cx, _cy, _feet + lift)
    .translate(0.33 * _heroic * s.unit, -2.36 * _heroic * s.unit);

/// The statue, [lift] tiles above the pedestal as she lands: her robe
/// falling in folds, the tablet held in her left arm, the crown's rays, and
/// her right arm raising the torch - its flame alight, and flaring as the
/// story starts.
void _statue(IsoStage s, double lift) {
  final u = s.unit * _heroic;
  final foot = s.at(_cx, _cy, _feet + lift);
  Offset p(double x, double y) => foot.translate(x * u, -y * u);
  final shade = s.colour(_copper.shade(-0.16));

  final robe = Path()
    ..moveTo(p(-0.3, 0).dx, p(-0.3, 0).dy)
    ..lineTo(p(0.3, 0).dx, p(0.3, 0).dy)
    ..quadraticBezierTo(
      p(0.28, 0.7).dx,
      p(0.28, 0.7).dy,
      p(0.2, 1.3).dx,
      p(0.2, 1.3).dy,
    )
    ..lineTo(p(-0.2, 1.3).dx, p(-0.2, 1.3).dy)
    ..quadraticBezierTo(
      p(-0.3, 0.7).dx,
      p(-0.3, 0.7).dy,
      p(-0.3, 0).dx,
      p(-0.3, 0).dy,
    )
    ..close();
  s.canvas.drawPath(
    robe,
    Paint()
      ..shader = LinearGradient(
        colors: [
          s.colour(_copper.shade(0.12)),
          s.colour(_copper),
          s.colour(_copper.shade(-0.16)),
        ],
        stops: const [0, 0.45, 1],
      ).createShader(robe.getBounds()),
  );
  // The folds, and the drape across her from the shoulder.
  final fold = s.stroke(_copper.shade(-0.2), 0.03);
  for (final x in const [-0.12, 0.04, 0.17]) {
    s.canvas.drawLine(p(x, 0.04), p(x * 0.8, 0.62), fold);
  }
  s.canvas.drawLine(
    p(-0.2, 1.22),
    p(0.22, 0.62),
    s.stroke(_copper.shade(-0.12), 0.05),
  );

  // The tablet in the crook of her left arm.
  s.canvas.drawPath(
    Path()
      ..moveTo(p(-0.36, 0.72).dx, p(-0.36, 0.72).dy)
      ..lineTo(p(-0.18, 0.76).dx, p(-0.18, 0.76).dy)
      ..lineTo(p(-0.2, 1.14).dx, p(-0.2, 1.14).dy)
      ..lineTo(p(-0.38, 1.1).dx, p(-0.38, 1.1).dy)
      ..close(),
    s.fill(_copper.shade(-0.08)),
  );

  // The raised arm, the head, and the crown's seven rays.
  s.canvas
    ..drawLine(p(0.15, 1.24), p(0.31, 2.08), s.stroke(_copper, 0.12))
    ..drawCircle(p(0, 1.46), u * 0.13, s.fill(_copper.shade(0.06)));
  for (var k = 0; k < 7; k++) {
    final a = -math.pi / 2 + (k - 3) * math.pi / 8;
    final from = p(0, 1.48) + Offset(math.cos(a), math.sin(a)) * u * 0.12;
    final to = p(0, 1.48) + Offset(math.cos(a), math.sin(a)) * u * 0.28;
    s.canvas.drawLine(from, to, s.stroke(_copper.shade(0.08), 0.035));
  }

  // The torch: its cup, and the flame - lit from the start, flaring as the
  // story begins and as it fires.
  final flare = s.story(
    () =>
        s.phase(_flare, _launch, Curves.easeOut) *
        (1 - s.phase(_launch + 0.02, _launch + 0.14, Curves.easeInOut)),
  );
  final tip = _torch(s, lift);
  s
    ..glow(
      tip,
      0.7 + 0.5 * flare,
      strength: 0.5 + 0.5 * flare,
      light: _flameLight,
    )
    ..canvas.drawPath(
      Path()
        ..moveTo(p(0.24, 2.12).dx, p(0.24, 2.12).dy)
        ..lineTo(p(0.42, 2.12).dx, p(0.42, 2.12).dy)
        ..lineTo(p(0.38, 2.24).dx, p(0.38, 2.24).dy)
        ..lineTo(p(0.28, 2.24).dx, p(0.28, 2.24).dy)
        ..close(),
      Paint()..color = shade,
    );
  final flame = Path()
    ..moveTo(p(0.25, 2.24).dx, p(0.25, 2.24).dy)
    ..quadraticBezierTo(
      p(0.24, 2.36 + 0.06 * flare).dx,
      p(0.24, 2.36 + 0.06 * flare).dy,
      p(0.33, 2.5 + 0.1 * flare).dx,
      p(0.33, 2.5 + 0.1 * flare).dy,
    )
    ..quadraticBezierTo(
      p(0.42, 2.36 + 0.06 * flare).dx,
      p(0.42, 2.36 + 0.06 * flare).dy,
      p(0.41, 2.24).dx,
      p(0.41, 2.24).dy,
    )
    ..close();
  s.canvas.drawPath(flame, s.fill(_flame.shade(0.1 * flare)));
}

/// The joke: the torch fires a rocket that whistles up over the harbour and
/// bursts into a heart, then two smaller bursts over the city - all gone by
/// the time the story is told.
void _fireworks(IsoStage s) {
  final u = s.unit;
  final torch = _torch(s);
  final heart = Offset(s.origin.dx - 2.6 * u, s.origin.dy - 0.95 * u);

  // The rocket: up from the torch on a slight curve, trailing sparks.
  final climb = s.story(() => s.phase(_launch, _burst, Curves.easeOut));
  if (climb > 0 && climb < 1) {
    Offset along(double f) {
      final straight = Offset.lerp(torch, heart, f)!;
      return straight.translate(u * 0.6 * math.sin(f * math.pi), 0);
    }

    final head = along(climb);
    for (var k = 1; k <= 6; k++) {
      final back = (climb - k * 0.04).clamp(0.0, 1.0);
      s.canvas.drawCircle(
        along(back),
        u * 0.04 * (1 - k / 8),
        s.fill(_sparkGold)
          ..color = s.colour(_sparkGold).withValues(alpha: 0.8 - k * 0.12),
      );
    }
    s
      ..glow(head, 0.35, light: _sparkGold)
      ..canvas.drawCircle(head, u * 0.06, s.fill(_flameLight));
  }

  _bloom(s, heart, at: _burst, size: 1.3, tint: _heart, heart: true);
  _bloom(
    s,
    Offset(s.origin.dx + 2.9 * u, s.origin.dy - 0.9 * u),
    at: _second,
    size: 0.95,
    tint: _sparkGold,
  );
  _bloom(
    s,
    Offset(s.origin.dx + 1.2 * u, s.origin.dy - 1.6 * u),
    at: _third,
    size: 0.75,
    tint: _sparkBlue,
  );
}

/// One burst at [centre] from [at]: sparks flying out to a ring - or a
/// heart - [size] tiles across, each with a short trail, drooping as they
/// fall and twinkling out.
void _bloom(
  IsoStage s,
  Offset centre, {
  required double at,
  required double size,
  required Tint tint,
  bool heart = false,
}) {
  final open = s.story(() => s.phase(at, at + 0.06));
  if (open <= 0) return;
  final fade = s.story(() => s.phase(at + 0.08, at + 0.3, Curves.easeIn));
  if (fade >= 1) return;
  final u = s.unit;
  final droop = s.story(() => s.phase(at + 0.02, at + 0.3)) * u * 0.45;
  final colour = s.colour(tint);
  s.glow(centre, size * 1.3, strength: open * (1 - fade) * 0.55, light: tint);
  // More sparks for the heart: its outline has to read as one.
  final sparks = heart ? 44 : 30;
  for (var k = 0; k < sparks; k++) {
    final a = k / sparks * 2 * math.pi;
    // The heart's outline, from its parametric curve, scaled to one.
    final shape = heart
        ? Offset(
            math.pow(math.sin(a), 3) * 16 / 17,
            -(13 * math.cos(a) -
                    5 * math.cos(2 * a) -
                    2 * math.cos(3 * a) -
                    math.cos(4 * a)) /
                17,
          )
        : Offset(math.cos(a), math.sin(a));
    final out = shape * size * u * open;
    final spark = centre + out + Offset(0, droop * (0.4 + 0.6 * open));
    final twinkle = 0.65 + 0.35 * math.sin(k * 1.7 + fade * 18);
    final alpha = (1 - fade) * twinkle;
    s.canvas
      ..drawLine(
        centre + out * (heart ? 0.86 : 0.72) + Offset(0, droop * 0.4),
        spark,
        Paint()
          ..strokeWidth = u * 0.035
          ..strokeCap = StrokeCap.round
          ..color = colour.withValues(alpha: alpha * 0.45),
      )
      ..drawCircle(
        spark,
        u * 0.055,
        Paint()..color = colour.withValues(alpha: alpha),
      );
  }
}
