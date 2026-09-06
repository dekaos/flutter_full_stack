# AGENTS.md

Working agreement for this repository — for AI agents and humans alike.
This is the canonical file; `CLAUDE.md` points here.

## What this is

A Melos monorepo backed by a native Dart workspace. Three packages, one
`pubspec.lock`, one `.dart_tool/` at the root:

| Package | Kind | Role |
|---|---|---|
| `flutter_full_stack_server` | Dart | Serverpod 4.0.0-rc.2 backend: endpoints, models, migrations, web routes |
| `flutter_full_stack_client` | Dart | **Fully generated** client. Never hand-edit. |
| `flutter_full_stack_flutter` | Flutter | The app. Riverpod + go_router, both code-generated. |

Data flows one way: you write server models and endpoints, run the generator,
and the client package plus the app's typed API appear from that.

## Commands

Every task has a Melos script. Use them instead of ad-hoc commands — CI invokes
the same scripts, so a green local run predicts a green pipeline.

```bash
melos run setup             # resolve dependencies (once, after cloning)
melos run docker:up         # Postgres + Redis, dev and test containers
melos run server:start      # docker:up + run the server with migrations
melos run server:debug      # same, with the VM service open for a debugger
melos run server:stop       # stop the containers

melos run generate          # regenerate ALL generated code (see below)
melos run format            # format every package
melos run analyze           # analyze every package (--fatal-infos)
melos run test              # server + Flutter tests
melos run check             # format:check + analyze + test — the CI gate

melos run test:e2e          # end-to-end: real app against a running server
```

Run `melos run check` before declaring any change finished. It covers CI's
`static` and `test` jobs. CI's third job, `codegen`, has no local equivalent:
reproduce it by running `melos run generate` and confirming `git status` is
clean afterwards.

`melos run` with no arguments opens a picker listing every script and its
description.

## Rules that are easy to get wrong

**Never hand-edit generated code.** It is overwritten on the next generate run:

- `flutter_full_stack_server/lib/src/generated/**`
- `flutter_full_stack_server/test/integration/test_tools/serverpod_test_tools.dart`
- `flutter_full_stack_client/lib/src/protocol/**`
- every `*.g.dart` in `flutter_full_stack_flutter`

Change the *source* instead: a `.spy.yaml` model, an endpoint class, or a
`@riverpod` annotation.

**Always use `melos run generate`, never `serverpod generate` on its own.**
Both generators emit code that `dart format` rejects on this language version,
so `melos run generate` runs the generators *and then formats*. Calling a
generator directly leaves the tree unformatted and turns CI red.

**Tests need the containers running.** `melos run test` talks to the `*_test`
Postgres on port 9090. Start it with `melos run docker:up` first. The test
runmode binds every server port to `0`, so tests never collide with a running
dev server.

**End-to-end tests are a separate command with prerequisites.** `melos run
test:e2e` drives the real app, through the real generated client, against a
running server — so it needs one:

```bash
melos run server:start        # one terminal
melos run test:e2e            # another
```

It is deliberately outside `test` and `check`, because it needs a live backend
and a real device. Four constraints worth knowing before extending it:

- **Web is a build target but not a test one.** `flutter test integration_test
  -d chrome` fails with "Web devices are not supported for integration tests
  yet", and the desktop targets are gone, so the only options are an Android
  emulator or an iOS simulator. `E2E_DEVICE` selects one by device id when
  several are attached; left unset, Flutter takes the only device it finds.
  None of this affects the `--wasm` web build, which is still supported and
  still what `flutter_build` produces for the server.
- **On an Android emulator the backend is not `localhost`.** Inside the
  emulator that name is the emulator itself; `10.0.2.2` is the alias for the
  host loopback, so point `E2E_SERVER_URL` there. Android also blocks plain
  HTTP from targetSdk 28 on, which the debug and profile manifests lift with
  `usesCleartextTraffic` — debug and profile only, never release.
- **It runs against the *development* database on 8090, not the test one.**
  Serverpod restricts `--mode` to `development`, `test`, `staging` and
  `production`, so a dedicated `e2e` runmode is impossible, and the `test`
  runmode binds its ports to `0` — unusable when the app needs a fixed URL.
  Reset the data with `melos run docker:down` when a test dirties it.
- **`E2E_SERVER_URL` overrides the backend** (default
  `http://localhost:8080/`). It is passed to the app as
  `--dart-define=SERVER_URL=`, which wins over `assets/config.json`.

**`config/passwords.yaml` is git-ignored and required.** After cloning:

```bash
cp flutter_full_stack_server/config/passwords.example.yaml \
   flutter_full_stack_server/config/passwords.yaml
```

Then fill it in following the comments in that file. The `development`/`test`
database and Redis entries must match `docker-compose.yaml`. In CI and in
production, `SERVERPOD_PASSWORD_<name>` environment variables take precedence
over the file.

**Lint rules live in one place:** the root `analysis_options.yaml`. The three
package files only add their own `analyzer.exclude` entries. Change a rule at
the root so the packages cannot drift.

**Name every model file `*.spy.yaml`, or the generator ignores it in silence.**
The discovery rule is not what the folder layout suggests:

| Extension | Where it is recognised |
|---|---|
| `.spy.yaml`, `.spy.yml`, `.spy` | anywhere under `lib/` |
| plain `.yaml`, `.yml` | **only** under `lib/src/models/` or `lib/src/protocol/` |

A valid model saved as `order.yaml` in, say, `lib/src/orders/` is simply not
seen. `serverpod generate` exits `0` and prints `✅ Done.` — no error, no
warning, and the class never appears in either package. The `.spy` marker is
what frees a model from the directory convention, which is why every model here
uses it.

**The model's folder is mirrored into both generated packages.** A model at
`lib/src/orders/order.spy.yaml` generates
`server/lib/src/generated/orders/order.dart` *and*
`client/lib/src/protocol/orders/order.dart`. So moving a `.spy.yaml` later
renames generated files in two packages and breaks every import of them —
choose the folder when you create the model, not afterwards.

## Adding a feature end to end

1. **Model** — add or edit a `.spy.yaml` under
   `flutter_full_stack_server/lib/src/<feature>/`. Add `table: <name>` only if it
   is persisted.
2. **Endpoint** — add `<feature>_endpoint.dart` in the same folder with a class
   extending `Endpoint`. The class name minus the `Endpoint` suffix becomes the
   client-side accessor (`GreetingEndpoint` → `client.greeting`).
3. **Generate** — `melos run generate`.
4. **Migration** (only if you touched a `table:`) —
   `cd flutter_full_stack_server && serverpod create-migration`, then restart with
   `melos run server:start`, which applies it.
5. **App** — add a controller under
   `flutter_full_stack_flutter/lib/features/<feature>/providers/` and a screen
   under `.../presentation/`. Register the route in `lib/app/router.dart`.
6. **Test** — an integration test in `flutter_full_stack_server/test/integration/`
   using `withServerpod`, and a widget test in `flutter_full_stack_flutter/test/`.
   Add an end-to-end test in `flutter_full_stack_flutter/integration_test/` only
   for a critical path: that suite is slow and needs a live server, so it earns
   its place on the few flows that must never break, not on every feature.
7. `melos run check`, plus `melos run test:e2e` if you touched step 6's
   end-to-end suite.

## Debugging the server

Breakpoints in endpoint methods work, and pause the real request.

**From VS Code — the normal path.** Put a breakpoint in the gutter, then press
F5 and pick **flutter_full_stack_server**. Its `preLaunchTask` starts the
containers first. The **flutter_full_stack (server + app)** compound runs the server
and the app together, both under the debugger, so a breakpoint on each side of
the same call hits in turn; stopping either stops both. The two start in
parallel, which is safe because nothing in the app reaches the server until you
press send — `serverpodClientProvider` is read in exactly one place, inside
`GreetingController.sayHello`.

**Stepping through the client.** Which code the debugger will step into is not
obvious, and it comes down to one rule in the Dart extension: a library is
"external" — and skipped — only when its resolved path sits in the pub cache
(`/hosted/pub.`) or under `third_party/`, plus `package:flutter` itself.

| Package | Resolves to | Steps in by default? |
|---|---|---|
| `flutter_full_stack_client` | `../flutter_full_stack_client` | **yes** — it is a workspace path dependency, not a pub package |
| `flutter_full_stack_server` | `../flutter_full_stack_server` | **yes** |
| `serverpod_client`, `serverpod`, `riverpod`, `flutter` | `~/.pub-cache/hosted/pub.dev/…` | no |

So breakpoints in the *generated client* work with no configuration — useful for
watching a call turn into `callServerEndpoint(...)` arguments. To follow it
further, into `package:serverpod_client` where the HTTP request and the
serialization actually happen, turn on `dart.debugExternalPackageLibraries` in
settings. Leave it off day to day, or you will step into Flutter framework code
constantly.

**Attaching to a server you started in a terminal.** `melos run server:start`
exposes no VM service, so nothing can attach to it. Use the debug variant
instead, then pick **Attach to the running server**:

```bash
melos run server:debug     # VM service on http://127.0.0.1:8181/
```

It passes `--observe=8181 --disable-service-auth-codes`, which is what makes the
URI stable enough to hard-code in `launch.json`. That also makes it
unauthenticated, so it binds to loopback only — never expose that port. The same
URI serves DevTools at `/devtools`.

**Two things that surprise people:**

- **While you sit on a breakpoint, the caller is blocked.** The isolate is
  paused, so the HTTP request stays open and the client eventually gives up —
  `curl --max-time` returns empty, and the Flutter app surfaces a timeout in its
  `AsyncValue`. A client-side timeout after a debugging session is not a bug.
- **`session` is inspectable, and it is the useful part.** At a breakpoint you
  get the endpoint arguments plus the live `MethodCallSession` — from there,
  `session.db`, the authenticated user, and the passwords.

Endpoint tests are debuggable the same way: put a breakpoint in the endpoint and
launch the test in `test/integration/` with the debugger rather than
`melos run test`.

## Conventions

**Server.** One folder per domain under `lib/src/`, holding that domain's models
and its endpoint together. Endpoint classes end in `Endpoint`. Session logging
via `session.log(...)`, never `print`.

Group by domain, never by whether a model is persisted. A domain normally needs
both — `order.spy.yaml` with `table: order` sits beside `order_summary.spy.yaml`
with no table at all — and since the folder is mirrored into the generated
packages, a "persisted models over here" split turns a one-line change
(adding `table:`) into a cross-package refactor the day a DTO gains storage.

**Flutter.** Feature-first: `lib/features/<feature>/{presentation,providers}/`.
Cross-feature code goes in `lib/core/`, app-level wiring in `lib/app/`.
Providers are always code-generated with `@riverpod` — do not declare
`Provider`/`FutureProvider` by hand. Async state uses `AsyncValue` and
`AsyncValue.guard`; do not write manual loading/error booleans.

**Style.** `very_good_analysis` at `--fatal-infos`, 80-column lines. Futures are
either awaited or wrapped in `unawaited(...)`. Constructors keep the
conventional `MyWidget({super.key})` form — the Dart 3.13 `new(...)` shorthand
is deliberately disabled in the root lint config.

## Ports

| Port | Service |
|---|---|
| 8080 / 8081 / 8082 | API / Insights / web server (dev) |
| 8181 | Dart VM service, only under `melos run server:debug` |
| 8090 / 8091 | Postgres / Redis (dev containers) |
| 9090 / 9091 | Postgres / Redis (test containers) |

Redis is `enabled: false` in both `development.yaml` and `test.yaml`; the
containers run anyway so enabling it is a one-line change.

`docs/local-development.svg` draws which of these each way of running reaches —
in particular that the end-to-end suite shares the development database while
endpoint tests get the separate one on 9090.

## CI

`.github/workflows/ci.yml` runs three jobs on every push and PR to `main`:

- **static** — `melos run format:check` and `melos run analyze`
- **codegen** — regenerates everything and fails if the working tree changed,
  catching a commit made without running `melos run generate`
- **test** — starts the containers and runs `melos run test`
- **e2e** — starts the server, boots an Android emulator via
  `reactivecircus/android-emulator-runner` and runs `melos run test:e2e`
  against it. It mints throwaway auth secrets per run,
  because `config/passwords.yaml` is git-ignored and the server aborts at
  start-up without the JWT peppers. The `test` job needs no such secrets:
  `withServerpod` never executes `lib/server.dart`'s `run()`.

SDK versions are pinned in the workflow `env` block and must stay in sync with
the `environment:` constraints in the pubspecs.
