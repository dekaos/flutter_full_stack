---
name: flutter-screen
description: Add or change a screen in the Flutter app - its widget, its Riverpod controller and its go_router route. Use when work touches lib/features/**, lib/app/router.dart, a @riverpod provider, a ConsumerWidget, or when someone asks to add a page, wire state to the UI, navigate between screens, or show loading and error states.
---

# Adding or changing a screen

The app is `flutter_full_stack_flutter`. Riverpod and go_router are both
code-generated, so most mistakes here surface as a missing `*.g.dart` symbol
rather than as a useful error.

For the server side of a new feature — model, endpoint, migration — use the
`serverpod-endpoint` skill first. This skill starts where the generated client
already has the method you need. For tests, see `flutter-testing`.

## Where things go

```
lib/
├── app/
│   ├── app.dart                     MaterialApp.router, theme
│   └── router.dart                  every route, @riverpod GoRouter
├── core/providers/
│   └── serverpod_client.dart        the API client, keepAlive
└── features/<feature>/
    ├── presentation/                screens and widgets
    └── providers/                   controllers
```

One folder per feature, always both subfolders. Do not add a `models/` folder
here: the API types are generated into `flutter_full_stack_client` and are
imported from there.

## 1. Controller

`lib/features/<feature>/providers/<name>_controller.dart`:

```dart
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
      return client.greeting.hello(name);
    });
  }
}
```

Four things that are not optional:

- **`part '<this file>.g.dart';`** — the name must match the file exactly, or
  generation fails with an error pointing at the wrong place.
- **The client is async.** `serverpodClientProvider` resolves the server URL and
  initialises auth before it yields, so it is a `Future`. Always
  `await ref.read(serverpodClientProvider.future)`; `ref.read(serverpodClientProvider)`
  hands you an `AsyncValue`, not a `Client`.
- **`AsyncValue.guard`** carries the error into the state instead of throwing
  into the void. Never hand-roll `isLoading` / `errorMessage` fields.
- **Never write a `Provider` by hand.** Everything is `@riverpod`.

The generated provider name is the class name lower-camel-cased plus `Provider`:
`GreetingController` → `greetingControllerProvider`.

### keepAlive

Plain `@riverpod` disposes the provider when the last widget stops listening.
Use `@Riverpod(keepAlive: true)` only for things that must survive that — the
client and the router do, because rebuilding either would drop the auth session
or the navigation stack. A screen's controller normally should not.

## 2. Screen

`lib/features/<feature>/presentation/<name>_screen.dart`. Use `ConsumerWidget`,
or `ConsumerStatefulWidget` when the screen owns a `TextEditingController` or
similar disposable:

```dart
class GreetingsScreen extends ConsumerWidget {
  const GreetingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(greetingControllerProvider);
    // ...
  }
}
```

- `ref.watch` in `build`, to rebuild on change.
- `ref.read` in callbacks — `ref.watch` in an `onPressed` leaks a subscription.

**The provider gives you the state; `.notifier` gives you the controller.**
Reading it without `.notifier` yields an `AsyncValue`, which has no `sayHello`,
so the mistake shows up as a confusing member-not-found on a type you did not
expect. Calling the method also returns a `Future` nobody awaits, and
`unawaited_futures` is on, so:

```dart
final state = ref.watch(greetingControllerProvider);           // AsyncValue<Greeting?>
unawaited(
  ref.read(greetingControllerProvider.notifier).sayHello(name), // the controller
);
```

### Rendering the three states

Match on the `AsyncValue` rather than testing booleans. The `_` case is the
initial `AsyncData(null)`:

```dart
final (text, background) = switch (state) {
  AsyncError(:final error) => ('$error', colors.errorContainer),
  AsyncData(:final value) when value != null => (value.toString(), colors.primaryContainer),
  AsyncLoading() => ('Calling server...', colors.surfaceContainerHighest),
  _ => ('No server response yet.', colors.surfaceContainerHighest),
};
```

Order matters: `AsyncLoading` after `AsyncData` reads better, but a bare
`AsyncData()` before the `when` clause would swallow the null case.

Take colours from `Theme.of(context).colorScheme`, never literals — the app
ships a light and a dark theme built from one seed in `app.dart`, and hardcoded
colours break one of them.

## 3. Route

Every route lives in `lib/app/router.dart`:

```dart
@Riverpod(keepAlive: true)
GoRouter router(Ref ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        name: 'home',
        builder: (context, state) => const GreetingsScreen(),
      ),
    ],
  );
}
```

Give every route a `name` and navigate with `context.goNamed('home')`, so a path
change does not mean hunting for string literals. `go` replaces the stack,
`push` stacks on top.

## 4. Generate

```bash
melos run generate
```

Never run `build_runner` directly: the generators emit code that `dart format`
rejects, and the Melos script formats afterwards, which is what CI checks. The
`--delete-conflicting-outputs` flag current build_runner prints a warning about
is already handled by the script — do not add it back.

Anything that adds or renames a `@riverpod` provider needs this before the code
will compile.

## 5. Check

```bash
melos run check
```

`analyze` runs with `--fatal-infos`, so an info-level lint fails CI exactly like
an error. The two that catch people here are `unawaited_futures` and
`always_use_package_imports` — inside `lib/`, import your own files as
`package:flutter_full_stack_flutter/...`, never `../`.

## Checklist

- [ ] Controller is `@riverpod`, with a matching `part '<file>.g.dart';`
- [ ] Client obtained with `await ref.read(serverpodClientProvider.future)`
- [ ] Async work wrapped in `AsyncValue.guard`, no hand-rolled loading flags
- [ ] `ref.watch` in `build`, `ref.read` in callbacks, `unawaited(...)` on
      fire-and-forget calls
- [ ] Loading, error and empty states all rendered
- [ ] Colours from `colorScheme`, verified in both light and dark
- [ ] Route registered in `lib/app/router.dart` with a `name`
- [ ] `melos run generate` run after touching any annotation
- [ ] Widget test added — see `flutter-testing`
- [ ] `melos run check` green
