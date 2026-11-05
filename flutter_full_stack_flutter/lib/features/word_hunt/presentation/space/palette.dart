import 'dart:ui';

import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_full_stack_flutter/features/word_hunt/presentation/space/geometry.dart';
import 'package:flutter_full_stack_flutter/features/word_hunt/presentation/space/renderer.dart';

/// The colours of one corner of space: its sky and nebulae, its planet and
/// the light everything there is lit by - all from one [hue], so each deck
/// is a place of its own and still belongs with the rest.
///
/// The sky stays near black whatever the hue: the words are read over it,
/// on dark labels, and a bright sky would fight them. The colour goes into
/// the nebulae, the planet and the light on the ships.
@immutable
class SpacePalette {
  SpacePalette(this.hue)
    : skyTop = _hsl(hue + 12, 0.6, 0.03),
      skyBottom = _hsl(hue - 18, 0.5, 0.085),
      nebulae = [
        _hsl(hue, 0.85, 0.5).withValues(alpha: 0.24),
        _hsl(hue + 55, 0.8, 0.58).withValues(alpha: 0.17),
        _hsl(hue - 45, 0.75, 0.48).withValues(alpha: 0.2),
      ],
      glow = _hsl(hue + 25, 1, 0.72),
      sea = Rgb.hsl(hue, 0.62, 0.46),
      land = Rgb.hsl(hue + 38, 0.58, 0.62),
      ice = Rgb.hsl(hue, 0.3, 0.92),
      ringInner = Rgb.hsl(hue + 180, 0.5, 0.74),
      ringOuter = Rgb.hsl(hue + 205, 0.42, 0.58),
      moon = Rgb.hsl(hue + 20, 0.14, 0.72),
      rock = Rgb.hsl(hue + 10, 0.14, 0.46),
      lighting = Lighting(
        sun: const V3(-0.5, 0.7, 0.55).unit,
        key: const Rgb(1, 0.95, 0.88) * 0.92,
        sky: Rgb.hsl(hue, 0.38, 0.66) * 0.36,
        ground: Rgb.hsl(hue + 40, 0.35, 0.45) * 0.2,
        rim: Rgb.hsl(hue + 30, 0.85, 0.74) * 0.55,
        fog: Rgb.hsl(hue - 10, 0.45, 0.1),
        fogDensity: 0.014,
      );

  /// The lobby's: CNA's blue, with its red in the details.
  static final lobby = SpacePalette(236);

  final double hue;

  final Color skyTop;
  final Color skyBottom;

  /// Three clouds of light behind everything.
  final List<Color> nebulae;

  /// Lasers, sparks and the light of a hit.
  final Color glow;

  final Rgb sea;
  final Rgb land;
  final Rgb ice;
  final Rgb ringInner;
  final Rgb ringOuter;
  final Rgb moon;
  final Rgb rock;

  final Lighting lighting;

  static Color _hsl(double hue, double saturation, double lightness) =>
      Rgb.hsl(hue, saturation, lightness).color;

  @override
  bool operator ==(Object other) => other is SpacePalette && other.hue == hue;

  @override
  int get hashCode => hue.hashCode;
}

/// The colours the word ships come in: cheerful, and far enough apart that
/// two ships side by side never look alike.
abstract final class ShipColours {
  static final body = [
    Rgb.hsl(8, 0.82, 0.62),
    Rgb.hsl(158, 0.58, 0.52),
    Rgb.hsl(204, 0.82, 0.6),
    Rgb.hsl(46, 0.95, 0.58),
    Rgb.hsl(278, 0.62, 0.66),
    Rgb.hsl(24, 0.92, 0.62),
  ];

  /// What shines round each ship's rim: a lighter, warmer cousin of it.
  static final List<Rgb> lights = [
    for (final c in body) c.lerp(const Rgb(1, 0.97, 0.8), 0.65),
  ];

  static int get count => body.length;
}
