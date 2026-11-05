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
) => [for (var i = 0; i <= steps; i++) at(i / steps)];

/// A lathe lying along `z`, its nose towards `-z`, centred on [at] and its
/// cross-section drawn out [wide] across and [tall] up: a hull, a nacelle,
/// a barrel.
V3 Function(double x, double h, double z) _lengthwise({
  V3 at = V3.zero,
  double wide = 1,
  double tall = 1,
}) =>
    (x, h, z) => V3(at.x + x * wide, at.y + z * tall, at.z - h);

/// A lathe standing up, centred on [at].
V3 Function(double x, double h, double z) _upright(V3 at) =>
    (x, h, z) => V3(at.x + x, at.y + h, at.z + z);

/// The normal of the flat face through [a], [b] and [c].
V3 _across(V3 a, V3 b, V3 c) => (b - a).cross(c - a).unit;

const _graphite = Rgb(0.2, 0.21, 0.24);
const _steel = Rgb(0.72, 0.74, 0.78);
const _plasma = Rgb(0.58, 0.86, 1);
const _foil = Rgb(0.95, 0.74, 0.32);

/// A light on a ship, drawn as a glow over it: where it is and which way it
/// shines, in the ship's own space - or, with no `facing`, all round - and
/// how big, as a share of the ship.
typedef ShipLight = ({V3 at, V3? facing, double size});

/// The kinds of ship a word can fly on. Each wave mixes them, so no two
/// look alike and the sky never settles into a pattern.
///
/// They are all about two units across, nose (where they have one) along
/// `-z`, and coloured when drawn - their paint and their lights - so one
/// mesh serves every colour.
enum ShipStyle {
  /// The classic flying saucer: a glass dome on a glossy disc, turning.
  saucer(spin: 1, tip: 0.34),

  /// A round scout drone, a glowing eye in front and a ring of lights.
  orb(spin: 0, tip: 0.1),

  /// A swept-wing interceptor.
  dart(spin: 0, tip: 0.25),

  /// A cargo hauler: a cab, a spine and containers.
  hauler(spin: 0, tip: 0.25),

  /// A flat ray of a ship, all curves.
  manta(spin: 0, tip: 0.4),

  /// A probe on wide solar panels, a dish on top, its panels turned to
  /// the viewer.
  probe(spin: 0, tip: 0.15);

  ShipStyle({required this.spin, required this.tip});

  /// How fast it turns about itself, as a share of a saucer's turn; `0`
  /// for one that faces where it flies.
  final double spin;

  /// How far it is tipped towards the viewer, beyond being seen from a
  /// little above: enough to see a saucer's dome, little enough to see a
  /// dart's wings side on.
  final double tip;

  /// Its lights that are drawn as glows: engines, an eye, a lamp.
  List<ShipLight> get lights => switch (this) {
    saucer => const [(at: V3(0, -0.22, 0), facing: null, size: 0.9)],
    orb => const [(at: V3(0, 0.02, -0.54), facing: V3(0, 0, -1), size: 0.4)],
    dart => const [(at: V3(0, 0, 0.74), facing: V3(0, 0, 1), size: 0.38)],
    hauler => const [
      (at: V3(0.13, 0, 0.9), facing: V3(0, 0, 1), size: 0.3),
      (at: V3(-0.13, 0, 0.9), facing: V3(0, 0, 1), size: 0.3),
    ],
    manta => const [
      (at: V3(0.22, 0, 0.68), facing: V3(0, 0, 1), size: 0.3),
      (at: V3(-0.22, 0, 0.68), facing: V3(0, 0, 1), size: 0.3),
    ],
    probe => const [(at: V3(0, 0.74, 0), facing: null, size: 0.18)],
  };
}

/// Everything the word hunt's space is built of, made from numbers rather
/// than drawn: nothing to license, nothing in the app bundle, and a change
/// of shape is a change of profile.
///
/// Each is made the first time it is asked for and kept, since a mesh is
/// only ever drawn, never changed.
abstract final class Models {
  static final Map<ShipStyle, Mesh> _ships = {};
  static final Map<double, Mesh> _planets = {};
  static final Map<double, Mesh> _rings = {};
  static final Map<double, Mesh> _moons = {};
  static final Map<(double, int), Mesh> _rocks = {};

  /// A word ship of [style], to be drawn in a ship's paint and trim.
  static Mesh ship(ShipStyle style) => _ships.putIfAbsent(
    style,
    () => switch (style) {
      ShipStyle.saucer => _saucer(),
      ShipStyle.orb => _orb(),
      ShipStyle.dart => _dart(),
      ShipStyle.hauler => _hauler(),
      ShipStyle.manta => _manta(),
      ShipStyle.probe => _probe(),
    },
  );

  /// The learner's ship, nose along `-z`: a working spacecraft rather than
  /// a toy rocket - a faceted, panelled hull, a framed glass canopy, twin
  /// engines on pylons, short swept wings with navigation lights, radiator
  /// fins and a pair of laser cannons under the nose. In CNA's white and
  /// red, over graphite. An original design in a utilitarian, hard
  /// science-fiction spirit.
  static final Mesh fighter = _fighter();

  /// Where the fighter's two cannons fire from, in its own space. The
  /// lasers leave from each in turn.
  static const List<V3> muzzles = [
    V3(0.2, -0.17, -1.02),
    V3(-0.2, -0.17, -1.02),
  ];

  /// The fighter's two engines, in its own space: where their glow is.
  static const List<V3> exhausts = [
    V3(0.62, -0.04, 0.78),
    V3(-0.62, -0.04, 0.78),
  ];

  /// A splinter of a ship, for its explosion: faceted, as broken metal is,
  /// in the ship's paint and trim.
  static final Mesh shard = _shard();

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

  // ----------------------------------------------------------- fighter --

  static Mesh _fighter() {
    final white = Rgb.hsl(220, 0.12, 0.9);
    final red = Rgb.of(Brand.red);
    final glass = Rgb.hsl(200, 0.65, 0.38);
    final b = MeshBuilder();

    // The hull: eight flat panels round, swelling from a capped nose and
    // closing behind, with seams between its sections.
    const hull = [
      (0.0, 1.12),
      (0.07, 1.06),
      (0.14, 0.94),
      (0.2, 0.76),
      (0.25, 0.54),
      (0.28, 0.3),
      (0.29, 0.1),
      (0.29, 0.02),
      (0.29, -0.3),
      (0.29, -0.36),
      (0.27, -0.55),
      (0.22, -0.72),
      (0.0, -0.78),
    ];
    b
      ..lathe(
        hull,
        segments: 8,
        twist: math.pi / 8,
        smooth: 28,
        place: _lengthwise(wide: 1.15, tall: 0.75),
        color: (band, _) {
          final h = (hull[band].$2 + hull[band + 1].$2) / 2;
          if (h > 0.9) return _graphite;
          if (h < 0.1 && h > 0.02) return red;
          if (h < -0.3) return _graphite;
          return white;
        },
      )
      // The canopy, and the frame across it.
      ..sphere(
        radius: 0.2,
        center: const V3(0, 0.17, -0.5),
        stretch: const V3(0.72, 0.42, 1.55),
        detail: 2,
        base: Finish.glass,
        color: (_) => glass,
        glow: (_) => 0.12,
      )
      ..box(
        const V3(-0.15, 0.17, -0.52),
        const V3(0.15, 0.255, -0.49),
        _graphite,
      )
      ..box(
        const V3(-0.012, 0.2, -0.78),
        const V3(0.012, 0.258, -0.24),
        _graphite,
      )
      // The spine along the back.
      ..box(
        const V3(-0.06, 0.12, -0.1),
        const V3(0.06, 0.23, 0.55),
        _graphite,
        finish: Finish.chrome,
      );

    for (final side in const [1.0, -1.0]) {
      final x = 0.62 * side;
      b
        // An engine nacelle: an intake in front, an engine bell behind,
        // glowing inside.
        ..lathe(
          const [
            (0, 0.34),
            (0.08, 0.36),
            (0.11, 0.42),
            (0.15, 0.38),
            (0.16, 0.2),
            (0.16, 0.05),
            (0.16, -0.02),
            (0.16, -0.45),
            (0.15, -0.52),
          ],
          segments: 14,
          smooth: 35,
          place: _lengthwise(at: V3(x, -0.04, 0)),
          color: (band, _) => switch (band) {
            0 => _graphite * 0.35,
            1 || 2 => _steel,
            5 => white,
            _ => _graphite,
          },
        )
        ..lathe(
          const [
            (0.15, -0.52),
            (0.135, -0.55),
            (0.16, -0.66),
            (0.185, -0.76),
            (0.17, -0.765),
            (0.1, -0.7),
            (0, -0.66),
          ],
          segments: 14,
          place: _lengthwise(at: V3(x, -0.04, 0)),
          base: Finish.chrome,
          color: (band, _) => band >= 4 ? _plasma : _steel * 0.75,
          glow: (band, _) => band >= 4 ? 1 : 0,
        )
        // The pylon it hangs on.
        ..box(
          V3(side > 0 ? 0.24 : -0.5, -0.08, -0.15),
          V3(side > 0 ? 0.5 : -0.24, 0.02, 0.35),
          _graphite,
        )
        // A short swept wing beyond it, a navigation light at its tip -
        // red to port, green to starboard.
        ..slab(
          [
            V3(0.74 * side, -0.03, -0.05),
            V3(1.12 * side, -0.05, 0.22),
            V3(1.16 * side, -0.05, 0.42),
            V3(0.74 * side, -0.03, 0.42),
          ],
          V3.up,
          0.045,
          white,
        )
        ..box(
          V3(1.12 * side - 0.03, -0.075, 0.38),
          V3(1.12 * side + 0.05, -0.025, 0.46),
          side > 0 ? const Rgb(0.3, 1, 0.45) : const Rgb(1, 0.25, 0.2),
          glow: 1,
        );

      // A radiator fin, angled up off the spine.
      final fin = [
        V3(0.06 * side, 0.2, 0.05),
        V3(0.34 * side, 0.33, 0.15),
        V3(0.34 * side, 0.33, 0.45),
        V3(0.06 * side, 0.2, 0.5),
      ];
      b
        ..slab(
          fin,
          _across(fin[0], fin[1], fin[2]),
          0.02,
          _steel,
          finish: Finish.chrome,
        )
        // A laser cannon under the nose, its muzzle a light.
        ..lathe(
          const [
            (0, 1.02),
            (0.025, 1.0),
            (0.03, 0.96),
            (0.03, 0.42),
            (0.05, 0.38),
            (0.05, 0.12),
            (0, 0.1),
          ],
          segments: 10,
          place: _lengthwise(at: V3(0.2 * side, -0.17, 0)),
          base: Finish.chrome,
          color: (band, _) => band < 2 ? _plasma : _steel,
          glow: (band, _) => band < 2 ? 1 : 0,
        );
    }
    return b.build();
  }

  // ------------------------------------------------------- word ships --

  /// How far out the saucer's dome stands.
  static const _domeFoot = 0.4;

  /// How high the saucer's upper shell is, [r] out from its middle.
  static double _shell(double r) =>
      0.03 + 0.17 * math.pow(1 - math.pow(r / 0.95, 2), 0.85).toDouble();

  static Mesh _saucer() {
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
        color: (band, _) => Swatch.paint(1.15 - 0.15 * band / 5),
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
        color: (band, step) =>
            band == 1 && step.isEven ? const Swatch.trim() : _steel,
        glow: (band, step) => band == 1 && step.isEven ? 1 : 0,
      )
      // Underneath, darker, curving in to the lamp.
      ..lathe(
        _curve(5, (t) => (0.94 - 0.66 * t, -0.045 - 0.16 * math.pow(t, 0.7))),
        segments: segments,
        smooth: 45,
        color: (_, _) => const Swatch.paint(0.4),
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
          return (_domeFoot * math.sin(a), foot + (0.58 - foot) * math.cos(a));
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
        color: (_, _) => _steel,
      )
      ..sphere(
        radius: 0.045,
        center: const V3(0, 0.77, 0),
        color: (_) => const Swatch.trim(),
        glow: (_) => 1,
      );
    return b.build();
  }

  static Mesh _orb() {
    final b = MeshBuilder()
      ..sphere(
        radius: 0.48,
        detail: 3,
        color: (_) => const Swatch.paint(),
      )
      // The ring round its middle: a chrome band, lit.
      ..lathe(
        const [
          (0.56, 0.08),
          (0.83, 0.08),
          (0.88, 0),
          (0.83, -0.08),
          (0.56, -0.08),
          (0.53, 0),
          (0.56, 0.08),
        ],
        segments: 24,
        smooth: 50,
        base: Finish.chrome,
        color: (band, step) =>
            band == 1 && step % 3 == 0 ? const Swatch.trim() : _steel,
        glow: (band, step) => band == 1 && step % 3 == 0 ? 1 : 0,
      )
      // Its eye, looking ahead.
      ..sphere(
        radius: 0.19,
        center: const V3(0, 0.02, -0.44),
        stretch: const V3(1, 1, 0.55),
        detail: 2,
        color: (_) => const Swatch.trim(),
        glow: (_) => 1,
      )
      ..lathe(
        const [(0.012, 0.7), (0.012, 0.45)],
        segments: 6,
        base: Finish.chrome,
        color: (_, _) => _steel,
      )
      ..sphere(
        radius: 0.035,
        center: const V3(0, 0.72, 0),
        color: (_) => const Swatch.trim(),
        glow: (_) => 1,
      );
    // Three thrusters under the ring, none in front of the eye.
    for (final angle in const [0.0, 2 * math.pi / 3, 4 * math.pi / 3]) {
      b.lathe(
        const [
          (0, -0.06),
          (0.06, -0.08),
          (0.07, -0.14),
          (0.06, -0.3),
          (0, -0.32),
        ],
        segments: 8,
        place: _upright(
          V3(0.68 * math.sin(angle), 0, 0.68 * math.cos(angle)),
        ),
        color: (band, _) => band == 3 ? const Swatch.trim() : _graphite,
        glow: (band, _) => band == 3 ? 1 : 0,
      );
    }
    return b.build();
  }

  static Mesh _dart() {
    const body = [
      (0.0, 1.0),
      (0.05, 0.92),
      (0.11, 0.72),
      (0.17, 0.42),
      (0.2, 0.12),
      (0.2, 0.06),
      (0.2, -0.4),
      (0.17, -0.56),
      (0.13, -0.62),
    ];
    final b = MeshBuilder()
      ..lathe(
        body,
        segments: 8,
        twist: math.pi / 8,
        smooth: 28,
        place: _lengthwise(tall: 0.7),
        color: (band, _) => band == 4 ? _graphite : const Swatch.paint(),
      )
      ..lathe(
        const [
          (0.13, -0.62),
          (0.11, -0.64),
          (0.13, -0.74),
          (0.115, -0.745),
          (0.06, -0.7),
          (0, -0.68),
        ],
        segments: 12,
        place: _lengthwise(),
        base: Finish.chrome,
        color: (band, _) => band >= 3 ? const Swatch.trim() : _steel * 0.7,
        glow: (band, _) => band >= 3 ? 1 : 0,
      )
      ..sphere(
        radius: 0.13,
        center: const V3(0, 0.11, -0.3),
        stretch: const V3(0.7, 0.5, 1.9),
        detail: 2,
        base: Finish.glass,
        color: (_) => Rgb.hsl(200, 0.6, 0.35),
        glow: (_) => 0.1,
      );
    for (final side in const [1.0, -1.0]) {
      b
        ..slab(
          [
            V3(0.15 * side, -0.03, -0.25),
            V3(0.88 * side, -0.06, 0.42),
            V3(0.88 * side, -0.06, 0.52),
            V3(0.15 * side, -0.03, 0.5),
          ],
          V3.up,
          0.04,
          const Swatch.paint(0.8),
        )
        ..box(
          V3(0.86 * side - 0.03, -0.085, 0.44),
          V3(0.86 * side + 0.03, -0.035, 0.52),
          const Swatch.trim(),
          glow: 1,
        )
        // A tail fin, canted out.
        ..slab(
          [
            V3(0.1 * side, 0.08, 0.2),
            V3(0.2 * side, 0.36, 0.5),
            V3(0.2 * side, 0.36, 0.6),
            V3(0.1 * side, 0.08, 0.6),
          ],
          V3(1, -0.3 * side, 0).unit,
          0.03,
          const Swatch.paint(0.65),
        );
    }
    return b.build();
  }

  static Mesh _hauler() {
    final glass = Rgb.hsl(200, 0.6, 0.4);
    const cab = [
      (0.0, 0.5),
      (0.14, 0.46),
      (0.24, 0.36),
      (0.28, 0.2),
      (0.28, -0.05),
      (0.0, -0.05),
    ];
    final b = MeshBuilder()
      // The cab, windows across its brow.
      ..lathe(
        cab,
        segments: 8,
        twist: math.pi / 8,
        smooth: 28,
        place: _lengthwise(at: const V3(0, 0, -0.45), wide: 1.1, tall: 0.95),
        color: (band, step) {
          final up = math.sin(math.pi / 8 + (step + 0.5) * math.pi / 4);
          if (band == 1 && up > 0.2) return glass;
          if (band == 4) return _graphite;
          return const Swatch.paint();
        },
        finish: (band, step) {
          final up = math.sin(math.pi / 8 + (step + 0.5) * math.pi / 4);
          return band == 1 && up > 0.2 ? Finish.glass : Finish.paint;
        },
      )
      ..box(const V3(-0.09, -0.09, -0.5), const V3(0.09, 0.09, 0.62), _graphite)
      ..box(
        const V3(-0.26, -0.15, 0.56),
        const V3(0.26, 0.15, 0.78),
        _graphite,
        finish: Finish.chrome,
      )
      ..box(
        const V3(-0.04, 0.24, -0.62),
        const V3(0.04, 0.28, -0.54),
        const Swatch.trim(),
        glow: 1,
      );
    // Containers either side of the spine, in the ship's colours and
    // others, as cargo comes.
    const cargo = [
      Swatch.paint(),
      Swatch.trim(0.8),
      Swatch.paint(0.6),
      _steel,
      Swatch.paint(0.85),
      Swatch.trim(0.6),
    ];
    var k = 0;
    for (final z in const [-0.2, 0.17, 0.48]) {
      for (final x in const [-0.23, 0.23]) {
        b.box(
          V3(x - 0.13, -0.14, z - 0.16),
          V3(x + 0.13, 0.14, z + 0.14),
          cargo[k++ % cargo.length],
          finish: const Finish(specular: 0.25, shininess: 20),
        );
      }
    }
    for (final x in const [-0.13, 0.13]) {
      b.lathe(
        const [(0.08, -0.78), (0.11, -0.9), (0.095, -0.905), (0, -0.84)],
        segments: 12,
        place: _lengthwise(at: V3(x, 0, 0)),
        base: Finish.chrome,
        color: (band, _) => band >= 2 ? const Swatch.trim() : _steel * 0.7,
        glow: (band, _) => band >= 2 ? 1 : 0,
      );
    }
    return b.build();
  }

  static Mesh _manta() {
    final b = MeshBuilder()
      ..sphere(
        radius: 1,
        detail: 3,
        stretch: const V3(0.95, 0.16, 0.62),
        color: (_) => const Swatch.paint(),
      )
      ..sphere(
        radius: 0.22,
        center: const V3(0, 0.1, -0.2),
        stretch: const V3(0.85, 0.45, 1.3),
        detail: 2,
        base: Finish.glass,
        color: (_) => Rgb.hsl(200, 0.6, 0.35),
        glow: (_) => 0.1,
      )
      // A tail fin.
      ..slab(
        const [
          V3(0, 0.05, 0.5),
          V3(0, 0.24, 0.8),
          V3(0, 0.22, 0.9),
          V3(0, 0.04, 0.62),
        ],
        const V3(1, 0, 0),
        0.03,
        const Swatch.paint(0.7),
      );
    for (final side in const [1.0, -1.0]) {
      b
        // A winglet at each tip, its light on top.
        ..slab(
          [
            V3(0.86 * side, 0, -0.05),
            V3(0.96 * side, 0.18, 0.2),
            V3(0.96 * side, 0.18, 0.3),
            V3(0.88 * side, 0, 0.3),
          ],
          const V3(1, 0, 0),
          0.03,
          const Swatch.paint(0.75),
        )
        ..box(
          V3(0.96 * side - 0.025, 0.17, 0.2),
          V3(0.96 * side + 0.025, 0.21, 0.3),
          const Swatch.trim(),
          glow: 1,
        )
        // An engine at the trailing edge.
        ..lathe(
          const [
            (0, -0.45),
            (0.06, -0.47),
            (0.065, -0.62),
            (0.07, -0.68),
            (0.06, -0.685),
            (0, -0.66),
          ],
          segments: 10,
          place: _lengthwise(at: V3(0.22 * side, 0, 0)),
          base: Finish.chrome,
          color: (band, _) => band >= 4 ? const Swatch.trim() : _steel * 0.7,
          glow: (band, _) => band >= 4 ? 1 : 0,
        );
    }
    return b.build();
  }

  static Mesh _probe() {
    const cells = Rgb(0.1, 0.16, 0.42);
    const solar = Finish(specular: 1, shininess: 60, metal: 0.3, sheen: 0.4);
    const body = [
      (0.0, 0.4),
      (0.13, 0.4),
      (0.19, 0.34),
      (0.19, 0.1),
      (0.19, 0.04),
      (0.19, -0.28),
      (0.13, -0.34),
      (0.0, -0.34),
    ];
    final b = MeshBuilder()
      // A hexagonal body in gold foil, a band of the ship's colour round it.
      ..lathe(
        body,
        segments: 6,
        smooth: 20,
        base: Finish.chrome,
        color: (band, _) => switch (band) {
          0 => _steel,
          3 => const Swatch.paint(),
          _ => _foil,
        },
        finish: (band, _) => band == 3 ? Finish.paint : Finish.chrome,
      )
      // A dish on top, its feed a light.
      ..lathe(
        const [(0.3, 0.62), (0.22, 0.56), (0.1, 0.52), (0, 0.5)],
        segments: 16,
        color: (_, _) => const Rgb(0.9, 0.9, 0.92),
      )
      ..lathe(
        const [(0, 0.51), (0.1, 0.53), (0.22, 0.57), (0.3, 0.63)],
        segments: 16,
        color: (_, _) => const Swatch.paint(1.1),
      )
      ..lathe(
        const [(0.012, 0.74), (0.012, 0.5)],
        segments: 6,
        base: Finish.chrome,
        color: (_, _) => _steel,
      )
      ..sphere(
        radius: 0.03,
        center: const V3(0, 0.75, 0),
        color: (_) => const Swatch.trim(),
        glow: (_) => 1,
      );
    for (final side in const [1.0, -1.0]) {
      b.box(
        V3(side > 0 ? 0.19 : -0.34, -0.02, -0.02),
        V3(side > 0 ? 0.34 : -0.19, 0.02, 0.02),
        _steel,
        finish: Finish.chrome,
      );
      // Three panels of solar cells on each arm, a hair apart.
      for (var k = 0; k < 3; k++) {
        final from = 0.34 + k * 0.25;
        b.box(
          V3(side > 0 ? from : -from - 0.23, -0.2, -0.012),
          V3(side > 0 ? from + 0.23 : -from, 0.2, 0.012),
          cells,
          finish: solar,
        );
      }
    }
    return b.build();
  }

  // ------------------------------------------------------------- shard --

  static Mesh _shard() {
    final b = MeshBuilder()..part(smooth: 0);
    final corners = [
      b.vertex(const V3(0, 0.9, 0)),
      b.vertex(const V3(-0.6, -0.4, 0.5)),
      b.vertex(const V3(0.7, -0.35, 0.3)),
      b.vertex(const V3(0, -0.3, -0.8)),
    ];
    final (a, c, d, e) = (corners[0], corners[1], corners[2], corners[3]);
    b
      ..tri(a, c, d, const Swatch.paint())
      ..tri(a, d, e, const Swatch.paint(0.75))
      ..tri(a, e, c, const Swatch.trim(), glow: 0.6)
      ..tri(c, e, d, _steel, finish: Finish.chrome)
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
