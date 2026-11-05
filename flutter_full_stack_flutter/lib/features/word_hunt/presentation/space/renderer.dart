import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_full_stack_flutter/features/word_hunt/presentation/space/geometry.dart';
import 'package:flutter_full_stack_flutter/features/word_hunt/presentation/space/mesh.dart';

/// The light a scene is lit by. Every colour here is linear light - add
/// two and you have both lights - and may go above `1`: the renderer's tone
/// mapping brings a bright scene back into what a screen can show, the way
/// a camera does.
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
    this.skyEnv = const Rgb(0.2, 0.25, 0.4),
    this.groundEnv = const Rgb(0.01, 0.01, 0.02),
    this.exposure = 1,
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

  /// What polished metal and glass show of their surroundings, looking up
  /// and looking down.
  final Rgb skyEnv;
  final Rgb groundEnv;

  /// How bright the whole scene is taken, before tone mapping.
  final double exposure;
}

/// Draws [Mesh]es seen through a [Camera], as smoothly shaded triangles.
///
/// The whole of a 3D scene's drawing, on an ordinary canvas: every mesh of a
/// frame is turned, lit and projected here, its faces turned away from the
/// eye or off the screen are dropped, and what is left is sorted far to
/// near and handed to the canvas in one [ui.Vertices] - the painter's
/// algorithm, with the GPU filling, and blending each triangle's three
/// colours across it. Thousands of triangles a frame, with no 3D engine and
/// on every platform the app builds for, the web included.
///
/// Light is worked out per corner, in linear light, as the world adds it
/// up: the sun, the sky above and the dark below, a highlight shaped by the
/// surface's [Finish], the surroundings reflected in metal and glass, light
/// round the edges. Then it is tone mapped (ACES) and encoded for the
/// screen. That is what makes paint look like paint and chrome like chrome,
/// where adding colours up in screen values washes everything out.
///
/// The sort is exact and the same every frame for the same scene, so no
/// two faces can swap places from one frame to the next - which is what a
/// flicker is. It sorts by solid first: a ship, the rocket, a splinter is
/// painted whole, in front of or behind the next, by how far its middle is
/// ([draw]'s `whole`), and only its own faces are sorted among themselves.
/// That is right for solids that do not pass through one another, which
/// none here do; the planet and its rings, which go round each other, are
/// sorted face by face instead.
class Renderer {
  static const _near = 0.15;

  late Camera _camera;
  late Lighting _light;

  Float32List _xy = Float32List(6 * 4096);
  Int32List _rgb = Int32List(3 * 4096);

  /// How far each face is, and how far the solid it belongs to is - the
  /// face's own depth again, for a solid sorted face by face.
  Float64List _depth = Float64List(4096);
  Float64List _solid = Float64List(4096);
  int _faces = 0;

  // A mesh's corners: in the world, their normals there, as the eye sees
  // them, and on the screen - and their light, once worked out.
  Float64List _world = Float64List(3 * 1024);
  Float64List _normal = Float64List(3 * 1024);
  Float64List _view = Float64List(3 * 1024);
  Float64List _screen = Float64List(2 * 1024);
  Int32List _lit = Int32List(1024);
  Int32List _litFor = Int32List(1024);
  int _draws = 0;

  // The sort's own buffers, kept between frames.
  Int32List _order = Int32List(4096);
  Float32List _outXy = Float32List(6 * 4096);
  Int32List _outRgb = Int32List(3 * 4096);

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
  /// [tint] is mixed into every corner's colour by [tinted] - a flash of
  /// colour, a ship greyed out. [glow] lights it from within on top of its
  /// own glow, and [light] dims or brightens the sun on it. [fog] scales how
  /// much distance fades it. [limb] is an atmosphere: light of that colour
  /// round its edge, brighter on the side the sun is on.
  ///
  /// [whole] paints it as one solid, in front of or behind the others by
  /// how far its origin is. Off, its faces are sorted in among everyone
  /// else's: for something another solid goes through, as a planet's rings
  /// go round it.
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
    Rgb? limb,
    bool whole = true,
  }) {
    if (scale <= 0) return;
    final cam = _camera;
    final centre = cam.depthOf(at);
    final reach = mesh.radius * scale;
    if (centre + reach < _near) return;
    // Wholly off the screen: nothing to do.
    if (centre - reach > _near) {
      final middle = cam.project(at);
      final spread = reach * cam.focal / (centre - reach);
      if (middle != null &&
          (middle.dx + spread < 0 ||
              middle.dx - spread > cam.size.width ||
              middle.dy + spread < 0 ||
              middle.dy - spread > cam.size.height)) {
        return;
      }
    }

    final n = mesh.vertexCount;
    if (_lit.length < n) {
      final room = n * 2;
      _world = Float64List(room * 3);
      _normal = Float64List(room * 3);
      _view = Float64List(room * 3);
      _screen = Float64List(room * 2);
      _lit = Int32List(room);
      _litFor = Int32List(room);
    }
    final draw = ++_draws;

    final eye = cam.eye;
    final r = cam.right;
    final u = cam.up;
    final f = cam.forward;
    // Depth from the camera - for sorting, fog and the near plane - but
    // the place on the screen from the solid's own lens, so that it keeps
    // its shape however far off to the side it is.
    final lens = cam.lensAt(at);
    final lr = lens.right;
    final lu = lens.up;
    final lf = lens.forward;
    final ox = lens.origin.dx;
    final oy = lens.origin.dy;
    final focal = lens.focal;
    final p = mesh.positions;
    final nm = mesh.normals;
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
      final ax = nm[i * 3];
      final ay = nm[i * 3 + 1];
      final az = nm[i * 3 + 2];
      _normal[i * 3] = turn.m00 * ax + turn.m01 * ay + turn.m02 * az;
      _normal[i * 3 + 1] = turn.m10 * ax + turn.m11 * ay + turn.m12 * az;
      _normal[i * 3 + 2] = turn.m20 * ax + turn.m21 * ay + turn.m22 * az;
      final dx = wx - eye.x;
      final dy = wy - eye.y;
      final dz = wz - eye.z;
      final vx = dx * r.x + dy * r.y + dz * r.z;
      final vy = dx * u.x + dy * u.y + dz * u.z;
      final vz = dx * f.x + dy * f.y + dz * f.z;
      _view[i * 3] = vx;
      _view[i * 3 + 1] = vy;
      _view[i * 3 + 2] = vz;
      final lz = dx * lf.x + dy * lf.y + dz * lf.z;
      if (vz > _near && lz > 0) {
        _screen[i * 2] = ox + focal * (dx * lr.x + dy * lr.y + dz * lr.z) / lz;
        _screen[i * 2 + 1] =
            oy - focal * (dx * lu.x + dy * lu.y + dz * lu.z) / lz;
      }
    }

    final tone = _Tone(
      lighting: _light,
      eye: eye,
      mesh: mesh,
      world: _world,
      normal: _normal,
      view: _view,
      tint: tint?.linear,
      tinted: tint == null ? 0 : tinted,
      glow: glow,
      light: light,
      fog: fog.clamp(0, 1),
      limb: limb,
    );
    int lit(int i) {
      if (_litFor[i] != draw) {
        _litFor[i] = draw;
        _lit[i] = tone.at(i);
      }
      return _lit[i];
    }

    final width = cam.size.width;
    final height = cam.size.height;
    final indices = mesh.indices;
    for (var face = 0; face < mesh.faceCount; face++) {
      final a = indices[face * 3];
      final b = indices[face * 3 + 1];
      final c = indices[face * 3 + 2];
      final za = _view[a * 3 + 2];
      final zb = _view[b * 3 + 2];
      final zc = _view[c * 3 + 2];
      if (za < _near || zb < _near || zc < _near) continue;

      // Turned away from the eye: not drawn.
      final ax = _world[a * 3];
      final ay = _world[a * 3 + 1];
      final az = _world[a * 3 + 2];
      final ux = _world[b * 3] - ax;
      final uy = _world[b * 3 + 1] - ay;
      final uz = _world[b * 3 + 2] - az;
      final vx = _world[c * 3] - ax;
      final vy = _world[c * 3 + 1] - ay;
      final vz = _world[c * 3 + 2] - az;
      final facing =
          (uy * vz - uz * vy) * (eye.x - ax) +
          (uz * vx - ux * vz) * (eye.y - ay) +
          (ux * vy - uy * vx) * (eye.z - az);
      if (facing <= 0) continue;

      final sax = _screen[a * 2];
      final say = _screen[a * 2 + 1];
      final sbx = _screen[b * 2];
      final sby = _screen[b * 2 + 1];
      final scx = _screen[c * 2];
      final scy = _screen[c * 2 + 1];
      // Off the screen: not drawn.
      if ((sax < 0 && sbx < 0 && scx < 0) ||
          (sax > width && sbx > width && scx > width) ||
          (say < 0 && sby < 0 && scy < 0) ||
          (say > height && sby > height && scy > height)) {
        continue;
      }

      _reserve(_faces + 1);
      final o = _faces * 6;
      _xy[o] = sax;
      _xy[o + 1] = say;
      _xy[o + 2] = sbx;
      _xy[o + 3] = sby;
      _xy[o + 4] = scx;
      _xy[o + 5] = scy;
      _rgb[_faces * 3] = lit(a);
      _rgb[_faces * 3 + 1] = lit(b);
      _rgb[_faces * 3 + 2] = lit(c);
      final depth = (za + zb + zc) / 3;
      _depth[_faces] = depth;
      _solid[_faces] = whole ? centre : depth;
      _faces++;
    }
  }

  void _reserve(int faces) {
    if (faces <= _depth.length) return;
    final grown = _depth.length * 2;
    _xy = Float32List(grown * 6)..setRange(0, _faces * 6, _xy);
    _rgb = Int32List(grown * 3)..setRange(0, _faces * 3, _rgb);
    _depth = Float64List(grown)..setRange(0, _faces, _depth);
    _solid = Float64List(grown)..setRange(0, _faces, _solid);
  }

  /// Paints everything drawn since [begin], far to near, and empties the
  /// batch.
  void flush(ui.Canvas canvas) {
    final count = _faces;
    _lastDrawn = count;
    if (count == 0) return;

    // Furthest solid first, then furthest face within it; a tie goes to
    // the order things were drawn in, so the result never depends on how
    // the sort happened to break it.
    if (_order.length < count) _order = Int32List(_depth.length);
    final order = Int32List.sublistView(_order, 0, count);
    for (var i = 0; i < count; i++) {
      order[i] = i;
    }
    final solid = _solid;
    final depth = _depth;
    order.sort((a, b) {
      final bySolid = solid[b].compareTo(solid[a]);
      if (bySolid != 0) return bySolid;
      final byFace = depth[b].compareTo(depth[a]);
      return byFace != 0 ? byFace : a - b;
    });

    if (_outRgb.length < count * 3) {
      _outXy = Float32List(_depth.length * 6);
      _outRgb = Int32List(_depth.length * 3);
    }
    for (var k = 0; k < count; k++) {
      final i = order[k];
      _outXy.setRange(k * 6, k * 6 + 6, _xy, i * 6);
      _outRgb.setRange(k * 3, k * 3 + 3, _rgb, i * 3);
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

/// The light at one mesh's corners, for one draw.
class _Tone {
  _Tone({
    required this.lighting,
    required this.eye,
    required this.mesh,
    required this.world,
    required this.normal,
    required this.view,
    required this.tint,
    required this.tinted,
    required this.glow,
    required this.light,
    required this.fog,
    required this.limb,
  });

  final Lighting lighting;
  final V3 eye;
  final Mesh mesh;
  final Float64List world;
  final Float64List normal;
  final Float64List view;
  final Rgb? tint;
  final double tinted;
  final double glow;
  final double light;
  final double fog;
  final Rgb? limb;

  /// ACES, as Narkowicz fitted it: a film's response, which rolls a bright
  /// highlight off into white instead of clipping it flat.
  static double _film(double x) {
    if (x <= 0) return 0;
    return (x * (2.51 * x + 0.03)) / (x * (2.43 * x + 0.59) + 0.14);
  }

  static int _channel(double linear) =>
      (math.sqrt(_film(linear).clamp(0.0, 1.0)) * 255).round();

  /// Corner [i], lit, tone mapped and packed for the screen.
  int at(int i) {
    final l = lighting;
    final sun = l.sun;
    final nx = normal[i * 3];
    final ny = normal[i * 3 + 1];
    final nz = normal[i * 3 + 2];
    var vx = eye.x - world[i * 3];
    var vy = eye.y - world[i * 3 + 1];
    var vz = eye.z - world[i * 3 + 2];
    final vl = math.sqrt(vx * vx + vy * vy + vz * vz);
    vx /= vl;
    vy /= vl;
    vz /= vl;

    final ndl = nx * sun.x + ny * sun.y + nz * sun.z;
    final ndvRaw = nx * vx + ny * vy + nz * vz;
    final ndv = ndvRaw.clamp(0.0, 1.0);
    final diffuse = math.max(0, ndl) * light;
    final skyward = 0.5 + 0.5 * ny;

    // The highlight, only where the sun reaches.
    final f = mesh.finishes;
    final specular = f[i * 4];
    final shininess = f[i * 4 + 1];
    final metal = f[i * 4 + 2];
    final sheen = f[i * 4 + 3];
    var highlight = 0.0;
    if (ndl > 0 && specular > 0) {
      final hx = sun.x + vx;
      final hy = sun.y + vy;
      final hz = sun.z + vz;
      final hl = math.sqrt(hx * hx + hy * hy + hz * hz);
      final ndh = hl == 0 ? 0.0 : (nx * hx + ny * hy + nz * hz) / hl;
      if (ndh > 0) {
        highlight =
            specular * math.pow(ndh, shininess).toDouble() * light * 1.6;
      }
    }

    // What the surface reflects: the view, mirrored about the normal, and
    // where it points - up to the nebula or down into the dark.
    final ry = 2 * ndvRaw * ny - vy;
    final up = (0.5 + 0.5 * ry).clamp(0.0, 1.0);
    final grazing = 1 - ndv;
    final edge = grazing * grazing * grazing;
    final fresnel = edge * grazing * grazing;

    final colors = mesh.colors;
    var ar = colors[i * 3];
    var ag = colors[i * 3 + 1];
    var ab = colors[i * 3 + 2];
    final t = tint;
    if (t != null && tinted > 0) {
      ar += (t.r - ar) * tinted;
      ag += (t.g - ag) * tinted;
      ab += (t.b - ab) * tinted;
    }

    double channel(
      double albedo,
      double key,
      double sky,
      double ground,
      double rim,
      double envUp,
      double envDown,
    ) {
      final ambient = ground + (sky - ground) * skyward;
      final env = envDown + (envUp - envDown) * up;
      final lit = albedo * (ambient + key * diffuse);
      // Metal tints what it reflects with its own colour, a little.
      final mirror = env * (0.7 + 0.3 * albedo) * 1.4;
      return lit * (1 - metal) +
          mirror * metal +
          key * highlight * (1 - metal + metal * albedo) +
          envUp * fresnel * sheen * 2 +
          rim * edge;
    }

    var cr = channel(
      ar,
      l.key.r,
      l.sky.r,
      l.ground.r,
      l.rim.r,
      l.skyEnv.r,
      l.groundEnv.r,
    );
    var cg = channel(
      ag,
      l.key.g,
      l.sky.g,
      l.ground.g,
      l.rim.g,
      l.skyEnv.g,
      l.groundEnv.g,
    );
    var cb = channel(
      ab,
      l.key.b,
      l.sky.b,
      l.ground.b,
      l.rim.b,
      l.skyEnv.b,
      l.groundEnv.b,
    );

    final atmosphere = limb;
    if (atmosphere != null) {
      final dawn = (ndl + 0.35).clamp(0.0, 1.0);
      final haze = grazing * grazing * (0.2 + 0.8 * dawn);
      cr += atmosphere.r * haze;
      cg += atmosphere.g * haze;
      cb += atmosphere.b * haze;
    }

    final shining = math.min(1, mesh.glow[i] + glow);
    if (shining > 0) {
      cr += (ar * 2.4 + 0.05 - cr) * shining;
      cg += (ag * 2.4 + 0.05 - cg) * shining;
      cb += (ab * 2.4 + 0.05 - cb) * shining;
    }

    final depth = view[i * 3 + 2];
    final hazed = (1 - math.exp(-l.fogDensity * depth)) * fog;
    cr += (l.fog.r - cr) * hazed;
    cg += (l.fog.g - cg) * hazed;
    cb += (l.fog.b - cb) * hazed;

    final e = l.exposure;
    return 0xFF000000 |
        (_channel(cr * e) << 16) |
        (_channel(cg * e) << 8) |
        _channel(cb * e);
  }
}
