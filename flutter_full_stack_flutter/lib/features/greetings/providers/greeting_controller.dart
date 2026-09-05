import 'dart:async';

import 'package:flutter_full_stack_client/flutter_full_stack_client.dart';
import 'package:flutter_full_stack_flutter/core/providers/serverpod_client.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'greeting_controller.g.dart';

@riverpod
class GreetingController extends _$GreetingController {
  @override
  FutureOr<Greeting?> build() => null;

  Future<void> sayHello(String name) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final client = await ref.read(serverpodClientProvider.future);
      return await client.greeting.hello(name);
    });
  }
}
