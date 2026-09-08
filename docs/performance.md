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

This one exists because the app already carries weight you would not guess
from reading it: Inter is bundled in `assets/fonts/` rather than fetched, which
is right for a first run on a bad connection and is also a permanent addition
to every download.

## 2. Coverage — a ratchet, not a target

```bash
melos run coverage        # measure, then gate
melos run coverage:floor  # raise the ratchet
```

Currently **88.6%** over 342 hand-written lines. Generated code is excluded:
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

`integration_test/perf_test.dart` drives the app through the frames that cost
the most — launch with the aurora drifting in and the staggered rise-in, two
theme flips (four `ThemeData` rebuilt from one seed, every glass surface
repainted), two language flips, then typing into the translucent well — and
`watchPerformance` records the timeline. `test_driver/perf_driver.dart` writes
it to `build/perf_report.json`, and `tool/perf_budget.dart` compares it against
`tool/perf_baseline.json`.

**No server is involved.** The behavioural e2e needs Postgres, a migration and
a running backend; this suite touches no network, which is what makes it cheap
enough to run often. The expensive parts of this app were never the HTTP call —
they are seven `BackdropFilter`s, a `CustomPaint` drawing three radial
gradients, and those four themes.

### What is gated

| Metric | Why |
|---|---|
| average / 90th / 99th frame **build** time | what our own widget code costs |
| average / 90th frame **rasterizer** time | what the GPU pays for blur, gradients, clipping |
| missed build & rasterizer budget counts | absolute, not relative: zero dropped frames becoming any is a regression no percentage expresses |

Relative metrics fail at **+35%**; missed-frame counts fail at **+2 frames**.

### Two honest caveats

**Profile mode or nothing.** A debug build keeps assertions on and skips AOT
compilation, which inflates frame build time by roughly an order of magnitude.
The build mode is written into the report *by the test itself* and baselines
are keyed `<tag>/<mode>`, so a debug run can never be compared against a
profile baseline. It cannot be configured wrong.

The iOS simulator does not support profile mode at all, so measuring there
needs `PERF_MODE=debug` and produces numbers comparable only to other debug
simulator runs. A measured example, taken exactly that way on an iPhone 17
simulator: 54 frames, average build 13.91 ms, worst 469 ms (the first frame,
loading fonts and building themes), 5 missed build budgets, raster 0.98 ms
average — and that raster figure is the Mac's GPU, not a phone's. **Do not read
those as the app's performance.** They demonstrate that the pipeline runs.

**The tolerance is loose on purpose.** This runs on emulators, where frame
times are noisy. A tight gate fails on noise, and a gate that fails on noise
gets rerun until green — which is worse than no gate, because it also teaches
everyone to ignore the next real failure.

### Recording a baseline

`PERF_TAG` names the entry, so an emulator's numbers are never compared with a
phone's:

```bash
PERF_TAG=pixel-7 melos run perf:baseline
```

Commit the diff, and say in the message what moved the numbers. That sentence
is the whole point of the file: a baseline updated without explanation is drift
with extra steps.

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
