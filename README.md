# flutter_app_back

A Serverpod backend and a Flutter app in one Melos monorepo.

| Package | Kind | Role |
|---|---|---|
| [`flutter_app_back_server`](flutter_app_back_server) | Dart | Serverpod backend — endpoints, models, migrations |
| [`flutter_app_back_client`](flutter_app_back_client) | Dart | Generated API client (never edited by hand) |
| [`flutter_app_back_flutter`](flutter_app_back_flutter) | Flutter | The app — Riverpod + go_router |

## Requirements

- Flutter **3.47.2** (bundles Dart 3.13.2) — the version CI runs
- Docker, for Postgres and Redis
- Serverpod CLI: `dart pub global activate serverpod_cli 3.4.13`

## Getting started

```bash
# 1. Dependencies (one resolve covers the whole workspace)
dart pub get

# 2. Secrets — the real file is git-ignored
cp flutter_app_back_server/config/passwords.example.yaml \
   flutter_app_back_server/config/passwords.yaml
#    then fill it in, following the comments inside

# 3. Containers + server
melos run server:start

# 4. The app, in another terminal
cd flutter_app_back_flutter && flutter run
```

The server comes up on **http://localhost:8080** (API) and
**http://localhost:8082** (web). VS Code users can instead pick the
**flutter_app_back (full stack)** compound launch configuration, which starts
the containers, the server and the app together.

## Everyday commands

```bash
melos run check       # format + analyze + test — run before every commit
melos run generate    # regenerate client, protocol and *.g.dart files
melos run test        # tests only (needs `melos run docker:up`)
melos run server:stop # stop the containers
```

`melos run` with no arguments lists every available script.

## Before you commit

Run `melos run check`. It is byte-for-byte what CI runs, so a green local run
means a green pipeline.

## Contributing

Conventions, the end-to-end flow for adding a feature, and the rules around
generated code are in **[AGENTS.md](AGENTS.md)**.
