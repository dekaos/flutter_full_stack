// Runs each skill the way an agent would, in a throwaway copy of the repo,
// then asserts on what came out.
//
// This is the expensive half of the eval story. `eval_skill_claims.dart`
// proves a skill's *nouns* still exist; nothing there proves the instructions
// produce working code. This does: it hands a real prompt to `claude -p` in a
// detached git worktree, lets it write, generate and test, and then checks the
// result against what the skill promises.
//
// Deliberately not part of `melos run check`: a case costs minutes and real
// money. Run it after editing a skill, and in a scheduled job - not per commit.
//
// The worktree is why this is safe to run: the agent gets a full checkout of
// HEAD that is thrown away afterwards, so a bad run cannot touch the tree you
// are working in. It is not a sandbox - the commands still run on this
// machine - which is why the allowlist below is narrow.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// What the agent is allowed to run. Narrow on purpose: everything the skills
/// actually tell you to do, and nothing else.
const _allowedTools = [
  'Read',
  'Edit',
  'Write',
  'Grep',
  'Glob',
  'Bash(dart *)',
  'Bash(flutter *)',
  'Bash(git status*)',
  'Bash(git diff*)',
  'Bash(ls *)',
  'Bash(cat *)',
];

final _cases = <_Case>[
  _Case(
    name: 'flutter-screen adds a screen, a controller and a route',
    skill: 'flutter-screen',
    prompt: '''
Add a screen to the Flutter app at the route /about, named "about", that shows
the app's own version. Follow the repository's conventions exactly.

It needs a Riverpod controller with a loading state, its route registered, its
copy translated into both supported languages, and a widget test. Do not start
a server or a device: analysis and widget tests are the whole verification.
''',
    assertions: [
      _Assert.fileMatching(
        'a @riverpod controller under features/',
        RegExp(r'features/.+/providers/.+_controller\.dart$'),
        contains: '@riverpod',
      ),
      _Assert.fileMatching(
        'its generated part',
        RegExp(r'features/.+/providers/.+_controller\.g\.dart$'),
      ),
      _Assert.fileMatching(
        'a screen under presentation/',
        RegExp(r'features/.+/presentation/.+\.dart$'),
        contains: 'AppLocalizations',
        absent: RegExp(r"""Text\(\s*['"][A-Za-z]"""),
      ),
      _Assert.fileMatching('a widget test', RegExp(r'^test/.+_test\.dart$')),
      _Assert.grep(
        'the route is registered with a name',
        'flutter_full_stack_flutter/lib/app/router.dart',
        RegExp(r"""name:\s*['"]about['"]"""),
      ),
      _Assert.grep(
        'English copy went into the ARB',
        'flutter_full_stack_flutter/lib/l10n/app_en.arb',
        RegExp(r'"\w+"\s*:'),
        minMatches: 16,
      ),
      _Assert.grep(
        'Portuguese copy went in too',
        'flutter_full_stack_flutter/lib/l10n/app_pt.arb',
        RegExp(r'"\w+"\s*:'),
        minMatches: 16,
      ),
      _Assert.command(
        'generated code matches its sources',
        ['dart', 'run', 'melos:melos', 'run', 'generate'],
        thenTreeIsClean: true,
      ),
      _Assert.command('analyze is clean', [
        'dart',
        'run',
        'melos:melos',
        'run',
        'analyze',
      ]),
      _Assert.command('widget tests pass', [
        'flutter',
        'test',
      ], workingSubdir: 'flutter_full_stack_flutter'),
    ],
  ),
];

Future<void> main(List<String> args) async {
  final budget = _flag(args, '--budget-usd') ?? '5';
  final keep = args.contains('--keep');
  // Skip flags *and* their values, or `--budget-usd 5` reads as a request to
  // run the case named "5".
  final only = <String>[];
  for (var i = 0; i < args.length; i++) {
    if (args[i].startsWith('-')) {
      if (args[i] == '--budget-usd') i++;
      continue;
    }
    only.add(args[i]);
  }

  final repo = Directory.current.absolute.path;
  final selected = only.isEmpty
      ? _cases
      : _cases.where((c) => only.any((o) => c.skill.contains(o))).toList();
  if (selected.isEmpty) {
    stderr.writeln('eval_skills: no case matches ${only.join(' ')}');
    exit(2);
  }

  var failed = 0;
  for (final c in selected) {
    final ok = await _run(c, repo: repo, budget: budget, keep: keep);
    if (!ok) failed++;
  }

  stdout.writeln(
    '\neval_skills: ${selected.length - failed}/${selected.length} cases '
    'passed.',
  );
  if (failed > 0) exit(1);
}

String? _flag(List<String> args, String name) {
  final i = args.indexOf(name);
  return i >= 0 && i + 1 < args.length ? args[i + 1] : null;
}

Future<bool> _run(
  _Case c, {
  required String repo,
  required String budget,
  required bool keep,
}) async {
  final stamp = DateTime.now().millisecondsSinceEpoch;
  final tree = '${Directory.systemTemp.path}/eval-${c.skill}-$stamp';

  stdout
    ..writeln('\n=== ${c.name}')
    ..writeln('    worktree: $tree');

  await _sh('git', ['worktree', 'add', '--detach', tree, 'HEAD'], cwd: repo);
  try {
    stdout.writeln('    resolving dependencies...');
    final pub = await _sh('flutter', ['pub', 'get'], cwd: tree);
    if (pub.exitCode != 0) {
      stdout
        ..writeln('    FAIL: flutter pub get in the worktree')
        ..writeln(_indent(pub.stderr.toString()));
      return false;
    }

    stdout.writeln('    running the agent (budget \$$budget)...');
    final started = DateTime.now();
    final agent = await _sh('claude', [
      '-p',
      c.prompt,
      '--output-format',
      'json',
      '--permission-mode',
      'acceptEdits',
      '--allowedTools',
      ..._allowedTools,
      '--max-budget-usd',
      budget,
    ], cwd: tree);
    final took = DateTime.now().difference(started);

    final report = _agentReport(agent.stdout.toString());
    stdout.writeln(
      '    agent finished in ${took.inSeconds}s'
      '${report == null ? '' : ', $report'}',
    );
    if (agent.exitCode != 0) {
      stdout
        ..writeln('    FAIL: the agent exited ${agent.exitCode}')
        ..writeln(_indent(agent.stderr.toString()));
      return false;
    }

    var passed = 0;
    for (final a in c.assertions) {
      final result = await a.check(tree);
      stdout.writeln('    ${result.ok ? 'pass' : 'FAIL'}  ${a.label}');
      if (!result.ok && result.detail.isNotEmpty) {
        stdout.writeln(_indent(result.detail, '          '));
      }
      if (result.ok) passed++;
    }
    stdout.writeln('    $passed/${c.assertions.length} assertions passed');
    return passed == c.assertions.length;
  } finally {
    if (keep) {
      stdout.writeln('    kept: $tree');
    } else {
      await _sh('git', ['worktree', 'remove', '--force', tree], cwd: repo);
    }
  }
}

/// Cost and turn count, when the JSON output carries them.
String? _agentReport(String out) {
  try {
    final json = jsonDecode(out) as Map<String, dynamic>;
    final cost = json['total_cost_usd'] ?? json['cost_usd'];
    final turns = json['num_turns'];
    final parts = [
      if (cost != null) '\$${(cost as num).toStringAsFixed(2)}',
      if (turns != null) '$turns turns',
    ];
    return parts.isEmpty ? null : parts.join(', ');
  } on Object {
    return null;
  }
}

String _indent(String text, [String prefix = '      ']) =>
    text.trim().split('\n').take(20).map((l) => '$prefix$l').join('\n');

// ----------------------------------------------------------------- cases --

class _Case {
  _Case({
    required this.name,
    required this.skill,
    required this.prompt,
    required this.assertions,
  });

  final String name;
  final String skill;
  final String prompt;
  final List<_Assert> assertions;
}

class _Result {
  _Result({required this.ok, this.detail = ''});

  final bool ok;
  final String detail;
}

/// One checkable promise a skill makes about its own output.
class _Assert {
  _Assert.fileMatching(
    this.label,
    RegExp this.pattern, {
    this.contains,
    this.absent,
  }) : kind = _Kind.fileMatching;

  _Assert.grep(
    this.label,
    String this.path,
    RegExp this.pattern, {
    this.minMatches = 1,
  }) : kind = _Kind.grep;

  _Assert.command(
    this.label,
    List<String> this.command, {
    this.workingSubdir,
    this.thenTreeIsClean = false,
  }) : kind = _Kind.command;

  final _Kind kind;
  final String label;
  RegExp? pattern;
  String? path;
  String? contains;
  RegExp? absent;
  int minMatches = 1;
  List<String>? command;
  String? workingSubdir;
  bool thenTreeIsClean = false;

  Future<_Result> check(String tree) async {
    switch (kind) {
      case _Kind.fileMatching:
        // Only files the agent added, so a pre-existing screen cannot pass a
        // case that was supposed to create one.
        final added = await _added(tree);
        final hits = added.where((p) => pattern!.hasMatch(p)).toList();
        if (hits.isEmpty) {
          return _Result(
            ok: false,
            detail: 'nothing added matching ${pattern!.pattern}',
          );
        }
        for (final hit in hits) {
          final body = File('$tree/$hit').readAsStringSync();
          if (contains != null && !body.contains(contains!)) continue;
          if (absent != null && absent!.hasMatch(body)) {
            return _Result(
              ok: false,
              detail: '$hit still matches ${absent!.pattern}',
            );
          }
          return _Result(ok: true);
        }
        return _Result(
          ok: false,
          detail: '${hits.first}: does not contain $contains',
        );

      case _Kind.grep:
        final file = File('$tree/${path!}');
        if (!file.existsSync()) {
          return _Result(ok: false, detail: '${path!} is missing');
        }
        final n = pattern!.allMatches(file.readAsStringSync()).length;
        return n >= minMatches
            ? _Result(ok: true)
            : _Result(ok: false, detail: '$n matches, expected $minMatches+');

      case _Kind.command:
        final cwd = workingSubdir == null ? tree : '$tree/$workingSubdir';
        final r = await _sh(
          command!.first,
          command!.skip(1).toList(),
          cwd: cwd,
        );
        if (r.exitCode != 0) {
          return _Result(
            ok: false,
            detail: _indent(
              '${r.stdout}\n${r.stderr}'.trim(),
              '',
            ),
          );
        }
        if (!thenTreeIsClean) return _Result(ok: true);
        final dirty = await _sh('git', ['status', '--porcelain'], cwd: tree);
        final changed = dirty.stdout
            .toString()
            .trim()
            .split('\n')
            .where((l) => l.isNotEmpty)
            .toList();
        return changed.isEmpty
            ? _Result(ok: true)
            : _Result(
                ok: false,
                detail: 'regenerating changed:\n${changed.join('\n')}',
              );
    }
  }
}

enum _Kind { fileMatching, grep, command }

/// Paths the agent added, relative to the package that holds them.
Future<List<String>> _added(String tree) async {
  final r = await _sh('git', [
    'status',
    '--porcelain',
    '--untracked-files=all',
  ], cwd: tree);
  return r.stdout
      .toString()
      .split('\n')
      .where((l) => l.trim().isNotEmpty)
      .map((l) => l.substring(3).trim())
      .toList();
}

Future<ProcessResult> _sh(
  String exe,
  List<String> args, {
  required String cwd,
}) => Process.run(exe, args, workingDirectory: cwd, runInShell: true);
