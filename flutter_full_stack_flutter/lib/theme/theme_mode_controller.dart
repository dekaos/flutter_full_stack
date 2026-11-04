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

  /// Flips what is on screen, light to dark or dark to light, whatever the
  /// mode - one tap, one change.
  ///
  /// It used to cycle through the three modes, and one step of the cycle
  /// was always invisible: following a light device, and pinned to light,
  /// look the same. That tap read as one the app had missed, and the user
  /// tapped again. Now there are only the two brightnesses to choose
  /// between, and flipping back to the one [deviceBrightness] asks for is
  /// following the device again - so it is still followed when it changes,
  /// at night, say.
  void toggle(Brightness deviceBrightness) {
    final next = switch (shownIn(state, device: deviceBrightness)) {
      Brightness.light => Brightness.dark,
      Brightness.dark => Brightness.light,
    };
    state = next == deviceBrightness
        ? ThemeMode.system
        : switch (next) {
            Brightness.light => ThemeMode.light,
            Brightness.dark => ThemeMode.dark,
          };
  }
}

/// The brightness on screen in [mode], on a device that asks for [device].
Brightness shownIn(ThemeMode mode, {required Brightness device}) =>
    switch (mode) {
      ThemeMode.system => device,
      ThemeMode.light => Brightness.light,
      ThemeMode.dark => Brightness.dark,
    };
