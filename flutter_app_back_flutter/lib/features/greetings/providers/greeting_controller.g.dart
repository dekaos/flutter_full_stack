// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'greeting_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(GreetingController)
final greetingControllerProvider = GreetingControllerProvider._();

final class GreetingControllerProvider
    extends $AsyncNotifierProvider<GreetingController, Greeting?> {
  GreetingControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'greetingControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$greetingControllerHash();

  @$internal
  @override
  GreetingController create() => GreetingController();
}

String _$greetingControllerHash() =>
    r'7f4ec7b1a5eee477fee1c1d5fee54d574762681c';

abstract class _$GreetingController extends $AsyncNotifier<Greeting?> {
  FutureOr<Greeting?> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<Greeting?>, Greeting?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<Greeting?>, Greeting?>,
              AsyncValue<Greeting?>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
