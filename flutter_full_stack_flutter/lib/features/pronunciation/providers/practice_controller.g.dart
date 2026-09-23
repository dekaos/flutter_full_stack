// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'practice_controller.dart';

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

/// The microphone, for as long as the app is running.
///
/// Deliberately not auto-disposed. `AudioRecorder` wraps a native recorder,
/// and an auto-disposed provider is torn down the moment the `ref.read` that
/// created it returns - so `start()` would be called on a recorder the
/// platform side had already released, which surfaces as "Recorder has not
/// yet been created or has already been disposed".

@ProviderFor(attemptRecorder)
final attemptRecorderProvider = AttemptRecorderProvider._();

/// The microphone, for as long as the app is running.
///
/// Deliberately not auto-disposed. `AudioRecorder` wraps a native recorder,
/// and an auto-disposed provider is torn down the moment the `ref.read` that
/// created it returns - so `start()` would be called on a recorder the
/// platform side had already released, which surfaces as "Recorder has not
/// yet been created or has already been disposed".

final class AttemptRecorderProvider
    extends
        $FunctionalProvider<AttemptRecorder, AttemptRecorder, AttemptRecorder>
    with $Provider<AttemptRecorder> {
  /// The microphone, for as long as the app is running.
  ///
  /// Deliberately not auto-disposed. `AudioRecorder` wraps a native recorder,
  /// and an auto-disposed provider is torn down the moment the `ref.read` that
  /// created it returns - so `start()` would be called on a recorder the
  /// platform side had already released, which surfaces as "Recorder has not
  /// yet been created or has already been disposed".
  AttemptRecorderProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'attemptRecorderProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$attemptRecorderHash();

  @$internal
  @override
  $ProviderElement<AttemptRecorder> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AttemptRecorder create(Ref ref) {
    return attemptRecorder(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AttemptRecorder value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AttemptRecorder>(value),
    );
  }
}

String _$attemptRecorderHash() => r'84e8fcfe677c68652da629e788f38695d950059b';

/// Opens the acoustic model at a path. Overridden in tests, which must never
/// load 355 MB of weights.

@ProviderFor(phonemeModelLoader)
final phonemeModelLoaderProvider = PhonemeModelLoaderProvider._();

/// Opens the acoustic model at a path. Overridden in tests, which must never
/// load 355 MB of weights.

final class PhonemeModelLoaderProvider
    extends
        $FunctionalProvider<
          Future<PhonemeAcousticModel> Function(String path),
          Future<PhonemeAcousticModel> Function(String path),
          Future<PhonemeAcousticModel> Function(String path)
        >
    with $Provider<Future<PhonemeAcousticModel> Function(String path)> {
  /// Opens the acoustic model at a path. Overridden in tests, which must never
  /// load 355 MB of weights.
  PhonemeModelLoaderProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'phonemeModelLoaderProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$phonemeModelLoaderHash();

  @$internal
  @override
  $ProviderElement<Future<PhonemeAcousticModel> Function(String path)>
  $createElement($ProviderPointer pointer) => $ProviderElement(pointer);

  @override
  Future<PhonemeAcousticModel> Function(String path) create(Ref ref) {
    return phonemeModelLoader(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(
    Future<PhonemeAcousticModel> Function(String path) value,
  ) {
    return $ProviderOverride(
      origin: this,
      providerOverride:
          $SyncValueProvider<
            Future<PhonemeAcousticModel> Function(String path)
          >(value),
    );
  }
}

String _$phonemeModelLoaderHash() =>
    r'a2786aa3ffd8c0cfc38cc31e686e5d5a919d3bd1';

/// Whether a language's pack is already on the device.
///
/// Auto-disposed on purpose: it is read by the chooser, which has to see the
/// pack appear after a download without the app being restarted.
/// Auto-disposal alone is not enough, because the chooser stays mounted under
/// the practice route and so never lets go of this. It is invalidated instead
/// whenever a pack lands or leaves - including a download that finished after
/// the learner walked away from it.

@ProviderFor(packDownloaded)
final packDownloadedProvider = PackDownloadedFamily._();

/// Whether a language's pack is already on the device.
///
/// Auto-disposed on purpose: it is read by the chooser, which has to see the
/// pack appear after a download without the app being restarted.
/// Auto-disposal alone is not enough, because the chooser stays mounted under
/// the practice route and so never lets go of this. It is invalidated instead
/// whenever a pack lands or leaves - including a download that finished after
/// the learner walked away from it.

final class PackDownloadedProvider
    extends $FunctionalProvider<AsyncValue<bool>, bool, FutureOr<bool>>
    with $FutureModifier<bool>, $FutureProvider<bool> {
  /// Whether a language's pack is already on the device.
  ///
  /// Auto-disposed on purpose: it is read by the chooser, which has to see the
  /// pack appear after a download without the app being restarted.
  /// Auto-disposal alone is not enough, because the chooser stays mounted under
  /// the practice route and so never lets go of this. It is invalidated instead
  /// whenever a pack lands or leaves - including a download that finished after
  /// the learner walked away from it.
  PackDownloadedProvider._({
    required PackDownloadedFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'packDownloadedProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$packDownloadedHash();

  @override
  String toString() {
    return r'packDownloadedProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<bool> create(Ref ref) {
    final argument = this.argument as String;
    return packDownloaded(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is PackDownloadedProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$packDownloadedHash() => r'10555e3b9ac0474affd57541ae3eb7ffb82cc7b7';

/// Whether a language's pack is already on the device.
///
/// Auto-disposed on purpose: it is read by the chooser, which has to see the
/// pack appear after a download without the app being restarted.
/// Auto-disposal alone is not enough, because the chooser stays mounted under
/// the practice route and so never lets go of this. It is invalidated instead
/// whenever a pack lands or leaves - including a download that finished after
/// the learner walked away from it.

final class PackDownloadedFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<bool>, String> {
  PackDownloadedFamily._()
    : super(
        retry: null,
        name: r'packDownloadedProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Whether a language's pack is already on the device.
  ///
  /// Auto-disposed on purpose: it is read by the chooser, which has to see the
  /// pack appear after a download without the app being restarted.
  /// Auto-disposal alone is not enough, because the chooser stays mounted under
  /// the practice route and so never lets go of this. It is invalidated instead
  /// whenever a pack lands or leaves - including a download that finished after
  /// the learner walked away from it.

  PackDownloadedProvider call(String lang) =>
      PackDownloadedProvider._(argument: lang, from: this);

  @override
  String toString() => r'packDownloadedProvider';
}

/// Drives read-aloud practice for one language.
///
/// Everything here happens on the device. The one thing that reaches the
/// network is the first download of the language pack, and only because a
/// 355 MB model cannot ship inside the app.

@ProviderFor(PracticeController)
final practiceControllerProvider = PracticeControllerFamily._();

/// Drives read-aloud practice for one language.
///
/// Everything here happens on the device. The one thing that reaches the
/// network is the first download of the language pack, and only because a
/// 355 MB model cannot ship inside the app.
final class PracticeControllerProvider
    extends $AsyncNotifierProvider<PracticeController, PracticeState> {
  /// Drives read-aloud practice for one language.
  ///
  /// Everything here happens on the device. The one thing that reaches the
  /// network is the first download of the language pack, and only because a
  /// 355 MB model cannot ship inside the app.
  PracticeControllerProvider._({
    required PracticeControllerFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'practiceControllerProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$practiceControllerHash();

  @override
  String toString() {
    return r'practiceControllerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  PracticeController create() => PracticeController();

  @override
  bool operator ==(Object other) {
    return other is PracticeControllerProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$practiceControllerHash() =>
    r'7d4464755343761a24bed9fc963a4a7faf0059ac';

/// Drives read-aloud practice for one language.
///
/// Everything here happens on the device. The one thing that reaches the
/// network is the first download of the language pack, and only because a
/// 355 MB model cannot ship inside the app.

final class PracticeControllerFamily extends $Family
    with
        $ClassFamilyOverride<
          PracticeController,
          AsyncValue<PracticeState>,
          PracticeState,
          FutureOr<PracticeState>,
          String
        > {
  PracticeControllerFamily._()
    : super(
        retry: null,
        name: r'practiceControllerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Drives read-aloud practice for one language.
  ///
  /// Everything here happens on the device. The one thing that reaches the
  /// network is the first download of the language pack, and only because a
  /// 355 MB model cannot ship inside the app.

  PracticeControllerProvider call(String lang) =>
      PracticeControllerProvider._(argument: lang, from: this);

  @override
  String toString() => r'practiceControllerProvider';
}

/// Drives read-aloud practice for one language.
///
/// Everything here happens on the device. The one thing that reaches the
/// network is the first download of the language pack, and only because a
/// 355 MB model cannot ship inside the app.

abstract class _$PracticeController extends $AsyncNotifier<PracticeState> {
  late final _$args = ref.$arg as String;
  String get lang => _$args;

  FutureOr<PracticeState> build(String lang);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<PracticeState>, PracticeState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<PracticeState>, PracticeState>,
              AsyncValue<PracticeState>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}
