// Fails if line coverage dropped below the recorded floor.
//
// A ratchet, not a target: the floor only ever moves up, and it moves in a
// commit someone has to write. That is the point - a fixed target of, say,
// 80% is either unreachable and ignored, or already met and therefore blind
// to the next feature landing untested. A ratchet asks one question, the only
// one that matters as a project grows: is this change better covered than
// what came before it?
//
//     melos run coverage            # measure, then gate
//     melos run coverage:floor      # measure, then raise the floor
//
// It reads lcov, which `flutter test --coverage` writes, and counts the two
// records that matter: LF (lines found) and LH (lines hit). Anything Flutter
// generates is excluded - counting `.g.dart` coverage measures the generators,
// not this repo, and generated code is the majority of some packages here.

import 'dart:convert';
import 'dart:io';

/// Paths whose coverage says nothing about work done by hand.
final _excluded = [
  RegExp(r'\.g\.dart$'),
  RegExp(r'\.tailor\.dart$'),
  RegExp(r'\.freezed\.dart$'),
  RegExp(r'/l10n/app_localizations.*\.dart$'),
  RegExp('/src/generated/'),
  RegExp('/src/protocol/'),
];

Future<void> main(List<String> args) async {
  final update = args.contains('--update');
  final lcovPath =
      _flag(args, '--lcov') ?? 'flutter_full_stack_flutter/coverage/lcov.info';
  final floorPath = _flag(args, '--floor') ?? 'tool/coverage_floor.json';
  final tag = _flag(args, '--tag') ?? 'flutter';

  final lcov = File(lcovPath);
  if (!lcov.existsSync()) {
    stderr.writeln(
      'coverage_floor: no lcov at $lcovPath. Run `melos run coverage` first.',
    );
    exit(2);
  }

  var found = 0;
  var hit = 0;
  var skipped = 0;
  var counted = 0;
  var current = '';
  var include = true;
  final seen = <String>{};

  for (final line in lcov.readAsLinesSync()) {
    if (line.startsWith('SF:')) {
      current = line.substring(3);
      seen.add(current);
      include = !_excluded.any((e) => e.hasMatch(current));
      include ? counted++ : skipped++;
      continue;
    }
    if (!include) continue;
    if (line.startsWith('LF:')) found += int.parse(line.substring(3));
    if (line.startsWith('LH:')) hit += int.parse(line.substring(3));
  }

  if (found == 0) {
    stderr.writeln('coverage_floor: no measurable lines in $lcovPath');
    exit(2);
  }

  // A file no test imports never reaches lcov at all, so it is not "0%
  // covered" - it is absent, and the percentage goes *up* when it is added.
  // That blind spot would make the ratchet worthless for exactly the case it
  // exists to catch: a new feature landing with no test.
  final unmeasured = _unmeasured(lcovPath, seen);
  if (unmeasured.isNotEmpty) {
    stderr.writeln(
      'coverage_floor: ${unmeasured.length} hand-written file(s) never '
      'reached lcov, which means no test imports them - so they raise the '
      'percentage instead of lowering it:',
    );
    for (final f in unmeasured) {
      stderr.writeln('  $f');
    }
    exit(1);
  }

  final pct = hit / found * 100;
  stdout.writeln(
    'coverage_floor: $tag ${pct.toStringAsFixed(2)}% '
    '($hit/$found lines, $counted files, $skipped generated files ignored)',
  );

  final floorFile = File(floorPath);
  final floors = floorFile.existsSync()
      ? jsonDecode(floorFile.readAsStringSync()) as Map<String, dynamic>
      : <String, dynamic>{};
  final floor = (floors[tag] as num?)?.toDouble();

  if (update) {
    if (floor != null && pct < floor) {
      stderr.writeln(
        'coverage_floor: refusing to lower the floor from '
        '${floor.toStringAsFixed(2)}% to ${pct.toStringAsFixed(2)}%. A ratchet '
        'that can be loosened is a suggestion. Pass --force if a deletion '
        'genuinely removed covered code.',
      );
      if (!args.contains('--force')) exit(1);
    }
    // Rounded down, so that ordinary noise in what gets counted does not turn
    // the next run red.
    floors[tag] = (pct * 10).floor() / 10;
    floorFile.writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(floors)}\n',
    );
    stdout.writeln('coverage_floor: floor for $tag set to ${floors[tag]}%');
    return;
  }

  if (floor == null) {
    stdout.writeln(
      '  no floor recorded for $tag. Set it with `melos run coverage:floor`.',
    );
    return;
  }

  if (pct + 0.001 < floor) {
    stderr.writeln(
      'coverage_floor: ${pct.toStringAsFixed(2)}% is below the floor of '
      '${floor.toStringAsFixed(2)}%. Either the change needs tests, or it '
      'deleted covered code - and only the second is fixed by lowering the '
      'floor.',
    );
    exit(1);
  }
  stdout.writeln('  at or above the floor of ${floor.toStringAsFixed(2)}%');
}

/// Hand-written libraries that no test ever loaded.
///
/// `lib/main.dart` is exempt because `runApp` is what an integration test
/// exercises, not a widget test - it is the one file whose absence here is
/// expected rather than a gap.
List<String> _unmeasured(String lcovPath, Set<String> seen) {
  final pkg = Directory(lcovPath).parent.parent.path;
  final lib = Directory('$pkg/lib');
  if (!lib.existsSync()) return const [];
  final missing = <String>[];
  for (final entry in lib.listSync(recursive: true)) {
    if (entry is! File || !entry.path.endsWith('.dart')) continue;
    final relative = entry.path.substring(pkg.length + 1);
    if (relative == 'lib/main.dart') continue;
    if (_excluded.any((e) => e.hasMatch(relative))) continue;
    if (!seen.contains(relative)) missing.add(relative);
  }
  return missing..sort();
}

String? _flag(List<String> args, String name) {
  final i = args.indexOf(name);
  return i >= 0 && i + 1 < args.length ? args[i + 1] : null;
}
