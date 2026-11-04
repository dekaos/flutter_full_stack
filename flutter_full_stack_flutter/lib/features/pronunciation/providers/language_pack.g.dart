// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'language_pack.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Kept alive because the downloads it runs must outlive the screen that
/// started them.

@ProviderFor(modelStore)
final modelStoreProvider = ModelStoreProvider._();

/// Kept alive because the downloads it runs must outlive the screen that
/// started them.

final class ModelStoreProvider
    extends $FunctionalProvider<ModelStore, ModelStore, ModelStore>
    with $Provider<ModelStore> {
  /// Kept alive because the downloads it runs must outlive the screen that
  /// started them.
  ModelStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'modelStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$modelStoreHash();

  @$internal
  @override
  $ProviderElement<ModelStore> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ModelStore create(Ref ref) {
    return modelStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ModelStore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ModelStore>(value),
    );
  }
}

String _$modelStoreHash() => r'79d71dcd6f4e9ad6b95d9bcaac19c40f31f2c3c4';

/// One language's pack, as the chooser shows it - and the download that
/// brings it, which starts there.
///
/// The download itself is the store's, not this controller's: it outlives
/// the controller, and a controller built while one is running follows it
/// instead of offering it again.

@ProviderFor(LanguagePackController)
final languagePackControllerProvider = LanguagePackControllerFamily._();

/// One language's pack, as the chooser shows it - and the download that
/// brings it, which starts there.
///
/// The download itself is the store's, not this controller's: it outlives
/// the controller, and a controller built while one is running follows it
/// instead of offering it again.
final class LanguagePackControllerProvider
    extends $AsyncNotifierProvider<LanguagePackController, LanguagePack> {
  /// One language's pack, as the chooser shows it - and the download that
  /// brings it, which starts there.
  ///
  /// The download itself is the store's, not this controller's: it outlives
  /// the controller, and a controller built while one is running follows it
  /// instead of offering it again.
  LanguagePackControllerProvider._({
    required LanguagePackControllerFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'languagePackControllerProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$languagePackControllerHash();

  @override
  String toString() {
    return r'languagePackControllerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  LanguagePackController create() => LanguagePackController();

  @override
  bool operator ==(Object other) {
    return other is LanguagePackControllerProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$languagePackControllerHash() =>
    r'1e7d14a27c86214165b5913e84418634f185c3f9';

/// One language's pack, as the chooser shows it - and the download that
/// brings it, which starts there.
///
/// The download itself is the store's, not this controller's: it outlives
/// the controller, and a controller built while one is running follows it
/// instead of offering it again.

final class LanguagePackControllerFamily extends $Family
    with
        $ClassFamilyOverride<
          LanguagePackController,
          AsyncValue<LanguagePack>,
          LanguagePack,
          FutureOr<LanguagePack>,
          String
        > {
  LanguagePackControllerFamily._()
    : super(
        retry: null,
        name: r'languagePackControllerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// One language's pack, as the chooser shows it - and the download that
  /// brings it, which starts there.
  ///
  /// The download itself is the store's, not this controller's: it outlives
  /// the controller, and a controller built while one is running follows it
  /// instead of offering it again.

  LanguagePackControllerProvider call(String lang) =>
      LanguagePackControllerProvider._(argument: lang, from: this);

  @override
  String toString() => r'languagePackControllerProvider';
}

/// One language's pack, as the chooser shows it - and the download that
/// brings it, which starts there.
///
/// The download itself is the store's, not this controller's: it outlives
/// the controller, and a controller built while one is running follows it
/// instead of offering it again.

abstract class _$LanguagePackController extends $AsyncNotifier<LanguagePack> {
  late final _$args = ref.$arg as String;
  String get lang => _$args;

  FutureOr<LanguagePack> build(String lang);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<LanguagePack>, LanguagePack>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<LanguagePack>, LanguagePack>,
              AsyncValue<LanguagePack>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}
