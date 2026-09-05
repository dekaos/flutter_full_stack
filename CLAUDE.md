# CLAUDE.md

The working agreement for this repository lives in **[AGENTS.md](AGENTS.md)** —
read it before making changes. It is the single source of truth and is shared
with every other agent tool, so keep instructions there rather than duplicating
them here.

The three things that cause the most damage if skipped:

1. **Never hand-edit generated code** (`lib/src/generated/**`,
   `flutter_app_back_client/lib/src/protocol/**`, any `*.g.dart`,
   `serverpod_test_tools.dart`). Edit the `.spy.yaml` model, the endpoint class,
   or the `@riverpod` annotation, then regenerate.
2. **Regenerate with `melos run generate`**, never `serverpod generate` or
   `build_runner` on their own — the Melos script formats afterwards, which the
   raw generators do not, and CI checks formatting.
3. **Finish with `melos run check`** (format + analyze + test). It is exactly
   what CI runs. Tests need the containers up: `melos run docker:up`.
