import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/animation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_full_stack_flutter/core/audio/sound.dart';
import 'package:flutter_full_stack_flutter/features/pronunciation/presentation/scenes/iso_stage.dart';
import 'package:flutter_full_stack_flutter/features/pronunciation/presentation/scenes/script.dart';

// The palette: a bright morning at a little airfield over the sea. Blue for
// the sky, the sea and the globe's oceans, sage for the grass and the land,
// warm sand for the terminal and the paving, gold for light, slate for trim
// - and coral kept for the story alone: her dress, the plane's tail and the
// route it flies, so the eye follows one coloured thread.
const _skyTop = Tint(214, 0.58, 0.56);
const _skyLow = Tint(198, 0.45, 0.95);
const _sunBody = Tint(46, 0.5, 1);
const _sunHalo = Tint(44, 0.6, 0.76);
const _cloud = Tint(214, 0.4, 1);
const _farCoast = Tint(204, 0.3, 0.74);
const _seaFar = Tint(196, 0.5, 0.8);
const _seaNear = Tint(204, 0.62, 0.54);
const _glint = Tint(196, 0.5, 1);
const _grass = Tint(100, 0.44, 0.4);
const _earth = Tint(22, 0.58, 0.3);
const _stone = Tint(26, 0.15, 0.17);
const _asphalt = Tint(224, 0.2, 0.26);
const _paint = Tint(40, 0.3, 1);
const _paving = Tint(34, 0.55, 0.64);
const _plinth = Tint(30, 0.3, 0.56);
const _wall = Tint(34, 0.6, 0.8);
const _glass = Tint(198, 0.62, 0.52);
const _iron = Tint(222, 0.25, 0.2);
const _slate = Tint(214, 0.32, 0.34);
const _lilac = Tint(272, 0.45, 0.6);
const _coral = Tint(8, 0.72, 0.52);
// The route: a little deeper and richer than her dress, so the loop still
// carries round the globe on the pastel light theme at phone size.
const _route = Tint(8, 0.78, 0.5);
const _gold = Tint(44, 0.85, 0.68);
const _lamp = Tint(46, 0.95, 0.8);
const _lampGlow = Tint(46, 0.8, 0.94);
const _ocean = Tint(206, 0.8, 0.55);
const _land = Tint(98, 0.55, 0.75);
const _ice = Tint(200, 0.2, 0.96);
const _brass = Tint(40, 0.62, 0.56);
const _hull = Tint(214, 0.14, 0.92);
const _wing = Tint(214, 0.14, 0.8);
const _leaves = Tint(128, 0.42, 0.34);
const _leavesLight = Tint(96, 0.42, 0.46);
const _bark = Tint(28, 0.4, 0.34);
const _stem = Tint(110, 0.45, 0.3);
const _skin = Tint(26, 0.5, 0.78);
const _hair = Tint(20, 0.45, 0.22);
const _straw = Tint(42, 0.55, 0.84);
const _case = Tint(176, 0.45, 0.46);
const _wood = Tint(28, 0.45, 0.42);
const _balloon = Tint(176, 0.5, 0.62);
const _sail = Tint(40, 0.3, 1);
// The line round her thought bubble.
const _ink = Tint(214, 0.3, 0.4);

/// Where the sea meets the sky, as a fraction of the screen's height.
const _horizon = 0.68;

// The globe on its plinth in the middle of the plaza: its centre, radius
// and height, and how far its axis leans.
const _gx = 3.8;
const _gy = 3.7;
const _globeR = 1.0;
const _globeZ = 1.92;
const _axis = 0.4;

// The route round the globe: a ring of radius [_orbitR] about its centre,
// tipped [_tilt] up at the front so it crosses the globe's face, the way
// the badge on a travel poster does. The plane joins it at its right-hand
// side, [_merge], and comes to rest a lap later just past the front, in
// front of the oceans, at [_rest].
const _orbitR = 2.05;
const _tilt = 0.72;
const double _merge = -math.pi / 4;
const double _rest = 2 * math.pi + math.pi / 4 - 0.12;

// The runway along the back of the island, and the take-off run on it:
// the part of it to the right of the globe, so the take-off is in view.
const _runY = 0.82;
const _taxiFrom = 3.0;
const _liftOffX = 4.05;

// When the plane drops onto the runway in act one, on act one's timeline.
const _planeIn = 0.1;
const _planeDown = 0.3;

// Where she stands: on the front rim of the plaza, her back to us, looking
// up at the globe - the subject of the sentence, centre stage.
const _herX = 4.7;
const _herY = 5.2;

/// Something that stands on the island, drawn in order of its depth.
typedef _Item = ({double depth, void Function() draw});

/// Where the plane is on its trip and which way it is going.
typedef _Pose = ({V3 p, V3 v});

/// "She wants to travel around the world", in two acts.
///
/// The airfield assembles first: the island rises out of the sea, the
/// terminal and the tower drop onto it, the plane lands on the runway, its
/// lights come on and the globe pops up spinning on the plaza. Then the
/// story, in the light while the rest of the island sinks back: she lands
/// on the plaza with her suitcase, looking up at the globe, and a thought
/// bubble rises from her with a little plane in it (*She wants*); the plane
/// on the runway rolls and lifts off (*travel*); and it swings onto a ring
/// round the globe and flies a whole lap of it, leaving its route behind it
/// (*around the world*), coming to rest in front of the oceans.
const travelScene = SceneScript(
  paintTravel,
  cues: [
    Cue('She wants', _wishes),
    Cue('travel', _takesOff),
    Cue('around the world', _rounds),
  ],
  sounds: [SceneSound(Sound.takeoff, _rolls)],
);

// The story's beats, on the arrival's clock: her wish first, then the plane
// doing what she wishes - taking off, and flying round the world.
const _wishes = 0.39;
const _takesOff = 0.5;
const _rounds = 0.61;
// She drops in just before her words light, the bubble opens as they do.
const double _sheLands = _wishes - 0.03;
// The plane starts its roll a hair before "travel" and is off the ground
// while the word is lit; it joins the ring as "around the world" lights,
// and is home from its lap before the story is told.
const double _rolls = _takesOff - 0.015;
const double _airborne = _takesOff + 0.035;
const _home = 0.9;

/// Paints [travelScene].
void paintTravel(IsoStage s) {
  s.setting(() {
    _backdrop(s);

    s.rising(0, 0.42, () {
      s.island(grass: _grass, earth: _earth, stone: _stone);
      _ground(s);
      _lights(s);

      late final _Trip trip;
      late final double halo;
      s.story(() {
        trip = _Trip(s);
        // The light follows the story: onto her as she lands, down the
        // runway for the take-off, then over the globe for the lap - where
        // it stays, with hers, at rest.
        final light = s.storyLight;
        final onGlobe = s.phase(_rounds - 0.05, _rounds + 0.02);
        s
          ..pool(
            _herX + 0.05,
            _herY - 0.05,
            0.95,
            strength: light * s.phase(_sheLands, _wishes + 0.02),
          )
          ..pool(
            _liftOffX - 0.2,
            _runY,
            1.35,
            strength:
                light *
                s.phase(_rolls - 0.04, _rolls) *
                (1 - s.phase(_rounds, _rounds + 0.12)),
          )
          ..pool(_gx, _gy, 1.8, strength: light * onGlobe);
        // The world itself lights up as the plane comes round it.
        final blaze = s.phase(_rounds - 0.01, _rounds + 0.04);
        final settle = s.phase(_rounds + 0.06, _rounds + 0.2);
        halo = light * blaze * (1 - 0.5 * settle);
      });

      final plane = trip.pose;
      if (s.t >= _planeIn) _planeShadow(s, plane.p);

      final items = <_Item>[
        (
          depth: 4.0,
          draw: () => s.dropping(0.2, 0.52, (lift) => _terminal(s, lift)),
        ),
        (
          depth: 5.8,
          draw: () => s.dropping(0.26, 0.58, (lift) => _tower(s, lift)),
        ),
        // Out of the way at the foot of the tower, so the space between the
        // terminal and the plaza is clear for her wish.
        (depth: 0.65 + 5.5, draw: () => _baggageCart(s, 0.3, 5.3)),
        (depth: _gx + _gy, draw: () => _globe(s, halo: halo)),
        (
          depth: _herX + _herY,
          draw: () => s.story(
            () => s.dropping(
              _sheLands,
              _wishes + 0.02,
              (lift) => _traveller(s, _herX, _herY, lift),
              from: 2.5,
            ),
          ),
        ),
        (
          depth: _herX + 0.44 + _herY - 0.03,
          draw: () => s.story(
            () => s.dropping(
              _sheLands + 0.005,
              _wishes + 0.025,
              (lift) => _suitcase(s, _herX + 0.22, _herY - 0.13, lift),
              from: 2.5,
            ),
          ),
        ),
        (depth: 3.05 + 5.75, draw: () => _signpost(s, 3.05, 5.75)),
        // Past the far end of the runway, clear of the climb out.
        (depth: 5.8 + 0.25, draw: () => _windsock(s, 5.8, 0.25)),
        (
          depth: 5.55 + 4.4,
          draw: () => _palm(s, 5.55, 4.4, h: 1.6, grow: s.pop(0.5, 0.72)),
        ),
        (
          depth: 1.9 + 5.85,
          draw: () => _palm(s, 1.9, 5.85, h: 1.35, grow: s.pop(0.56, 0.78)),
        ),
        (
          depth: 5.8 + 5.55,
          draw: () => s.bush(5.8, 5.55, _leavesLight, grow: s.pop(0.6, 0.8)),
        ),
        (
          depth: 1.5 + 5.4,
          draw: () =>
              s.bush(1.5, 5.4, _leaves, size: 0.8, grow: s.pop(0.64, 0.84)),
        ),
        ..._flowers(s),
        ...trip.trail(),
        if (s.t >= _planeIn)
          (
            depth: plane.p.x + plane.p.y,
            draw: () => s.dropping(
              _planeIn,
              _planeDown,
              (lift) => _plane(
                s,
                (x: plane.p.x, y: plane.p.y, z: plane.p.z + lift),
                plane.v,
                trip.bank,
              ),
              from: 3,
            ),
          ),
      ]..sort((a, b) => a.depth.compareTo(b.depth));
      for (final item in items) {
        item.draw();
      }

      s.story(() {
        // Her wish floats over everything round her.
        _wish(
          s,
          s.at(_herX, _herY, 1.2),
          puffs: [
            s.pop(_wishes - 0.005, _wishes + 0.025),
            s.pop(_wishes + 0.005, _wishes + 0.035),
          ],
          open: s.pop(_wishes + 0.012, _wishes + 0.06),
        );

        // The rest of the airfield steps back while she, then the plane,
        // then the globe have the stage; at rest the light sits between
        // her and the world she wants to go round.
        final her = s.at(_herX, _herY, 0.7);
        final runway = s.at(_liftOffX + 0.3, _runY + 0.8, 0.4);
        final globe = s.at(_gx + 0.1, _gy + 0.1, 1.5);
        final toRunway = s.phase(_rolls - 0.05, _takesOff, Curves.easeInOut);
        final toGlobe = s.phase(_rounds - 0.05, _rounds, Curves.easeInOut);
        final toRest = s.phase(_home - 0.08, Act.told, Curves.easeInOut);
        var focus = Offset.lerp(her, runway, toRunway)!;
        focus = Offset.lerp(focus, globe, toGlobe)!;
        focus = Offset.lerp(focus, Offset.lerp(her, globe, 0.6), toRest)!;
        s.spotlight(focus, radius: 2.4, strength: s.storyLight);
      });
    });
  });
}

// --------------------------------------------------------------- backdrop --

void _backdrop(IsoStage s) {
  s.sky(_skyTop, _skyLow);
  // A small sun clear above the headline, white-hot at its core.
  final climb = s.phase(0.08, 0.8);
  s
    ..sun(0.14, 0.07 - 0.02 * climb, 0.45, _sunBody, _sunHalo, rings: 2)
    ..ridge(_horizon, 1.1, _farCoast, seed: 3);

  // The sea, from the horizon down, deepening toward the viewer.
  final top = s.size.height * _horizon;
  final sea = Rect.fromLTRB(0, top, s.size.width, s.size.height);
  s.canvas.drawRect(
    sea,
    Paint()
      ..shader = ui.Gradient.linear(sea.topCenter, sea.bottomCenter, [
        s.colour(_seaFar),
        s.colour(_seaNear),
      ]),
  );

  // Glints on the water, catching the light as the sun comes up.
  const glints = [
    (fx: 0.05, dy: 0.018, w: 0.5),
    (fx: 0.16, dy: 0.05, w: 0.7),
    (fx: 0.83, dy: 0.026, w: 0.6),
    (fx: 0.93, dy: 0.07, w: 0.45),
    (fx: 0.03, dy: 0.12, w: 0.6),
    (fx: 0.94, dy: 0.17, w: 0.5),
  ];
  final shine = s.phase(0.3, 0.9);
  if (shine > 0) {
    for (final g in glints) {
      final a = s.screen(g.fx, _horizon + g.dy);
      s.canvas.drawLine(
        a,
        a.translate(g.w * s.unit * shine, 0),
        s.stroke(_glint, 0.035),
      );
    }
  }

  // A far islet with a lighthouse that comes on, and a sailboat drifting
  // in from the left and stopping.
  _farIslet(s, s.screen(0.89, _horizon + 0.004), s.pop(0.7, 0.86));
  _sailboat(s, s.screen(0.04 + 0.06 * s.phase(0.1, 0.95), _horizon + 0.035));

  final drift = s.phase(0.2, 1);
  s
    ..cloud(s.screen(0.5 + 0.4 * (1 - drift), 0.05), 2.2, _cloud)
    ..cloud(s.screen(0.28 - 0.5 * (1 - drift), 0.205), 1.4, _cloud);

  // A hot-air balloon in the free sky right of the headline, rising into
  // place.
  final rise = s.phase(0.04, 0.9);
  _hotAirBalloon(s, s.screen(0.87, 0.085 + 0.4 * (1 - rise)));
}

/// A balloon whose envelope is centred on [c].
void _hotAirBalloon(IsoStage s, Offset c) {
  final r = 0.72 * s.unit;
  final basket = c.translate(0, r * 1.78);
  final neck = Path()
    ..moveTo(c.dx - r * 0.7, c.dy + r * 0.5)
    ..quadraticBezierTo(
      c.dx - r * 0.34,
      c.dy + r * 1.08,
      c.dx - r * 0.2,
      c.dy + r * 1.3,
    )
    ..lineTo(c.dx + r * 0.2, c.dy + r * 1.3)
    ..quadraticBezierTo(
      c.dx + r * 0.34,
      c.dy + r * 1.08,
      c.dx + r * 0.7,
      c.dy + r * 0.5,
    )
    ..close();
  final rope = s.stroke(_iron.shade(0.3), 0.02);
  s.canvas
    ..drawLine(
      c.translate(-r * 0.2, r * 1.3),
      basket.translate(-r * 0.17, 0),
      rope,
    )
    ..drawLine(
      c.translate(r * 0.2, r * 1.3),
      basket.translate(r * 0.17, 0),
      rope,
    )
    ..drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: basket, width: r * 0.42, height: r * 0.3),
        Radius.circular(r * 0.06),
      ),
      s.fill(_wood),
    )
    ..drawPath(neck, s.fill(_wood));
  // The envelope in three gores: teal, a cream band, a teal middle.
  for (final (width, tint) in const [
    (2.0, _balloon),
    (1.2, _sail),
    (0.44, _balloon),
  ]) {
    s.canvas.drawOval(
      Rect.fromCenter(center: c, width: r * width, height: r * 2.2),
      _lit(s, c, r * 1.1, tint),
    );
  }
}

/// A far islet whose foot is centred on [c], with a lighthouse whose lamp
/// is [lamp] of the way lit.
void _farIslet(IsoStage s, Offset c, double lamp) {
  final u = s.unit;
  final hump = Path()
    ..moveTo(c.dx - u * 0.95, c.dy)
    ..quadraticBezierTo(c.dx - u * 0.55, c.dy - u * 0.34, c.dx, c.dy - u * 0.3)
    ..quadraticBezierTo(c.dx + u * 0.5, c.dy - u * 0.27, c.dx + u * 0.85, c.dy)
    ..close();
  // The tower tapers up from the top of the islet; two slate bands.
  final foot = c.translate(-u * 0.12, -u * 0.28);
  Path band(double from, double to) {
    double half(double f) => u * (0.085 - 0.03 * f);
    final y0 = foot.dy - u * 0.62 * from;
    final y1 = foot.dy - u * 0.62 * to;
    return Path()
      ..moveTo(foot.dx - half(from), y0)
      ..lineTo(foot.dx + half(from), y0)
      ..lineTo(foot.dx + half(to), y1)
      ..lineTo(foot.dx - half(to), y1)
      ..close();
  }

  final lantern = foot.translate(0, -u * 0.7);
  s.canvas
    ..drawPath(hump, s.fill(_farCoast.shade(-0.06)))
    ..drawPath(band(0, 1), s.fill(_sail))
    ..drawPath(band(0.2, 0.38), s.fill(_slate.shade(0.2)))
    ..drawPath(band(0.6, 0.78), s.fill(_slate.shade(0.2)));
  if (lamp > 0) {
    s.canvas.drawCircle(lantern, u * 0.2 * lamp, s.fill(_lampGlow));
  }
  s.canvas
    ..drawRect(
      Rect.fromCenter(center: lantern, width: u * 0.1, height: u * 0.12),
      s.fill(lamp > 0 ? _lamp : _sail.shade(-0.1)),
    )
    ..drawPath(
      Path()
        ..moveTo(lantern.dx - u * 0.08, lantern.dy - u * 0.06)
        ..lineTo(lantern.dx + u * 0.08, lantern.dy - u * 0.06)
        ..lineTo(lantern.dx, lantern.dy - u * 0.16)
        ..close(),
      s.fill(_slate),
    );
}

/// A small sailboat whose waterline is centred on [c].
void _sailboat(IsoStage s, Offset c) {
  final u = s.unit;
  final hull = Path()
    ..moveTo(c.dx - u * 0.36, c.dy - u * 0.1)
    ..lineTo(c.dx + u * 0.36, c.dy - u * 0.1)
    ..lineTo(c.dx + u * 0.24, c.dy)
    ..lineTo(c.dx - u * 0.26, c.dy)
    ..close();
  final sail = Path()
    ..moveTo(c.dx - u * 0.02, c.dy - u * 0.14)
    ..lineTo(c.dx - u * 0.02, c.dy - u * 0.72)
    ..lineTo(c.dx + u * 0.3, c.dy - u * 0.14)
    ..close();
  final jib = Path()
    ..moveTo(c.dx - u * 0.06, c.dy - u * 0.14)
    ..lineTo(c.dx - u * 0.06, c.dy - u * 0.6)
    ..lineTo(c.dx - u * 0.3, c.dy - u * 0.14)
    ..close();
  s.canvas
    ..drawPath(jib, s.fill(_sail.shade(-0.1)))
    ..drawPath(sail, s.fill(_sail))
    ..drawPath(hull, s.fill(_slate));
}

/// A fill shaded like the kit's spheres: lit from the upper left of a ball
/// centred on [c], [radius] pixels across.
Paint _lit(IsoStage s, Offset c, double radius, Tint tint) => Paint()
  ..shader = ui.Gradient.radial(
    c.translate(-radius * 0.35, -radius * 0.4),
    radius * 1.5,
    [s.colour(tint.shade(0.16)), s.colour(tint), s.colour(tint.shade(-0.16))],
    [0, 0.5, 1],
  );

// ----------------------------------------------------------------- ground --

/// The runway, the plaza round the globe and the paths: everything flat.
void _ground(IsoStage s) {
  s
    ..patch(0.35, 0.32, 5.3, 1, _asphalt)
    // Paths: the terminal's glass front to the plaza, the plaza to the
    // front edge where she waits.
    ..patch(1.5, 3.1, 1.2, 0.55, _paving)
    ..patch(2.75, 4.6, 0.6, 1.4, _paving);
  // Threshold bars at the start of the runway, then the centre line.
  for (var i = 0; i < 4; i++) {
    s.patch(0.5, 0.44 + i * 0.22, 0.34, 0.1, _paint, z: 0.004);
  }
  for (var i = 0; i < 9; i++) {
    s.patch(1.05 + i * 0.5, _runY - 0.03, 0.28, 0.06, _paint, z: 0.004);
  }
  s.canvas
    ..drawOval(s.disc(_gx, _gy, 0.003, 1.3), s.fill(_paving))
    ..drawOval(s.disc(_gx, _gy, 0.005, 1.02), s.fill(_paving.shade(0.08)));
  _compass(s);
}

/// A compass rose set into the plaza under the globe: four long points,
/// each lit on one half and shaded on the other, and four short ones.
void _compass(IsoStage s) {
  const z = 0.007;
  V3 polar(double a, double r) =>
      (x: _gx + r * math.cos(a), y: _gy + r * math.sin(a), z: z);
  const centre = (x: _gx, y: _gy, z: z);
  final lit = Path();
  final shaded = Path();
  final short = Path();
  for (var i = 0; i < 4; i++) {
    final a = i * math.pi / 2;
    lit.addPath(
      s.face([centre, polar(a, 1.26), polar(a + 0.4, 0.5)]),
      Offset.zero,
    );
    shaded.addPath(
      s.face([centre, polar(a, 1.26), polar(a - 0.4, 0.5)]),
      Offset.zero,
    );
    final b = a + math.pi / 4;
    short.addPath(
      s.face([polar(b - 0.36, 0.4), polar(b, 0.96), polar(b + 0.36, 0.4)]),
      Offset.zero,
    );
  }
  s.canvas
    ..drawPath(short, s.fill(_gold.shade(0.04)))
    ..drawPath(lit, s.fill(_paving.shade(0.2)))
    ..drawPath(shaded, s.fill(_paving.shade(-0.12)));
}

/// The runway's edge lights, coming on in pairs down its length: few and
/// small, with no halo, so the route is the one dotted line the eye follows.
void _lights(IsoStage s) {
  for (var i = 0; i < 5; i++) {
    final on = s.pop(0.3 + i * 0.045, 0.4 + i * 0.045);
    if (on <= 0) continue;
    final x = 0.62 + i * 1.2;
    for (final y in const [0.4, 1.24]) {
      s.canvas.drawCircle(
        s.at(x, y, 0.01),
        0.036 * s.unit * on,
        s.fill(_lamp),
      );
    }
  }
}

/// A soft shadow under the plane, wherever it is over the island, shrinking
/// to nothing as it climbs.
void _planeShadow(IsoStage s, V3 p) {
  final r = 0.34 * (1 - p.z / 1.3);
  if (r <= 0.03) return;
  if (p.x < 0.2 || p.x > 5.8 || p.y < 0.2 || p.y > 5.8) return;
  final onRunway = p.y > 0.32 && p.y < 1.32 && p.x > 0.35 && p.x < 5.65;
  final dx = p.x - _gx;
  final dy = p.y - _gy;
  final onPlaza = dx * dx + dy * dy < 1.3 * 1.3;
  final ground = onRunway
      ? _asphalt
      : onPlaza
      ? _paving
      : _grass;
  s.shadow(p.x, p.y, r, ground);
}

// -------------------------------------------------------------- buildings --

/// The terminal along the back left, [lift] tiles above its place.
void _terminal(IsoStage s, double lift) {
  const x = 0.35;
  const y = 1.7;
  const w = 1.15;
  const d = 2.5;
  const h = 0.75;
  final z = lift;
  if (lift < 0.05) {
    s.patch(x, y - 0.05, w + 0.25, d + 0.12, _grass.shade(-0.14));
  }
  s
    ..box(x, y, z, w, d, h, _wall)
    // The glass front facing the plaza, and a glass door at the end.
    ..onRight(x + w, y + 0.14, z + 0.1, d - 0.28, 0.5, _glass.shade(-0.08))
    ..onLeft(y + d, x + 0.36, z, 0.44, 0.56, _glass);
  for (var i = 1; i < 8; i++) {
    final along = y + 0.14 + i * (d - 0.28) / 8;
    s.canvas.drawLine(
      s.at(x + w, along, z + 0.1),
      s.at(x + w, along, z + 0.6),
      s.stroke(_wall.shade(-0.12), 0.02),
    );
  }
  // A flat roof slab with a slate fascia, a row of skylights and a little
  // plant room on it.
  s
    ..box(x - 0.08, y - 0.08, z + h, w + 0.16, d + 0.16, 0.12, _wall)
    ..onLeft(y + d + 0.08, x - 0.08, z + h, w + 0.16, 0.12, _slate)
    ..onRight(
      x + w + 0.08,
      y - 0.08,
      z + h,
      d + 0.16,
      0.12,
      _slate.shade(-0.14),
    );
  for (var i = 0; i < 3; i++) {
    s.patch(
      x + 0.15,
      y + 1.2 + i * 0.4,
      w - 0.3,
      0.22,
      _glass.shade(0.1),
      z: z + h + 0.121,
    );
  }
  s.box(x + 0.3, y + 0.5, z + h + 0.12, 0.42, 0.5, 0.18, _slate.shade(0.3));
}

/// The control tower in front of the terminal, [lift] tiles above its place;
/// its beacon comes on once it has landed.
void _tower(IsoStage s, double lift) {
  const x = 0.85;
  const y = 4.95;
  final z = lift;
  if (lift < 0.05) s.shadow(x, y, 0.5, _grass);
  s
    ..box(x - 0.26, y - 0.26, z, 0.52, 0.52, 0.32, _wall.shade(-0.06))
    ..cylinder(x, y, z + 0.32, 0.15, 1.42, _wall)
    ..cylinder(x, y, z + 1.74, 0.36, 0.08, _wall.shade(0.04))
    ..cylinder(x, y, z + 1.82, 0.31, 0.32, _glass);
  // Mullions round the glass cab, on the side that faces us.
  for (final a in const [0.15, 0.785, 1.42]) {
    final px = x + 0.31 * math.cos(a);
    final py = y + 0.31 * math.sin(a);
    s.canvas.drawLine(
      s.at(px, py, z + 1.82),
      s.at(px, py, z + 2.14),
      s.stroke(_wall, 0.02),
    );
  }
  s.cylinder(x, y, z + 2.14, 0.38, 0.08, _slate);
  final mast = s.at(x, y, z + 2.22);
  final tip = s.at(x, y, z + 2.56);
  s.canvas.drawLine(mast, tip, s.stroke(_iron, 0.025));
  final beacon = s.pop(0.5, 0.66);
  if (beacon > 0) {
    s.canvas
      ..drawCircle(tip, 0.13 * s.unit * beacon, s.fill(_lampGlow))
      ..drawCircle(tip, 0.055 * s.unit, s.fill(_lamp));
  }
}

/// A baggage cart by the terminal, its back corner at [x], [y]: it rolls
/// up, then the cases drop onto it one after another.
void _baggageCart(IsoStage s, double x, double y) {
  const w = 0.7;
  const d = 0.4;
  final arrive = s.pop(0.4, 0.56);
  if (arrive <= 0) return;
  s.scaled(s.at(x + w / 2, y + d / 2), arrive, () {
    s.shadow(x + w / 2, y + d / 2, 0.42, _grass);
    for (final (wx, wy) in const [(0.1, d), (w - 0.1, d), (w, 0.08)]) {
      s.canvas.drawCircle(
        s.at(x + wx, y + wy, 0.05),
        0.055 * s.unit,
        s.fill(_iron),
      );
    }
    s
      ..box(x, y, 0.08, w, d, 0.06, _iron.shade(0.3))
      ..canvas.drawLine(
        s.at(x + w / 2, y + d, 0.12),
        s.at(x + w / 2, y + d + 0.26, 0.2),
        s.stroke(_iron.shade(0.3), 0.03),
      );
  });
  // The cases: the first two side by side, the third on top of the first.
  // Drawn back to front, which is not the order they land in.
  const cases = [
    (dx: 0.04, dy: 0.05, z: 0.14, w: 0.3, d: 0.3, h: 0.22, at: 0.66),
    (dx: 0.08, dy: 0.08, z: 0.36, w: 0.22, d: 0.22, h: 0.16, at: 0.76),
    (dx: 0.38, dy: 0.06, z: 0.14, w: 0.27, d: 0.28, h: 0.3, at: 0.71),
  ];
  final tints = [_slate.shade(0.2), _case, _gold];
  for (var i = 0; i < cases.length; i++) {
    final c = cases[i];
    s.dropping(
      c.at,
      c.at + 0.16,
      (lift) => s.box(
        x + c.dx,
        y + c.dy,
        c.z + lift,
        c.w,
        c.d,
        c.h,
        tints[i],
      ),
      from: 2.5,
    );
  }

  // The stowaway in the little case on top, once that has landed.
  final top = cases[1];
  if (s.t < top.at + 0.16) return;
  final lid = top.z + top.h;
  _cat(
    s,
    s.at(x + top.dx, y + top.dy + top.d, lid),
    s.at(x + top.dx + top.w, y + top.dy, lid),
  );
}

/// The black cat, stowed away in the little case on top of the baggage -
/// the scene's easter egg (see `HidingCat`). Curled up inside it, only the
/// tips of its ears show over the lid; when it has a reason it sits up out
/// of the case onto the lid, and settles back down into it.
///
/// [left] and [right] are the lid's side corners; it shows only above the
/// line between them.
void _cat(IsoStage s, Offset left, Offset right) {
  final middle = Offset.lerp(left, right, 0.5)!;
  s.hidingCat(
    hidden: middle.translate(0, 0.59 * s.unit),
    out: middle,
    reveal: s.beyond(left, right, of: middle.translate(0, -1)),
    // Its tail on the side away from the palm.
    flip: true,
  );
}

// ------------------------------------------------------------------ globe --

/// The landmasses, as overlapping blobs: longitude and latitude in degrees,
/// and their half-size as a fraction of the globe's radius.
typedef _Land = ({double lon, double lat, double w, double h});

const List<_Land> _lands = [
  // A northern continent in the west, with a big island off its shoulder.
  (lon: -110, lat: 56, w: 0.3, h: 0.15),
  (lon: -96, lat: 45, w: 0.28, h: 0.17),
  (lon: -102, lat: 32, w: 0.17, h: 0.13),
  (lon: -80, lat: 40, w: 0.12, h: 0.12),
  (lon: -70, lat: 52, w: 0.12, h: 0.09),
  (lon: -86, lat: 20, w: 0.07, h: 0.09),
  (lon: -42, lat: 72, w: 0.12, h: 0.07),
  // Its southern neighbour.
  (lon: -74, lat: 2, w: 0.08, h: 0.1),
  (lon: -62, lat: -6, w: 0.2, h: 0.17),
  (lon: -56, lat: -20, w: 0.17, h: 0.17),
  (lon: -66, lat: -36, w: 0.1, h: 0.16),
  // The great continent across the north and east.
  (lon: 10, lat: 48, w: 0.14, h: 0.1),
  (lon: 26, lat: 56, w: 0.17, h: 0.1),
  (lon: 60, lat: 58, w: 0.34, h: 0.14),
  (lon: 92, lat: 52, w: 0.36, h: 0.16),
  (lon: 120, lat: 60, w: 0.24, h: 0.11),
  (lon: 110, lat: 36, w: 0.22, h: 0.15),
  (lon: 46, lat: 28, w: 0.12, h: 0.1),
  (lon: 80, lat: 24, w: 0.11, h: 0.13),
  (lon: 138, lat: 36, w: 0.04, h: 0.08),
  // The one below it, and the island continent far to the south-east.
  (lon: 14, lat: 10, w: 0.24, h: 0.18),
  (lon: 25, lat: -6, w: 0.18, h: 0.2),
  (lon: 27, lat: -24, w: 0.12, h: 0.14),
  (lon: 40, lat: 8, w: 0.1, h: 0.11),
  (lon: 134, lat: -25, w: 0.18, h: 0.12),
  (lon: 146, lat: -33, w: 0.07, h: 0.06),
];

/// The globe on its plinth, popping up and spinning to a stop, in a warm
/// [halo] of light that blooms as the plane comes round it.
void _globe(IsoStage s, {required double halo}) {
  final grow = s.pop(0.34, 0.56);
  if (grow <= 0) return;
  final spin = 0.5 - (1 - s.phase(0.34, 0.95)) * math.pi * 3;
  s.scaled(s.at(_gx, _gy), grow, () {
    const base = 0.2;
    const cap = 0.12;
    const radius = _globeR * 1.15;
    const ring = radius * 1.14;
    s
      ..glow(s.at(_gx, _gy, _globeZ), radius * 1.9, strength: halo)
      ..shadow(_gx, _gy, 0.66, _paving)
      ..cylinder(_gx, _gy, 0, 0.6, base, _plinth)
      ..cylinder(_gx, _gy, base, 0.42, cap, _plinth.shade(0.1))
      ..cylinder(
        _gx,
        _gy,
        base + cap,
        0.06,
        _globeZ - ring - base - cap,
        _brass,
      );

    // The ball: shaded like the kit's spheres but glossier, a lacquered
    // globe catching the light, so it reads as a lit sphere in front of the
    // runway and the terminal in both themes rather than a hole in them.
    final c = s.at(_gx, _gy, _globeZ);
    final rho = radius * s.unit;
    final rr = ring * s.unit;
    s.canvas
      ..drawCircle(
        c,
        rho,
        Paint()
          ..shader = ui.Gradient.radial(
            c.translate(-rho * 0.35, -rho * 0.4),
            rho * 1.5,
            [
              s.colour(_ocean.shade(0.24)),
              s.colour(_ocean.shade(0.04)),
              s.colour(_ocean.shade(-0.16)),
            ],
            [0, 0.45, 1],
          ),
      )
      ..save()
      ..translate(c.dx, c.dy)
      ..rotate(_axis)
      ..save()
      ..clipPath(
        Path()..addOval(Rect.fromCircle(center: Offset.zero, radius: rho)),
      );
    _continents(s, rho, spin);
    s.canvas
      ..restore()
      // The meridian: a brass half ring holding the poles.
      ..drawArc(
        Rect.fromCircle(center: Offset.zero, radius: rr),
        -math.pi / 2,
        math.pi,
        false,
        s.stroke(_brass, 0.075),
      )
      ..drawArc(
        Rect.fromCircle(center: Offset.zero, radius: rr - 0.02 * s.unit),
        -math.pi / 2,
        math.pi * 0.6,
        false,
        s.stroke(_brass.shade(0.16), 0.025),
      )
      ..drawLine(Offset(0, -rho), Offset(0, -rr), s.stroke(_brass, 0.05))
      ..drawLine(Offset(0, rho), Offset(0, rr), s.stroke(_brass, 0.05))
      ..drawCircle(Offset(0, -rr), 0.065 * s.unit, s.fill(_brass.shade(0.1)))
      ..drawCircle(Offset(0, rr), 0.065 * s.unit, s.fill(_brass.shade(0.1)))
      ..restore();
  });
}

/// The land on a globe of [rho] pixels' radius, turned by [spin], drawn in
/// the globe's own frame (its centre at the origin, its axis upright).
void _continents(IsoStage s, double rho, double spin) {
  // The camera looks down on the globe, so its north tips toward us.
  const lean = 0.45;
  final cl = math.cos(lean);
  final sl = math.sin(lean);
  final land = Path();
  for (final blob in _lands) {
    final lon = blob.lon * math.pi / 180 + spin;
    final lat = blob.lat * math.pi / 180;
    final x = math.cos(lat) * math.sin(lon);
    final y0 = math.sin(lat);
    final f0 = math.cos(lat) * math.cos(lon);
    final y = y0 * cl - f0 * sl;
    final facing = f0 * cl + y0 * sl;
    if (facing < -0.15) continue;
    final across = math.sqrt(math.max(0, 1 - x * x));
    final up = math.sqrt(math.max(0, 1 - y * y));
    land.addOval(
      Rect.fromCenter(
        center: Offset(x * rho, -y * rho),
        width: 2 * blob.w * rho * math.max(across, 0.12),
        height: 2 * blob.h * rho * math.max(up, 0.12),
      ),
    );
  }
  // The light comes from the upper left of the screen, which in the
  // globe's leaning frame is a little further round.
  final light = Offset(-0.35 * rho, -0.4 * rho);
  final ca = math.cos(-_axis);
  final sa = math.sin(-_axis);
  final local = Offset(
    light.dx * ca - light.dy * sa,
    light.dx * sa + light.dy * ca,
  );
  final shade = Paint()
    ..shader = ui.Gradient.radial(
      local,
      rho * 1.5,
      [
        s.colour(_land.shade(0.14)),
        s.colour(_land),
        s.colour(_land.shade(-0.2)),
      ],
      [0, 0.5, 1],
    );
  s.canvas
    ..drawPath(land, shade)
    // The northern ice, seen from above.
    ..drawOval(
      Rect.fromCenter(
        center: Offset(0, -cl * rho),
        width: rho * 0.52,
        height: rho * 0.52 * sl,
      ),
      s.fill(_ice),
    );
}

// ------------------------------------------------------------------- trip --

/// The plane's trip: parked on the runway, a take-off run, a
/// climbing turn onto the route, and a lap of the globe that slows to rest.
///
/// Built on the story's clock. Each leg is timed to its beat - off the
/// ground just after [_takesOff], onto the ring at [_rounds], home by
/// [_home] - and the speed runs on smoothly from one leg into the next.
class _Trip {
  _Trip(this.s) {
    var length = 0.0;
    var last = _climbAt(0).p;
    for (var i = 1; i <= 16; i++) {
      final next = _climbAt(i / 16).p;
      length += _distance(last, next);
      last = next;
    }
    climb = length;
    total = roll + climb + _orbitR * (_rest - _merge);
    travelled = _along(s.t);
  }

  final IsoStage s;
  static const double roll = _liftOffX - _taxiFrom;
  late final double climb;
  late final double total;
  late final double travelled;

  /// How far along the trip the plane is at [t] of the arrival.
  double _along(double t) {
    // When it is how far along, and how fast it is going then: it gathers
    // speed down the runway, keeps it through the climb, and swings round
    // the world faster still before easing to a stop.
    const lift = 2 * roll / (_airborne - _rolls);
    final keys = [
      (t: _rolls, d: 0.0, v: 0.0),
      (t: _airborne, d: roll, v: lift),
      (t: _rounds, d: roll + climb, v: lift),
      (t: _home, d: total, v: 0.0),
    ];
    if (t <= keys.first.t) return 0;
    if (t >= keys.last.t) return total;
    var i = 0;
    while (t > keys[i + 1].t) {
      i++;
    }
    final a = keys[i];
    final b = keys[i + 1];
    final span = b.t - a.t;
    final u = (t - a.t) / span;
    // A cubic Hermite step from a to b, leaving and arriving at their speeds.
    final u2 = u * u;
    final u3 = u2 * u;
    return a.d +
        (u3 - 2 * u2 + u) * a.v * span +
        (-2 * u3 + 3 * u2) * (b.d - a.d) +
        (u3 - u2) * b.v * span;
  }

  /// Where the plane is now.
  _Pose get pose => _at(travelled);

  /// How far it leans into the turn: none on the runway, then into the
  /// climb, then steadily round the globe.
  double get bank {
    final airborne = travelled - roll;
    if (airborne <= 0) return 0;
    return 0.32 * math.min(1, airborne / climb);
  }

  /// The route as dashes, laid down behind the plane once round the globe
  /// from where it joins the ring.
  List<_Item> trail() {
    const period = 0.4;
    const dash = 0.24;
    const lap = 2 * math.pi * _orbitR - period * 0.5;
    final start = roll + climb;
    return [
      for (var from = 0.0; from < lap; from += period)
        if (start + from + dash < travelled - 0.5) _dash(start + from, dash),
    ];
  }

  _Item _dash(double from, double length) {
    final a = _at(from).p;
    final b = _at(from + length).p;
    return (
      depth: (a.x + a.y + b.x + b.y) / 2,
      draw: () => s.canvas.drawLine(
        s.at(a.x, a.y, a.z),
        s.at(b.x, b.y, b.z),
        s.stroke(_route, 0.085),
      ),
    );
  }

  _Pose _at(double d) {
    if (d <= roll) {
      return (
        p: (x: _taxiFrom + d, y: _runY, z: 0.0),
        v: (x: 1.0, y: 0.0, z: 0.0),
      );
    }
    if (d <= roll + climb) return _climbAt((d - roll) / climb);
    return _orbitAt(_merge + (d - roll - climb) / _orbitR);
  }

  /// A smooth climbing turn from the lift-off point onto the route, as a
  /// cubic curve that leaves along the runway and arrives along the ring.
  _Pose _climbAt(double q) {
    final end = _orbitAt(_merge);
    const start = (x: _liftOffX, y: _runY, z: 0.0);
    const out = (x: _liftOffX + 0.7, y: _runY, z: 0.08);
    final into = (
      x: end.p.x - end.v.x * 0.3,
      y: end.p.y - end.v.y * 0.3,
      z: end.p.z,
    );
    double bez(double a, double b, double c, double d) {
      final r = 1 - q;
      return r * r * r * a +
          3 * r * r * q * b +
          3 * r * q * q * c +
          q * q * q * d;
    }

    double tan(double a, double b, double c, double d) {
      final r = 1 - q;
      return 3 * r * r * (b - a) + 6 * r * q * (c - b) + 3 * q * q * (d - c);
    }

    return (
      p: (
        x: bez(start.x, out.x, into.x, end.p.x),
        y: bez(start.y, out.y, into.y, end.p.y),
        z: bez(start.z, out.z, into.z, end.p.z),
      ),
      v: (
        x: tan(start.x, out.x, into.x, end.p.x),
        y: tan(start.y, out.y, into.y, end.p.y),
        z: tan(start.z, out.z, into.z, end.p.z),
      ),
    );
  }

  static double _distance(V3 a, V3 b) {
    final dx = b.x - a.x;
    final dy = b.y - a.y;
    final dz = b.z - a.z;
    return math.sqrt(dx * dx + dy * dy + dz * dz);
  }
}

/// The point at angle [a] round the route, and the way along it: highest at
/// the front, level with the globe's centre at the sides.
_Pose _orbitAt(double a) {
  final front = a - math.pi / 4;
  // The way along, scaled so the climb's last handle can be cut from it.
  const pull = 2.0;
  return (
    p: (
      x: _gx + _orbitR * math.cos(a),
      y: _gy + _orbitR * math.sin(a),
      z: _globeZ + _tilt * math.cos(front),
    ),
    v: (
      x: -math.sin(a) * pull,
      y: math.cos(a) * pull,
      z: -_tilt / _orbitR * math.sin(front) * pull,
    ),
  );
}

/// A small airliner at [p], heading along [v], its wings banked by [bank].
void _plane(IsoStage s, V3 p, V3 v, double bank) {
  const size = 0.95;
  final heading = math.atan2(v.y, v.x);
  final run = math.sqrt(v.x * v.x + v.y * v.y);
  final pitch = run < 1e-6 ? 0.0 : (v.z / run).clamp(-0.5, 0.5);
  final c = math.cos(heading);
  final sn = math.sin(heading);
  // u runs to the nose, w to the right wingtip, h up.
  Offset o(double u, double w, double h) => s.at(
    p.x + (u * c - w * sn) * size,
    p.y + (u * sn + w * c) * size,
    p.z + (h + u * pitch - w * bank) * size,
  );
  Path shape(List<Offset> points) {
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final q in points.skip(1)) {
      path.lineTo(q.dx, q.dy);
    }
    return path..close();
  }

  // The fin's face: lighter turned to the left, darker to the right.
  var nx = -sn;
  var ny = c;
  if (nx + ny < 0) {
    nx = -nx;
    ny = -ny;
  }
  final finShade = nx > 0 ? -0.16 * nx * nx : 0.0;
  void fin() => s.canvas.drawPath(
    shape([
      o(-0.34, 0, 0.06),
      o(-0.6, 0, 0.06),
      o(-0.7, 0, 0.44),
      o(-0.56, 0, 0.44),
    ]),
    s.fill(_coral.shade(finShade)),
  );
  // Seen nose-on the tail is further away, so the fin goes behind the body.
  final towardUs = c + sn > 0;

  for (final side in const [-1.0, 1.0]) {
    s.canvas
      ..drawLine(
        o(0.16, 0.3 * side, -0.06),
        o(-0.02, 0.3 * side, -0.06),
        s.stroke(_wing.shade(-0.12), 0.1 * size),
      )
      ..drawPath(
        shape([
          o(0.2, 0, 0),
          o(-0.02, 0.68 * side, 0),
          o(-0.17, 0.68 * side, 0),
          o(-0.16, 0, 0),
        ]),
        s.fill(_wing),
      )
      ..drawPath(
        shape([
          o(-0.42, 0, 0.04),
          o(-0.56, 0.26 * side, 0.04),
          o(-0.64, 0.26 * side, 0.04),
          o(-0.62, 0, 0.04),
        ]),
        s.fill(_wing),
      );
  }
  if (towardUs) fin();
  s.canvas
    ..drawLine(
      o(-0.6, 0, 0.04),
      o(0.54, 0, 0.03),
      s.stroke(_hull.shade(-0.18), 0.22 * size),
    )
    ..drawLine(o(-0.6, 0, 0.07), o(0.54, 0, 0.06), s.stroke(_hull, 0.18 * size))
    ..drawLine(
      o(-0.5, 0, 0.12),
      o(0.46, 0, 0.11),
      s.stroke(_hull.shade(0.1), 0.06 * size),
    )
    ..drawLine(
      o(-0.48, 0, 0.04),
      o(0.4, 0, 0.035),
      s.stroke(_coral, 0.035 * size),
    )
    ..drawLine(
      o(0.4, 0, 0.09),
      o(0.48, 0, 0.08),
      s.stroke(_iron.shade(0.2), 0.05 * size),
    );
  if (!towardUs) fin();
}

// ----------------------------------------------------------------- people --

/// Her, at [x], [y], [lift] tiles above the ground, looking up at the globe
/// with her back to us.
void _traveller(IsoStage s, double x, double y, double lift) {
  if (lift < 0.6) s.shadow(x, y, 0.28 * (1 - lift / 0.6), _paving);
  // Over life size, so the subject of the sentence reads at a glance on a
  // phone.
  s.scaled(s.at(x, y, lift), 1.4, () {
    final z = lift;
    s
      ..canvas.drawLine(
        s.at(x + 0.04, y - 0.03, z),
        s.at(x + 0.04, y - 0.03, z + 0.26),
        s.stroke(_skin.shade(-0.12), 0.045),
      )
      ..canvas.drawLine(
        s.at(x - 0.03, y + 0.04, z),
        s.at(x - 0.03, y + 0.04, z + 0.26),
        s.stroke(_skin, 0.045),
      )
      ..cone(x, y, z + 0.2, 0.17, 0.55, _coral)
      ..cylinder(x, y, z + 0.5, 0.075, 0.16, _coral.shade(0.06))
      // Her arm, reaching to the suitcase's handle.
      ..canvas.drawLine(
        s.at(x + 0.05, y - 0.02, z + 0.62),
        s.at(x + 0.2, y - 0.04, z + 0.48),
        s.stroke(_skin, 0.04),
      )
      ..sphere(x, y, z + 0.8, 0.1, _skin)
      // Her hair, seen from behind, and a ponytail down her back.
      ..sphere(x + 0.03, y + 0.03, z + 0.8, 0.095, _hair)
      ..sphere(x + 0.08, y + 0.08, z + 0.7, 0.05, _hair.shade(0.04))
      // A sun hat.
      ..canvas.drawOval(s.disc(x, y, z + 0.87, 0.18), s.fill(_straw))
      ..cylinder(x, y, z + 0.87, 0.09, 0.08, _straw.shade(0.06))
      ..cylinder(x, y, z + 0.87, 0.092, 0.03, _coral);
  });
}

/// Her wish: a thought bubble rising from her [head], two small [puffs] of
/// it first, then the bubble itself, [open] of the way, with a little plane
/// climbing across it. It glows a little, the way an idea does.
void _wish(
  IsoStage s,
  Offset head, {
  required List<double> puffs,
  required double open,
}) {
  final u = s.unit;
  // Up and to her left, clear of the globe above her and the plane that
  // comes to rest in front of it.
  final c = head.translate(-1.05 * u, -0.8 * u);
  for (var i = 0; i < puffs.length; i++) {
    final grow = puffs[i];
    if (grow <= 0) continue;
    final at = Offset.lerp(head, c, 0.2 + 0.22 * i)!;
    final r = (0.05 + 0.035 * i) * u * grow;
    s.canvas
      ..drawCircle(at, r + 0.03 * u, s.fill(_ink))
      ..drawCircle(at, r, s.fill(_sail));
  }
  if (open <= 0) return;
  s.glow(c, 1.1, strength: 0.7 * open * s.storyLight);
  s.scaled(c, open, () {
    // A puffed-up oval: lobes round an ellipse, outlined, its underside in
    // shade.
    const a = 0.52;
    const b = 0.33;
    const lobes = 8;
    Path body(double grow, double dy) {
      final path = Path()
        ..addOval(
          Rect.fromCenter(
            center: c.translate(0, dy),
            width: 2 * (a + grow) * u,
            height: 2 * (b + grow) * u,
          ),
        );
      for (var i = 0; i < lobes; i++) {
        final angle = i * 2 * math.pi / lobes + 0.2;
        path.addOval(
          Rect.fromCircle(
            center: c.translate(
              a * math.cos(angle) * u,
              b * math.sin(angle) * u + dy,
            ),
            radius: (0.16 + grow) * u,
          ),
        );
      }
      return path;
    }

    s.canvas
      ..drawPath(body(0.03, 0), s.fill(_ink))
      ..drawPath(body(0, 0), s.fill(_sail.shade(-0.14)))
      ..drawPath(body(0, -0.035 * u), s.fill(_sail));

    // The little plane, climbing to the upper right.
    s.canvas
      ..save()
      ..translate(c.dx, c.dy)
      ..rotate(-0.38);
    // The plane's length, in tiles and in pixels.
    const k = 0.78;
    final l = k * u;
    Path shape(List<Offset> points) =>
        Path()..addPolygon([for (final p in points) p * l], true);
    s.canvas
      ..drawPath(
        shape(const [
          Offset(-0.34, 0),
          Offset(-0.5, -0.27),
          Offset(-0.4, -0.27),
          Offset(-0.18, 0),
        ]),
        s.fill(_coral),
      )
      ..drawLine(
        const Offset(-0.44, 0) * l,
        const Offset(0.4, 0) * l,
        s.stroke(_hull.shade(-0.24), 0.17 * k),
      )
      ..drawLine(
        const Offset(-0.44, -0.015) * l,
        const Offset(0.4, -0.015) * l,
        s.stroke(_hull, 0.12 * k),
      )
      ..drawPath(
        shape(const [
          Offset(0.1, 0.02),
          Offset(-0.14, 0.34),
          Offset(-0.26, 0.34),
          Offset(-0.12, 0.02),
        ]),
        s.fill(_wing.shade(-0.18)),
      )
      ..drawLine(
        const Offset(-0.3, -0.02) * l,
        const Offset(0.26, -0.02) * l,
        s.stroke(_coral, 0.025 * k),
      )
      ..restore();
  });
}

/// Her suitcase at [x], [y], covered in stickers, [lift] above the ground.
void _suitcase(IsoStage s, double x, double y, double lift) {
  const w = 0.44;
  const d = 0.2;
  const h = 0.48;
  final z = lift;
  if (lift < 0.05) s.shadow(x + w / 2, y + d / 2, 0.3, _paving);
  s
    ..box(x, y, z, w, d, h, _case)
    ..onLeft(y + d, x + 0.04, z + 0.27, 0.13, 0.13, _gold)
    ..onLeft(y + d, x + 0.22, z + 0.31, 0.16, 0.1, _paint)
    ..onLeft(y + d, x + 0.07, z + 0.07, 0.11, 0.14, _coral)
    ..onLeft(y + d, x + 0.25, z + 0.08, 0.13, 0.13, _land)
    ..onRight(x + w, y + 0.04, z + 0.18, 0.12, 0.16, _gold.shade(-0.1));
  // A telescopic handle.
  final grip = _iron.shade(0.15);
  final l = s.at(x + 0.1, y + d / 2, z + h + 0.24);
  final r = s.at(x + 0.3, y + d / 2, z + h + 0.24);
  s.canvas
    ..drawLine(s.at(x + 0.1, y + d / 2, z + h), l, s.stroke(grip, 0.025))
    ..drawLine(s.at(x + 0.3, y + d / 2, z + h), r, s.stroke(grip, 0.025))
    ..drawLine(l, r, s.stroke(grip, 0.04));
}

/// The arrows on the signpost: their height, the way they point at rest
/// (radians in the ground plane, 0 along x) and colour.
typedef _Arrow = ({double z, double heading, Tint tint});

final List<_Arrow> _arrows = [
  (z: 1.06, heading: 3 * math.pi / 4 - 0.2, tint: _slate.shade(0.2)),
  (z: 0.84, heading: -math.pi / 4 + 0.15, tint: _gold),
  (z: 0.62, heading: 0.35, tint: _ocean),
];

/// A signpost at [x], [y]: it pops up, and its arrows spin round and settle
/// pointing every which way.
void _signpost(IsoStage s, double x, double y) {
  final grow = s.pop(0.52, 0.7);
  if (grow <= 0) return;
  s.scaled(s.at(x, y), grow, () {
    final boards = [
      for (var i = 0; i < _arrows.length; i++)
        (
          arrow: _arrows[i],
          heading:
              _arrows[i].heading +
              (1 - s.pop(0.6 + i * 0.05, 0.82 + i * 0.04)) * math.pi * 2,
        ),
    ];
    // Boards pointing away go behind the post, the rest in front of it.
    bool away(double h) => math.cos(h) + math.sin(h) < 0;
    s.shadow(x, y, 0.22, _grass);
    for (final b in boards) {
      if (away(b.heading)) _board(s, x, y, b.arrow.z, b.heading, b.arrow.tint);
    }
    s
      ..box(x - 0.05, y - 0.05, 0, 0.1, 0.1, 1.28, _wood)
      ..cone(x, y, 1.28, 0.08, 0.1, _wood.shade(0.1));
    for (final b in boards) {
      if (!away(b.heading)) {
        _board(s, x, y, b.arrow.z, b.heading, b.arrow.tint);
      }
    }
  });
}

/// One arrow board on a post at [x], [y], its bottom at [z].
void _board(
  IsoStage s,
  double x,
  double y,
  double z,
  double heading,
  Tint tint,
) {
  final dx = math.cos(heading);
  final dy = math.sin(heading);
  V3 p(double u, double h) => (x: x + dx * u, y: y + dy * u, z: z + h);
  var nx = -dy;
  var ny = dx;
  if (nx + ny < 0) {
    nx = -nx;
    ny = -ny;
  }
  final shade = nx > 0 ? -0.16 * nx * nx : 0.0;
  s.canvas
    ..drawPath(
      s.face([
        p(-0.1, 0),
        p(0.48, 0),
        p(0.62, 0.09),
        p(0.48, 0.18),
        p(-0.1, 0.18),
      ]),
      s.fill(tint.shade(shade)),
    )
    ..drawLine(
      s.at(x - dx * 0.1, y - dy * 0.1, z + 0.18),
      s.at(x + dx * 0.48, y + dy * 0.48, z + 0.18),
      s.stroke(tint.shade(shade + 0.2), 0.02),
    );
}

// ------------------------------------------------------------- furniture --

/// The windsock at the far end of the runway, filling with the wind.
void _windsock(IsoStage s, double x, double y) {
  final up = s.pop(0.44, 0.6);
  if (up <= 0) return;
  final top = 1.05 * up;
  s.canvas.drawLine(
    s.at(x, y),
    s.at(x, y, top),
    s.stroke(_iron.shade(0.2), 0.03),
  );
  final fill = s.pop(0.64, 0.9);
  if (fill <= 0) return;
  final mouth = s.at(x, y, top - 0.06);
  // It streams to the left of the screen, drooping less as it fills.
  final dir = Offset(-1, 0.15 + 0.7 * (1 - fill));
  final along = dir / dir.distance;
  final across = Offset(-along.dy, along.dx);
  final length = 0.66 * s.unit * (0.4 + 0.6 * fill);
  for (var i = 0; i < 4; i++) {
    final f0 = i / 4;
    final f1 = (i + 1) / 4;
    final w0 = (0.1 - 0.045 * f0) * s.unit;
    final w1 = (0.1 - 0.045 * f1) * s.unit;
    final a = mouth + along * (length * f0);
    final b = mouth + along * (length * f1);
    s.canvas.drawPath(
      Path()
        ..moveTo(a.dx + across.dx * w0, a.dy + across.dy * w0)
        ..lineTo(b.dx + across.dx * w1, b.dy + across.dy * w1)
        ..lineTo(b.dx - across.dx * w1, b.dy - across.dy * w1)
        ..lineTo(a.dx - across.dx * w0, a.dy - across.dy * w0)
        ..close(),
      s.fill(i.isEven ? _gold.shade(-0.06) : _paint),
    );
  }
}

/// A palm at [x], [y], [h] tall, [grow] of the way grown.
void _palm(
  IsoStage s,
  double x,
  double y, {
  required double h,
  required double grow,
}) {
  if (grow <= 0) return;
  s.shadow(x, y, 0.42 * grow, _grass);
  final base = s.at(x, y);
  final top = s.at(x - 0.1 * grow, y + 0.1 * grow, h * grow);
  final bend = Offset.lerp(base, top, 0.5)!.translate(0.14 * s.unit * grow, 0);
  s.canvas.drawPath(
    Path()
      ..moveTo(base.dx, base.dy)
      ..quadraticBezierTo(bend.dx, bend.dy, top.dx, top.dy),
    s.stroke(_bark, 0.11 * grow)..strokeCap = StrokeCap.butt,
  );
  // Rings up the trunk.
  for (var i = 1; i < 5; i++) {
    final f = i / 5;
    final q = Offset.lerp(
      Offset.lerp(base, bend, f),
      Offset.lerp(bend, top, f),
      f,
    )!;
    s.canvas.drawLine(
      q.translate(-0.055 * s.unit * grow, 0),
      q.translate(0.055 * s.unit * grow, 0),
      s.stroke(_bark.shade(-0.12), 0.025),
    );
  }
  final reach = 0.78 * s.unit * grow;
  void frond(double a, Tint tint) {
    final dir = Offset(math.cos(a), math.sin(a) * 0.5);
    final tip = top + dir * reach + Offset(0, reach * 0.36);
    final mid = top + dir * (reach * 0.55) + Offset(0, -reach * 0.16);
    final side = Offset(-dir.dy, dir.dx) * (reach * 0.16);
    s.canvas.drawPath(
      Path()
        ..moveTo(top.dx, top.dy)
        ..quadraticBezierTo(mid.dx + side.dx, mid.dy + side.dy, tip.dx, tip.dy)
        ..quadraticBezierTo(mid.dx - side.dx, mid.dy - side.dy, top.dx, top.dy),
      s.fill(tint),
    );
  }

  const fronds = 7;
  for (var i = 0; i < fronds; i++) {
    final a = 0.3 + i * 2 * math.pi / fronds;
    if (math.sin(a) < 0) frond(a, _leaves);
  }
  for (final o in const [Offset(-0.06, 0.05), Offset(0.06, 0.06)]) {
    s.canvas.drawCircle(
      top + o * s.unit * grow,
      0.07 * s.unit * grow,
      s.fill(_bark.shade(-0.06)),
    );
  }
  for (var i = 0; i < fronds; i++) {
    final a = 0.3 + i * 2 * math.pi / fronds;
    if (math.sin(a) >= 0) frond(a, _leavesLight);
  }
}

/// Flowers round the plaza, opening one after another.
List<_Item> _flowers(IsoStage s) {
  const beds = [
    (x: 2.6, y: 2.4, tint: _gold),
    (x: 5.2, y: 2.6, tint: _lilac),
    (x: 2.4, y: 4.6, tint: _gold),
    (x: 5.3, y: 4.9, tint: _lilac),
    (x: 4.9, y: 2.1, tint: _paint),
    (x: 2.2, y: 3.0, tint: _paint),
    (x: 3.9, y: 5.5, tint: _gold),
    (x: 5.6, y: 3.3, tint: _gold),
    (x: 5.1, y: 5.75, tint: _lilac),
    (x: 5.75, y: 5.0, tint: _paint),
  ];
  return [
    for (var i = 0; i < beds.length; i++)
      (
        depth: beds[i].x + beds[i].y,
        draw: () => s.flower(
          beds[i].x,
          beds[i].y,
          beds[i].tint,
          _stem,
          grow: s.pop(0.62 + i * 0.03, 0.8 + i * 0.02),
        ),
      ),
  ];
}
