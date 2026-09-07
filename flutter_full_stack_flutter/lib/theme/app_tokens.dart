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
    required this.wellFill,
    required this.wellBorder,
  });

  /// Derives the tokens for [scheme].
  ///
  /// [paneTranslucency] and [wellTranslucency] are how see-through each
  /// material is, from `0` (fully opaque) to `1` (as glassy as the design
  /// goes). They are separate because the two materials want different
  /// answers: a card can afford to be barely there, while a field holds text
  /// the user is reading back as they type.
  ///
  /// With [highContrast] both are forced to zero: the glass stops being glass,
  /// because a translucent surface cannot honour a contrast request. Callers
  /// do not branch on any of this — they read the tokens.
  factory AppTokens.of(
    ColorScheme scheme, {
    required bool highContrast,
    required double paneTranslucency,
    required double wellTranslucency,
  }) {
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
        wellFill: scheme.surface,
        wellBorder: scheme.outline,
      );
    }

    final isDark = scheme.brightness == Brightness.dark;
    final pane = paneTranslucency.clamp(0.0, 1.0);
    final well = wellTranslucency.clamp(0.0, 1.0);

    return AppTokens(
      backdropTop: scheme.primaryContainer,
      backdropBottom: scheme.surface,
      glassTint: scheme.surface.withValues(
        alpha: _translucent(isDark ? 0.18 : 0.55, pane),
      ),
      glassBorder: scheme.onSurface.withValues(alpha: isDark ? 0.16 : 0.22),
      glassHighlight: Colors.white.withValues(
        alpha: (isDark ? 0.06 : 0.35) * pane,
      ),
      // Blur follows translucency: a frost nothing shows through is a
      // BackdropFilter paying for an effect no one can see.
      glassBlur: (isDark ? 18 : 14) * pane,
      radiusLarge: _radiusLarge,
      radiusMedium: _radiusMedium,
      auroraOne: scheme.primary.withValues(alpha: isDark ? 0.38 : 0.30),
      auroraTwo: scheme.tertiary.withValues(alpha: isDark ? 0.32 : 0.26),
      auroraThree: scheme.secondary.withValues(alpha: isDark ? 0.26 : 0.20),
      wellFill: scheme.surfaceContainerLowest.withValues(
        alpha: _translucent(isDark ? 0.55 : 0.82, well),
      ),
      wellBorder: scheme.outlineVariant,
    );
  }

  /// Interpolates between opaque and [glassy] by [t], so `0` always means
  /// solid regardless of what the glassy end of the scale happens to be.
  static double _translucent(double glassy, double t) => 1 - t * (1 - glassy);

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

  /// Fill for a control the user types into.
  ///
  /// Deliberately not [glassTint]. A glass pane is *raised* — outer shadow,
  /// sheen along the top — and a field has to read as *recessed*, or it looks
  /// like a decorative tile that happens to contain a placeholder. Denser and
  /// darker than the surface around it is what says "this is a well".
  @override
  final Color wellFill;

  /// Edge of a well. Crisper than [glassBorder], because a field needs a
  /// boundary the eye can find without hunting.
  @override
  final Color wellBorder;
}
