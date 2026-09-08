// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'locale_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Whether the app follows the device's language or is pinned to one.
///
/// `null` means follow the device, which is also what `MaterialApp.locale`
/// treats as "resolve from the platform" — so following is the default and
/// costs nothing. This provider exists to let a user *override* it.
///
/// The choice is not persisted: that would need a storage dependency the app
/// does not have. Restarting returns to the device's language.

@ProviderFor(LocaleController)
final localeControllerProvider = LocaleControllerProvider._();

/// Whether the app follows the device's language or is pinned to one.
///
/// `null` means follow the device, which is also what `MaterialApp.locale`
/// treats as "resolve from the platform" — so following is the default and
/// costs nothing. This provider exists to let a user *override* it.
///
/// The choice is not persisted: that would need a storage dependency the app
/// does not have. Restarting returns to the device's language.
final class LocaleControllerProvider
    extends $NotifierProvider<LocaleController, Locale?> {
  /// Whether the app follows the device's language or is pinned to one.
  ///
  /// `null` means follow the device, which is also what `MaterialApp.locale`
  /// treats as "resolve from the platform" — so following is the default and
  /// costs nothing. This provider exists to let a user *override* it.
  ///
  /// The choice is not persisted: that would need a storage dependency the app
  /// does not have. Restarting returns to the device's language.
  LocaleControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'localeControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$localeControllerHash();

  @$internal
  @override
  LocaleController create() => LocaleController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Locale? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Locale?>(value),
    );
  }
}

String _$localeControllerHash() => r'f40ad22fa2be6839e4db50d5ac938f0405bd3244';

/// Whether the app follows the device's language or is pinned to one.
///
/// `null` means follow the device, which is also what `MaterialApp.locale`
/// treats as "resolve from the platform" — so following is the default and
/// costs nothing. This provider exists to let a user *override* it.
///
/// The choice is not persisted: that would need a storage dependency the app
/// does not have. Restarting returns to the device's language.

abstract class _$LocaleController extends $Notifier<Locale?> {
  Locale? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<Locale?, Locale?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<Locale?, Locale?>,
              Locale?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
