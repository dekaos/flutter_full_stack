# Caching

## Nothing is cached today

There is no call to `session.caches` anywhere in the server, nothing cached in
the app, and `redis: enabled: false` in **every** config — development, test,
staging and production. So this is not a description of a cache layer in use.
It is what is available, and the traps to know about before switching one on.

The one thing that does hold state is the app's provider layer, and that is
Riverpod rather than anything here — a `keepAlive` provider keeps its value for
the life of the app while a plain one is disposed with its last listener. See
[The glue: Riverpod and the backend](flutter-architecture.md#the-glue-riverpod-and-the-backend),
and the `flutter-screen` skill for when each is right.

## The four server caches

Every endpoint gets them through `session.caches`:

| Cache | Scope | Intended for |
|---|---|---|
| `local` | one server process | lower-priority values, may differ between servers |
| `localPrio` | one server process | high-priority values, may differ between servers |
| `global` | all servers, via Redis | values that must agree across the cluster |
| `query` | one server process | database queries Serverpod chooses to cache |

All four are `LocalCache(10000)` — a hard cap of 10,000 entries, and the oldest
entry is dropped once that is reached. There is no size accounting, only a count,
so 10,000 large objects and 10,000 small ones are treated alike.

```dart
await session.caches.local.put('greeting-42', greeting,
    lifetime: const Duration(minutes: 5), group: 'greetings');

final hit = await session.caches.local.get<Greeting>('greeting-42');

await session.caches.local.invalidateGroup('greetings');
```

`get` also takes a miss handler, which writes and returns a value when the key
is absent, so read-through caching does not need a branch of its own.

**Values are serialized on the way in**, with `SerializationManager.encode`.
That means a cache entry has to be a type the protocol knows — a generated
model such as `Greeting`. It is a copy, too, so mutating the object you passed
in does not change what a later `get` returns.

## The trap: `global` without Redis

`global` is only distributed if Redis is actually configured. Otherwise it falls
back to a *separate* local cache — separate on purpose, so that something cached
locally cannot be read back through `global` and hide the mistake in
development.

That fallback does not check the run mode. With `redis: enabled: false`, which
is what every config in this repo says, `session.caches.global` is a per-process
cache **in production too**. On a single server that is invisible. On two, the
two disagree, and nothing in the logs says why.

Redis being *enabled but unreachable* behaves differently again:

| Situation | Result |
|---|---|
| `enabled: false` | Redis skipped; `global` is per-process, silently, in every run mode |
| enabled, unreachable, non-production | 1s timeout, `Failed to connect to Redis. Falling back to local cache.`, `global` degrades |
| enabled, unreachable, production | the error is not handled — start-up fails |

So the rule is: if a value has to be consistent across servers, `global` alone
is not enough. Redis has to be on in that environment, and in production a
misconfiguration stops the server rather than quietly weakening the cache.

## Turning Redis on

The containers already run it — `melos run docker:up` starts Redis on 8091 for
development and 9091 for the test stack, whether or not the server uses them.
Two changes are needed:

1. `redis: enabled: true` in the config for that run mode.
2. A `redis` password under that run mode in `config/passwords.yaml`, matching
   the `--requirepass` in `docker-compose.yaml` (for development and test those
   are not secrets, and `passwords.example.yaml` says which value goes where).

Then `melos run test` still needs to pass: enabling Redis for the `test` run
mode makes the suite depend on the test container being up, which is already a
prerequisite of `melos run test`.

## HTTP caching

Separate from the object caches, the web server sends `Cache-Control` on the
files it serves, and each route type can be overridden from the environment
without a rebuild:

| Env var | Route |
|---|---|
| `SERVERPOD_WEB_SERVER_STATIC_CACHE_CONTROL` | `StaticRoute` — `web/static/**` |
| `SERVERPOD_WEB_SERVER_FLUTTER_CACHE_CONTROL` | `FlutterRoute` — the Flutter web build under `/app` |
| `SERVERPOD_WEB_SERVER_SPA_CACHE_CONTROL` | `SpaRoute` |

Serverpod 4 defaults the Flutter build to `private, no-cache`, which is the safe
choice: the app is versioned by its own asset hashes, and a cached `index.html`
is how a browser ends up requesting assets that no longer exist.

API responses carry no caching of their own. An endpoint that needs it caches on
the server, with the caches above.
