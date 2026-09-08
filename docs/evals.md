# Evaluating the skills

The repo carries four skills in `.claude/skills/`. They are instructions an
agent follows literally, which makes them a kind of code — and until this
existed, the only code here that nothing verified.

That is not hypothetical. `flutter-screen` told three sessions in a row to
wrap a screen in `AppBackdrop`, a class renamed to `AuroraBackdrop` during the
theming work. Its worked example also rendered `'No server response yet.'`,
a string deleted in the redesign, three sections above the rule saying no
user-visible string may be written in a widget. Both were found by the checker
below on its first run, not by a person.

There are two layers, and the split is the whole design: one is cheap enough to
run on every commit, the other is the only one that can tell whether the advice
actually works.

## Layer 1 — the claims still hold

```bash
melos run eval:claims          # ~1s warm, part of `melos run check` and of CI
```

`tool/eval_skill_claims.dart` reads every `SKILL.md` and checks four things
that are mechanically decidable:

| Claim | How it is checked |
|---|---|
| paths | every `lib/…` file named in prose resolves |
| scripts | every `melos run X` names a script in `pubspec.yaml` |
| symbols | every backticked type in prose is declared in this repo or a dependency |
| skills | every sibling skill referenced by name exists |

**Symbols are resolved, not allowlisted.** The universe is built from
`.dart_tool/package_config.json` — all 225 resolved packages plus the Dart SDK,
about 22,000 types — and cached next to it until that file changes. So
`ConsumerWidget` passes because riverpod really declares it, and would start
failing if riverpod were dropped. No list to keep by hand.

**Two rules keep it free of false positives**, which matters more than
coverage: a checker that cries wolf teaches everyone to ignore it.

- *Prose only, never fenced code.* Fenced code invents names on purpose —
  `MyWidget`, an `orders` feature that was never built. A type named in a
  sentence is a claim; a type in an example is an illustration.
- *Files, and only where the parent directory exists.* A missing parent means
  hypothetical (`lib/src/orders/order.spy.yaml`); a parent that exists with the
  file gone means renamed, which is the rot worth catching.

It found one real defect and zero false alarms across 771 lines of skills.

What it cannot do is judge whether the advice is any good. It proves the nouns
exist, nothing more.

## Layer 2 — the instructions actually work

```bash
melos run eval:skills                      # every case
melos run eval:skills -- flutter-screen    # one skill
melos run eval:skills -- --budget-usd 3 --keep
```

`tool/eval_skills.dart` gives a real prompt to `claude -p` inside a **detached
git worktree** of `HEAD`, lets it write, generate and test, then asserts on
what came out. The worktree is what makes it safe to run: the agent gets a full
throwaway checkout, so a bad run cannot touch the tree you are working in. It
is not a sandbox — the commands still run on this machine — which is why the
tool allowlist is narrow (`dart`, `flutter`, read-only `git`, and the file
tools).

Assertions come in three kinds, and a case mixes them:

- **`fileMatching`** — a path pattern the agent must have *added*, optionally
  with content it must contain or must not. This is how "no hardcoded copy" is
  checked: the new screen has to mention `AppLocalizations` and must not
  contain a `Text('…')` literal.
- **`grep`** — an existing file must have gained something, such as
  `name: 'about'` in `lib/app/router.dart` or a sixteenth key in both ARBs.
- **`command`** — something that must exit zero. `thenTreeIsClean` reruns
  `melos run generate` afterwards and fails if anything moved, which is the
  same gate CI applies to generated code.

Both layers of the app are asserted on, not just the server: a case that adds
an endpoint has to end with a working controller, route, translation and widget
test, because that is what the skills promise.

### Why it is not in `check`

A case costs minutes of wall clock and real money — the run prints both. Run it
after editing a skill, or on a schedule. `melos run check` stays fast on
purpose.

### Adding a case

One `_Case` in the `_cases` list: the skill it exercises, the prompt, and the
assertions. Write the prompt the way a person would ask, not as a checklist —
a prompt that spells out every step tests your own typing, not the skill.

## What is deliberately not here

`claude plugin eval`, the first-party runner, is not available in this CLI
(2.1.126 has no such subcommand). When it lands, layer 2 is the piece to
revisit: the prompts and assertions carry over, the harness around them is what
that tool would replace.
