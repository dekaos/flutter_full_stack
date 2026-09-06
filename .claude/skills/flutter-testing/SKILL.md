---
name: flutter-testing
description: Write or run tests for the Flutter app - widget tests with Riverpod provider overrides, and the end-to-end suite that drives the real app against a running server. Use when adding a test under flutter_full_stack_flutter/test or integration_test, when a widget test needs to avoid hitting the network, or when melos run test:e2e fails to find a device or reach the backend.
---

# Testing the Flutter app

Two suites, with very different costs:

| Suite | Where | Needs | In `melos run check`? |
|---|---|---|---|
| Widget tests | `test/` | nothing | yes |
| End-to-end | `integration_test/` | running server + a device | no |

Write widget tests by default. Add to the end-to-end suite only for a flow that
must never break, because it is the only layer that catches a stale generated
client, a missing migration or a changed serialization.

```bash
melos run test            # both packages' unit and widget tests
melos run check           # format + analyze + test, the CI gate
```

## Widget tests

A screen reads state from a controller, so a test drives the screen by
overriding that controller — not by faking the network.

### Do not try to fake the client

`serverpodClientProvider` yields a generated `Client`, whose endpoints are
`late final` fields:

```dart
class Client extends ServerpodClientShared {
  late final EndpointGreeting greeting;   // a field, not a getter
}
```

A subclass cannot replace a `late final` field, so there is no way to hand the
app a `Client` with a stubbed endpoint. Override the controller instead: it is
the seam the UI actually depends on, and it keeps the test free of the client,
the URL lookup and the auth initialisation.

### The pattern

```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_full_stack_client/flutter_full_stack_client.dart';
import 'package:flutter_full_stack_flutter/features/greetings/presentation/greetings_screen.dart';
import 'package:flutter_full_stack_flutter/features/greetings/providers/greeting_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _StubGreetingController extends GreetingController {
  _StubGreetingController(this.greeting);

  final Greeting? greeting;

  @override
  FutureOr<Greeting?> build() => greeting;
}

void main() {
  testWidgets('renders the greeting returned by the controller', (tester) async {
    final greeting = Greeting(
      message: 'Hello Bob',
      author: 'Serverpod',
      timestamp: DateTime.utc(2026),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          greetingControllerProvider.overrideWith(
            () => _StubGreetingController(greeting),
          ),
        ],
        child: const MaterialApp(home: GreetingsScreen()),
      ),
    );
    await tester.pump();

    expect(find.textContaining('Hello Bob'), findsOneWidget);
  });
}
```

Three details that are easy to get wrong:

- **`overrideWith` on a `@riverpod` class takes a builder**, not an instance:
  `overrideWith(() => _StubGreetingController(greeting))`. Extend the real
  controller and override `build()`.
- **`pumpWidget` alone is not enough.** The state is an `AsyncValue`, which
  resolves a microtask later, so the first frame still shows loading. One
  `await tester.pump()` settles it. Use `pumpAndSettle` only when an animation
  is running — it returns as soon as no frame is scheduled, which is also true
  while a real request is in flight.
- **`ProviderScope` is required**, even with no overrides. Without it any
  `ref.watch` throws.

To assert the error state, have the stub's `build()` throw. To assert loading,
return a `Completer`'s future that the test never completes.

A screen that takes no overrides at all — no controller, no network — needs
nothing but `ProviderScope` and `MaterialApp`, as `test/widget_test.dart` shows.

## End-to-end tests

`integration_test/` runs the real app, through the real generated client,
against a real server and database. It is outside `melos run check` because it
needs a live backend and a device.

```bash
melos run server:start        # one terminal
melos run test:e2e            # another
```

- **The target is an Android emulator or an iOS simulator.** The app has no
  desktop targets, and `integration_test` refuses to run on web. `E2E_DEVICE`
  picks a device id when several are attached; unset, Flutter takes the only
  one it finds.
- **On an Android emulator `localhost` is the emulator itself.** The host is
  `10.0.2.2`, so pass `E2E_SERVER_URL=http://10.0.2.2:8080/`. Cleartext HTTP is
  already permitted in the debug and profile manifests; release still refuses it.
- **It runs against the development database on 8090**, not the test one, so a
  test that writes dirties real dev data. Reset with `melos run docker:down`.
- **`pumpAndSettle` does not wait for a network round trip.** Pump in a loop
  until the finder matches, with a timeout — `integration_test/greeting_flow_test.dart`
  has the helper.

Keep this suite small. Every test here costs a build and a device.

## Checklist

- [ ] Widget test overrides the controller, not the client
- [ ] `ProviderScope` present; `await tester.pump()` after `pumpWidget` when the
      screen reads an `AsyncValue`
- [ ] Loading and error paths covered, not just the happy one
- [ ] End-to-end test added only for a flow that must never break
- [ ] `melos run check` green
