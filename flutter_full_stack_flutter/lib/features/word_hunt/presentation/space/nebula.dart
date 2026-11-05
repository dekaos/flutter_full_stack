import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter_full_stack_flutter/features/word_hunt/presentation/space/geometry.dart';
import 'package:flutter_full_stack_flutter/features/word_hunt/presentation/space/palette.dart';

/// The deep sky behind a deck's space: clouds of glowing gas folded over
/// themselves, dark lanes of dust across them, and the faint band of a
/// galaxy - painted from noise once per deck, and kept.
///
/// Made off the UI isolate the first time a deck's space asks for it, and
/// small: it is soft by nature, so it is drawn scaled up and loses nothing
/// by it. Until it is ready, the space draws its plainer sky instead.
abstract final class Nebula {
  static final Map<double, ui.Image> _ready = {};
  static final Map<double, Future<void>> _making = {};

  /// Pixels across and down.
  static const side = 192;

  /// [palette]'s nebula, if it has been made - and if not, it is asked for.
  static ui.Image? of(SpacePalette palette) {
    final image = _ready[palette.hue];
    if (image == null) _making[palette.hue] ??= _make(palette);
    return image;
  }

  static Future<void> _make(SpacePalette palette) async {
    try {
      final pixels = await compute(
        nebulaPixels,
        NebulaRecipe(
          top: palette.skyTop.toARGB32(),
          bottom: palette.skyBottom.toARGB32(),
          gas: [for (final c in palette.nebulae) c.toARGB32()],
          side: side,
        ),
      );
      final image = Completer<ui.Image>();
      ui.decodeImageFromPixels(
        pixels,
        side,
        side,
        ui.PixelFormat.rgba8888,
        image.complete,
      );
      _ready[palette.hue] = await image.future;
    } on Object catch (error) {
      // A sky without its nebula is still a sky.
      debugPrint('Could not paint the nebula: $error');
    }
  }
}

/// What a nebula is painted from, in a form another isolate can be given.
@immutable
class NebulaRecipe {
  const NebulaRecipe({
    required this.top,
    required this.bottom,
    required this.gas,
    required this.side,
  });

  /// The sky's colour at the top and the bottom, as ARGB.
  final int top;
  final int bottom;

  /// The colours of its gas, as ARGB.
  final List<int> gas;
  final int side;
}

/// [recipe]'s nebula, as RGBA pixels. Top level, to run on another isolate.
Uint8List nebulaPixels(NebulaRecipe recipe) {
  final n = recipe.side;
  final out = Uint8List(n * n * 4);
  Rgb rgb(int argb) => Rgb(
    (argb >> 16 & 0xFF) / 255,
    (argb >> 8 & 0xFF) / 255,
    (argb & 0xFF) / 255,
  );
  final top = rgb(recipe.top).linear;
  final bottom = rgb(recipe.bottom).linear;
  final gas = [for (final c in recipe.gas) rgb(c).linear];
  double smooth(double from, double to, double x) {
    final t = ((x - from) / (to - from)).clamp(0.0, 1.0);
    return t * t * (3 - 2 * t);
  }

  for (var y = 0; y < n; y++) {
    for (var x = 0; x < n; x++) {
      final u = x / n;
      final v = y / n;
      final px = u * 2.4;
      final py = v * 2.4;
      // The gas, its shape folded over itself: noise looked up where other
      // noise says, which is what turns blobs into wisps.
      final qx = fbm3(px, py, 0.3, seed: 1);
      final qy = fbm3(px + 5.2, py + 1.3, 0.3, seed: 2);
      final density = fbm3(
        px + 1.8 * qx,
        py + 1.8 * qy,
        0.7,
        octaves: 5,
        seed: 3,
      );
      final cloud = smooth(0, 0.75, density);
      final hue = smooth(-0.4, 0.4, fbm3(px * 0.6 + 3, py * 0.6, 1.1, seed: 4));
      final dust = smooth(
        0.05,
        0.5,
        fbm3(px * 2.2 + 9, py * 2.2, 1.7, seed: 5),
      );
      // A galaxy's faint band, across the corner.
      final band =
          math.exp(-math.pow(u - 0.85 * v - 0.1, 2) / 0.03) *
          (0.55 + 0.45 * fbm3(px * 3, py * 3, 2.1, seed: 6));

      final sky = top.lerp(bottom, v);
      final glow = gas[0].lerp(gas[1 % gas.length], hue);
      final strength = math.pow(cloud, 2.2) * 0.7 * (1 - 0.8 * dust);
      final core = math.pow(smooth(0.6, 0.95, density), 2) * (1 - dust) * 0.22;
      final r =
          sky.r +
          glow.r * strength +
          gas[2 % gas.length].r * band * 0.22 +
          core * 0.8;
      final g =
          sky.g +
          glow.g * strength +
          gas[2 % gas.length].g * band * 0.22 +
          core * 0.75;
      final b =
          sky.b +
          glow.b * strength +
          gas[2 % gas.length].b * band * 0.22 +
          core * 0.9;
      int channel(double linear) =>
          (math.sqrt(linear.clamp(0.0, 1.0)) * 255).round();
      final i = (y * n + x) * 4;
      out
        ..[i] = channel(r)
        ..[i + 1] = channel(g)
        ..[i + 2] = channel(b)
        ..[i + 3] = 255;
    }
  }
  return out;
}
