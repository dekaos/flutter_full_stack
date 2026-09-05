---
name: serverpod-migration
description: Create, apply, review or repair a Serverpod database migration. Use when a model gains or loses a `table:` key or a persisted field, when the server reports the database schema is out of date, when a migration fails to apply, or when a merge produces a conflict in migrations/migration_registry.txt.
---

# Database migrations

Migrations live in `flutter_full_stack_server/migrations/<timestamp>/` and are
tracked in `migration_registry.txt`. Both are generated — never edit them by
hand, including the SQL.

## When a migration is needed

Only changes to **persisted** state need one: a model that has (or gains, or
loses) a `table:` key, a field added to or removed from such a model, or a type
or nullability change on one of its fields. Adding a plain serializable model
with no `table:` needs no migration.

## Creating one

Model changes must be generated first, otherwise the migration is built from a
stale schema:

```bash
melos run generate
cd flutter_full_stack_server && serverpod create-migration
```

Read the output. If it warns that data may be destroyed, it stops. Confirm the
loss is intended before reaching for `--force`:

```bash
serverpod create-migration --force
```

Use `--tag <name>` for a migration worth identifying later, e.g.
`serverpod create-migration --tag add-user-profile`.

## Reviewing before committing

Always read the generated SQL — this is the one part of a change that can
destroy production data:

```bash
cat flutter_full_stack_server/migrations/<timestamp>/migration.sql
```

Look for `DROP TABLE`, `DROP COLUMN` and type narrowing. A column rename is
emitted as drop + add, which silently loses the data; if you meant a rename,
write the data-preserving SQL as a follow-up migration rather than editing this
one.

## Applying

The server applies pending migrations on start-up with `--apply-migrations`,
which is what the Melos script passes:

```bash
melos run server:start
```

Success looks like `Latest database migration already applied.` in the log.

## Committing

Commit as one unit: the `.spy.yaml` change, everything `melos run generate`
produced, the entire new `migrations/<timestamp>/` folder, and the updated
`migration_registry.txt`. A migration committed without its registry entry, or
vice versa, breaks every other developer's server start-up.

## Merge conflicts in migration_registry.txt

The file header says it: resolve by **deleting your migration folder and
recreating it** on top of the merged state. Do not hand-merge the timestamps —
that produces a registry which does not match the folders on disk.

```bash
git checkout --theirs flutter_full_stack_server/migrations/migration_registry.txt
rm -rf flutter_full_stack_server/migrations/<your-timestamp>/
melos run generate
cd flutter_full_stack_server && serverpod create-migration
```

## When the live database has drifted

If the database no longer matches the migration history — someone changed it by
hand, or a migration was applied then rolled back — compare against the live
schema instead of the last migration:

```bash
cd flutter_full_stack_server && serverpod create-repair-migration
```

Apply it with `dart bin/main.dart --apply-repair-migration`. This is a recovery
tool: prefer it in development, and in production only after reviewing the SQL.

## Starting over in development

The dev database is disposable. To wipe it and replay every migration:

```bash
melos run docker:down   # removes the volumes
melos run server:start
```

## Checklist

- [ ] `melos run generate` run before creating the migration
- [ ] `migration.sql` read, and any destructive statement intended
- [ ] Migration applied locally and the server starts clean
- [ ] Model, generated code, migration folder and registry committed together
- [ ] `melos run check` green
