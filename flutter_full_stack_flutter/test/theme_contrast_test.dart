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
  for (final theme in [
    (name: 'light', data: AppTheme.light()),
    (name: 'dark', data: AppTheme.dark()),
    (name: 'high contrast light', data: AppTheme.highContrastLight()),
    (name: 'high contrast dark', data: AppTheme.highContrastDark()),
  ]) {
    final scheme = theme.data.colorScheme;
    final tokens = theme.data.extension<AppTokens>()!;

    // Worst case for both materials: the strongest aurora pool sits directly
    // behind the surface, which is the least the fill has to work with.
    final backdrop = _over(tokens.auroraOne, tokens.backdropTop);

    test('text on a field is legible — ${theme.name}', () {
      final ratio = _ratio(scheme.onSurface, _over(tokens.wellFill, backdrop));
      printOnFailure('measured ${ratio.toStringAsFixed(2)}:1');
      expect(ratio, greaterThanOrEqualTo(4.5));
    });

    test('text on a pane is legible — ${theme.name}', () {
      final ratio = _ratio(scheme.onSurface, _over(tokens.glassTint, backdrop));
      printOnFailure('measured ${ratio.toStringAsFixed(2)}:1');
      expect(ratio, greaterThanOrEqualTo(4.5));
    });
  }
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
