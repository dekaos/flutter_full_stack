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

  /// Cycles system → light → dark → system, which is enough for one button.
  ///
  /// A settings screen with three explicit choices would add its own method
  /// here. There is no generic setter: `use_setters_to_change_properties`
  /// and `avoid_setters_without_getters` cannot both be satisfied by one.
  void cycle() => state = switch (state) {
    ThemeMode.system => ThemeMode.light,
    ThemeMode.light => ThemeMode.dark,
    ThemeMode.dark => ThemeMode.system,
  };
}
