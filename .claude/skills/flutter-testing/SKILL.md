---
name: flutter-testing
description: Write or run tests for the Flutter app - widget tests with Riverpod provider overrides, the end-to-end suite that downloads a language pack from a running server and practises on a device, and the frame-timing suite. Use when adding a test under flutter_full_stack_flutter/test, integration_test or perf, when a widget test needs to avoid the network, the microphone or a platform channel, or when melos run test:e2e fails to find a device or reach the server.
---

# Testing the Flutter app

Two suites, with very different costs:

| Suite | Where | Needs | In `melos run check`? |
|---|---|---|---|
| Widget tests | `test/` | nothing | yes |
| End-to-end | `integration_test/` | running server serving packs + a device | no |
| Frame timings | `perf/` | a device (profile mode on Android) | no |

Write widget tests by default. Add to the end-to-end suite only for a flow that
must never break, because it is the only layer that runs the app on a device
against a real server: today, the language pack's download and practice on it.

```bash
melos run test            # both packages' unit and widget tests
melos run check           # format + analyze + test, the CI gate
```

## Widget tests

A screen reads state from a controller, so a test drives the screen by
overriding that controller — not by faking what is behind it: the network, the
microphone, the 355 MB acoustic model or the speakers.

### Do not try to fake the client

`serverpodClientProvider` yields a generated `Client`, whose endpoints are
`late final` fields:

```dart
class Client extends ServerpodClientShared {
  late final EndpointEmailIdp emailIdp;   // a field, not a getter
}
```

A subclass cannot replace a `late final` field, so there is no way to hand the
app a `Client` with a stubbed endpoint. When a screen calls an endpoint,
override its controller instead: it is the seam the UI actually depends on, and
it keeps the test free of the client, the URL lookup and the auth
initialisation.

### The pattern

`test/support/practice.dart` has `StubPracticeController`, which holds still on
the `PracticeState` it is given and records what the screen asked of it:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_full_stack_flutter/features/pronunciation/presentation/practice_screen.dart';
import 'package:flutter_full_stack_flutter/features/pronunciation/providers/practice_audio.dart';
import 'package:flutter_full_stack_flutter/features/pronunciation/providers/practice_controller.dart';
import 'package:flutter_full_stack_flutter/l10n/app_localizations.dart';
import 'package:flutter_full_stack_flutter/theme/app_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_audio.dart';
import '../../support/practice.dart';

void main() {
  testWidgets('practice opens on its first prompt', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          soundBoardProvider.overrideWithValue(fakeSoundBoard()),
          practiceControllerProvider.overrideWith2(
            (_) => StubPracticeController(),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: const PracticeScreen(lang: 'en'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('hello'), findsOneWidget);
  });
}
```

Details that are easy to get wrong:

- **A family controller is overridden with `overrideWith2`**, which is handed
  the argument, so the stub stands in for every language rather than only the
  one the test opens. A plain `@riverpod` class takes `overrideWith` and a
  builder, not an instance. Either way, extend the real controller and
  override `build()`.
- **Override `soundBoardProvider`.** The real board reaches for the platform's
  audio players and text-to-speech; `fakeSoundBoard()` in
  `test/support/fake_audio.dart` writes down what it was asked to play
  instead.
- **Point `modelStoreProvider` at a real folder** when a test builds the
  chooser or the router: `ModelStore(directory: ...)`. Its default asks a
  platform channel for the app's support folder, which a widget test lacks.
- **`pumpWidget` alone is not enough.** The state is an `AsyncValue`, which
  resolves a microtask later, so the first frame still shows loading. One
  `await tester.pump()` settles it. Use `pumpAndSettle` only when an animation
  is running — it returns as soon as no frame is scheduled, which is also true
  while a real request is in flight.
- **`ProviderScope` is required**, even with no overrides. Without it any
  `ref.watch` throws.
- **So is a theme.** Widgets read design tokens through
  `Theme.of(context).appTokens`, whose generated getter ends in `!`, so
  `MaterialApp(home: ...)` with no `theme:` throws a `_TypeError` while
  building. Pass `theme: AppTheme.light()`.

To assert the error state, have the stub's `build()` throw. To assert loading,
return a `Completer`'s future that the test never completes.

A widget that reads no provider at all needs nothing but `MaterialApp` and a
theme — `test/theme/glass_reveal_test.dart` is one.

## The contrast guard

`test/theme_contrast_test.dart` is not about a widget. It composites the glass
and field fills over the backdrop for all four themes and asserts WCAG AA
against `onSurface`, because a translucent surface has no contrast ratio until
you know what is behind it — so lowering a translucency dial can make text
illegible with nothing else failing.

If it fails, the fix is a token, not the test: raise the fill alpha in
`AppTokens.of`, or lower the dial in `AppTheme`. See
[docs/theming.md](../../../docs/theming.md).

## End-to-end tests

`integration_test/` runs the real app on a device: it downloads a language
pack from a running server's `/models`, which opens practice, then records and
scores an attempt. It is outside `melos run check` because it needs a live
backend and a device.

```bash
melos run e2e:packs                                        # stand-ins, once
MODELS_DIR=$PWD/build/e2e_packs melos run server:start     # one terminal
melos run test:e2e                                         # another
```

What a device in CI cannot provide is stood in for, in
`integration_test/support/on_device.dart`, shared with `perf/`:

- **The packs** are 8 MB stand-ins under the real names, written by
  `tool/e2e_packs.dart`. They cannot match the real digest, so the test's
  `ModelStore` is given a `fingerprint` that vouches for them; the request, the
  `.part`, the rename and the router's guard are all real.
- **The voice** is `ScriptedRecorder`: always permitted, it returns a second
  and a half of something shaped like speech. A real microphone would put a
  system permission dialog in front of the test.
- **The acoustic model** is `ParrotModel`, which hears the prompt being scored
  phoneme for phoneme. The aligner, the scorer and the shipped calibration run
  for real on what it emits, so a perfect reading has to score as one.

- **The target is an Android emulator or an iOS simulator.** The app has no
  desktop targets, and `integration_test` refuses to run on web. `E2E_DEVICE`
  picks a device id when several are attached; unset, Flutter takes the only
  one it finds.
- **On an Android emulator `localhost` is the emulator itself.** Run
  `adb reverse tcp:8082 tcp:8082` before the suite and the default
  `E2E_MODEL_BASE_URL`, `http://localhost:8082/models`, reaches the host. Do not reach for the `10.0.2.2` alias: on current images traffic
  goes over the emulated Wi-Fi stack, where it is not routable, and the symptom
  is a test that builds and runs but never gets a response. Cleartext HTTP is
  already permitted in the debug and profile manifests; release still refuses it.
- **It runs against the development server**, not the test one. The suite
  writes nothing to the database, and its packs land in a temporary folder on
  the device that is deleted when it ends, so every run starts with the pack
  missing.
- **`pumpAndSettle` does not wait for a download, a file stat or a scoring
  pass.** Pump in a loop until the condition holds, with a timeout —
  `pumpUntil` and `pumpUntilFound` in `integration_test/support/on_device.dart`.
- **Only `*_test.dart` files are suites.** `flutter test integration_test`
  collects every one of them, which is why the frame-timing suite lives in
  `perf/` (it needs its driver) and the shared support has no `_test` suffix.

Keep this suite small. Every test here costs a build and a device.

## Frame timings

`perf/frame_timings_test.dart` measures the language chooser and practice as
two summaries in one report, driven by `test_driver/perf_driver.dart`:

```bash
melos run perf            # measure, then gate against the recorded baseline
```

A new screen gets its own `watchPerformance(..., reportKey: '<screen>')` block;
`tool/perf_budget.dart` gates every summary in the report, and fails on a
screen the baseline has and the report has lost. CI also fails on a screen the
baseline has *no entry* for (`--require-baseline`), so a new block means a
second step after its first CI run: record that run's `perf-report` artifact
into `tool/perf_baseline.json` with `--update`, as
[docs/performance.md](../../../docs/performance.md) describes. Profile mode
only.

## Checklist

- [ ] Widget test overrides the controller, not the client
- [ ] `ProviderScope` present; `await tester.pump()` after `pumpWidget` when the
      screen reads an `AsyncValue`
- [ ] Loading and error paths covered, not just the happy one
- [ ] End-to-end test added only for a flow that must never break
- [ ] `melos run check` green
