import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'theme_mode_controller.g.dart';

/// Whether the app follows the device or is pinned to one brightness.
///
/// The default is [ThemeMode.system], which is also `MaterialApp`'s own
/// default — so this provider exists to let a user *override* the device, not
/// to make the app follow it. Following it is free.
///
/// The choice is not persisted: that would need a storage dependency, and
/// nothing here has one yet. Restarting the app returns to `system`.
@Riverpod(keepAlive: true)
class ThemeModeController extends _$ThemeModeController {
  @override
  ThemeMode build() => ThemeMode.system;

  /// Cycles through the three modes, leaving `system` by flipping away from
  /// [deviceBrightness].
  ///
  /// The order depends on the device for a reason. Stepping from `system` to a
  /// fixed `ThemeMode.light` changes nothing on screen when the device is
  /// already light: the state moves, the pixels do not, and the tap reads as
  /// one the app missed. Leaving `system` therefore always flips the
  /// brightness, so the first tap is always visible. The one step that looks
  /// like nothing happened is now the return to following the device, by
  /// which point both brightnesses have been seen.
  ///
  /// A settings screen with three explicit choices would add its own method
  /// here. There is no generic setter: `use_setters_to_change_properties`
  /// and `avoid_setters_without_getters` cannot both be satisfied by one.
  void cycle(Brightness deviceBrightness) {
    final isDark = deviceBrightness == Brightness.dark;
    final opposite = isDark ? ThemeMode.light : ThemeMode.dark;
    final matching = isDark ? ThemeMode.dark : ThemeMode.light;
    state = switch (state) {
      ThemeMode.system => opposite,
      final mode when mode == opposite => matching,
      _ => ThemeMode.system,
    };
  }
}
