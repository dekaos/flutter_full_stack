# Keeping the app fast as it grows

Three gates, in order of how much you can trust them. None of them tells you
the app is fast; all three tell you whether *this change* made it slower than
the last one, which is the question that actually decays over time.

The premise is worth stating plainly, because it shapes every choice below:
**no single feature makes an app slow.** Each one adds a millisecond, and after
twenty of them the app is sluggish with no commit to blame. A fixed threshold
catches a cliff and never catches that. What catches it is a recorded number
that someone has to deliberately raise, in a diff another person reads.

## 1. Binary size — the only number with no noise

```bash
melos run size            # build, then gate
melos run size:budget     # record what it found
```

Same source, same bytes, on any machine. A failure here is always real. It
gates the release APK against `tool/size_budget.json` with 5% of headroom,
because a toolchain upgrade moves it a percent or two on its own.

**What it measures is the arm64 APK of a per-ABI split**
(`--split-per-abi --target-platform android-arm64`): what an arm64 phone
installs. Without the split, `--target-platform` narrows only Flutter's own
libraries, and the APK still carries every plugin's native code for x86_64 and
32-bit ARM. That APK measured 78 MB; the arm64 one is 41 MB (38.85 MiB). Of
those, as of the budget recorded with this change:

| | uncompressed in the APK |
|---|---|
| `libonnxruntime.so` — ONNX Runtime, which scores pronunciation | 18.4 MiB |
| `libflutter.so` — the engine | 11.2 MiB |
| `libapp.so` — the app's Dart, compiled | 6.9 MiB |
| everything else: dex, the Inter fonts, resources, licences | ~2.4 MiB |

**The native libraries are stored uncompressed, on purpose.** That is the
Android Gradle Plugin's default: a page-aligned, uncompressed `.so` is loaded
straight from the APK, so nothing is extracted on install and the app takes
less space on the phone. Compressing them
(`packaging.jniLibs.useLegacyPackaging = true`) was measured too: the arm64
APK drops to 17.6 MB, and the phone then keeps both the APK and ~38 MB of
extracted libraries. That is the better trade for an APK handed out directly,
and no gain through the Play Store, which compresses what it downloads. The
three big libraries compress to 6.6, 5.2 and 2.7 MiB.

This gate exists because the app already carries weight you would not guess
from reading it: ONNX Runtime above all, and Inter, bundled in
`assets/fonts/` rather than fetched, which is right for a first run on a bad
connection and is also a permanent addition to every download.

## 2. Coverage — a ratchet, not a target

```bash
melos run coverage        # measure, then gate
melos run coverage:floor  # raise the ratchet
```

The floor is **88.6%**; the suite measures 98.1% over 10,770 hand-written
lines, so the floor has room to be raised. Generated code is excluded:
counting `.g.dart` measures the generators, not this repo.

It only moves up, and only in a commit someone writes. A fixed target of 80%
would be either unreachable and ignored, or already met and therefore blind to
the next feature landing untested.

**It also refuses to run with a blind spot.** A library no test imports never
reaches lcov at all — it is not "0% covered", it is *absent*, and adding it
makes the percentage go **up**. That would defeat the ratchet in exactly the
case it exists for, so any hand-written file missing from lcov fails the gate
by name. `lib/main.dart` is the single exemption: `runApp` is what an
integration test exercises, not a widget test.

## 3. Frame timings — the real question, and the noisiest answer

```bash
melos run perf            # measure, then gate
melos run perf:baseline   # record what it found
```

`perf/frame_timings_test.dart` drives the app through the frames that cost
the most, on its two screens, and `watchPerformance` records one timeline
summary for each:

- **`language_screen`** — launch (the splash's mark, the aurora drifting in,
  the headline and panel rising), each place arriving as its page comes into
  view, the parallax of a swipe, a tab tap animating across two pages, and two
  theme flips (four `ThemeData` rebuilt from one seed, every glass surface
  repainted over a full-screen scene).
- **`practice_screen`** — practice opening with its scene arriving behind the
  glass deck, the deck swiped twice and the scene changing with it, an attempt
  held (the hush over the scene, the halo rippling, the countdown) and its
  score revealed — the medal, the voice message, the hint, the cat answering.

The English pack is planted on the disk rather than downloaded, and the
microphone and the acoustic model are stood in for by the same
`ScriptedRecorder` and `ParrotModel` the end-to-end suite uses
(`integration_test/support/on_device.dart`): what they replace is not what is
measured. `test_driver/perf_driver.dart` writes the report to
`build/perf_report.json`, and `tool/perf_budget.dart` gates every screen in it
against `tool/perf_baseline.json` — a screen the baseline has and the report
lacks fails too, so the suite cannot quietly stop measuring one.

It sits in `perf/` and not in `integration_test/` for a mechanical reason:
the e2e script runs `flutter test integration_test`, which collects every
`*_test.dart` in that directory. A perf suite living there gets run without its
driver, fails, and reports itself as an end-to-end failure - which is exactly
what happened once.

**No server is involved.** The behavioural e2e needs Postgres and a running
backend serving packs; this suite touches no network, which is what makes it
cheap enough to run often. The expensive parts of this app were never the
network — they are full-screen animated scenes painted under frosted glass
(`BackdropFilter`), a `CustomPaint` drawing three radial gradients, and those
four themes.

### What is gated

| Metric | Why |
|---|---|
| average / 90th / 99th frame **build** time | what our own widget code costs |
| average / 90th frame **rasterizer** time | what the GPU pays for blur, gradients, clipping |
| missed build & rasterizer budget counts | absolute, not relative: zero dropped frames becoming any is a regression no percentage expresses |

Relative metrics fail at **+35%** (and more than 0.2 ms); missed-frame counts
fail at **+2 frames** — unless the baseline already missed at least half its
frames. Then the count follows how many frames were drawn rather than how slow
they were (a faster run draws more, and "misses" more), so it is reported and
skipped; the frame times still gate that run. On CI's emulator, rendering in
software, nearly every frame misses the raster budget, which is why its raster
counts are skipped and its build counts are not.

**CI requires a baseline.** Without one nothing is gated and the run passes,
which is right on a machine measuring a device for the first time and wrong in
CI, where the app could get as slow as it liked in silence. So CI passes
`--require-baseline`: a missing entry for `ci-android-emulator/profile`, or a
measured screen the entry has nothing for, fails the job.

### Two honest caveats

**Profile mode or nothing.** A debug build keeps assertions on and skips AOT
compilation, which inflates frame build time by roughly an order of magnitude.
The build mode is written into the report *by the test itself* and baselines
are keyed `<tag>/<mode>`, one entry per screen under it, so a debug run can
never be compared against a profile baseline. It cannot be configured wrong.

The iOS simulator does not support profile mode at all, so measuring there
needs `PERF_MODE=debug` and produces numbers comparable only to other debug
simulator runs. A measured example, taken exactly that way on an iPhone 16
simulator: the language screen in 220 frames, average build 7.68 ms, 99th
percentile 43.2 ms, 9 missed build budgets, raster 3.55 ms average; practice in
235 frames, average build 4.81 ms, 99th percentile 28.8 ms, 8 missed build
budgets, raster 3.25 ms average — and those raster figures are the Mac's GPU,
not a phone's. **Do not read those as the app's performance.** They
demonstrate that the pipeline runs.

**The tolerance is loose on purpose.** This runs on emulators, where frame
times are noisy. A tight gate fails on noise, and a gate that fails on noise
gets rerun until green — which is worse than no gate, because it also teaches
everyone to ignore the next real failure.

**CI's emulator draws in software, through ANGLE on SwiftShader.** It is
pinned to emulator 36.2.12 with `-gpu swangle_indirect` (see the CI section of
[AGENTS.md](../AGENTS.md) for why). Its numbers say nothing about a phone's
GPU — the first green run averaged 90–110 ms of raster per frame — and are
comparable only with other runs of the same job on the same emulator and
renderer, which is what `PERF_TAG=ci-android-emulator` keys them by. Moving
either means recording the baseline again.

### Recording a baseline

`PERF_TAG` names the entry, so an emulator's numbers are never compared with a
phone's:

```bash
PERF_TAG=pixel-7 melos run perf:baseline
```

**CI's numbers can only be taken by CI.** Download the `perf-report` artifact
of one or more green runs of the *Frame timings* job, then:

```bash
dart run tool/perf_budget.dart --update --tag ci-android-emulator \
  --report run-a.json --report run-b.json --note "CI runs <ids>, <what changed>"
```

**Use more than one run.** The baseline keeps the worst each metric did across
the reports given, and records how many there were. One run is not enough:
two CI runs of the same commit on the same emulator differed by 30–40% in
raster time, so a baseline taken from one lucky run fails the next ordinary
one, and a gate that fails on noise is worse than none. The first baseline,
`ci-android-emulator/profile`, is the worst of two runs; adding the next green
runs' reports to a later `--update` makes it steadier.

Commit the diff, and say in the message what moved the numbers. That sentence
is the whole point of the file: a baseline updated without explanation is drift
with extra steps. Moving the emulator pin or its renderer in `ci.yml` changes
what is measured, so record the CI entry again when either moves.

## What none of this covers

Being specific about the holes is more useful than a claim of coverage:

- **Memory.** Nothing measures it. The timeline carries GC counts and this
  ignores them.
- **Startup time to first frame** as a metric of its own.
- **Scrolling**, because no screen scrolls yet. The first list view should add
  a case here.
- **Server latency and query plans.** No load test, no N+1 detection. The
  cache degrades to per-process without Redis, which is documented in
  [caching.md](caching.md) and not tested.
- **Real hardware.** Every number here comes from an emulator or a simulator
  unless someone records a baseline from a device.
