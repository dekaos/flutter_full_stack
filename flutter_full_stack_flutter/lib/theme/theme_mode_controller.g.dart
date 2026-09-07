// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'theme_mode_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Whether the app follows the device or is pinned to one brightness.
///
/// The default is [ThemeMode.system], which is also `MaterialApp`'s own
/// default — so this provider exists to let a user *override* the device, not
/// to make the app follow it. Following it is free.
///
/// The choice is not persisted: that would need a storage dependency, and
/// nothing here has one yet. Restarting the app returns to `system`.

@ProviderFor(ThemeModeController)
final themeModeControllerProvider = ThemeModeControllerProvider._();

/// Whether the app follows the device or is pinned to one brightness.
///
/// The default is [ThemeMode.system], which is also `MaterialApp`'s own
/// default — so this provider exists to let a user *override* the device, not
/// to make the app follow it. Following it is free.
///
/// The choice is not persisted: that would need a storage dependency, and
/// nothing here has one yet. Restarting the app returns to `system`.
final class ThemeModeControllerProvider
    extends $NotifierProvider<ThemeModeController, ThemeMode> {
  /// Whether the app follows the device or is pinned to one brightness.
  ///
  /// The default is [ThemeMode.system], which is also `MaterialApp`'s own
  /// default — so this provider exists to let a user *override* the device, not
  /// to make the app follow it. Following it is free.
  ///
  /// The choice is not persisted: that would need a storage dependency, and
  /// nothing here has one yet. Restarting the app returns to `system`.
  ThemeModeControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'themeModeControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$themeModeControllerHash();

  @$internal
  @override
  ThemeModeController create() => ThemeModeController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ThemeMode value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ThemeMode>(value),
    );
  }
}

String _$themeModeControllerHash() =>
    r'e700a451604b4939ebebc7ad66a40190ffe977ca';

/// Whether the app follows the device or is pinned to one brightness.
///
/// The default is [ThemeMode.system], which is also `MaterialApp`'s own
/// default — so this provider exists to let a user *override* the device, not
/// to make the app follow it. Following it is free.
///
/// The choice is not persisted: that would need a storage dependency, and
/// nothing here has one yet. Restarting the app returns to `system`.

abstract class _$ThemeModeController extends $Notifier<ThemeMode> {
  ThemeMode build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<ThemeMode, ThemeMode>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ThemeMode, ThemeMode>,
              ThemeMode,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
