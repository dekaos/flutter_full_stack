import 'dart:math' as math;

import 'package:flutter_full_stack_flutter/features/word_hunt/presentation/space/geometry.dart';
import 'package:flutter_full_stack_flutter/features/word_hunt/presentation/space/mesh.dart';
import 'package:flutter_full_stack_flutter/features/word_hunt/presentation/space/palette.dart';
import 'package:flutter_full_stack_flutter/theme/app_theme.dart';

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

  /// A word ship in colour [variant]: a round little saucer, its glass dome
  /// up, lights round its rim and a lamp underneath, about two units across.
  static Mesh saucer(int variant) => _saucers.putIfAbsent(
    variant % ShipColours.count,
    () => _saucer(variant % ShipColours.count),
  );

  /// The learner's rocket, nose along `-z`, about two units long - in CNA's
  /// white, red and blue.
  static final Mesh rocket = _rocket();

  /// A splinter of ship [variant], for its explosion.
  static Mesh shard(int variant) => _shards.putIfAbsent(
    variant % ShipColours.count,
    () => _shard(variant % ShipColours.count),
  );

  /// A planet of unit radius, its seas and lands in [palette]'s colours.
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

  static Mesh _saucer(int variant) {
    final body = ShipColours.body[variant];
    final lights = ShipColours.lights[variant];
    final top = body.lerp(const Rgb(1, 1, 1), 0.18);
    final belly = body * 0.62;
    const lamp = Rgb(1, 0.96, 0.78);
    final b = MeshBuilder()
      // The hull, from the top of its upper shell, out to the rim and in
      // again underneath, to the lamp.
      ..lathe(
        const [
          (0, 0.21),
          (0.32, 0.2),
          (0.58, 0.15),
          (0.8, 0.075),
          (0.96, 0.005),
          (0.96, -0.05),
          (0.8, -0.11),
          (0.55, -0.17),
          (0.3, -0.205),
          (0.2, -0.215),
          (0, -0.23),
        ],
        segments: 14,
        color: (band, step) => switch (band) {
          4 => step.isEven ? lights : body * 0.5,
          < 4 => top.lerp(body, band / 4),
          8 || 9 => lamp,
          _ => belly,
        },
        glow: (band, step) => switch (band) {
          4 => step.isEven ? 1 : 0,
          8 || 9 => 0.9,
          _ => 0,
        },
      )
      // The dome, glass that catches the light.
      ..lathe(
        const [
          (0, 0.6),
          (0.14, 0.58),
          (0.26, 0.52),
          (0.34, 0.42),
          (0.38, 0.3),
          (0.39, 0.17),
        ],
        segments: 14,
        twist: 0.2,
        color: (band, step) => Rgb.hsl(192, 0.75, 0.7 + 0.04 * (3 - band)),
        glow: (band, step) => band == 0 ? 0.5 : 0.22,
      )
      // An antenna, its tip a light.
      ..box(
        const V3(-0.018, 0.58, -0.018),
        const V3(0.018, 0.74, 0.018),
        body * 0.8,
      )
      ..sphere(
        radius: 0.06,
        center: const V3(0, 0.77, 0),
        detail: 0,
        color: (_) => lights,
        glow: (_) => 1,
      );
    return b.build();
  }

  // ------------------------------------------------------------ rocket --

  static Mesh _rocket() {
    final white = Rgb.hsl(220, 0.25, 0.93);
    final red = Rgb.of(Brand.red);
    final blue = Rgb.of(Brand.blue).lerp(const Rgb(0.4, 0.5, 1), 0.3);
    const metal = Rgb(0.28, 0.3, 0.36);
    const flame = Rgb(1, 0.62, 0.25);
    final glass = Rgb.hsl(195, 0.85, 0.66);
    const segments = 16;
    // Along the rocket, from the tip of its nose (`h` forwards, so towards
    // `-z`) to the end of its nozzle.
    V3 along(double x, double h, double z) => V3(x, z, -h);
    bool window(int step) =>
        math.sin((step + 0.5) * 2 * math.pi / segments) > 0.62;

    final b = MeshBuilder()
      ..lathe(
        const [
          (0, 1.05),
          (0.1, 0.92),
          (0.19, 0.7),
          (0.25, 0.42),
          (0.27, 0.12),
          (0.27, -0.12),
          (0.25, -0.3),
          (0.21, -0.44),
          (0.15, -0.52),
          (0.19, -0.64),
          (0.12, -0.66),
          (0, -0.62),
        ],
        segments: segments,
        place: along,
        color: (band, step) => switch (band) {
          0 || 1 => red,
          2 when window(step) => glass,
          5 => blue,
          8 || 9 => metal,
          10 => flame,
          _ => white,
        },
        glow: (band, step) => switch (band) {
          2 when window(step) => 0.55,
          10 => 1,
          _ => 0,
        },
      );

    // Four fins, set as an X so that from behind - where the learner sees
    // it - the rocket stands on two and shows two.
    for (var k = 0; k < 4; k++) {
      final angle = math.pi / 4 + k * math.pi / 2;
      final c = math.cos(angle);
      final s = math.sin(angle);
      V3 at(double radial, double h) => V3(radial * c, radial * s, -h);
      b.slab(
        [at(0.2, -0.02), at(0.6, -0.4), at(0.62, -0.62), at(0.2, -0.5)],
        V3(-s, c, 0),
        0.05,
        k.isEven ? red : red * 0.86,
      );
    }
    return b.build();
  }

  // ------------------------------------------------------------- shard --

  static Mesh _shard(int variant) {
    final body = ShipColours.body[variant];
    final b = MeshBuilder();
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
      ..tri(c, e, d, body * 0.6)
      ..outwardFrom(0, const V3(0, -0.04, 0));
    return b.build();
  }

  // ------------------------------------------------------------ planet --

  static Mesh _planet(SpacePalette palette) {
    double height(V3 d) =>
        noise3(d.x * 2.1, d.y * 2.1, d.z * 2.1, seed: 3) +
        0.45 * noise3(d.x * 4.8, d.y * 4.8, d.z * 4.8, seed: 7);
    final b = MeshBuilder()
      ..sphere(
        radius: 1,
        detail: 3,
        shape: (d) => height(d) > 0.12 ? 1.018 : 1,
        color: (d) {
          final h = height(d);
          final speckle = 0.06 * noise3(d.x * 9, d.y * 9, d.z * 9, seed: 5);
          if (d.y.abs() > 0.84 + 0.05 * h) return palette.ice;
          if (h > 0.12) {
            return palette.land.lerp(palette.ice, (h - 0.12) * 0.45) *
                (1 + speckle);
          }
          return palette.sea * (0.86 + 0.14 * (h + 1) / 2 + speckle);
        },
      );
    return b.build();
  }

  /// Ice and dust that scatter the sun whichever side they are seen from,
  /// so they glow a little of their own accord.
  static Mesh _ringsOf(SpacePalette palette) {
    final b = MeshBuilder()
      ..ring(
        inner: 1.42,
        outer: 1.78,
        segments: 56,
        color: (step) => palette.ringInner * (step.isEven ? 1 : 0.94),
        glow: 0.45,
      )
      ..ring(
        inner: 1.84,
        outer: 2.25,
        segments: 56,
        color: (step) => palette.ringOuter * (step.isEven ? 1 : 0.93),
        glow: 0.35,
      );
    return b.build();
  }

  static Mesh _moon(SpacePalette palette) {
    final b = MeshBuilder()
      ..sphere(
        radius: 1,
        color: (d) =>
            palette.moon *
            (0.86 + 0.14 * noise3(d.x * 5, d.y * 5, d.z * 5, seed: 11)),
      );
    return b.build();
  }

  static Mesh _rock(SpacePalette palette, int seed) {
    final b = MeshBuilder()
      ..sphere(
        radius: 1,
        shape: (d) =>
            1 + 0.3 * noise3(d.x * 2.4, d.y * 2.4, d.z * 2.4, seed: seed),
        color: (d) =>
            palette.rock *
            (0.8 + 0.2 * noise3(d.x * 6, d.y * 6, d.z * 6, seed: seed + 1)),
      );
    return b.build();
  }
}
