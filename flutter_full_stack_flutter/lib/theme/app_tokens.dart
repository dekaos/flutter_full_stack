import 'package:flutter/material.dart';
import 'package:theme_tailor_annotation/theme_tailor_annotation.dart';

part 'app_tokens.tailor.dart';

/// The design decisions Material's own theme has no slot for.
///
/// Read them with `Theme.of(context).appTokens`. Because this is a
/// [ThemeExtension], the values interpolate when the theme changes, so a
/// light/dark switch animates the glass along with the colours instead of
/// snapping.
///
/// Every colour here is derived from the [ColorScheme] in [AppTokens.of], so
/// changing the seed in `AppTheme` moves the whole surface with it.
@TailorMixin(themeGetter: ThemeGetter.onThemeData)
class AppTokens extends ThemeExtension<AppTokens> with _$AppTokensTailorMixin {
  const AppTokens({
    required this.backdropTop,
    required this.backdropBottom,
    required this.glassTint,
    required this.glassBorder,
    required this.glassHighlight,
    required this.glassBlur,
    required this.radiusLarge,
    required this.radiusMedium,
    required this.auroraOne,
    required this.auroraTwo,
    required this.auroraThree,
  });

  /// Derives the tokens for [scheme].
  ///
  /// With [highContrast] the glass stops being glass: the blur goes to zero
  /// and the fill becomes opaque, because a translucent surface cannot honour
  /// a contrast request. Callers do not branch on it — they read the tokens.
  factory AppTokens.of(ColorScheme scheme, {required bool highContrast}) {
    if (highContrast) {
      return AppTokens(
        backdropTop: scheme.surface,
        backdropBottom: scheme.surface,
        glassTint: scheme.surfaceContainerHighest,
        glassBorder: scheme.outline,
        glassHighlight: Colors.transparent,
        glassBlur: 0,
        radiusLarge: _radiusLarge,
        radiusMedium: _radiusMedium,
        // Flat: an aurora behind an opaque pane is invisible anyway, and
        // colour wash is the first thing to go when contrast is requested.
        auroraOne: Colors.transparent,
        auroraTwo: Colors.transparent,
        auroraThree: Colors.transparent,
      );
    }

    final isDark = scheme.brightness == Brightness.dark;
    return AppTokens(
      backdropTop: scheme.primaryContainer,
      backdropBottom: scheme.surface,
      glassTint: scheme.surface.withValues(alpha: isDark ? 0.18 : 0.55),
      glassBorder: scheme.onSurface.withValues(alpha: isDark ? 0.16 : 0.22),
      glassHighlight: Colors.white.withValues(alpha: isDark ? 0.06 : 0.35),
      glassBlur: isDark ? 18 : 14,
      radiusLarge: _radiusLarge,
      radiusMedium: _radiusMedium,
      auroraOne: scheme.primary.withValues(alpha: isDark ? 0.38 : 0.30),
      auroraTwo: scheme.tertiary.withValues(alpha: isDark ? 0.32 : 0.26),
      auroraThree: scheme.secondary.withValues(alpha: isDark ? 0.26 : 0.20),
    );
  }

  static const _radiusLarge = 24.0;
  static const _radiusMedium = 16.0;

  /// Top stop of the page backdrop. Glass only reads as glass over something
  /// with structure, so the backdrop is part of the design system, not decor.
  @override
  final Color backdropTop;

  /// Bottom stop of the page backdrop.
  @override
  final Color backdropBottom;

  /// Fill painted over the blur.
  @override
  final Color glassTint;

  /// Hairline that gives the pane an edge.
  @override
  final Color glassBorder;

  /// Sheen along the top edge, which is what sells the material.
  @override
  final Color glassHighlight;

  /// Blur sigma. Zero means no `BackdropFilter` is inserted at all.
  @override
  final double glassBlur;

  /// Corner radius for panes and cards.
  @override
  final double radiusLarge;

  /// Corner radius for controls inside a pane.
  @override
  final double radiusMedium;

  /// The three colour pools the backdrop is built from.
  ///
  /// A single linear wash reads as a flat gradient. Three overlapping radial
  /// pools read as light, and give the glass something with structure to
  /// refract instead of one even field of colour.
  @override
  final Color auroraOne;

  /// Second aurora pool.
  @override
  final Color auroraTwo;

  /// Third aurora pool.
  @override
  final Color auroraThree;
}
