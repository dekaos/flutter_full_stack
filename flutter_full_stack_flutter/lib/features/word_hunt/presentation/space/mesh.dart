import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_full_stack_flutter/features/word_hunt/presentation/space/geometry.dart';

/// What a surface is made of, as the light sees it.
@immutable
class Finish {
  const Finish({
    this.specular = 0.15,
    this.shininess = 16,
    this.metal = 0,
    this.sheen = 0,
  });

  /// Chalky: nearly no highlight.
  static const matte = Finish(specular: 0.03, shininess: 6);

  /// Bare stone: a dull, broad sheen.
  static const rock = Finish(specular: 0.06, shininess: 10);

  /// Glossy paint over metal: a tight highlight and a faint reflection at
  /// the edges.
  static const paint = Finish(specular: 0.55, shininess: 30, sheen: 0.14);

  /// Polished metal: it shows the sky around it more than its own colour.
  static const chrome = Finish(
    specular: 1.1,
    shininess: 50,
    metal: 0.85,
    sheen: 0.25,
  );

  /// Glass: dark in itself, bright where it reflects, and brightest at the
  /// edges, as glass is.
  static const glass = Finish(
    specular: 1.5,
    shininess: 55,
    metal: 0.5,
    sheen: 0.8,
  );

  /// Open water seen from space: the sun's glint across it.
  static const water = Finish(specular: 0.7, shininess: 48, sheen: 0.1);

  /// How bright the sun's highlight on it is.
  final double specular;

  /// How tight that highlight is.
  final double shininess;

  /// How much it reflects its surroundings instead of showing its colour,
  /// `0` to `1`.
  final double metal;

  /// How much it reflects the sky when seen edge on.
  final double sheen;
}

/// A solid made of triangles, shaded smoothly across each surface and
/// sharply where one surface meets another.
///
/// Built once, by a [MeshBuilder], and drawn as many times as wanted at any
/// place, turn and size by the `Renderer`. Every corner carries its own
/// normal, colour and [Finish], so the light is worked out per corner and
/// blended across each triangle by the GPU: a curve looks curved, not cut
/// from flat facets. Its triangles are wound so that, seen from outside,
/// their corners run anticlockwise - which is how the renderer knows a face
/// is turned away and need not be drawn.
class Mesh {
  Mesh._(
    this.positions,
    this.normals,
    this.colors,
    this.glow,
    this.finishes,
    this.indices,
    this.radius,
  );

  /// `x, y, z` of every corner.
  final Float64List positions;

  /// The surface's direction at every corner, a unit vector.
  final Float64List normals;

  /// `r, g, b` of every corner, as linear light, `0` to `1`.
  final Float64List colors;

  /// How much every corner shines by its own light, `0` to `1`: a window,
  /// a lamp, an engine.
  final Float64List glow;

  /// Each corner's [Finish], as `specular, shininess, metal, sheen`.
  final Float64List finishes;

  /// Three corners per triangle.
  final Uint32List indices;

  /// How far the furthest corner is from the origin.
  final double radius;

  int get vertexCount => positions.length ~/ 3;
  int get faceCount => indices.length ~/ 3;
}

/// Puts a [Mesh] together a triangle at a time, in parts.
///
/// Each part - a hull, a dome, a fin - is smoothed within itself and kept
/// sharp against the others: its faces share their normals at a corner only
/// with faces of the same part that meet them at less than its `smooth`
/// angle. So a saucer's rim is a crisp edge between two smooth shells, and
/// a fin stays flat.
class MeshBuilder {
  final List<double> _positions = [];
  final List<int> _indices = [];

  // Three of each per face, one for each of its corners.
  final List<Rgb> _colors = [];
  final List<double> _glow = [];
  final List<Finish> _finishes = [];

  final List<int> _parts = [];
  final List<double> _creases = [];

  int _part = 0;
  double _crease = math.cos(40 * math.pi / 180);
  Finish _finish = Finish.paint;

  int get faceCount => _indices.length ~/ 3;

  /// Starts a new part: what is added from here on is smoothed across
  /// edges gentler than [smooth] degrees - `0` for flat facets, `180` for
  /// smooth all over - and has [finish] unless a face says otherwise.
  void part({double smooth = 40, Finish finish = Finish.paint}) {
    _part++;
    _crease = smooth <= 0 ? 2 : math.cos(smooth * math.pi / 180);
    _finish = finish;
  }

  /// Adds a corner, returning its index.
  int vertex(V3 p) {
    _positions.addAll([p.x, p.y, p.z]);
    return _positions.length ~/ 3 - 1;
  }

  V3 _at(int i) =>
      V3(_positions[i * 3], _positions[i * 3 + 1], _positions[i * 3 + 2]);

  /// A triangle through corners [a], [b] and [c], turned to face along
  /// [outward] - whichever way round its corners were given.
  ///
  /// Each corner can have a [corners] colour and finish of its own, which
  /// the light then blends across the face: a coast fading from sea to
  /// land, rather than a triangle of each.
  void tri(
    int a,
    int b,
    int c,
    Rgb color, {
    V3? outward,
    double glow = 0,
    Finish? finish,
    (Rgb, Finish) Function(int corner)? corners,
  }) {
    var (p, q) = (b, c);
    if (outward != null) {
      final pa = _at(a);
      final normal = (_at(b) - pa).cross(_at(c) - pa);
      if (normal.dot(outward) < 0) (p, q) = (c, b);
    }
    _indices.addAll([a, p, q]);
    for (final corner in [a, p, q]) {
      final (rgb, surface) =
          corners?.call(corner) ?? (color, finish ?? _finish);
      _colors.add(rgb);
      _glow.add(glow);
      _finishes.add(surface);
    }
    _parts.add(_part);
    _creases.add(_crease);
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
    Finish? finish,
  }) {
    tri(a, b, c, color, outward: outward, glow: glow, finish: finish);
    tri(a, c, d, color, outward: outward, glow: glow, finish: finish);
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
        // Each corner's colour, glow and finish go with it.
        void swap<T>(List<T> of) {
          final first = of[f * 3 + 1];
          of[f * 3 + 1] = of[f * 3 + 2];
          of[f * 3 + 2] = first;
        }

        swap(_colors);
        swap(_glow);
        swap(_finishes);
      }
    }
  }

  /// The mesh: each corner of each face given the normal of its part's
  /// surface there, and corners that differ in normal, colour, glow or
  /// finish kept apart, so each edge between them stays sharp.
  Mesh build() {
    final faces = faceCount;
    final normal = Float64List(faces * 3);
    final weighted = Float64List(faces * 3);
    final touching = List.generate(_positions.length ~/ 3, (_) => <int>[]);
    for (var f = 0; f < faces; f++) {
      final a = _at(_indices[f * 3]);
      final cross = (_at(_indices[f * 3 + 1]) - a).cross(
        _at(_indices[f * 3 + 2]) - a,
      );
      final unit = cross.unit;
      normal
        ..[f * 3] = unit.x
        ..[f * 3 + 1] = unit.y
        ..[f * 3 + 2] = unit.z;
      weighted
        ..[f * 3] = cross.x
        ..[f * 3 + 1] = cross.y
        ..[f * 3 + 2] = cross.z;
      for (var k = 0; k < 3; k++) {
        touching[_indices[f * 3 + k]].add(f);
      }
    }

    final positions = <double>[];
    final normals = <double>[];
    final colors = <double>[];
    final glow = <double>[];
    final finishes = <double>[];
    final indices = <int>[];
    final seen = <String, int>{};
    var radius = 0.0;

    for (var f = 0; f < faces; f++) {
      for (var k = 0; k < 3; k++) {
        final rgb = _colors[f * 3 + k].linear;
        final finish = _finishes[f * 3 + k];
        final shine = _glow[f * 3 + k];
        final p = _indices[f * 3 + k];
        var nx = 0.0;
        var ny = 0.0;
        var nz = 0.0;
        for (final g in touching[p]) {
          if (_parts[g] != _parts[f]) continue;
          final agree =
              normal[f * 3] * normal[g * 3] +
              normal[f * 3 + 1] * normal[g * 3 + 1] +
              normal[f * 3 + 2] * normal[g * 3 + 2];
          if (g != f && agree < _creases[f]) continue;
          nx += weighted[g * 3];
          ny += weighted[g * 3 + 1];
          nz += weighted[g * 3 + 2];
        }
        final length = math.sqrt(nx * nx + ny * ny + nz * nz);
        if (length > 0) {
          nx /= length;
          ny /= length;
          nz /= length;
        }
        final key =
            '$p|${(nx * 512).round()},${(ny * 512).round()},'
            '${(nz * 512).round()}|${rgb.r},${rgb.g},${rgb.b}|$shine|'
            '${identityHashCode(finish)}';
        indices.add(
          seen.putIfAbsent(key, () {
            final at = _at(p);
            radius = math.max(radius, at.length);
            positions.addAll([at.x, at.y, at.z]);
            normals.addAll([nx, ny, nz]);
            colors.addAll([rgb.r, rgb.g, rgb.b]);
            glow.add(shine);
            finishes.addAll([
              finish.specular,
              finish.shininess,
              finish.metal,
              finish.sheen,
            ]);
            return positions.length ~/ 3 - 1;
          }),
        );
      }
    }
    return Mesh._(
      Float64List.fromList(positions),
      Float64List.fromList(normals),
      Float64List.fromList(colors),
      Float64List.fromList(glow),
      Float64List.fromList(finishes),
      Uint32List.fromList(indices),
      radius,
    );
  }

  // ----------------------------------------------------------- solids --

  /// A solid of revolution: [profile] - pairs of radius and height, from the
  /// top down - turned round an axis in [segments] steps, as one part.
  ///
  /// [place] puts a point given across the axis (`x`, `z`) and along it
  /// (`h`) into the mesh, so the same profile can stand upright (a saucer)
  /// or lie along `z` (a rocket). [color], [glow] and [finish] are asked
  /// for each band of the profile and each step round it.
  void lathe(
    List<(double, double)> profile, {
    required int segments,
    required Rgb Function(int band, int step) color,
    double Function(int band, int step)? glow,
    Finish Function(int band, int step)? finish,
    V3 Function(double x, double h, double z)? place,
    double twist = 0,
    double smooth = 40,
    Finish base = Finish.paint,
  }) {
    part(smooth: smooth, finish: base);
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
        final f = finish?.call(i, j);
        if (top.length == 1) {
          tri(
            top[0],
            bottom[j],
            bottom[k],
            c,
            outward: dir,
            glow: g,
            finish: f,
          );
        } else if (bottom.length == 1) {
          tri(top[j], top[k], bottom[0], c, outward: dir, glow: g, finish: f);
        } else {
          quad(
            top[j],
            top[k],
            bottom[k],
            bottom[j],
            c,
            outward: dir,
            glow: g,
            finish: f,
          );
        }
      }
    }
  }

  /// A ball of radius [radius] about [center], from an icosahedron split
  /// [detail] times, as one part, smooth all over unless [smooth] says
  /// otherwise. [shape] can push each corner in or out - by its direction
  /// from the middle - and [stretch] draws it out along each axis.
  /// [color], [glow] and [finish] are asked for each face, by its middle's
  /// direction - or, with [blend], [color] and [finish] for each corner, by
  /// its own, and blended across the faces between.
  void sphere({
    required double radius,
    required Rgb Function(V3 direction) color,
    V3 center = V3.zero,
    int detail = 1,
    double Function(V3 direction)? shape,
    double Function(V3 direction)? glow,
    Finish Function(V3 direction)? finish,
    V3 stretch = const V3(1, 1, 1),
    double smooth = 180,
    Finish base = Finish.paint,
    bool blend = false,
  }) {
    part(smooth: smooth, finish: base);
    final (points, faces) = _icosphere(detail);
    final from = faceCount;
    final first = _positions.length ~/ 3;
    final index = [
      for (final p in points)
        vertex(
          center +
              V3(p.x * stretch.x, p.y * stretch.y, p.z * stretch.z) *
                  (radius * (shape?.call(p) ?? 1)),
        ),
    ];
    final looks = blend
        ? [for (final p in points) (color(p), finish?.call(p) ?? base)]
        : null;
    for (final (a, b, c) in faces) {
      final middle = (points[a] + points[b] + points[c]).unit;
      tri(
        index[a],
        index[b],
        index[c],
        looks == null ? color(middle) : looks[a].$1,
        glow: glow?.call(middle) ?? 0,
        finish: finish?.call(middle),
        corners: looks == null ? null : (corner) => looks[corner - first],
      );
    }
    outwardFrom(from, center);
  }

  /// A box with its corners at [min] and [max], one colour, turned by
  /// [turn] about [pivot]: a part of its own, flat-faced.
  void box(
    V3 min,
    V3 max,
    Rgb color, {
    Rot turn = Rot.identity,
    V3 pivot = V3.zero,
    double glow = 0,
    Finish finish = Finish.paint,
  }) {
    part(smooth: 0, finish: finish);
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
  /// thick across [across]: a fin, a wing. Its faces stay flat; its edges
  /// are rounded a little by [smooth].
  void slab(
    List<V3> points,
    V3 across,
    double depth,
    Rgb color, {
    Finish finish = Finish.paint,
    double smooth = 0,
  }) {
    part(smooth: smooth, finish: finish);
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
    part(smooth: 0, finish: Finish.matte);
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
