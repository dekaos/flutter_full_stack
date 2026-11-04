// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'practice_audio.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Everything practice plays, for as long as the app runs: the sounds are
/// made once, and the platform's players are not worth setting up again
/// for every visit. Overridden in tests, which have no speakers.

@ProviderFor(soundBoard)
final soundBoardProvider = SoundBoardProvider._();

/// Everything practice plays, for as long as the app runs: the sounds are
/// made once, and the platform's players are not worth setting up again
/// for every visit. Overridden in tests, which have no speakers.

final class SoundBoardProvider
    extends $FunctionalProvider<SoundBoard, SoundBoard, SoundBoard>
    with $Provider<SoundBoard> {
  /// Everything practice plays, for as long as the app runs: the sounds are
  /// made once, and the platform's players are not worth setting up again
  /// for every visit. Overridden in tests, which have no speakers.
  SoundBoardProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'soundBoardProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$soundBoardHash();

  @$internal
  @override
  $ProviderElement<SoundBoard> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SoundBoard create(Ref ref) {
    return soundBoard(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SoundBoard value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SoundBoard>(value),
    );
  }
}

String _$soundBoardHash() => r'c0160d6fb2f478998eebd318981924bf3e9e83b9';

/// Whether the scenes, the cat and the score make their sounds. The voice
/// reading a prompt aloud is not one of them: the learner asks for that,
/// and it is part of the lesson.
///
/// On to begin with, and not persisted - like the theme and the language,
/// for the same reason: that needs a storage dependency nothing here has
/// yet. Restarting the app turns the sounds back on.

@ProviderFor(SoundEffects)
final soundEffectsProvider = SoundEffectsProvider._();

/// Whether the scenes, the cat and the score make their sounds. The voice
/// reading a prompt aloud is not one of them: the learner asks for that,
/// and it is part of the lesson.
///
/// On to begin with, and not persisted - like the theme and the language,
/// for the same reason: that needs a storage dependency nothing here has
/// yet. Restarting the app turns the sounds back on.
final class SoundEffectsProvider extends $NotifierProvider<SoundEffects, bool> {
  /// Whether the scenes, the cat and the score make their sounds. The voice
  /// reading a prompt aloud is not one of them: the learner asks for that,
  /// and it is part of the lesson.
  ///
  /// On to begin with, and not persisted - like the theme and the language,
  /// for the same reason: that needs a storage dependency nothing here has
  /// yet. Restarting the app turns the sounds back on.
  SoundEffectsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'soundEffectsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$soundEffectsHash();

  @$internal
  @override
  SoundEffects create() => SoundEffects();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$soundEffectsHash() => r'2751f9e8813f660fcd1ff9b00fb77032fa9e80e1';

/// Whether the scenes, the cat and the score make their sounds. The voice
/// reading a prompt aloud is not one of them: the learner asks for that,
/// and it is part of the lesson.
///
/// On to begin with, and not persisted - like the theme and the language,
/// for the same reason: that needs a storage dependency nothing here has
/// yet. Restarting the app turns the sounds back on.

abstract class _$SoundEffects extends $Notifier<bool> {
  bool build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<bool, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<bool, bool>,
              bool,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Whether this device has a voice to read [lang]'s prompts in, in the
/// accent they are scored against.

@ProviderFor(phraseVoiceAvailable)
final phraseVoiceAvailableProvider = PhraseVoiceAvailableFamily._();

/// Whether this device has a voice to read [lang]'s prompts in, in the
/// accent they are scored against.

final class PhraseVoiceAvailableProvider
    extends $FunctionalProvider<AsyncValue<bool>, bool, FutureOr<bool>>
    with $FutureModifier<bool>, $FutureProvider<bool> {
  /// Whether this device has a voice to read [lang]'s prompts in, in the
  /// accent they are scored against.
  PhraseVoiceAvailableProvider._({
    required PhraseVoiceAvailableFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'phraseVoiceAvailableProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$phraseVoiceAvailableHash();

  @override
  String toString() {
    return r'phraseVoiceAvailableProvider'
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
    return phraseVoiceAvailable(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is PhraseVoiceAvailableProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$phraseVoiceAvailableHash() =>
    r'b82cf2763358dc5efe18c3496825b5f2b36aa4f8';

/// Whether this device has a voice to read [lang]'s prompts in, in the
/// accent they are scored against.

final class PhraseVoiceAvailableFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<bool>, String> {
  PhraseVoiceAvailableFamily._()
    : super(
        retry: null,
        name: r'phraseVoiceAvailableProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Whether this device has a voice to read [lang]'s prompts in, in the
  /// accent they are scored against.

  PhraseVoiceAvailableProvider call(String lang) =>
      PhraseVoiceAvailableProvider._(argument: lang, from: this);

  @override
  String toString() => r'phraseVoiceAvailableProvider';
}
