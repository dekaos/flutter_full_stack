import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_full_stack_flutter/core/providers/serverpod_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// No screen calls an endpoint yet, so nothing else builds the client: this
/// is what keeps the wiring the first such screen will read from rotting
/// unseen.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // Restoring the auth session reads the platform's secure storage, which
    // a test does not have: an empty one is a learner who never signed in.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (call) async => null,
        );
  });

  test('the client points at the API the bundle names', () async {
    final config = jsonDecode(
      await rootBundle.loadString('assets/config.json'),
    ) as Map<String, dynamic>;
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final client = await container.read(serverpodClientProvider.future);

    expect(
      Uri.parse(client.host),
      Uri.parse(
        '${(config['apiUrl'] as String).replaceAll(RegExp(r'/$'), '')}/',
      ),
    );
  });

  test('the client outlives every screen that reads it', () async {
    // Rebuilt, it would drop the signed-in session and look the URL up again.
    expect(serverpodClientProvider.isAutoDispose, isFalse);

    final container = ProviderContainer();
    addTearDown(container.dispose);
    final first = await container.read(serverpodClientProvider.future);
    await container.pump();
    expect(await container.read(serverpodClientProvider.future), same(first));
  });
}
