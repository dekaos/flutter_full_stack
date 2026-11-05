// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'practice_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
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

/// The way back from a refused microphone. Overridden in tests, which have no
/// settings screen to open.

@ProviderFor(appSettings)
final appSettingsProvider = AppSettingsProvider._();

/// The way back from a refused microphone. Overridden in tests, which have no
/// settings screen to open.

final class AppSettingsProvider
    extends $FunctionalProvider<AppSettings, AppSettings, AppSettings>
    with $Provider<AppSettings> {
  /// The way back from a refused microphone. Overridden in tests, which have no
  /// settings screen to open.
  AppSettingsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appSettingsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appSettingsHash();

  @$internal
  @override
  $ProviderElement<AppSettings> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AppSettings create(Ref ref) {
    return appSettings(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppSettings value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AppSettings>(value),
    );
  }
}

String _$appSettingsHash() => r'a9ed7b0cf28113656f77712d024b09733a5570d8';

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

/// Drives read-aloud practice for one language.
///
/// Everything here happens on the device, and nothing reaches the network:
/// the language pack is already there when practice opens.

@ProviderFor(PracticeController)
final practiceControllerProvider = PracticeControllerFamily._();

/// Drives read-aloud practice for one language.
///
/// Everything here happens on the device, and nothing reaches the network:
/// the language pack is already there when practice opens.
final class PracticeControllerProvider
    extends $AsyncNotifierProvider<PracticeController, PracticeState> {
  /// Drives read-aloud practice for one language.
  ///
  /// Everything here happens on the device, and nothing reaches the network:
  /// the language pack is already there when practice opens.
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
    r'f64e6b26a4213af40ecba61dc23de22aeb65187f';

/// Drives read-aloud practice for one language.
///
/// Everything here happens on the device, and nothing reaches the network:
/// the language pack is already there when practice opens.

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
  /// Everything here happens on the device, and nothing reaches the network:
  /// the language pack is already there when practice opens.

  PracticeControllerProvider call(String lang) =>
      PracticeControllerProvider._(argument: lang, from: this);

  @override
  String toString() => r'practiceControllerProvider';
}

/// Drives read-aloud practice for one language.
///
/// Everything here happens on the device, and nothing reaches the network:
/// the language pack is already there when practice opens.

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
