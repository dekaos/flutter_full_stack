import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter/painting.dart' show HSLColor;

/// A point or a direction in the world: `x` to the right, `y` up, `z` out of
/// the screen towards the viewer - so what is ahead of the camera has a
/// negative `z`.
@immutable
class V3 {
  const V3(this.x, this.y, this.z);

  static const zero = V3(0, 0, 0);
  static const up = V3(0, 1, 0);

  final double x;
  final double y;
  final double z;

  V3 operator +(V3 o) => V3(x + o.x, y + o.y, z + o.z);
  V3 operator -(V3 o) => V3(x - o.x, y - o.y, z - o.z);
  V3 operator *(double k) => V3(x * k, y * k, z * k);
  V3 operator -() => V3(-x, -y, -z);

  double dot(V3 o) => x * o.x + y * o.y + z * o.z;

  V3 cross(V3 o) => V3(y * o.z - z * o.y, z * o.x - x * o.z, x * o.y - y * o.x);

  double get length => math.sqrt(x * x + y * y + z * z);

  V3 get unit {
    final l = length;
    return l == 0 ? this : V3(x / l, y / l, z / l);
  }

  /// The point [t] of the way from this to [o].
  V3 lerp(V3 o, double t) =>
      V3(x + (o.x - x) * t, y + (o.y - y) * t, z + (o.z - z) * t);

  @override
  bool operator ==(Object other) =>
      other is V3 && other.x == x && other.y == y && other.z == z;

  @override
  int get hashCode => Object.hash(x, y, z);

  @override
  String toString() => 'V3($x, $y, $z)';
}

/// A rotation, as its 3x3 matrix in row order.
@immutable
class Rot {
  const Rot._(
    this.m00,
    this.m01,
    this.m02,
    this.m10,
    this.m11,
    this.m12,
    this.m20,
    this.m21,
    this.m22,
  );

  /// Turned [yaw] about `y` (to the left, for a positive angle, seen from
  /// above), after [pitch] about `x` (nose up) and [roll] about `z`.
  factory Rot.euler({double yaw = 0, double pitch = 0, double roll = 0}) {
    final cy = math.cos(yaw);
    final sy = math.sin(yaw);
    final cp = math.cos(pitch);
    final sp = math.sin(pitch);
    final cr = math.cos(roll);
    final sr = math.sin(roll);
    // Ry * Rx * Rz.
    return Rot._(
      cy * cr + sy * sp * sr,
      -cy * sr + sy * sp * cr,
      sy * cp,
      cp * sr,
      cp * cr,
      -sp,
      -sy * cr + cy * sp * sr,
      sy * sr + cy * sp * cr,
      cy * cp,
    );
  }

  /// The yaw and pitch that turn the forward axis, `-z`, to [direction].
  static ({double yaw, double pitch}) facing(V3 direction) {
    final d = direction.unit;
    return (
      yaw: math.atan2(-d.x, -d.z),
      pitch: math.asin(d.y.clamp(-1.0, 1.0)),
    );
  }

  static const identity = Rot._(1, 0, 0, 0, 1, 0, 0, 0, 1);

  final double m00;
  final double m01;
  final double m02;
  final double m10;
  final double m11;
  final double m12;
  final double m20;
  final double m21;
  final double m22;

  /// This turn after [o]: `(a * b).apply(v)` is `a.apply(b.apply(v))`.
  Rot operator *(Rot o) => Rot._(
    m00 * o.m00 + m01 * o.m10 + m02 * o.m20,
    m00 * o.m01 + m01 * o.m11 + m02 * o.m21,
    m00 * o.m02 + m01 * o.m12 + m02 * o.m22,
    m10 * o.m00 + m11 * o.m10 + m12 * o.m20,
    m10 * o.m01 + m11 * o.m11 + m12 * o.m21,
    m10 * o.m02 + m11 * o.m12 + m12 * o.m22,
    m20 * o.m00 + m21 * o.m10 + m22 * o.m20,
    m20 * o.m01 + m21 * o.m11 + m22 * o.m21,
    m20 * o.m02 + m21 * o.m12 + m22 * o.m22,
  );

  V3 apply(V3 v) => V3(
    m00 * v.x + m01 * v.y + m02 * v.z,
    m10 * v.x + m11 * v.y + m12 * v.z,
    m20 * v.x + m21 * v.y + m22 * v.z,
  );

  V3 get right => V3(m00, m10, m20);
  V3 get upward => V3(m01, m11, m21);

  /// Where `-z` points after the turn.
  V3 get forward => V3(-m02, -m12, -m22);
}

/// The eye the world is seen through: where it is, which way it looks, and
/// how wide.
///
/// Its field of view is set across the *shorter* side of the screen, so a
/// phone held upright sees as far to the sides as one on its side sees up
/// and down, and the play area is never too narrow for the ships.
@immutable
class Camera {
  Camera({
    required this.eye,
    required Rot rotation,
    required this.size,
    double fov = 62 * math.pi / 180,
  }) : right = rotation.right,
       up = rotation.upward,
       forward = rotation.forward,
       focal = size.shortestSide / 2 / math.tan(fov / 2);

  final V3 eye;
  final V3 right;
  final V3 up;
  final V3 forward;
  final Size size;

  /// Pixels per unit of the world at a distance of one.
  final double focal;

  /// How far in front of the eye [p] is; negative behind it.
  double depthOf(V3 p) => (p - eye).dot(forward);

  /// Where [p] lands on the screen, or `null` when it is behind the eye.
  Offset? project(V3 p) {
    final d = p - eye;
    final z = d.dot(forward);
    if (z <= 0.05) return null;
    return Offset(
      size.width / 2 + focal * d.dot(right) / z,
      size.height / 2 - focal * d.dot(up) / z,
    );
  }

  /// The point of the world [depth] in front of the eye that lands on
  /// screen point [s].
  V3 unproject(Offset s, double depth) {
    final x = (s.dx - size.width / 2) / focal;
    final y = -(s.dy - size.height / 2) / focal;
    return eye + (right * x + up * y + forward) * depth;
  }

  /// How many pixels one unit of the world spans at [depth].
  double scaleAt(double depth) => focal / math.max(depth, 0.05);

  /// How a solid whose middle is at [centre] is seen: as if the camera had
  /// turned to face it squarely, then put where this camera puts its
  /// middle, at the size this camera gives it there.
  ///
  /// A wide lens stretches what is off to its side - on an upright phone,
  /// whose view is wide across its long side, a planet in a corner came out
  /// half as long again one way as the other. Seen through its own [Lens],
  /// a solid keeps its shape wherever it is on the screen; only where it
  /// is, and how big, come from this camera.
  Lens lensAt(V3 centre) {
    final d = centre - eye;
    final depth = d.dot(forward);
    final distance = d.length;
    final centred = Offset(size.width / 2, size.height / 2);
    if (depth <= 0.05 || distance == 0) {
      return Lens._(centred, eye, right, up, forward, focal);
    }
    final ahead = d * (1 / distance);
    final across = ahead.cross(up);
    if (across.length < 1e-6) {
      return Lens._(centred, eye, right, up, forward, focal);
    }
    final side = across.unit;
    return Lens._(
      Offset(
        centred.dx + focal * d.dot(right) / depth,
        centred.dy - focal * d.dot(up) / depth,
      ),
      eye,
      side,
      side.cross(ahead),
      ahead,
      focal * distance / depth,
    );
  }
}

/// A camera turned to look straight at one solid: see [Camera.lensAt].
@immutable
class Lens {
  const Lens._(
    this.origin,
    this.eye,
    this.right,
    this.up,
    this.forward,
    this.focal,
  );

  /// Where the solid's middle lands on the screen.
  final Offset origin;
  final V3 eye;
  final V3 right;
  final V3 up;
  final V3 forward;
  final double focal;

  /// Where [p] lands on the screen, or `null` when it is behind the eye.
  Offset? project(V3 p) {
    final d = p - eye;
    final z = d.dot(forward);
    if (z <= 0.05) return null;
    return Offset(
      origin.dx + focal * d.dot(right) / z,
      origin.dy - focal * d.dot(up) / z,
    );
  }
}

/// A colour as three channels from `0` to `1`, for lighting arithmetic.
@immutable
class Rgb {
  const Rgb(this.r, this.g, this.b);

  factory Rgb.of(Color c) => Rgb(c.r, c.g, c.b);

  /// A colour by its hue (degrees), saturation and lightness (`0`-`1`).
  factory Rgb.hsl(double hue, double saturation, double lightness) =>
      Rgb.of(HSLColor.fromAHSL(1, hue % 360, saturation, lightness).toColor());

  final double r;
  final double g;
  final double b;

  Rgb operator +(Rgb o) => Rgb(r + o.r, g + o.g, b + o.b);
  Rgb operator *(double k) => Rgb(r * k, g * k, b * k);

  /// Channel by channel: a light on a surface.
  Rgb times(Rgb o) => Rgb(r * o.r, g * o.g, b * o.b);

  /// This colour as light: from the screen's encoding into linear
  /// intensities, where light adds up as it does in the world. (Gamma 2 -
  /// near enough to the screen's 2.2, and a square is cheap.)
  Rgb get linear => Rgb(r * r, g * g, b * b);

  Rgb lerp(Rgb o, double t) =>
      Rgb(r + (o.r - r) * t, g + (o.g - g) * t, b + (o.b - b) * t);

  Color get color => Color.fromARGB(
    255,
    (r.clamp(0.0, 1.0) * 255).round(),
    (g.clamp(0.0, 1.0) * 255).round(),
    (b.clamp(0.0, 1.0) * 255).round(),
  );

  @override
  bool operator ==(Object other) =>
      other is Rgb && other.r == r && other.g == g && other.b == b;

  @override
  int get hashCode => Object.hash(r, g, b);
}

/// Smooth noise over space, `-1` to `1`, the same for the same [seed]: a
/// few waves at odd angles laid over one another. Plenty for colouring a
/// planet's continents or roughening a rock, and cheap.
double noise3(double x, double y, double z, {int seed = 0}) {
  final s = seed * 1.618;
  return (math.sin(x * 1.7 + y * 0.6 + s) * math.cos(z * 1.3 - x * 0.4 + s) +
          0.5 *
              math.sin(y * 3.1 - z * 1.1 + s * 2) *
              math.cos(x * 2.7 + z * 0.9) +
          0.25 *
              math.sin(z * 5.3 + x * 1.9 - s) *
              math.cos(y * 4.7 - x * 2.1 + s)) /
      1.75;
}

int _hash(int x, int y, int z, int seed) {
  var n = x * 73856093 ^ y * 19349663 ^ z * 83492791 ^ seed * 2654435761;
  n = (n ^ (n >> 13)) * 1274126177;
  n ^= n >> 16;
  return n & 0xffff;
}

double _corner(int x, int y, int z, int seed) =>
    _hash(x, y, z, seed) / 32767.5 - 1;

/// Value noise over space, `-1` to `1`: random values on a lattice, eased
/// between - smooth, and without the regular stripes of [noise3]. What
/// coasts, craters and clouds are made of.
double valueNoise3(double x, double y, double z, {int seed = 0}) {
  final xi = x.floor();
  final yi = y.floor();
  final zi = z.floor();
  double ease(double t) => t * t * (3 - 2 * t);
  final u = ease(x - xi);
  final v = ease(y - yi);
  final w = ease(z - zi);
  double lerp(double a, double b, double t) => a + (b - a) * t;
  double c(int dx, int dy, int dz) => _corner(xi + dx, yi + dy, zi + dz, seed);
  return lerp(
    lerp(lerp(c(0, 0, 0), c(1, 0, 0), u), lerp(c(0, 1, 0), c(1, 1, 0), u), v),
    lerp(lerp(c(0, 0, 1), c(1, 0, 1), u), lerp(c(0, 1, 1), c(1, 1, 1), u), v),
    w,
  );
}

/// [valueNoise3] in [octaves] layers, each twice as fine and half as
/// strong as the last: fractal detail, as nature has it. `-1` to `1`.
double fbm3(
  double x,
  double y,
  double z, {
  int octaves = 4,
  int seed = 0,
}) {
  var sum = 0.0;
  var amplitude = 1.0;
  var norm = 0.0;
  var f = 1.0;
  for (var i = 0; i < octaves; i++) {
    sum += amplitude * valueNoise3(x * f, y * f, z * f, seed: seed + i * 31);
    norm += amplitude;
    amplitude *= 0.5;
    f *= 2.03;
  }
  return sum / norm;
}
