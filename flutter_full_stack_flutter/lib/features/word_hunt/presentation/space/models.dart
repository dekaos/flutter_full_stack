import 'dart:math' as math;

import 'package:flutter_full_stack_flutter/features/word_hunt/presentation/space/geometry.dart';
import 'package:flutter_full_stack_flutter/features/word_hunt/presentation/space/mesh.dart';
import 'package:flutter_full_stack_flutter/features/word_hunt/presentation/space/palette.dart';
import 'package:flutter_full_stack_flutter/theme/app_theme.dart';

/// [steps] + 1 points of a profile, from `t = 0` to `t = 1`: the radius and
/// height [at] each.
List<(double, double)> _curve(
  int steps,
  (double, double) Function(double t) at,
) => [
  for (var i = 0; i <= steps; i++) at(i / steps),
];

/// Everything the word hunt's space is built of, made from numbers rather
/// than drawn: nothing to license, nothing in the app bundle, and a change
/// of shape is a change of profile.
///
/// Each is made the first time it is asked for and kept, since a mesh is
/// only ever drawn, never changed.
abstract final class Models {
  static final Map<int, Mesh> _saucers = {};
  static final Map<int, Mesh> _shards = {};
  static final Map<double, Mesh> _planets = {};
  static final Map<double, Mesh> _rings = {};
  static final Map<double, Mesh> _moons = {};
  static final Map<(double, int), Mesh> _rocks = {};

  /// A word ship in colour [variant]: a round little saucer in glossy
  /// paint, a glass dome up, a chrome rim set with lights and a lamp
  /// underneath, about two units across.
  static Mesh saucer(int variant) => _saucers.putIfAbsent(
    variant % ShipColours.count,
    () => _saucer(variant % ShipColours.count),
  );

  /// The learner's rocket, nose along `-z`, about two units long: CNA's
  /// white, red and blue in glossy paint, a glass canopy, a chrome nozzle,
  /// and a laser cannon on each upper fin.
  static final Mesh rocket = _rocket();

  /// Where the rocket's two cannons fire from, in its own space. The lasers
  /// leave from each in turn.
  static final List<V3> muzzles = [
    for (final angle in const [math.pi / 4, 3 * math.pi / 4])
      V3(_cannonAt * math.cos(angle), _cannonAt * math.sin(angle), -0.04),
  ];

  static const _cannonAt = 0.6;

  /// A splinter of ship [variant], for its explosion: faceted, as broken
  /// metal is.
  static Mesh shard(int variant) => _shards.putIfAbsent(
    variant % ShipColours.count,
    () => _shard(variant % ShipColours.count),
  );

  /// A planet of unit radius: oceans, coasts, lands and mountains, ice at
  /// its poles and clouds over it, in [palette]'s colours.
  static Mesh planet(SpacePalette palette) =>
      _planets.putIfAbsent(palette.hue, () => _planet(palette));

  /// The planet's rings, round `y`, for a planet of unit radius.
  static Mesh rings(SpacePalette palette) =>
      _rings.putIfAbsent(palette.hue, () => _ringsOf(palette));

  static Mesh moon(SpacePalette palette) =>
      _moons.putIfAbsent(palette.hue, () => _moon(palette));

  /// A lumpy rock of about unit radius; [seed] picks its shape.
  static Mesh rock(SpacePalette palette, int seed) =>
      _rocks.putIfAbsent((palette.hue, seed), () => _rock(palette, seed));

  // ------------------------------------------------------------ saucer --

  /// How far out the saucer's dome stands.
  static const _domeFoot = 0.4;

  /// How high the saucer's upper shell is, [r] out from its middle.
  static double _shell(double r) =>
      0.03 + 0.17 * math.pow(1 - math.pow(r / 0.95, 2), 0.85).toDouble();

  static Mesh _saucer(int variant) {
    final body = ShipColours.body[variant];
    final lights = ShipColours.lights[variant];
    final belly = body * 0.55;
    const steel = Rgb(0.78, 0.8, 0.86);
    const lamp = Rgb(1, 0.96, 0.8);
    const segments = 24;
    final b = MeshBuilder()
      // The upper shell, from under the dome out to the rim: a gentle
      // curve. It starts where the dome stands rather than under it, so the
      // two never pass through each other.
      ..lathe(
        _curve(5, (t) {
          final r = _domeFoot + (0.95 - _domeFoot) * t;
          return (r, _shell(r));
        }),
        segments: segments,
        smooth: 30,
        color: (band, step) =>
            body.lerp(const Rgb(1, 1, 1), 0.1 * (1 - band / 5)),
      )
      // The rim: a rounded lip of chrome, set with lights.
      ..lathe(
        const [
          (0.95, 0.03),
          (0.99, 0.014),
          (1, -0.008),
          (0.985, -0.03),
          (0.94, -0.045),
        ],
        segments: segments,
        smooth: 70,
        base: Finish.chrome,
        color: (band, step) => band == 1 && step.isEven ? lights : steel,
        glow: (band, step) => band == 1 && step.isEven ? 1 : 0,
      )
      // Underneath, darker, curving in to the lamp.
      ..lathe(
        _curve(
          5,
          (t) => (0.94 - 0.66 * t, -0.045 - 0.16 * math.pow(t, 0.7)),
        ),
        segments: segments,
        smooth: 45,
        color: (_, _) => belly,
      )
      ..lathe(
        const [(0.28, -0.205), (0.2, -0.218), (0, -0.226)],
        segments: segments,
        color: (_, _) => lamp,
        glow: (_, _) => 0.95,
      )
      // The dome: glass, which shows the sky more than its own tint,
      // standing on the shell's inner edge.
      ..lathe(
        _curve(7, (t) {
          final a = t * math.pi / 2;
          final foot = _shell(_domeFoot);
          return (
            _domeFoot * math.sin(a),
            foot + (0.58 - foot) * math.cos(a),
          );
        }),
        segments: segments,
        smooth: 60,
        base: Finish.glass,
        color: (_, _) => Rgb.hsl(194, 0.55, 0.32),
        glow: (_, _) => 0.06,
      )
      // An antenna, its tip a light.
      ..lathe(
        const [(0.014, 0.74), (0.014, 0.52)],
        segments: 8,
        base: Finish.chrome,
        color: (_, _) => steel,
      )
      ..sphere(
        radius: 0.045,
        center: const V3(0, 0.77, 0),
        color: (_) => lights,
        glow: (_) => 1,
      );
    return b.build();
  }

  // ------------------------------------------------------------ rocket --

  static Mesh _rocket() {
    final white = Rgb.hsl(220, 0.2, 0.94);
    final red = Rgb.of(Brand.red);
    final blue = Rgb.of(Brand.blue).lerp(const Rgb(0.35, 0.45, 1), 0.35);
    const steel = Rgb(0.74, 0.76, 0.8);
    const flame = Rgb(1, 0.6, 0.22);
    const segments = 28;
    // Along the rocket, from the tip of its nose (`h` forwards, so towards
    // `-z`) to the end of its nozzle.
    V3 along(double x, double h, double z) => V3(x, z, -h);

    // The body: an ogive nose swelling into the barrel, then tapering to
    // the engine.
    final body = [
      ..._curve(
        9,
        (t) => (0.27 * math.pow(1 - math.pow(1 - t, 2), 0.6), 1.12 - 0.6 * t),
      ),
      (0.27, 0.34),
      (0.27, 0.04),
      (0.27, -0.06),
      (0.27, -0.24),
      (0.258, -0.33),
      (0.235, -0.4),
      (0.205, -0.46),
    ];
    final b = MeshBuilder()
      ..lathe(
        body,
        segments: segments,
        place: along,
        smooth: 30,
        color: (band, step) {
          final h = (body[band].$2 + body[band + 1].$2) / 2;
          return h > 0.66
              ? red
              : h < 0.04 && h > -0.06
              ? blue
              : white;
        },
      )
      // The nozzle: a bell of bare metal, glowing inside.
      ..lathe(
        const [
          (0.2, -0.46),
          (0.15, -0.475),
          (0.16, -0.55),
          (0.18, -0.63),
          (0.205, -0.72),
          (0.19, -0.725),
          (0.12, -0.66),
          (0, -0.62),
        ],
        segments: segments,
        place: along,
        base: Finish.chrome,
        color: (band, _) => band >= 6 ? flame : steel * 0.7,
        glow: (band, _) => band >= 6 ? 1 : 0,
      )
      // The canopy: a bubble of glass over the cockpit, lit from inside.
      ..sphere(
        radius: 0.12,
        center: const V3(0, 0.24, -0.34),
        stretch: const V3(0.85, 0.8, 1.9),
        detail: 2,
        base: Finish.glass,
        color: (_) => Rgb.hsl(198, 0.7, 0.5),
        glow: (_) => 0.18,
      );

    // Four fins, set as an X so that from behind - where the learner sees
    // it - the rocket stands on two and shows two.
    for (var k = 0; k < 4; k++) {
      final angle = math.pi / 4 + k * math.pi / 2;
      final c = math.cos(angle);
      final s = math.sin(angle);
      V3 at(double radial, double h) => V3(radial * c, radial * s, -h);
      b.slab(
        [at(0.24, -0.05), at(0.56, -0.42), at(0.6, -0.66), at(0.24, -0.5)],
        V3(-s, c, 0),
        0.045,
        k.isEven ? red : red * 0.9,
      );
    }

    // A laser cannon along the tip of each upper fin, its muzzle a light.
    for (final angle in const [math.pi / 4, 3 * math.pi / 4]) {
      final cx = _cannonAt * math.cos(angle);
      final cy = _cannonAt * math.sin(angle);
      b.lathe(
        const [
          (0, 0.04),
          (0.02, 0.035),
          (0.026, 0.01),
          (0.026, -0.5),
          (0.042, -0.52),
          (0.042, -0.64),
          (0, -0.64),
        ],
        segments: 10,
        place: (x, h, z) => V3(cx + x, cy + z, -h),
        base: Finish.chrome,
        color: (band, _) => band < 2 ? const Rgb(0.5, 0.95, 1) : steel,
        glow: (band, _) => band < 2 ? 1 : 0,
      );
    }
    return b.build();
  }

  // ------------------------------------------------------------- shard --

  static Mesh _shard(int variant) {
    final body = ShipColours.body[variant];
    final b = MeshBuilder()..part(smooth: 0);
    final corners = [
      b.vertex(const V3(0, 0.9, 0)),
      b.vertex(const V3(-0.6, -0.4, 0.5)),
      b.vertex(const V3(0.7, -0.35, 0.3)),
      b.vertex(const V3(0, -0.3, -0.8)),
    ];
    final (a, c, d, e) = (corners[0], corners[1], corners[2], corners[3]);
    b
      ..tri(a, c, d, body)
      ..tri(a, d, e, body * 0.8)
      ..tri(a, e, c, ShipColours.lights[variant], glow: 0.6)
      ..tri(c, e, d, const Rgb(0.7, 0.72, 0.78), finish: Finish.chrome)
      ..outwardFrom(0, const V3(0, -0.04, 0));
    return b.build();
  }

  // ------------------------------------------------------------ planet --

  static Mesh _planet(SpacePalette palette) {
    double height(V3 d) =>
        fbm3(d.x * 1.7, d.y * 1.7, d.z * 1.7, octaves: 5, seed: 3);
    double clouds(V3 d) => fbm3(
      d.x * 2.6 + 7,
      d.y * 5.2,
      d.z * 2.6 - 3,
      seed: 11,
    );
    final deep = palette.sea * 0.55;
    final shallow = palette.sea.lerp(const Rgb(0.6, 0.9, 1), 0.25);
    final shore = palette.land.lerp(const Rgb(0.95, 0.88, 0.7), 0.5);
    final low = palette.land * 0.8;
    final high = palette.land.lerp(const Rgb(0.42, 0.36, 0.32), 0.55);
    const coast = 0.04;

    Rgb ground(V3 d) {
      final h = height(d);
      if (h < coast) {
        return deep.lerp(shallow, ((h + 0.35) / (0.35 + coast)).clamp(0, 1));
      }
      final up = (h - coast) / 0.4;
      if (up < 0.06) return shore.lerp(low, up / 0.06);
      if (up < 0.6) return low.lerp(high, (up - 0.06) / 0.54);
      return high.lerp(palette.ice, ((up - 0.6) / 0.25).clamp(0, 1));
    }

    Rgb colour(V3 d) {
      var c = ground(d);
      // Ice towards the poles, its edge ragged.
      final polar = d.y.abs() + 0.06 * fbm3(d.x * 6, d.y * 6, d.z * 6, seed: 5);
      if (polar > 0.8) {
        c = c.lerp(palette.ice, ((polar - 0.8) / 0.08).clamp(0, 1));
      }
      // And weather over all of it.
      final cloud = ((clouds(d) - 0.08) / 0.3).clamp(0.0, 1.0);
      return c.lerp(const Rgb(0.97, 0.98, 1), cloud * 0.85);
    }

    final b = MeshBuilder()
      ..sphere(
        radius: 1,
        detail: 4,
        blend: true,
        shape: (d) => 1 + 0.025 * math.max(0, height(d) - coast),
        color: colour,
        finish: (d) =>
            height(d) < coast && clouds(d) < 0.12 ? Finish.water : Finish.matte,
      );
    return b.build();
  }

  /// Bands of ice and dust, some bright and some dim, with gaps between:
  /// they scatter the sun whichever side they are seen from, so they glow
  /// a little of their own accord.
  static Mesh _ringsOf(SpacePalette palette) {
    // Inner edge, outer edge, how bright: many fine bands, as ice rings
    // are, the brightest in the middle and a dark gap two thirds out.
    const bands = [
      (1.36, 1.44, 0.35),
      (1.45, 1.53, 0.5),
      (1.54, 1.66, 0.8),
      (1.67, 1.79, 0.95),
      (1.8, 1.84, 0.6),
      (1.92, 2.02, 0.7),
      (2.03, 2.14, 0.55),
      (2.15, 2.2, 0.35),
      (2.24, 2.28, 0.25),
    ];
    final b = MeshBuilder();
    for (final (i, (inner, outer, strength)) in bands.indexed) {
      final tone =
          palette.ringInner.lerp(palette.ringOuter, i / (bands.length - 1)) *
          strength;
      b.ring(
        inner: inner,
        outer: outer,
        segments: 96,
        color: (_) => tone,
        glow: 0.25,
      );
    }
    return b.build();
  }

  static Mesh _moon(SpacePalette palette) {
    final b = MeshBuilder()
      ..sphere(
        radius: 1,
        detail: 3,
        blend: true,
        base: Finish.rock,
        shape: (d) => 1 + 0.02 * fbm3(d.x * 4, d.y * 4, d.z * 4, seed: 13),
        color: (d) {
          // Its dark seas fade in and out: a hard edge between them and
          // the highlands came out as a polygon drawn on the moon.
          final maria = fbm3(d.x * 1.6, d.y * 1.6, d.z * 1.6, seed: 9);
          final sea = ((maria + 0.05) / 0.35).clamp(0.0, 1.0);
          final dust = fbm3(d.x * 9, d.y * 9, d.z * 9, seed: 12);
          return palette.moon *
              (0.95 - 0.2 * sea * sea * (3 - 2 * sea) + 0.1 * dust);
        },
      );
    return b.build();
  }

  static Mesh _rock(SpacePalette palette, int seed) {
    final b = MeshBuilder()
      ..sphere(
        radius: 1,
        blend: true,
        detail: 2,
        smooth: 55,
        base: Finish.rock,
        shape: (d) =>
            1 +
            0.34 * fbm3(d.x * 1.4, d.y * 1.4, d.z * 1.4, seed: seed) +
            0.1 * fbm3(d.x * 4.5, d.y * 4.5, d.z * 4.5, seed: seed + 7) +
            0.04 * fbm3(d.x * 11, d.y * 11, d.z * 11, seed: seed + 9),
        color: (d) =>
            palette.rock *
            (0.78 + 0.22 * fbm3(d.x * 4, d.y * 4, d.z * 4, seed: seed + 1)),
      );
    return b.build();
  }
}
