import 'package:flutter/material.dart';
import 'package:flutter_full_stack_flutter/theme/scene_tone.dart';
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
    required this.sceneLow,
    required this.sceneHigh,
    required this.sceneGamma,
    required this.sceneOpacity,
    required this.sceneHush,
    required this.worldLow,
    required this.worldHigh,
    required this.glassDense,
    required this.scoreStrong,
    required this.scoreFair,
    required this.scoreWeak,
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
    final isDarkScheme = scheme.brightness == Brightness.dark;
    // Worked out from the text that sits straight on the backdrop: whatever
    // the scene paints inside this band, those stay at 4.5:1 or better.
    final band = SceneTone.around(
      [scheme.onSurface, scheme.onSurfaceVariant],
      dark: isDarkScheme,
      // Wider on light: its glass is denser, and a saturated green seen
      // through it composites darker than its lightness promises - by
      // enough, at 3, to take error text on a card below AA.
      margin: isDarkScheme ? 3 : 5,
    );
    // The world on the island gets far more range than the sky, because no
    // text sits straight on it any more: what is read over it is on dense
    // glass. Sun-lit faces, deep shadows and lights that glow live here.
    // The bounds are what the dense glass keeps text legible over, and
    // theme_contrast_test holds them.
    final world = isDarkScheme
        ? SceneTone(5, 68, band.gamma)
        : SceneTone(36, 98, band.gamma);

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
        // Gone for the same reason as the aurora: an illustration behind the
        // text is exactly what a contrast request asks to remove. The band
        // is still the honest one, so a theme change animates sensibly.
        sceneLow: band.low,
        sceneHigh: band.high,
        sceneGamma: band.gamma,
        sceneOpacity: 0,
        sceneHush: Colors.transparent,
        worldLow: world.low,
        worldHigh: world.high,
        // Already opaque here, like every pane.
        glassDense: scheme.surfaceContainerHighest,
        scoreStrong: isDarkScheme
            ? const Color(0xFF7FE8B4)
            : const Color(0xFF0F5C34),
        scoreFair: isDarkScheme
            ? const Color(0xFFFFC85C)
            : const Color(0xFF6B4400),
        scoreWeak: scheme.error,
      );
    }

    final isDark = scheme.brightness == Brightness.dark;
    final pane = paneTranslucency.clamp(0.0, 1.0);
    final well = wellTranslucency.clamp(0.0, 1.0);

    return AppTokens(
      // Down from the calm colour, not the loud one: the red is for what to
      // do, and a page washed in it would shout. Only part of the way to
      // it, too - the brand blue in full leans to violet over a whole page.
      backdropTop: Color.alphaBlend(
        scheme.secondaryContainer.withValues(alpha: isDark ? 0.5 : 0.6),
        scheme.surface,
      ),
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
      // Blue behind the sentence and below it, and the red as an ember at
      // the side: light enough to sell the glass, quiet enough to stay
      // sober in both brightnesses.
      // The ember is kept small: red over blue mixes to magenta, and a page
      // that reads purple is no longer CNA's.
      auroraOne: scheme.tertiary.withValues(alpha: isDark ? 0.34 : 0.20),
      auroraTwo: scheme.primary.withValues(alpha: isDark ? 0.16 : 0.07),
      auroraThree: scheme.tertiary.withValues(alpha: isDark ? 0.18 : 0.12),
      wellFill: scheme.surfaceContainerLowest.withValues(
        alpha: _translucent(isDark ? 0.34 : 0.58, well),
      ),
      wellBorder: scheme.outlineVariant,
      sceneLow: band.low,
      sceneHigh: band.high,
      sceneGamma: band.gamma,
      sceneOpacity: 1,
      sceneHush: scheme.surface.withValues(alpha: isDark ? 0.6 : 0.55),
      worldLow: world.low,
      worldHigh: world.high,
      glassDense: scheme.surface.withValues(alpha: isDark ? 0.74 : 0.86),
      scoreStrong: isDark ? const Color(0xFF5FD39A) : const Color(0xFF1B7F4B),
      scoreFair: isDark ? const Color(0xFFE8B04B) : const Color(0xFF8A5A00),
      scoreWeak: scheme.error,
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

  /// The darkest the scene behind a prompt may paint, in CIE L*.
  ///
  /// The scene is full-bleed and opaque, so it is what the headline is read
  /// on and what the glass shows through. [sceneLow] and [sceneHigh] are the
  /// band it is confined to, derived from the text colours so that anything
  /// painted inside it leaves them at WCAG AA: light themes get pastels, dark
  /// ones deep jewel tones. [SceneTone] turns a hue into a colour in it, and
  /// `test/theme_contrast_test.dart` holds the promise.
  @override
  final double sceneLow;

  /// The lightest the scene may paint, in CIE L*.
  @override
  final double sceneHigh;

  /// How a scene's levels are spread over the band; see [SceneTone.gamma].
  @override
  final double sceneGamma;

  /// `1` normally and `0` under high contrast, which is how the scene
  /// disappears there without the widget asking. A double, not a flag, so a
  /// theme change fades it rather than snapping.
  @override
  final double sceneOpacity;

  /// The darkest the world on a scene's island may paint, in CIE L*: the
  /// island's own band, much wider than the sky's ([sceneLow]..[sceneHigh]).
  ///
  /// The sky stays calm because the deck and the controls sit over it. The
  /// world is where the sentence is acted out, and it needs real light to do
  /// that - a lit window, a sun-struck roof, a shadow under a tree. Nothing
  /// on it is read straight off it: the deck and every pane over it use
  /// [glassDense].
  @override
  final double worldLow;

  /// The lightest the world on a scene's island may paint, in CIE L*.
  @override
  final double worldHigh;

  /// Glass for what must be read over the scene: the sentence, the score,
  /// a failure. Frosted rather than clear - enough of the world shows through
  /// to keep it glass, little enough that the text holds AA over anything
  /// the world band can paint. It is also what makes the sentence the one
  /// solid, still thing on a lively screen.
  @override
  final Color glassDense;

  /// Laid over the scene while the learner speaks, so the sentence is the
  /// one thing left in focus. The surface colour, so it only ever moves the
  /// scene away from the text: lighter under dark text, darker under light.
  @override
  final Color sceneHush;

  /// A pronunciation score that is good enough to move on from.
  ///
  /// The three score colours are the one exception to deriving everything
  /// from the seed: "you said it right" is a fixed meaning, and a brand that
  /// seeds green would otherwise render a good score and a bad one in the
  /// same hue. [ColorScheme] has a slot for error and none for its opposite,
  /// so the positive end is spelled out here. Each value is tuned against the
  /// surface of its own brightness, which is why they are not one constant
  /// with an opacity.
  @override
  final Color scoreStrong;

  /// A score that is understandable but not yet right.
  @override
  final Color scoreFair;

  /// A score the learner has to do something about. [ColorScheme.error], so a
  /// mispronunciation reads with the same urgency as anything else that went
  /// wrong.
  @override
  final Color scoreWeak;
}

/// The scene's band as something that makes colours.
///
/// An extension rather than a getter on [AppTokens], because theme_tailor
/// treats every getter there as a token of its own and would put this one
/// in `copyWith`, `lerp` and equality next to the three fields it derives
/// from.
extension SceneToneOfTokens on AppTokens {
  /// The sky's band.
  SceneTone get sceneTone => SceneTone(sceneLow, sceneHigh, sceneGamma);

  /// The island's band. Shares the sky's gamma, so a level means the same
  /// thing in both, only over a longer reach.
  SceneTone get worldTone => SceneTone(worldLow, worldHigh, sceneGamma);
}
