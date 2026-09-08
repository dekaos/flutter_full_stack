// Fails if the shipped binary grew past its budget.
//
// The cheapest honest gate of the three: no device, no model, no noise. The
// same source produces the same bytes, so a failure is always a real change
// and never a flake - which makes it the one performance-adjacent number that
// can be trusted on any runner.
//
// It exists because this app already carries weight a reader would not guess:
// the Inter typeface is bundled as assets rather than fetched, which is the
// right call for a first run on a bad connection and is also a permanent
// addition to every download.
//
//     melos run size            # build, then gate
//     melos run size:budget     # build, then record what it found
//
// Budgets are per artifact and stored with a little headroom, because a
// toolchain upgrade moves these numbers by a percent or two on its own and
// that is not worth a red build.

import 'dart:convert';
import 'dart:io';

/// How much an artifact may grow past its recorded budget before this fails.
const _headroom = 0.05;

Future<void> main(List<String> args) async {
  final update = args.contains('--update');
  final budgetPath = _flag(args, '--budget') ?? 'tool/size_budget.json';
  final artifact =
      _flag(args, '--artifact') ??
      'flutter_full_stack_flutter/build/app/outputs/flutter-apk/app-release.apk';
  final tag = _flag(args, '--tag') ?? 'android-arm64-release';

  final file = File(artifact);
  if (!file.existsSync()) {
    stderr.writeln(
      'size_budget: nothing at $artifact. Build it first - see '
      '`melos run size`.',
    );
    exit(2);
  }

  final bytes = file.lengthSync();
  stdout.writeln('size_budget: $tag is ${_mb(bytes)} ($bytes bytes)');

  final budgetFile = File(budgetPath);
  final budgets = budgetFile.existsSync()
      ? jsonDecode(budgetFile.readAsStringSync()) as Map<String, dynamic>
      : <String, dynamic>{};

  if (update) {
    budgets[tag] = bytes;
    budgetFile.writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(budgets)}\n',
    );
    stdout.writeln('size_budget: budget for $tag recorded as $bytes bytes');
    return;
  }

  final budget = budgets[tag];
  if (budget is! num) {
    stdout.writeln(
      '  no budget for $tag yet. Record it with `melos run size:budget`.',
    );
    return;
  }

  final ceiling = (budget * (1 + _headroom)).round();
  final change = (bytes - budget) / budget * 100;
  stdout.writeln(
    '  budget ${_mb(budget)}, ceiling ${_mb(ceiling)}, '
    'change ${change >= 0 ? '+' : ''}${change.toStringAsFixed(1)}%',
  );

  if (bytes > ceiling) {
    stderr.writeln(
      'size_budget: $tag is ${_mb(bytes - ceiling)} over the ceiling. Every '
      'user pays this on every install, so raising the budget is a decision, '
      'not a formality.',
    );
    exit(1);
  }
  stdout.writeln('  within budget.');
}

String _mb(num bytes) => '${(bytes / 1024 / 1024).toStringAsFixed(2)} MB';

String? _flag(List<String> args, String name) {
  final i = args.indexOf(name);
  return i >= 0 && i + 1 < args.length ? args[i + 1] : null;
}
