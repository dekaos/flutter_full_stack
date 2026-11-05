import 'dart:math' as math;

import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter/painting.dart';

/// The band of lightness the scene behind a prompt is painted in, and the
/// colours that fit inside it.
///
/// The scene is full-bleed and opaque, so every colour it paints is a colour
/// some text is read against: the headline straight on it, the deck and the
/// score through the glass. Rather than vetting a palette colour by colour,
/// the scene is confined to a band of CIE lightness (L*, 0 to 100) worked out
/// from the text colours themselves, in `AppTokens.of`: on a light theme it
/// starts where the faintest text reaches 4.5:1, on a dark one it ends there.
/// Inside it, any hue at any saturation is legible, which is what lets the
/// scenes be colourful without anyone having to check them.
///
/// The price is that a scene cannot use the full range of lightness: light
/// themes get airy pastels, dark ones deep jewel tones. That is the sobriety
/// the design asks for anyway.
@immutable
class SceneTone {
  const SceneTone(this.low, this.high, [this.gamma = 1]);

  /// Derives the band for text colours [texts] read straight on the scene.
  ///
  /// On a light scheme the text is dark, so the band runs from the lightness
  /// at which every text colour reaches [ratio] (plus [margin]) up to near
  /// white; on a dark scheme it runs from near black up to the lightness at
  /// which they still do (minus [margin]).
  factory SceneTone.around(
    List<Color> texts, {
    required bool dark,
    double ratio = 4.5,
    double margin = 3,
  }) {
    final luminances = [for (final text in texts) text.computeLuminance()];
    if (dark) {
      final darkest = luminances.reduce(math.min);
      final ceiling = (darkest + 0.05) / ratio - 0.05;
      return SceneTone(5, lightnessOf(ceiling) - margin, 0.8);
    }
    final lightest = luminances.reduce(math.max);
    final floor = ratio * (lightest + 0.05) - 0.05;
    return SceneTone(lightnessOf(floor) + margin, 98, 1.7);
  }

  /// The darkest a scene colour may be, in L*.
  final double low;

  /// The lightest a scene colour may be, in L*.
  final double high;

  /// How [color]'s `level` is spread over the band.
  ///
  /// Colour has the most body at the end of the band nearest the text: deep
  /// end on a light theme, light end on a dark one. Spread evenly, the middle
  /// levels a scene uses most would be washed out on one theme and murky on
  /// the other; above `1` pulls them toward the dark end, below `1` toward
  /// the light end, so one palette carries both.
  final double gamma;

  /// The most saturated a scene colour gets, whatever it asks for.
  ///
  /// Partly taste - full saturation is what makes an illustration loud - and
  /// partly arithmetic: at full saturation a channel drops to zero, and such
  /// a colour seen through the glass composites darker than its lightness
  /// promises, by enough to cost a score colour its contrast.
  static const maxSaturation = 0.85;

  /// A colour of [hue] (degrees) and HSL [saturation] (`0` to `1`), [level]
  /// of the way from the dark end of the band (`0`) to the light end (`1`).
  ///
  /// [level] is spread over L*, which is perceptual, bent by [gamma], so a
  /// scene written once shades the same way - lighter tops, darker sides -
  /// on a light theme and a dark one.
  Color color(double hue, double saturation, double level) {
    final spread = math.pow(level.clamp(0.0, 1.0), gamma).toDouble();
    final lightness = low + (high - low) * spread;
    final target = luminanceOf(lightness);
    final h = hue % 360;
    final s = saturation.clamp(0.0, maxSaturation);
    // Luminance only grows with HSL lightness for a fixed hue and
    // saturation, so the lightness that hits the target can be bisected.
    var below = 0.0;
    var above = 1.0;
    for (var i = 0; i < 24; i++) {
      final mid = (below + above) / 2;
      final y = HSLColor.fromAHSL(1, h, s, mid).toColor().computeLuminance();
      if (y < target) {
        below = mid;
      } else {
        above = mid;
      }
    }
    return HSLColor.fromAHSL(1, h, s, (below + above) / 2).toColor();
  }

  /// CIE L* of a relative luminance.
  static double lightnessOf(double luminance) {
    final y = luminance.clamp(0.0, 1.0);
    return y <= 216 / 24389
        ? y * 24389 / 27
        : 116 * math.pow(y, 1 / 3).toDouble() - 16;
  }

  /// Relative luminance of a CIE L*.
  static double luminanceOf(double lightness) {
    final l = lightness.clamp(0.0, 100.0);
    if (l <= 8) return l * 27 / 24389;
    final f = (l + 16) / 116;
    return f * f * f;
  }

  @override
  bool operator ==(Object other) =>
      other is SceneTone &&
      other.low == low &&
      other.high == high &&
      other.gamma == gamma;

  @override
  int get hashCode => Object.hash(low, high, gamma);
}
