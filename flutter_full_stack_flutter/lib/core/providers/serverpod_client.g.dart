// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'serverpod_client.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provides an initialized Serverpod [Client].
///
/// The server URL is resolved from `--dart-define=SERVER_URL=...`,
/// falling back to `assets/config.json` and then to localhost.

@ProviderFor(serverpodClient)
final serverpodClientProvider = ServerpodClientProvider._();

/// Provides an initialized Serverpod [Client].
///
/// The server URL is resolved from `--dart-define=SERVER_URL=...`,
/// falling back to `assets/config.json` and then to localhost.

final class ServerpodClientProvider
    extends $FunctionalProvider<AsyncValue<Client>, Client, FutureOr<Client>>
    with $FutureModifier<Client>, $FutureProvider<Client> {
  /// Provides an initialized Serverpod [Client].
  ///
  /// The server URL is resolved from `--dart-define=SERVER_URL=...`,
  /// falling back to `assets/config.json` and then to localhost.
  ServerpodClientProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'serverpodClientProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$serverpodClientHash();

  @$internal
  @override
  $FutureProviderElement<Client> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<Client> create(Ref ref) {
    return serverpodClient(ref);
  }
}

String _$serverpodClientHash() => r'aae4b8e1235365ef8302296786d84e00635548fa';
