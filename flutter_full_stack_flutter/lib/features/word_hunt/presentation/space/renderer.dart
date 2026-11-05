import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_full_stack_flutter/features/word_hunt/presentation/space/geometry.dart';
import 'package:flutter_full_stack_flutter/features/word_hunt/presentation/space/mesh.dart';

/// The light a scene is lit by.
@immutable
class Lighting {
  const Lighting({
    required this.sun,
    required this.key,
    required this.sky,
    required this.ground,
    required this.rim,
    required this.fog,
    this.fogDensity = 0.03,
    this.shine = 0.35,
  });

  /// Towards the light, as a unit vector.
  final V3 sun;

  /// The light's colour on a face turned full to it.
  final Rgb key;

  /// What a face turned up is lit by when the sun is not on it: the glow of
  /// the nebula above...
  final Rgb sky;

  /// ...and what a face turned down is: the planet's light from below.
  final Rgb ground;

  /// The light round an edge seen side on, which is what lifts a solid off
  /// a dark sky.
  final Rgb rim;

  /// What distance fades everything into.
  final Rgb fog;
  final double fogDensity;

  /// How bright the highlights are.
  final double shine;
}

/// Draws [Mesh]es seen through a [Camera], as flat-shaded triangles.
///
/// The whole of a 3D scene's drawing, on an ordinary canvas: every mesh of a
/// frame is turned, lit and projected here, its faces turned away from the
/// eye are dropped, and what is left is sorted far to near and handed to the
/// canvas in one [ui.Vertices] - the painter's algorithm, with the GPU doing
/// the filling. Thousands of triangles a frame, with no 3D engine and on
/// every platform the app builds for, the web included.
///
/// The painter's algorithm sorts whole faces, so two solids that pass
/// through each other can show the wrong one in front where they cross.
/// Nothing in the scenes does: ships keep apart, and the planet is far
/// behind them.
class Renderer {
  static const _near = 0.15;

  late Camera _camera;
  late Lighting _light;

  Float32List _xy = Float32List(6 * 2048);
  Int32List _rgb = Int32List(2048);
  Float32List _depth = Float32List(2048);
  int _faces = 0;

  // A mesh's corners, in the world and as the eye sees them.
  Float64List _world = Float64List(3 * 512);
  Float64List _view = Float64List(3 * 512);

  // The sort's own buffers, kept between frames.
  Int32List _order = Int32List(2048);
  final Int32List _counts = Int32List(_buckets + 1);
  Float32List _outXy = Float32List(6 * 2048);
  Int32List _outRgb = Int32List(3 * 2048);

  static const _buckets = 2048;

  /// Faces drawn by the last [flush].
  int get drawn => _lastDrawn;
  int _lastDrawn = 0;

  /// Starts a batch: everything drawn until [flush] is sorted together.
  void begin(Camera camera, Lighting light) {
    _camera = camera;
    _light = light;
    _faces = 0;
  }

  /// Draws [mesh] with its origin at [at], turned by [turn] and [scale]d.
  ///
  /// [tint] is mixed into every face by [tinted] - a flash of colour, a
  /// ship greyed out. [glow] lights every face from within on top of its
  /// own, and [light] dims or brightens the sun on it. [fog] scales how much
  /// distance fades it.
  void draw(
    Mesh mesh, {
    required V3 at,
    Rot turn = Rot.identity,
    double scale = 1,
    Rgb? tint,
    double tinted = 0,
    double glow = 0,
    double light = 1,
    double fog = 1,
  }) {
    if (scale <= 0) return;
    final cam = _camera;
    final centre = cam.depthOf(at);
    final reach = mesh.radius * scale;
    if (centre + reach < _near) return;

    final n = mesh.vertexCount;
    if (_world.length < n * 3) {
      _world = Float64List(n * 3 * 2);
      _view = Float64List(n * 3 * 2);
    }

    final eye = cam.eye;
    final r = cam.right;
    final u = cam.up;
    final f = cam.forward;
    final p = mesh.positions;
    for (var i = 0; i < n; i++) {
      final x = p[i * 3] * scale;
      final y = p[i * 3 + 1] * scale;
      final z = p[i * 3 + 2] * scale;
      final wx = at.x + turn.m00 * x + turn.m01 * y + turn.m02 * z;
      final wy = at.y + turn.m10 * x + turn.m11 * y + turn.m12 * z;
      final wz = at.z + turn.m20 * x + turn.m21 * y + turn.m22 * z;
      _world[i * 3] = wx;
      _world[i * 3 + 1] = wy;
      _world[i * 3 + 2] = wz;
      final dx = wx - eye.x;
      final dy = wy - eye.y;
      final dz = wz - eye.z;
      _view[i * 3] = dx * r.x + dy * r.y + dz * r.z;
      _view[i * 3 + 1] = dx * u.x + dy * u.y + dz * u.z;
      _view[i * 3 + 2] = dx * f.x + dy * f.y + dz * f.z;
    }

    final lighting = _light;
    final sun = lighting.sun;
    final cx = cam.size.width / 2;
    final cy = cam.size.height / 2;
    final focal = cam.focal;
    final indices = mesh.indices;
    final colors = mesh.colors;
    final glows = mesh.glow;

    for (var face = 0; face < mesh.faceCount; face++) {
      final ia = indices[face * 3] * 3;
      final ib = indices[face * 3 + 1] * 3;
      final ic = indices[face * 3 + 2] * 3;
      final za = _view[ia + 2];
      final zb = _view[ib + 2];
      final zc = _view[ic + 2];
      if (za < _near || zb < _near || zc < _near) continue;

      final ax = _world[ia];
      final ay = _world[ia + 1];
      final az = _world[ia + 2];
      final ux = _world[ib] - ax;
      final uy = _world[ib + 1] - ay;
      final uz = _world[ib + 2] - az;
      final vx = _world[ic] - ax;
      final vy = _world[ic + 1] - ay;
      final vz = _world[ic + 2] - az;
      var nx = uy * vz - uz * vy;
      var ny = uz * vx - ux * vz;
      var nz = ux * vy - uy * vx;
      final length = math.sqrt(nx * nx + ny * ny + nz * nz);
      if (length < 1e-12) continue;
      nx /= length;
      ny /= length;
      nz /= length;

      // Towards the eye, from the face.
      final ex = eye.x - ax;
      final ey = eye.y - ay;
      final ez = eye.z - az;
      final facing = nx * ex + ny * ey + nz * ez;
      if (facing <= 0) continue;
      final toEye = math.sqrt(ex * ex + ey * ey + ez * ez);

      // The sun, the sky above and the glow below, the edge light and a
      // highlight.
      final sunlit = math.max(0, nx * sun.x + ny * sun.y + nz * sun.z) * light;
      final skyward = 0.5 + 0.5 * ny;
      final edge = math.pow(1 - facing / toEye, 3).toDouble();
      final hx = sun.x + ex / toEye;
      final hy = sun.y + ey / toEye;
      final hz = sun.z + ez / toEye;
      final hl = math.sqrt(hx * hx + hy * hy + hz * hz);
      final highlight = hl == 0
          ? 0.0
          : math
                    .pow(
                      math.max(0, (nx * hx + ny * hy + nz * hz) / hl),
                      28,
                    )
                    .toDouble() *
                lighting.shine *
                light;

      var red = colors[face * 3];
      var green = colors[face * 3 + 1];
      var blue = colors[face * 3 + 2];
      if (tint != null && tinted > 0) {
        red += (tint.r - red) * tinted;
        green += (tint.g - green) * tinted;
        blue += (tint.b - blue) * tinted;
      }
      double shade(
        double albedo,
        double key,
        double sky,
        double ground,
        double rim,
      ) =>
          albedo * (ground + (sky - ground) * skyward + key * sunlit) +
          rim * edge +
          highlight;
      var lr = shade(
        red,
        lighting.key.r,
        lighting.sky.r,
        lighting.ground.r,
        lighting.rim.r,
      );
      var lg = shade(
        green,
        lighting.key.g,
        lighting.sky.g,
        lighting.ground.g,
        lighting.rim.g,
      );
      var lb = shade(
        blue,
        lighting.key.b,
        lighting.sky.b,
        lighting.ground.b,
        lighting.rim.b,
      );

      final shining = math.min(1, glows[face] + glow);
      if (shining > 0) {
        lr += (red * 1.2 + 0.08 - lr) * shining;
        lg += (green * 1.2 + 0.08 - lg) * shining;
        lb += (blue * 1.2 + 0.08 - lb) * shining;
      }

      final depth = (za + zb + zc) / 3;
      final hazed =
          (1 - math.exp(-lighting.fogDensity * depth)) * fog.clamp(0, 1);
      lr += (lighting.fog.r - lr) * hazed;
      lg += (lighting.fog.g - lg) * hazed;
      lb += (lighting.fog.b - lb) * hazed;

      _reserve(_faces + 1);
      final o = _faces * 6;
      _xy[o] = cx + focal * _view[ia] / za;
      _xy[o + 1] = cy - focal * _view[ia + 1] / za;
      _xy[o + 2] = cx + focal * _view[ib] / zb;
      _xy[o + 3] = cy - focal * _view[ib + 1] / zb;
      _xy[o + 4] = cx + focal * _view[ic] / zc;
      _xy[o + 5] = cy - focal * _view[ic + 1] / zc;
      _rgb[_faces] = _pack(lr, lg, lb);
      _depth[_faces] = depth;
      _faces++;
    }
  }

  static int _pack(double r, double g, double b) =>
      0xFF000000 |
      ((r.clamp(0.0, 1.0) * 255).round() << 16) |
      ((g.clamp(0.0, 1.0) * 255).round() << 8) |
      (b.clamp(0.0, 1.0) * 255).round();

  void _reserve(int faces) {
    if (faces <= _rgb.length) return;
    final grown = _rgb.length * 2;
    _xy = Float32List(grown * 6)..setRange(0, _faces * 6, _xy);
    _rgb = Int32List(grown)..setRange(0, _faces, _rgb);
    _depth = Float32List(grown)..setRange(0, _faces, _depth);
  }

  /// Paints everything drawn since [begin], far to near, and empties the
  /// batch.
  void flush(ui.Canvas canvas) {
    final count = _faces;
    _lastDrawn = count;
    if (count == 0) return;

    var far = -double.infinity;
    var near = double.infinity;
    for (var i = 0; i < count; i++) {
      far = math.max(far, _depth[i]);
      near = math.min(near, _depth[i]);
    }
    final span = math.max(far - near, 1e-6);

    // A counting sort into depth buckets, furthest first: linear in the
    // faces, where a comparison sort would not be.
    _counts.fillRange(0, _counts.length, 0);
    int bucket(int i) =>
        ((far - _depth[i]) / span * (_buckets - 1)).floor().clamp(
          0,
          _buckets - 1,
        );
    for (var i = 0; i < count; i++) {
      _counts[bucket(i) + 1]++;
    }
    for (var b = 0; b < _buckets; b++) {
      _counts[b + 1] += _counts[b];
    }
    if (_order.length < count) _order = Int32List(_rgb.length);
    for (var i = 0; i < count; i++) {
      _order[_counts[bucket(i)]++] = i;
    }

    if (_outRgb.length < count * 3) {
      _outXy = Float32List(_rgb.length * 6);
      _outRgb = Int32List(_rgb.length * 3);
    }
    for (var k = 0; k < count; k++) {
      final i = _order[k];
      _outXy.setRange(k * 6, k * 6 + 6, _xy, i * 6);
      final c = _rgb[i];
      _outRgb[k * 3] = c;
      _outRgb[k * 3 + 1] = c;
      _outRgb[k * 3 + 2] = c;
    }

    final vertices = ui.Vertices.raw(
      ui.VertexMode.triangles,
      Float32List.sublistView(_outXy, 0, count * 6),
      colors: Int32List.sublistView(_outRgb, 0, count * 3),
    );
    canvas.drawVertices(vertices, ui.BlendMode.dst, ui.Paint());
    vertices.dispose();
    _faces = 0;
  }
}
