import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_full_stack_flutter/theme/app_theme.dart';
import 'package:flutter_full_stack_flutter/theme/app_tokens.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guards the translucency dials against making text illegible.
///
/// A translucent surface has no contrast ratio of its own: what the reader
/// sees is the fill composited over whatever happens to be behind it. Dial
/// `paneTranslucency` or `wellTranslucency` far enough and the text on those
/// surfaces quietly stops meeting WCAG AA, with nothing failing to say so.
/// This is that something.
void main() {
  // Building a theme reaches for the font, which needs a binding. Without
  // this, google_fonts floods the log with "Binding has not yet been
  // initialized" and falls back to a default face.
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final variant in [
    (name: 'light', build: AppTheme.light),
    (name: 'dark', build: AppTheme.dark),
    (name: 'high contrast light', build: AppTheme.highContrastLight),
    (name: 'high contrast dark', build: AppTheme.highContrastDark),
  ]) {
    /// Worst case for both materials: the strongest aurora pool sits directly
    /// behind the surface, which is the least the fill has to work with.
    ({Color field, Color pane, Color text}) surfaces() {
      final theme = variant.build();
      final tokens = theme.extension<AppTokens>()!;
      final backdrop = _over(tokens.auroraOne, tokens.backdropTop);
      return (
        field: _over(tokens.wellFill, backdrop),
        pane: _over(tokens.glassTint, backdrop),
        text: theme.colorScheme.onSurface,
      );
    }

    test('text on a field is legible — ${variant.name}', () {
      final s = surfaces();
      final ratio = _ratio(s.text, s.field);
      printOnFailure('measured ${ratio.toStringAsFixed(2)}:1');
      expect(ratio, greaterThanOrEqualTo(4.5));
    });

    test('text on a pane is legible — ${variant.name}', () {
      final s = surfaces();
      final ratio = _ratio(s.text, s.pane);
      printOnFailure('measured ${ratio.toStringAsFixed(2)}:1');
      expect(ratio, greaterThanOrEqualTo(4.5));
    });

    // The scene behind a prompt is full-bleed and opaque: it is what the
    // headline is read on and what the glass shows through. It is confined to
    // a band of lightness rather than to a palette, so this sweeps the band -
    // every hue, from grey to as saturated as a scene may get, from its
    // darkest to its lightest - instead of checking colours one by one.
    test('any colour a scene can paint keeps text legible — '
        '${variant.name}', () {
      final theme = variant.build();
      final tokens = theme.extension<AppTokens>()!;
      final scheme = theme.colorScheme;
      final tone = tokens.sceneTone;

      for (var hue = 0; hue < 360; hue += 15) {
        for (final saturation in [0.0, 0.35, 0.7, 1.0]) {
          for (var step = 0; step <= 20; step++) {
            final scene = tone.color(hue.toDouble(), saturation, step / 20);
            final pane = _over(tokens.glassTint, scene);
            final where =
                'hue $hue, saturation $saturation, level ${step / 20}';
            void legible(Color text, Color on, double ratio) => expect(
              _ratio(text, on),
              greaterThanOrEqualTo(ratio),
              reason: '$text on $where',
            );

            // Straight on the scene: the headline, the tagline, the
            // position under the deck.
            legible(scheme.onSurface, scene, 4.5);
            legible(scheme.onSurfaceVariant, scene, 4.5);
            // Through the glass: the sentence, the explanations, and errors
            // and the weak phoneme, which are small text.
            legible(scheme.onSurface, pane, 4.5);
            legible(scheme.onSurfaceVariant, pane, 4.5);
            legible(scheme.error, pane, 4.5);
            // The score colours only ever colour the prompt and the overall
            // number, 24 px and up: large text, whose AA is 3:1.
            legible(tokens.scoreStrong, pane, 3);
            legible(tokens.scoreFair, pane, 3);
          }
        }
      }
    });

    // The world on the island is painted in a much wider band, because
    // nothing is read straight off it: the sentence and every pane over it
    // are dense glass. So the promise moves to the glass - over anything
    // the world band can paint, what is on it stays legible.
    test('dense glass keeps text legible over the whole world — '
        '${variant.name}', () {
      final theme = variant.build();
      final tokens = theme.extension<AppTokens>()!;
      final scheme = theme.colorScheme;
      final world = tokens.worldTone;

      for (var hue = 0; hue < 360; hue += 15) {
        for (final saturation in [0.0, 0.35, 0.7, 1.0]) {
          for (var step = 0; step <= 20; step++) {
            final under = world.color(hue.toDouble(), saturation, step / 20);
            final pane = _over(tokens.glassDense, under);
            final where =
                'hue $hue, saturation $saturation, level ${step / 20}';
            void legible(Color text, double ratio) => expect(
              _ratio(text, pane),
              greaterThanOrEqualTo(ratio),
              reason: '$text on $where',
            );

            legible(scheme.onSurface, 4.5);
            legible(scheme.onSurfaceVariant, 4.5);
            legible(scheme.error, 4.5);
            // 24 px and up: large text.
            legible(tokens.scoreStrong, 3);
            legible(tokens.scoreFair, 3);
          }
        }
      }
    });
  }

  test('the scene steps aside when contrast is requested', () {
    for (final build in [
      AppTheme.highContrastLight,
      AppTheme.highContrastDark,
    ]) {
      expect(build().extension<AppTokens>()!.sceneOpacity, 0);
    }
    for (final build in [AppTheme.light, AppTheme.dark]) {
      expect(build().extension<AppTokens>()!.sceneOpacity, 1);
    }
  });
}

/// Composites [top] over [bottom] using [top]'s own alpha.
Color _over(Color top, Color bottom) {
  final a = top.a;
  double mix(double t, double b) => t * a + b * (1 - a);
  return Color.from(
    alpha: 1,
    red: mix(top.r, bottom.r),
    green: mix(top.g, bottom.g),
    blue: mix(top.b, bottom.b),
  );
}

double _channel(double c) =>
    c <= 0.03928 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();

double _luminance(Color c) =>
    0.2126 * _channel(c.r) + 0.7152 * _channel(c.g) + 0.0722 * _channel(c.b);

/// WCAG 2.1 relative contrast between two opaque colours.
double _ratio(Color a, Color b) {
  final first = _luminance(a);
  final second = _luminance(b);
  return (math.max(first, second) + 0.05) / (math.min(first, second) + 0.05);
}
