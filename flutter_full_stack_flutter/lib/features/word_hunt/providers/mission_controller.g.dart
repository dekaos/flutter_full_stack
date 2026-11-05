// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'mission_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Where a mission's luck comes from: which words, in which order, among
/// which decoys. Overridden in tests with a seeded one.

@ProviderFor(missionRandom)
final missionRandomProvider = MissionRandomProvider._();

/// Where a mission's luck comes from: which words, in which order, among
/// which decoys. Overridden in tests with a seeded one.

final class MissionRandomProvider
    extends $FunctionalProvider<math.Random, math.Random, math.Random>
    with $Provider<math.Random> {
  /// Where a mission's luck comes from: which words, in which order, among
  /// which decoys. Overridden in tests with a seeded one.
  MissionRandomProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'missionRandomProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$missionRandomHash();

  @$internal
  @override
  $ProviderElement<math.Random> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  math.Random create(Ref ref) {
    return missionRandom(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(math.Random value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<math.Random>(value),
    );
  }
}

String _$missionRandomHash() => r'80df82162fe58390d999fadb0b309aff86df7c6f';

/// One mission on one deck, from its countdown to its results: which word is
/// asked for, which ships fly, what each shot is worth, and when the next
/// thing happens.
///
/// The ships, their lasers and explosions are only drawn by the screen; what
/// a shot *means* is decided here, once, when it lands ([shoot]). That is
/// what the web version got wrong in several ways at once: there, a hit
/// scored, and then for most of a second the word was still the one just
/// found, and the game - seeing no ship carry it - sent another, which could
/// be shot for the same points again. Here a round takes one answer, a
/// shot at a round that is over or at a ship already missed counts for
/// nothing, and the next word is chosen only once its predecessor is done.
///
/// Every clock - the countdown, a word's time, the pause before the next -
/// is one timer at a time, so pausing holds all of them, and disposing the
/// mission (leaving the screen) stops all of them.

@ProviderFor(MissionController)
final missionControllerProvider = MissionControllerFamily._();

/// One mission on one deck, from its countdown to its results: which word is
/// asked for, which ships fly, what each shot is worth, and when the next
/// thing happens.
///
/// The ships, their lasers and explosions are only drawn by the screen; what
/// a shot *means* is decided here, once, when it lands ([shoot]). That is
/// what the web version got wrong in several ways at once: there, a hit
/// scored, and then for most of a second the word was still the one just
/// found, and the game - seeing no ship carry it - sent another, which could
/// be shot for the same points again. Here a round takes one answer, a
/// shot at a round that is over or at a ship already missed counts for
/// nothing, and the next word is chosen only once its predecessor is done.
///
/// Every clock - the countdown, a word's time, the pause before the next -
/// is one timer at a time, so pausing holds all of them, and disposing the
/// mission (leaving the screen) stops all of them.
final class MissionControllerProvider
    extends $NotifierProvider<MissionController, MissionState> {
  /// One mission on one deck, from its countdown to its results: which word is
  /// asked for, which ships fly, what each shot is worth, and when the next
  /// thing happens.
  ///
  /// The ships, their lasers and explosions are only drawn by the screen; what
  /// a shot *means* is decided here, once, when it lands ([shoot]). That is
  /// what the web version got wrong in several ways at once: there, a hit
  /// scored, and then for most of a second the word was still the one just
  /// found, and the game - seeing no ship carry it - sent another, which could
  /// be shot for the same points again. Here a round takes one answer, a
  /// shot at a round that is over or at a ship already missed counts for
  /// nothing, and the next word is chosen only once its predecessor is done.
  ///
  /// Every clock - the countdown, a word's time, the pause before the next -
  /// is one timer at a time, so pausing holds all of them, and disposing the
  /// mission (leaving the screen) stops all of them.
  MissionControllerProvider._({
    required MissionControllerFamily super.from,
    required WordDeck super.argument,
  }) : super(
         retry: null,
         name: r'missionControllerProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$missionControllerHash();

  @override
  String toString() {
    return r'missionControllerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  MissionController create() => MissionController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MissionState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MissionState>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is MissionControllerProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$missionControllerHash() => r'fbb1ef618387e10dd16a18f8d03afc5b71e81c48';

/// One mission on one deck, from its countdown to its results: which word is
/// asked for, which ships fly, what each shot is worth, and when the next
/// thing happens.
///
/// The ships, their lasers and explosions are only drawn by the screen; what
/// a shot *means* is decided here, once, when it lands ([shoot]). That is
/// what the web version got wrong in several ways at once: there, a hit
/// scored, and then for most of a second the word was still the one just
/// found, and the game - seeing no ship carry it - sent another, which could
/// be shot for the same points again. Here a round takes one answer, a
/// shot at a round that is over or at a ship already missed counts for
/// nothing, and the next word is chosen only once its predecessor is done.
///
/// Every clock - the countdown, a word's time, the pause before the next -
/// is one timer at a time, so pausing holds all of them, and disposing the
/// mission (leaving the screen) stops all of them.

final class MissionControllerFamily extends $Family
    with
        $ClassFamilyOverride<
          MissionController,
          MissionState,
          MissionState,
          MissionState,
          WordDeck
        > {
  MissionControllerFamily._()
    : super(
        retry: null,
        name: r'missionControllerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// One mission on one deck, from its countdown to its results: which word is
  /// asked for, which ships fly, what each shot is worth, and when the next
  /// thing happens.
  ///
  /// The ships, their lasers and explosions are only drawn by the screen; what
  /// a shot *means* is decided here, once, when it lands ([shoot]). That is
  /// what the web version got wrong in several ways at once: there, a hit
  /// scored, and then for most of a second the word was still the one just
  /// found, and the game - seeing no ship carry it - sent another, which could
  /// be shot for the same points again. Here a round takes one answer, a
  /// shot at a round that is over or at a ship already missed counts for
  /// nothing, and the next word is chosen only once its predecessor is done.
  ///
  /// Every clock - the countdown, a word's time, the pause before the next -
  /// is one timer at a time, so pausing holds all of them, and disposing the
  /// mission (leaving the screen) stops all of them.

  MissionControllerProvider call(WordDeck deck) =>
      MissionControllerProvider._(argument: deck, from: this);

  @override
  String toString() => r'missionControllerProvider';
}

/// One mission on one deck, from its countdown to its results: which word is
/// asked for, which ships fly, what each shot is worth, and when the next
/// thing happens.
///
/// The ships, their lasers and explosions are only drawn by the screen; what
/// a shot *means* is decided here, once, when it lands ([shoot]). That is
/// what the web version got wrong in several ways at once: there, a hit
/// scored, and then for most of a second the word was still the one just
/// found, and the game - seeing no ship carry it - sent another, which could
/// be shot for the same points again. Here a round takes one answer, a
/// shot at a round that is over or at a ship already missed counts for
/// nothing, and the next word is chosen only once its predecessor is done.
///
/// Every clock - the countdown, a word's time, the pause before the next -
/// is one timer at a time, so pausing holds all of them, and disposing the
/// mission (leaving the screen) stops all of them.

abstract class _$MissionController extends $Notifier<MissionState> {
  late final _$args = ref.$arg as WordDeck;
  WordDeck get deck => _$args;

  MissionState build(WordDeck deck);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<MissionState, MissionState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<MissionState, MissionState>,
              MissionState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}
