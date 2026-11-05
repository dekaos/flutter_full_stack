// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'hunt_records.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The one store for the app's lifetime. Overridden in tests with one in a
/// temporary folder.

@ProviderFor(huntRecordStore)
final huntRecordStoreProvider = HuntRecordStoreProvider._();

/// The one store for the app's lifetime. Overridden in tests with one in a
/// temporary folder.

final class HuntRecordStoreProvider
    extends
        $FunctionalProvider<HuntRecordStore, HuntRecordStore, HuntRecordStore>
    with $Provider<HuntRecordStore> {
  /// The one store for the app's lifetime. Overridden in tests with one in a
  /// temporary folder.
  HuntRecordStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'huntRecordStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$huntRecordStoreHash();

  @$internal
  @override
  $ProviderElement<HuntRecordStore> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  HuntRecordStore create(Ref ref) {
    return huntRecordStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(HuntRecordStore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<HuntRecordStore>(value),
    );
  }
}

String _$huntRecordStoreHash() => r'f26fc39617ac3aa258311cb9841989a703ac83a8';

/// Every deck's best, as far as this device knows.

@ProviderFor(HuntRecords)
final huntRecordsProvider = HuntRecordsProvider._();

/// Every deck's best, as far as this device knows.
final class HuntRecordsProvider
    extends $AsyncNotifierProvider<HuntRecords, Map<WordDeck, DeckRecord>> {
  /// Every deck's best, as far as this device knows.
  HuntRecordsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'huntRecordsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$huntRecordsHash();

  @$internal
  @override
  HuntRecords create() => HuntRecords();
}

String _$huntRecordsHash() => r'd6b7395c5a15662df6d104e66e99fff69c0457d5';

/// Every deck's best, as far as this device knows.

abstract class _$HuntRecords extends $AsyncNotifier<Map<WordDeck, DeckRecord>> {
  FutureOr<Map<WordDeck, DeckRecord>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<
              AsyncValue<Map<WordDeck, DeckRecord>>,
              Map<WordDeck, DeckRecord>
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<Map<WordDeck, DeckRecord>>,
                Map<WordDeck, DeckRecord>
              >,
              AsyncValue<Map<WordDeck, DeckRecord>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
