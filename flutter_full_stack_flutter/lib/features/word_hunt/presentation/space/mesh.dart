import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_full_stack_flutter/features/word_hunt/presentation/space/geometry.dart';

/// A solid made of flat triangles, each with its own colour: the low-poly
/// look, where every facet catches the light on its own.
///
/// Built once, by a [MeshBuilder], and drawn as many times as wanted at any
/// place, turn and size by the `Renderer`. Its triangles are wound so that,
/// seen from outside, their corners run anticlockwise - which is how the
/// renderer knows a face is turned away and need not be drawn.
class Mesh {
  Mesh._(this.positions, this.indices, this.colors, this.glow, this.radius);

  /// `x, y, z` of every corner.
  final Float64List positions;

  /// Three corners per triangle.
  final Uint16List indices;

  /// `r, g, b` of every triangle, `0` to `1`.
  final Float64List colors;

  /// How much every triangle shines by its own light, `0` to `1`: a window,
  /// a lamp, an engine. Lit faces are shaded; glowing ones are not.
  final Float64List glow;

  /// How far the furthest corner is from the origin.
  final double radius;

  int get vertexCount => positions.length ~/ 3;
  int get faceCount => indices.length ~/ 3;
}

/// Puts a [Mesh] together a triangle at a time.
class MeshBuilder {
  final List<double> _positions = [];
  final List<int> _indices = [];
  final List<double> _colors = [];
  final List<double> _glow = [];

  int get faceCount => _indices.length ~/ 3;

  /// Adds a corner, returning its index.
  int vertex(V3 p) {
    _positions.addAll([p.x, p.y, p.z]);
    return _positions.length ~/ 3 - 1;
  }

  V3 _at(int i) =>
      V3(_positions[i * 3], _positions[i * 3 + 1], _positions[i * 3 + 2]);

  /// A triangle through corners [a], [b] and [c], turned to face along
  /// [outward] - whichever way round its corners were given.
  void tri(int a, int b, int c, Rgb color, {V3? outward, double glow = 0}) {
    var (p, q) = (b, c);
    if (outward != null) {
      final pa = _at(a);
      final normal = (_at(b) - pa).cross(_at(c) - pa);
      if (normal.dot(outward) < 0) (p, q) = (c, b);
    }
    _indices.addAll([a, p, q]);
    _colors.addAll([color.r, color.g, color.b]);
    _glow.add(glow);
  }

  /// Two triangles over the four corners [a], [b], [c], [d], in order round
  /// the edge.
  void quad(
    int a,
    int b,
    int c,
    int d,
    Rgb color, {
    V3? outward,
    double glow = 0,
  }) {
    tri(a, b, c, color, outward: outward, glow: glow);
    tri(a, c, d, color, outward: outward, glow: glow);
  }

  /// Turns every face from [fromFace] on to face away from [center]. Right
  /// for any part that every straight line from [center] leaves only once -
  /// a ball, a rock, a box.
  void outwardFrom(int fromFace, V3 center) {
    for (var f = fromFace; f < faceCount; f++) {
      final a = _indices[f * 3];
      final b = _indices[f * 3 + 1];
      final c = _indices[f * 3 + 2];
      final pa = _at(a);
      final normal = (_at(b) - pa).cross(_at(c) - pa);
      final middle = (pa + _at(b) + _at(c)) * (1 / 3);
      if (normal.dot(middle - center) < 0) {
        _indices[f * 3 + 1] = c;
        _indices[f * 3 + 2] = b;
      }
    }
  }

  Mesh build() {
    var radius = 0.0;
    for (var i = 0; i < _positions.length; i += 3) {
      radius = math.max(
        radius,
        V3(_positions[i], _positions[i + 1], _positions[i + 2]).length,
      );
    }
    return Mesh._(
      Float64List.fromList(_positions),
      Uint16List.fromList(_indices),
      Float64List.fromList(_colors),
      Float64List.fromList(_glow),
      radius,
    );
  }

  // ----------------------------------------------------------- solids --

  /// A solid of revolution: [profile] - pairs of radius and height, from the
  /// top down - turned round an axis in [segments] steps.
  ///
  /// [place] puts a point given across the axis (`x`, `z`) and along it
  /// (`h`) into the mesh, so the same profile can stand upright (a saucer)
  /// or lie along `z` (a rocket). [color] and [glow] are asked for each
  /// band of the profile and each step round it.
  void lathe(
    List<(double, double)> profile, {
    required int segments,
    required Rgb Function(int band, int step) color,
    double Function(int band, int step)? glow,
    V3 Function(double x, double h, double z)? place,
    double twist = 0,
  }) {
    final put = place ?? V3.new;
    final rings = <List<int>>[];
    for (final (r, h) in profile) {
      if (r == 0) {
        rings.add([vertex(put(0, h, 0))]);
        continue;
      }
      rings.add([
        for (var j = 0; j < segments; j++)
          vertex(
            put(
              r * math.cos(twist + j * 2 * math.pi / segments),
              h,
              r * math.sin(twist + j * 2 * math.pi / segments),
            ),
          ),
      ]);
    }

    for (var i = 0; i + 1 < profile.length; i++) {
      final (r0, h0) = profile[i];
      final (r1, h1) = profile[i + 1];
      // Outward across the profile, traced from the top down: its tangent
      // turned a quarter anticlockwise.
      final nr = -(h1 - h0);
      final nh = r1 - r0;
      final top = rings[i];
      final bottom = rings[i + 1];
      for (var j = 0; j < segments; j++) {
        final k = (j + 1) % segments;
        final angle = twist + (j + 0.5) * 2 * math.pi / segments;
        final dir =
            put(nr * math.cos(angle), nh, nr * math.sin(angle)) - put(0, 0, 0);
        final c = color(i, j);
        final g = glow?.call(i, j) ?? 0;
        if (top.length == 1) {
          tri(top[0], bottom[j], bottom[k], c, outward: dir, glow: g);
        } else if (bottom.length == 1) {
          tri(top[j], top[k], bottom[0], c, outward: dir, glow: g);
        } else {
          quad(top[j], top[k], bottom[k], bottom[j], c, outward: dir, glow: g);
        }
      }
    }
  }

  /// A ball of radius [radius] about [center], from an icosahedron split
  /// [detail] times. [shape] can push each corner in or out - by its
  /// direction from the middle - and [color] colours each face by its
  /// middle's.
  void sphere({
    required double radius,
    required Rgb Function(V3 direction) color,
    V3 center = V3.zero,
    int detail = 1,
    double Function(V3 direction)? shape,
    double Function(V3 direction)? glow,
  }) {
    final (points, faces) = _icosphere(detail);
    final from = faceCount;
    final index = [
      for (final p in points)
        vertex(center + p * (radius * (shape?.call(p) ?? 1))),
    ];
    for (final (a, b, c) in faces) {
      final middle = (points[a] + points[b] + points[c]).unit;
      tri(
        index[a],
        index[b],
        index[c],
        color(middle),
        glow: glow?.call(middle) ?? 0,
      );
    }
    outwardFrom(from, center);
  }

  /// A box with its corners at [min] and [max], one colour, turned by
  /// [turn] about [pivot].
  void box(
    V3 min,
    V3 max,
    Rgb color, {
    Rot turn = Rot.identity,
    V3 pivot = V3.zero,
    double glow = 0,
  }) {
    final from = faceCount;
    V3 corner(int i) =>
        pivot +
        turn.apply(
          V3(
            i & 1 == 0 ? min.x : max.x,
            i & 2 == 0 ? min.y : max.y,
            i & 4 == 0 ? min.z : max.z,
          ),
        );
    final c = [for (var i = 0; i < 8; i++) vertex(corner(i))];
    for (final (a, b, d, e) in const [
      (0, 1, 3, 2),
      (4, 5, 7, 6),
      (0, 1, 5, 4),
      (2, 3, 7, 6),
      (0, 2, 6, 4),
      (1, 3, 7, 5),
    ]) {
      quad(c[a], c[b], c[d], c[e], color, glow: glow);
    }
    outwardFrom(from, pivot + turn.apply((min + max) * 0.5));
  }

  /// A flat slab through the outline [points] (in order round it), [depth]
  /// thick across [across]: a fin, a wing.
  void slab(List<V3> points, V3 across, double depth, Rgb color) {
    final from = faceCount;
    final half = across.unit * (depth / 2);
    final front = [for (final p in points) vertex(p + half)];
    final back = [for (final p in points) vertex(p - half)];
    for (var i = 1; i + 1 < points.length; i++) {
      tri(front[0], front[i], front[i + 1], color);
      tri(back[0], back[i], back[i + 1], color);
    }
    for (var i = 0; i < points.length; i++) {
      final j = (i + 1) % points.length;
      quad(front[i], front[j], back[j], back[i], color);
    }
    var middle = V3.zero;
    for (final p in points) {
      middle = middle + p;
    }
    outwardFrom(from, middle * (1 / points.length));
  }

  /// A flat ring round the `y` axis from [inner] to [outer], in [segments]
  /// steps, coloured by [color] for each step. Both sides are faces.
  void ring({
    required double inner,
    required double outer,
    required int segments,
    required Rgb Function(int step) color,
    double glow = 0,
  }) {
    final a = <int>[];
    final b = <int>[];
    for (var j = 0; j < segments; j++) {
      final angle = j * 2 * math.pi / segments;
      final c = math.cos(angle);
      final s = math.sin(angle);
      a.add(vertex(V3(inner * c, 0, inner * s)));
      b.add(vertex(V3(outer * c, 0, outer * s)));
    }
    for (var j = 0; j < segments; j++) {
      final k = (j + 1) % segments;
      quad(a[j], a[k], b[k], b[j], color(j), outward: V3.up, glow: glow);
      quad(a[j], a[k], b[k], b[j], color(j), outward: -V3.up, glow: glow);
    }
  }
}

/// The corners and faces of an icosahedron split [detail] times, every
/// corner on the unit ball.
(List<V3>, List<(int, int, int)>) _icosphere(int detail) {
  final t = (1 + math.sqrt(5)) / 2;
  final points = [
    for (final p in [
      V3(-1, t, 0),
      V3(1, t, 0),
      V3(-1, -t, 0),
      V3(1, -t, 0),
      V3(0, -1, t),
      V3(0, 1, t),
      V3(0, -1, -t),
      V3(0, 1, -t),
      V3(t, 0, -1),
      V3(t, 0, 1),
      V3(-t, 0, -1),
      V3(-t, 0, 1),
    ])
      p.unit,
  ];
  var faces = const [
    (0, 11, 5),
    (0, 5, 1),
    (0, 1, 7),
    (0, 7, 10),
    (0, 10, 11),
    (1, 5, 9),
    (5, 11, 4),
    (11, 10, 2),
    (10, 7, 6),
    (7, 1, 8),
    (3, 9, 4),
    (3, 4, 2),
    (3, 2, 6),
    (3, 6, 8),
    (3, 8, 9),
    (4, 9, 5),
    (2, 4, 11),
    (6, 2, 10),
    (8, 6, 7),
    (9, 8, 1),
  ];
  for (var level = 0; level < detail; level++) {
    final halfway = <int, int>{};
    int middle(int a, int b) {
      final key = a < b ? a * 65536 + b : b * 65536 + a;
      return halfway.putIfAbsent(key, () {
        points.add(((points[a] + points[b]) * 0.5).unit);
        return points.length - 1;
      });
    }

    faces = [
      for (final (a, b, c) in faces) ...[
        (a, middle(a, b), middle(c, a)),
        (b, middle(b, c), middle(a, b)),
        (c, middle(c, a), middle(b, c)),
        (middle(a, b), middle(b, c), middle(c, a)),
      ],
    ];
  }
  return (points, faces);
}
