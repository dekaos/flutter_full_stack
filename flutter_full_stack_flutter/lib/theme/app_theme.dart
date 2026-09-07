import 'package:flutter/material.dart';
import 'package:flutter_full_stack_flutter/theme/app_tokens.dart';
import 'package:google_fonts/google_fonts.dart';

/// The one place the app's look is defined.
///
/// Four variants, because a device asks for more than light or dark: it can
/// also ask for high contrast, and `MaterialApp` has a slot for each
/// combination. All four come from the same [seed] and the same [_build], so
/// they cannot drift apart.
abstract final class AppTheme {
  /// The single colour the palette is derived from.
  ///
  /// Change this line and every Material colour moves, and so does every
  /// token in [AppTokens], because those are derived from the scheme too.
  static const seed = Color(0xFF6C5CE7);

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

  static ThemeData _build({
    required Brightness brightness,
    required bool highContrast,
  }) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
      // `tonalSpot`, the default, is what makes an M3 app look like every
      // other M3 app. `expressive` pushes the secondary and tertiary tones
      // apart, which the aurora needs to read as three colours and not one.
      dynamicSchemeVariant: DynamicSchemeVariant.expressive,
      // Material's own answer to a contrast request. It moves the palette;
      // AppTokens.of moves the glass.
      contrastLevel: highContrast ? 1 : 0,
    );
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
