import 'package:flutter/material.dart';
import 'package:flutter_full_stack_flutter/theme/app_tokens.dart';
import 'package:google_fonts/google_fonts.dart';

/// CNA's colours, as cna.com.br declares them in its own stylesheet - the
/// two the app is dressed in, and the night its dark sections are set in.
abstract final class Brand {
  /// `--color-cna-red-6`: the red of CNA's calls to action.
  static const red = Color(0xFFED1941);

  /// `--color-cna-blue-brand`.
  static const blue = Color(0xFF2E2C83);

  /// The deep navy cna.com.br sets its dark sections in, and what the dark
  /// theme's surfaces are built up from.
  static const night = Color(0xFF01102E);
}

/// The one place the app's look is defined.
///
/// Four variants, because a device asks for more than light or dark: it can
/// also ask for high contrast, and `MaterialApp` has a slot for each
/// combination. All four come from the same [Brand] colours and the same
/// [_build], so they cannot drift apart.
abstract final class AppTheme {
  /// How see-through a glass pane is: `0` is a solid card, `1` is as glassy
  /// as the design goes.
  ///
  /// Separate from [wellTranslucency] because the two materials want
  /// different answers. Dialling this down also reduces the blur, since a
  /// frost nothing shows through costs GPU for nothing.
  static const paneTranslucency = 1.0;

  /// How see-through a field is. Lower it toward `0` if typed text is hard to
  /// read against a busy backdrop; a well is about legibility first.
  static const wellTranslucency = 1.0;

  /// Change this line to change the app's font everywhere.
  ///
  /// Any `GoogleFonts.*TextTheme` works. Note that google_fonts downloads the
  /// family at runtime on first use; see docs/theming.md for how to bundle it
  /// instead.
  static TextTheme _font(TextTheme base) => GoogleFonts.interTextTheme(base);

  /// Theme for a device asking for light.
  static ThemeData light() =>
      _build(brightness: Brightness.light, highContrast: false);

  /// Theme for a device asking for dark.
  static ThemeData dark() =>
      _build(brightness: Brightness.dark, highContrast: false);

  /// Theme for a device asking for light *and* increased contrast.
  static ThemeData highContrastLight() =>
      _build(brightness: Brightness.light, highContrast: true);

  /// Theme for a device asking for dark *and* increased contrast.
  static ThemeData highContrastDark() =>
      _build(brightness: Brightness.dark, highContrast: true);

  /// CNA's red for what to do, its blue for the rest, on surfaces drawn
  /// from its night.
  ///
  /// Material's tonal algorithm, seeded with each brand colour, lays out
  /// the families - `fidelity`, so the colour survives instead of being
  /// rotated into another hue. Then, outside high contrast, the brand's own
  /// tones are set where the algorithm would have softened them away: a
  /// dark theme's primary would otherwise be a pale pink, and its surfaces
  /// a neutral grey rather than CNA's navy. Under high contrast, Material's
  /// tones stand: they are what that request is for.
  ///
  /// Every pairing here is held to WCAG AA by `test/theme_contrast_test`.
  static ColorScheme _scheme(
    Brightness brightness, {
    required bool highContrast,
  }) {
    ColorScheme seeded(Color seed) => ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
      dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
      // Material's own answer to a contrast request. It moves the palette;
      // AppTokens.of moves the glass.
      contrastLevel: highContrast ? 1 : 0,
    );
    final red = seeded(Brand.red);
    final blue = seeded(Brand.blue);

    if (highContrast) {
      return blue.copyWith(
        primary: red.primary,
        onPrimary: red.onPrimary,
        primaryContainer: red.primaryContainer,
        onPrimaryContainer: red.onPrimaryContainer,
        inversePrimary: red.inversePrimary,
        secondary: blue.primary,
        onSecondary: blue.onPrimary,
        secondaryContainer: blue.primaryContainer,
        onSecondaryContainer: blue.onPrimaryContainer,
      );
    }

    if (brightness == Brightness.light) {
      return blue.copyWith(
        // The brand red, as deep as white on it needs to stay legible.
        primary: const Color(0xFFDB0F3A),
        onPrimary: Colors.white,
        primaryContainer: const Color(0xFFFDE2E7),
        onPrimaryContainer: const Color(0xFF6B0A1E),
        inversePrimary: const Color(0xFFFFB3BC),
        secondary: Brand.blue,
        onSecondary: Colors.white,
        secondaryContainer: const Color(0xFFDEDEF2),
        onSecondaryContainer: const Color(0xFF212359),
        // CNA's "English" blue: brighter than the brand's, for a second
        // pool of light that is still clearly CNA.
        tertiary: const Color(0xFF144092),
        onTertiary: Colors.white,
        tertiaryContainer: const Color(0xFFDCE5FF),
        onTertiaryContainer: const Color(0xFF0A2A66),
        // Cool, faintly blue whites, and text in CNA's navy rather than
        // black.
        surface: const Color(0xFFFAFAFD),
        surfaceDim: const Color(0xFFDCDDE8),
        surfaceBright: const Color(0xFFFAFAFD),
        surfaceContainerLowest: Colors.white,
        surfaceContainerLow: const Color(0xFFF4F5FA),
        surfaceContainer: const Color(0xFFEEEFF6),
        surfaceContainerHigh: const Color(0xFFE8E9F2),
        surfaceContainerHighest: const Color(0xFFE2E3EE),
        onSurface: const Color(0xFF15173A),
        onSurfaceVariant: const Color(0xFF4A4C75),
        outline: const Color(0xFF75779A),
        outlineVariant: const Color(0xFFC8CADB),
        inverseSurface: const Color(0xFF2A2C4C),
        onInverseSurface: const Color(0xFFF1F1FA),
      );
    }

    return blue.copyWith(
      // Still the brand's red at night - not the pale pink Material would
      // pick - lifted the touch it takes to be read as text on the night
      // (4.7:1) as well as to carry its own dark ink (4.7:1). White on it,
      // as by day, would leave red text on the night under AA.
      primary: const Color(0xFFF22B4C),
      onPrimary: const Color(0xFF2B0009),
      primaryContainer: const Color(0xFF4A0A1A),
      onPrimaryContainer: const Color(0xFFFFD9DF),
      inversePrimary: const Color(0xFFBA002D),
      secondary: const Color(0xFFB9BBF2),
      onSecondary: const Color(0xFF1A1B5A),
      // The brand blue itself, for what sits on a tonal fill.
      secondaryContainer: Brand.blue,
      onSecondaryContainer: const Color(0xFFE1E1F8),
      tertiary: const Color(0xFF9DB6FF),
      onTertiary: const Color(0xFF08245E),
      tertiaryContainer: const Color(0xFF144092),
      onTertiaryContainer: const Color(0xFFDCE5FF),
      // CNA's night, lifted a step at a time for each container.
      surface: const Color(0xFF0A0F2C),
      surfaceDim: const Color(0xFF0A0F2C),
      surfaceBright: const Color(0xFF2A3160),
      surfaceContainerLowest: const Color(0xFF060A20),
      surfaceContainerLow: const Color(0xFF0E1434),
      surfaceContainer: const Color(0xFF121838),
      surfaceContainerHigh: const Color(0xFF192044),
      surfaceContainerHighest: const Color(0xFF21284F),
      onSurface: const Color(0xFFE8E9F8),
      onSurfaceVariant: const Color(0xFFBBBDDC),
      outline: const Color(0xFF8B8EB3),
      outlineVariant: const Color(0xFF383E69),
      inverseSurface: const Color(0xFFE8E9F8),
      onInverseSurface: const Color(0xFF1B1E3F),
    );
  }

  static ThemeData _build({
    required Brightness brightness,
    required bool highContrast,
  }) {
    final scheme = _scheme(brightness, highContrast: highContrast);
    final tokens = AppTokens.of(
      scheme,
      highContrast: highContrast,
      paneTranslucency: paneTranslucency,
      wellTranslucency: wellTranslucency,
    );
    final base = ThemeData(colorScheme: scheme);

    return base.copyWith(
      textTheme: _font(base.textTheme),
      extensions: [tokens],
      // AuroraBackdrop paints behind everything, so the bars sit on top of it
      // rather than covering it with their own surface colour.
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      // A field is a well, not a pane: the fill is denser than the glass and
      // there is no sheen, because a highlight sitting where the text goes is
      // what makes an input look like a button.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: tokens.wellFill,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(tokens.radiusMedium),
          borderSide: BorderSide(color: tokens.wellBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(tokens.radiusMedium),
          borderSide: BorderSide(color: tokens.wellBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(tokens.radiusMedium),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(tokens.radiusMedium),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        ),
      ),
    );
  }
}
