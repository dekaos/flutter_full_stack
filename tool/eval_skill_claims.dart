// Fails if a SKILL.md claims something about this repo that is no longer true.
//
// Why this exists: a skill is documentation an agent follows literally, so its
// rot does not read as "slightly out of date" - it produces code that does not
// compile. `flutter-screen` told three sessions in a row to wrap a screen in
// `AppBackdrop`, a class that has not existed since the theming work renamed
// it to `AuroraBackdrop`. Nothing failed, because nothing checks a skill.
//
// This is the cheap half of the eval story: it is deterministic, needs no
// model, and runs in seconds, so it can sit in `melos run check`. What it
// cannot do is judge whether the advice is *good* - only whether the things it
// names still exist. `melos run eval:skills` is the other half.
//
// Four claims are checked, and only claims that are mechanically decidable:
//
//   paths    every lib/, docs/, test/, tool/ path mentioned resolves to a file
//   scripts  every `melos run X` names a script that exists in pubspec.yaml
//   symbols  every backticked type in *prose* is declared in this repo or in
//            one of its resolved dependencies
//   skills   every sibling skill referenced by name exists
//
// Symbols are read from prose only, never from fenced code blocks: fenced code
// is illustrative and legitimately invents names, while a type named in a
// sentence is a claim about the codebase.

import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> args) async {
  final repo = _repoRoot();
  final skillsDir = Directory('${repo.path}/.claude/skills');
  if (!skillsDir.existsSync()) {
    stderr.writeln('eval_skill_claims: no .claude/skills directory');
    exit(2);
  }

  final skills =
      skillsDir
          .listSync()
          .whereType<Directory>()
          .map((d) => File('${d.path}/SKILL.md'))
          .where((f) => f.existsSync())
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  final scripts = _melosScripts(repo);
  final skillNames = skills.map(_skillName).toSet();
  final symbols = await _symbolUniverse(repo);

  final findings = <_Finding>[];
  for (final skill in skills) {
    findings.addAll(
      _check(
        skill: skill,
        repo: repo,
        scripts: scripts,
        skillNames: skillNames,
        symbols: symbols,
      ),
    );
  }

  if (findings.isEmpty) {
    stdout.writeln(
      'eval_skill_claims: ${skills.length} skills, every claim still holds.',
    );
    return;
  }

  for (final skill in findings.map((f) => f.skill).toSet()) {
    stdout.writeln('\n$skill');
    for (final f in findings.where((f) => f.skill == skill)) {
      stdout.writeln('  ${f.line}: [${f.kind}] ${f.detail}');
    }
  }
  stdout.writeln(
    '\neval_skill_claims: ${findings.length} stale claims. A skill that names '
    'something gone tells an agent to write code that cannot compile.',
  );
  exit(1);
}

class _Finding {
  _Finding(this.skill, this.line, this.kind, this.detail);

  final String skill;
  final int line;
  final String kind;
  final String detail;
}

String _skillName(File skill) =>
    skill.parent.path.split(Platform.pathSeparator).last;

Directory _repoRoot() {
  var dir = Directory.current;
  while (!File('${dir.path}/melos.yaml').existsSync() &&
      !Directory('${dir.path}/.claude').existsSync()) {
    final parent = dir.parent;
    if (parent.path == dir.path) return Directory.current;
    dir = parent;
  }
  return dir;
}

// ---------------------------------------------------------------- claims --

final _pathPattern = RegExp(
  // The lookbehind stops `package:flutter_test/flutter_test.dart` from
  // matching as the repo path `test/flutter_test.dart`.
  r'(?<![\w/.])(?:\.\./)*(?:lib|test|tool|docs|integration_test|migrations'
  r'|\.claude|\.vscode|\.github)/[A-Za-z0-9_./-]*[A-Za-z0-9_/]',
);
final _linkPattern = RegExp(r'\]\(([^)#]+)');
final _melosPattern = RegExp(r'melos run ([A-Za-z0-9_:]+)');
final _inlineCode = RegExp(r'`([^`\n]+)`');
final _typeToken = RegExp(r'^[A-Z][A-Za-z0-9_]*$');
final _providerToken = RegExp(r'^[a-z][A-Za-z0-9_]*Provider$');

List<_Finding> _check({
  required File skill,
  required Directory repo,
  required Set<String> scripts,
  required Set<String> skillNames,
  required Set<String> symbols,
}) {
  final name = _skillName(skill);
  final findings = <_Finding>[];
  final lines = skill.readAsLinesSync();
  var inFence = false;

  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    final at = i + 1;
    if (line.trimLeft().startsWith('```')) {
      inFence = !inFence;
      continue;
    }

    for (final m in _pathPattern.allMatches(line)) {
      final claimed = m.group(0)!;
      if (claimed.contains('<') || claimed.contains('*')) continue;
      if (!_isConcreteFileClaim(claimed, repo, skill)) continue;
      if (!_resolves(claimed, repo, skill)) {
        findings.add(_Finding(name, at, 'path', '\$claimed does not exist'));
      }
    }

    for (final m in _linkPattern.allMatches(line)) {
      final target = m.group(1)!;
      if (target.startsWith('http') || target.contains('<')) continue;
      if (!_resolves(target, repo, skill)) {
        findings.add(_Finding(name, at, 'link', '$target does not exist'));
      }
    }

    for (final m in _melosPattern.allMatches(line)) {
      final script = m.group(1)!;
      if (!scripts.contains(script)) {
        findings.add(
          _Finding(name, at, 'script', "melos run $script is not defined"),
        );
      }
    }

    // Prose only. Fenced code invents names on purpose.
    if (inFence) continue;

    for (final m in _inlineCode.allMatches(line)) {
      for (final token in _candidates(m.group(1)!)) {
        if (symbols.contains(token)) continue;
        findings.add(
          _Finding(name, at, 'symbol', '$token is not declared anywhere'),
        );
      }
    }

    for (final m in RegExp(r'`([a-z][a-z0-9-]+)`').allMatches(line)) {
      final token = m.group(1)!;
      if (!token.contains('-')) continue;
      if (!token.startsWith('flutter-') && !token.startsWith('serverpod-')) {
        continue;
      }
      if (!skillNames.contains(token)) {
        findings.add(
          _Finding(name, at, 'skill', 'skill `$token` does not exist'),
        );
      }
    }
  }

  return findings;
}

/// The type-ish tokens inside one span of inline code.
///
/// `AppTokens.of` claims `AppTokens`; `Theme.of(context).appTokens` claims
/// nothing checkable. A token needs a lowercase letter after the first
/// character so that CI, SVG and WCAG are not mistaken for classes.
Iterable<String> _candidates(String code) {
  // `Latest database migration already applied.` is a log line, not a class.
  if (code.trim().contains(RegExp(r'\s'))) return const [];
  final head = code.split(RegExp(r'[.(<\s]')).first.replaceAll(r'$', '');
  if (head.isEmpty) return const [];
  if (_providerToken.hasMatch(head)) return [head];
  if (!_typeToken.hasMatch(head)) return const [];
  if (!head.substring(1).contains(RegExp('[a-z]'))) return const [];
  return [head];
}

/// Whether a bare path in the text is a claim about *this* repo.
///
/// Only files, and only where the containing directory exists. The skills also
/// write illustrative paths - `lib/src/orders/order.spy.yaml` for a feature
/// that was never built, `lib/src/models/` for a Serverpod convention this
/// project does not use - and flagging those would train everyone to ignore
/// the check. A missing parent directory means "hypothetical"; a present one
/// with the file gone means "renamed", which is the rot worth catching.
bool _isConcreteFileClaim(String claimed, Directory repo, File skill) {
  final last = claimed.split('/').last;
  if (!last.contains('.')) return false;
  final parent = claimed.substring(0, claimed.length - last.length);
  if (parent.isEmpty) return false;
  return _resolves(parent, repo, skill);
}

bool _resolves(String claimed, Directory repo, File skill) {
  final candidates = <String>[
    // Markdown links are relative to the skill; bare paths are repo- or
    // package-relative, because that is how the skills write them.
    '${skill.parent.path}/$claimed',
    '${repo.path}/$claimed',
    for (final pkg in _packages) '${repo.path}/$pkg/$claimed',
  ];
  return candidates.any(
    (p) =>
        File(p).existsSync() ||
        Directory(p).existsSync() ||
        // The skills write `lib/src/generated/` and similar with a trailing
        // slash stripped by the pattern.
        Directory(p.replaceAll(RegExp(r'/$'), '')).existsSync(),
  );
}

const _packages = [
  'flutter_full_stack_flutter',
  'flutter_full_stack_server',
  'flutter_full_stack_client',
];

// --------------------------------------------------------------- scripts --

Set<String> _melosScripts(Directory repo) {
  final pubspec = File('${repo.path}/pubspec.yaml');
  if (!pubspec.existsSync()) return {};
  final names = <String>{};
  var inScripts = false;
  for (final line in pubspec.readAsLinesSync()) {
    if (line.startsWith('  scripts:')) {
      inScripts = true;
      continue;
    }
    if (inScripts && RegExp(r'^\s{0,2}\S').hasMatch(line)) inScripts = false;
    if (!inScripts) continue;
    final m = RegExp(r'^    ([A-Za-z0-9_:]+):\s*$').firstMatch(line);
    if (m != null) names.add(m.group(1)!);
  }
  return names;
}

// --------------------------------------------------------------- symbols --

final _declaration = RegExp(
  // `abstract mixin class Stream<T>` is real Dart: `mixin` appears here as a
  // modifier as well as being a declaration keyword of its own.
  r'^\s*(?:abstract\s+|base\s+|final\s+|sealed\s+|interface\s+|mixin\s+|)*'
  r'(?:class|mixin|enum|extension type|extension|typedef)\s+(\w+)',
);
final _providerDeclaration = RegExp(r'\b(\w+Provider)\b');

/// Every type this repo or any resolved dependency declares.
///
/// Built from `.dart_tool/package_config.json` rather than a hand-kept
/// allowlist, so `ConsumerWidget` resolves because riverpod really declares it
/// - and stops resolving if riverpod is ever dropped. Cached next to the
/// package config and rebuilt when that file changes, because the first pass
/// reads every Dart file of 200-odd packages.
Future<Set<String>> _symbolUniverse(Directory repo) async {
  final config = File('${repo.path}/.dart_tool/package_config.json');
  final cache = File('${repo.path}/.dart_tool/skill_symbols.json');

  if (config.existsSync() && cache.existsSync()) {
    final cached = jsonDecode(cache.readAsStringSync()) as Map<String, dynamic>;
    if (cached['stamp'] == config.statSync().modified.toIso8601String()) {
      return (cached['symbols'] as List).cast<String>().toSet();
    }
  }

  final roots = <Directory>[
    for (final pkg in _packages) Directory('${repo.path}/$pkg'),
    // dart:core and dart:async are not packages, so `Future`, `Stream` and
    // `StateError` have to come from the SDK the running `dart` belongs to.
    Directory('${File(Platform.resolvedExecutable).parent.parent.path}/lib'),
  ];
  if (config.existsSync()) {
    final decoded = jsonDecode(config.readAsStringSync());
    final packages =
        (decoded as Map<String, dynamic>)['packages'] as List<dynamic>;
    for (final entry in packages.cast<Map<String, dynamic>>()) {
      final root = entry['rootUri'] as String;
      // Without the trailing slash, `resolve('lib/')` replaces the package
      // directory instead of descending into it - which silently produced an
      // empty universe and made every SDK type look undeclared.
      final slashed = root.endsWith('/') ? root : '$root/';
      final uri = slashed.startsWith('file:')
          ? Uri.parse(slashed)
          : config.parent.uri.resolveUri(Uri.parse(slashed));
      roots.add(Directory.fromUri(uri.resolve('lib/')));
    }
  }

  final symbols = <String>{};
  for (final root in roots) {
    if (!root.existsSync()) continue;
    for (final file in root.listSync(recursive: true, followLinks: false)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      for (final line in file.readAsLinesSync()) {
        final m = _declaration.firstMatch(line);
        if (m != null) symbols.add(m.group(1)!);
        for (final p in _providerDeclaration.allMatches(line)) {
          symbols.add(p.group(1)!);
        }
      }
    }
  }

  if (config.existsSync()) {
    cache.writeAsStringSync(
      jsonEncode({
        'stamp': config.statSync().modified.toIso8601String(),
        'symbols': symbols.toList()..sort(),
      }),
    );
  }
  return symbols;
}
