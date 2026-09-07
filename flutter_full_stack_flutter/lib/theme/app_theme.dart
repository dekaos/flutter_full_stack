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
      // Material's own answer to a contrast request. It moves the palette;
      // AppTokens.of moves the glass.
      contrastLevel: highContrast ? 1 : 0,
    );
    final tokens = AppTokens.of(scheme, highContrast: highContrast);
    final base = ThemeData(colorScheme: scheme);

    return base.copyWith(
      textTheme: _font(base.textTheme),
      extensions: [tokens],
      // The backdrop gradient is painted by AppBackdrop, so the bars sit on
      // top of it rather than covering it with their own surface colour.
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: tokens.glassTint,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(tokens.radiusMedium),
          borderSide: BorderSide(color: tokens.glassBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(tokens.radiusMedium),
          borderSide: BorderSide(color: tokens.glassBorder),
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
