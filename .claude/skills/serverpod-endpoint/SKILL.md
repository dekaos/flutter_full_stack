---
name: serverpod-endpoint
description: Add or change a Serverpod endpoint, model, or the Flutter screen that calls it, end to end across the server, generated client and app. Use whenever work touches a .spy.yaml model, an *_endpoint.dart class, a Riverpod controller that calls the API, or when someone asks to add an API route, expose data to the app, or wire a new screen to the backend.
---

# Adding or changing a Serverpod endpoint

A change here crosses three packages. Skipping a step leaves the generated
client stale and the app broken in a way the analyzer will not catch.

## Before starting

Containers must be up, or generation and tests fail:

```bash
melos run docker:up
```

## 1. Model

Models live beside their endpoint, in
`flutter_full_stack_server/lib/src/<feature>/<name>.spy.yaml`.

The examples follow one illustrative feature, `Order`, which is not in the
repo — the endpoints it has today are the sign-in ones in `lib/src/auth/`.

```yaml
### An order placed from the app.
class: Order
# table: order           # ONLY if this is persisted — see step 4
fields:
  ### What was ordered.
  item: String
  ### Optional field.
  note: String?
```

- `### ` comments become dartdoc on the generated class.
- A `?` suffix makes the field nullable.
- Adding `table:` turns this into a database table and **requires a migration**.

### The filename must end in `.spy.yaml`

This is the trap in this step, because failure is silent:

| Extension | Where the generator looks |
|---|---|
| `.spy.yaml`, `.spy.yml`, `.spy` | anywhere under `lib/` |
| plain `.yaml`, `.yml` | **only** `lib/src/models/` or `lib/src/protocol/` |

Save a perfectly valid model as `order.yaml` under `lib/src/orders/` and nothing
happens: `serverpod generate` exits `0`, prints `✅ Done.`, emits no warning, and
the class exists in neither package. The first sign is a compile error somewhere
unrelated. The `.spy` marker is what lifts the directory restriction — always
use it.

### Pick the folder now, not later

The model's folder is mirrored into both generated packages:

```
lib/src/orders/order.spy.yaml
  ├─→ server/lib/src/generated/orders/order.dart
  └─→ client/lib/src/protocol/orders/order.dart
```

Moving the `.spy.yaml` afterwards therefore renames generated files in two
packages and breaks every import of them.

Group by domain, and keep the endpoint in the same folder. Never split by
whether a model is persisted — a domain usually needs both kinds side by side:

```
lib/src/orders/
├── order.spy.yaml            # table: order
├── order_item.spy.yaml       # table: order_item
├── order_summary.spy.yaml    # response DTO, no table
└── order_endpoint.dart
```

## 2. Endpoint

`flutter_full_stack_server/lib/src/<feature>/<feature>_endpoint.dart`:

```dart
import 'package:flutter_full_stack_server/src/generated/protocol.dart';
import 'package:serverpod/serverpod.dart';

class OrderEndpoint extends Endpoint {
  Future<Order> place(Session session, String item) async {
    return Order(item: item);
  }
}
```

Rules:

- Class name **must** end in `Endpoint`. The rest, lower-camel-cased, becomes
  the client accessor: `EmailIdpEndpoint` → `client.emailIdp`, and the
  example above → `client.order.place(...)`.
- First parameter is always `Session`. Parameters and return types must be
  serializable — a generated model, a primitive, or a `List`/`Map` of those.
- Use `session.log(...)` for logging, never `print`.
- Use package imports (`package:flutter_full_stack_server/...`), not relative
  ones — `always_use_package_imports` is enforced.

## 3. Generate

```bash
melos run generate
```

Never run `serverpod generate` directly: it emits code that `dart format`
rejects, and the Melos script formats afterwards. This step rewrites
`lib/src/generated/**`, the whole `flutter_full_stack_client` protocol, and
`serverpod_test_tools.dart`. Do not hand-edit any of them.

## 4. Migration — only if the model has `table:`

```bash
cd flutter_full_stack_server && serverpod create-migration
```

Then restart the server, which applies it:

```bash
melos run server:start
```

Commit the whole new folder under `migrations/` together with the model change.
See the `serverpod-migration` skill when a migration fails or needs repairing.

## 5. Call it from the app

Controller — `flutter_full_stack_flutter/lib/features/<feature>/providers/`:

```dart
@riverpod
class OrderController extends _$OrderController {
  @override
  FutureOr<Order?> build() => null;

  Future<void> place(String item) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final client = await ref.read(serverpodClientProvider.future);
      return client.order.place(item);
    });
  }
}
```

It is the first controller in the app to read `serverpodClientProvider`: the
provider is there and wired, and nothing reads it yet.

- Providers are always `@riverpod`-generated; never declare a `Provider` by
  hand.
- Wrap async work in `AsyncValue.guard` — no manual `isLoading`/`error` fields.
- Screens go under `.../presentation/` and read state with `ref.watch`.
- A new route is registered in `flutter_full_stack_flutter/lib/app/router.dart`.

If you added a provider or route, run `melos run generate` again for the
`*.g.dart` files.

## 6. Test and verify

An integration test in `flutter_full_stack_server/test/integration/`, beside
the generated `test_tools/`. It imports `package:test` and
`test_tools/serverpod_test_tools.dart`, which declares `withServerpod`:

```dart
void main() {
  withServerpod('Given Order endpoint', (sessionBuilder, endpoints) {
    test('when placing an order then it carries the item', () async {
      final order = await endpoints.order.place(sessionBuilder, 'coffee');
      expect(order.item, 'coffee');
    });
  });
}
```

And a widget test in `flutter_full_stack_flutter/test/` for the screen.

For a flow that must never break, add an end-to-end test in
`flutter_full_stack_flutter/integration_test/`, which drives the real app on a
device against a running server — the one layer that catches a stale
generated client or a missing migration. Keep that suite small — it needs a
live backend and a real device; the `flutter-testing` skill has how it runs:

```bash
melos run e2e:packs                                        # once
MODELS_DIR=$PWD/build/e2e_packs melos run server:start     # one terminal
melos run test:e2e                                         # another
```

Then the gate:

```bash
melos run check
```

## Checklist

- [ ] Model filename ends in `.spy.yaml`, in the same domain folder as the
      endpoint
- [ ] `melos run generate` run, generated files never hand-edited
- [ ] The generated class actually appeared in **both** packages — the generator
      reports success even when it silently skipped the model file
- [ ] Migration created and committed, if a `table:` was touched
- [ ] Controller uses `@riverpod` + `AsyncValue.guard`
- [ ] Integration test covering the new endpoint
- [ ] `melos run check` green
