// Compares a perf report against a committed baseline and fails on a cliff.
//
// Why a baseline file and not a fixed threshold: the thing worth catching is
// *drift*. No single feature blows a frame budget - each one adds a
// millisecond, and after twenty of them the app is slow with no commit to
// blame. A fixed threshold only catches the cliff; a baseline that is updated
// deliberately, in a reviewable diff, is what makes twenty milliseconds of
// drift visible as twenty separate refusals to update it.
//
// The report holds one summary per screen the suite measured (its
// `reportKey`), and each is gated on its own, so a regression names the screen
// it is in.
//
// Baselines are keyed by `<tag>/<build mode>`, and the build mode is read from
// the report rather than passed in. A debug frame time is roughly ten times a
// profile one, so a single shared baseline would either pass everything or
// fail everything depending on which was recorded. Refusing to compare across
// modes is the only honest option.
//
//     melos run perf                 # measure, then gate against the baseline
//     melos run perf:baseline        # measure, then record what it found
//
// The tolerance is deliberately loose. This runs on emulators, where frame
// times are noisy and not representative of any real device: a tight gate
// would fail on noise, and a gate that fails on noise gets rerun until green,
// which is worse than no gate. Two CI runs of the same commit on the same
// emulator differed by 30-40% in raster time, which is why `--update` takes
// several `--report`s and keeps the worst each metric did: a baseline taken
// from one lucky run fails the next ordinary one.
//
// Without a baseline nothing is gated, and the run passes. That is right on a
// machine measuring a device for the first time, and wrong in CI, where it
// would let the app get as slow as it likes in silence - so CI passes
// `--require-baseline`, which fails on a missing baseline, or on a screen the
// baseline has no entry for.

import 'dart:convert';
import 'dart:io';

/// The metrics that describe how the app feels, and what a regression looks
/// like in each.
///
/// Build time is what our own widget code costs; raster time is what the GPU
/// pays for blur, gradients and clipping - the parts this app leans on. The
/// missed-budget counters are absolute rather than relative: going from zero
/// dropped frames to any is a regression no percentage can express.
const _gated = <String, _Metric>{
  'average_frame_build_time_millis': _Metric.relative,
  '90th_percentile_frame_build_time_millis': _Metric.relative,
  '99th_percentile_frame_build_time_millis': _Metric.relative,
  'average_frame_rasterizer_time_millis': _Metric.relative,
  '90th_percentile_frame_rasterizer_time_millis': _Metric.relative,
  'missed_frame_build_budget_count': _Metric.absolute,
  'missed_frame_rasterizer_budget_count': _Metric.absolute,
};

enum _Metric { relative, absolute }

/// How much worse a relative metric may get before this fails.
const _tolerance = 0.35;

/// How many newly missed frames are tolerated. One dropped frame is visible.
const _missedFrameSlack = 2;

/// The share of a baseline's frames that, once missed, makes its missed-frame
/// count stop meaning anything.
///
/// When most frames already miss the budget - every frame does, near enough,
/// on an emulator rendering in software - the count follows how many frames
/// were drawn, not how slow they were: a faster run draws more frames and
/// "misses" more. The frame times still gate such a run; the count does not.
const _saturated = 0.5;

/// What one report holds: its build mode, and per screen the gated metrics
/// plus how many frames they were taken over.
typedef _Report = ({
  String mode,
  Map<String, Map<String, num>> screens,
  Map<String, num> frames,
});

Future<void> main(List<String> args) async {
  final update = args.contains('--update');
  final requireBaseline = args.contains('--require-baseline');
  final tag =
      _flag(args, '--tag') ?? Platform.environment['PERF_TAG'] ?? 'local';
  final reportPaths = _flags(args, '--report');
  if (reportPaths.isEmpty) {
    reportPaths.add('flutter_full_stack_flutter/build/perf_report.json');
  }
  final baselinePath = _flag(args, '--baseline') ?? 'tool/perf_baseline.json';
  final note = _flag(args, '--note');

  if (!update && reportPaths.length > 1) {
    stderr.writeln(
      'perf_budget: a comparison takes one report; several are for --update',
    );
    exit(2);
  }
  final reports = [for (final path in reportPaths) _read(path)];
  final mode = reports.first.mode;
  if (reports.any((r) => r.mode != mode)) {
    stderr.writeln(
      'perf_budget: the reports were taken in different build modes '
      '(${reports.map((r) => r.mode).toSet().join(', ')})',
    );
    exit(2);
  }

  final key = '$tag/$mode';
  stdout.writeln('perf_budget: $key');
  if (mode == 'debug') {
    stdout.writeln(
      '  note: debug build. These numbers say nothing about how the app '
      'performs on a device - they are only comparable to other debug runs.',
    );
  }

  final baselineFile = File(baselinePath);
  final baselines = baselineFile.existsSync()
      ? (jsonDecode(baselineFile.readAsStringSync()) as Map<String, dynamic>)
      : <String, dynamic>{};

  if (update) {
    // The worst each metric did across the runs given, so that a baseline is
    // not one lucky run that the next ordinary one fails against.
    final screens = {for (final r in reports) ...r.screens.keys}.toList()
      ..sort();
    baselines[key] = {
      'recorded': DateTime.now().toUtc().toIso8601String(),
      'samples': reports.length,
      'note': ?note,
      for (final screen in screens)
        screen: {
          for (final metric in _gated.keys)
            metric: _worst([
              for (final r in reports) ?r.screens[screen]?[metric],
            ]),
          // Not a metric: what a missed-frame count is set against to tell
          // whether it is saturated. The most frames any run drew, so that
          // calling it saturated takes the strongest case.
          'frame_count': [
            for (final r in reports) ?r.frames[screen],
          ].reduce((a, b) => a > b ? a : b),
        },
    };
    baselineFile.writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(baselines)}\n',
    );
    final entry = baselines[key] as Map<String, dynamic>;
    for (final screen in screens) {
      final recorded = entry[screen] as Map<String, num>;
      stdout.writeln('  $screen, worst of ${reports.length} run(s)');
      for (final e in recorded.entries) {
        stdout.writeln('    recorded ${e.key} = ${_round(e.value)}');
      }
    }
    stdout.writeln(
      'perf_budget: baseline for $key written to $baselinePath. Commit it, '
      'and say in the message what made the numbers move.',
    );
    return;
  }

  final report = reports.single;
  final baseline = baselines[key];
  if (baseline is! Map<String, dynamic>) {
    stdout.writeln('  no baseline for $key yet. Measured:');
    for (final MapEntry(key: screen, value: metrics)
        in report.screens.entries) {
      stdout.writeln('  $screen, ${report.frames[screen]} frames');
      for (final e in metrics.entries) {
        stdout.writeln('    ${e.key} = ${_round(e.value)}');
      }
    }
    if (requireBaseline) {
      stderr.writeln(
        '\nperf_budget: no baseline for $key, and this run requires one - '
        'without it nothing is gated, however slow the app gets.\n'
        '${_howToRecord(tag)}',
      );
      exit(1);
    }
    stdout.writeln(
      '  Record it with `melos run perf:baseline` once you believe the '
      'numbers, then a later run has something to fail against.',
    );
    return;
  }

  final regressions = <String>[];
  // A screen the baseline has and the report does not is a suite that
  // stopped measuring it - which would otherwise pass in silence.
  for (final screen in baseline.keys.where((k) => baseline[k] is Map)) {
    if (!report.screens.containsKey(screen)) {
      stdout.writeln('  GONE $screen: in the baseline, not in the report');
      regressions.add(screen);
    }
  }
  for (final MapEntry(key: screen, value: metrics) in report.screens.entries) {
    stdout.writeln('  $screen, ${report.frames[screen]} frames');
    final was = baseline[screen];
    if (was is! Map<String, dynamic>) {
      if (requireBaseline) {
        stdout.writeln('    NONE: no baseline for this screen');
        regressions.add('$screen (no baseline)');
      } else {
        stdout.writeln(
          '    no baseline for it yet - `melos run perf:baseline` records one',
        );
      }
      continue;
    }
    final frames = was['frame_count'];
    for (final entry in metrics.entries) {
      final before = was[entry.key];
      if (before is! num) continue;
      final now = entry.value;
      final kind = _gated[entry.key]!;
      if (kind == _Metric.absolute &&
          frames is num &&
          frames > 0 &&
          before >= frames * _saturated) {
        stdout.writeln(
          '    skip ${entry.key}: ${_round(now)} - the baseline already '
          'missed ${_round(before)} of ${_round(frames)} frames, so the '
          'count follows how many were drawn',
        );
        continue;
      }
      final over = switch (kind) {
        _Metric.relative =>
          now > before * (1 + _tolerance) && now - before > 0.2,
        _Metric.absolute => now > before + _missedFrameSlack,
      };
      final change = before == 0 ? null : (now - before) / before * 100;
      final delta = change == null
          ? ''
          : ' (${change >= 0 ? '+' : ''}${change.toStringAsFixed(0)}%)';
      stdout.writeln(
        '    ${over ? 'OVER ' : 'ok   '}${entry.key}: '
        '${_round(now)} vs ${_round(before)}$delta',
      );
      if (over) regressions.add('$screen ${entry.key}');
    }
  }

  if (regressions.isEmpty) {
    stdout.writeln('perf_budget: within budget.');
    return;
  }

  stderr.writeln(
    '\nperf_budget: ${regressions.length} problem(s) for $key: '
    '${regressions.join(', ')}.\n'
    'Either the change made the app slower, or the baseline is genuinely out '
    'of date - and only one of those is fixed by recording it again.\n'
    '${_howToRecord(tag)}',
  );
  exit(1);
}

/// Reads one report, or exits saying what is wrong with it.
_Report _read(String path) {
  final file = File(path);
  if (!file.existsSync()) {
    stderr.writeln(
      'perf_budget: no report at $path. Run `melos run perf` first.',
    );
    exit(2);
  }
  final report = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  // One timeline summary per screen the suite measured, under the
  // `reportKey` it was measured with.
  final summaries = <String, Map<String, dynamic>>{
    for (final entry in report.entries)
      if (entry.value case final Map<String, dynamic> summary
          when summary.containsKey('frame_count'))
        entry.key: summary,
  };
  if (summaries.isEmpty) {
    stderr.writeln('perf_budget: $path carries no frame summaries');
    exit(2);
  }
  final screens = <String, Map<String, num>>{};
  for (final MapEntry(key: screen, value: summary) in summaries.entries) {
    final metrics = <String, num>{
      for (final metric in _gated.keys)
        if (summary[metric] is num) metric: summary[metric] as num,
    };
    final missing = _gated.keys.where((m) => !metrics.containsKey(m));
    if (missing.isNotEmpty) {
      stderr.writeln(
        'perf_budget: $screen in $path is missing ${missing.join(', ')}',
      );
      exit(2);
    }
    screens[screen] = metrics;
  }
  return (
    mode: report['build_mode'] as String? ?? 'unknown',
    screens: screens,
    frames: {
      for (final MapEntry(key: screen, value: summary) in summaries.entries)
        screen: summary['frame_count'] as num,
    },
  );
}

/// Every metric here gets worse as it grows, so the worst is the largest.
num _worst(List<num> values) => values.reduce((a, b) => a > b ? a : b);

/// How to record a baseline from CI's numbers, which only CI can take.
String _howToRecord(String tag) =>
    'To record one from CI: download the `perf-report` artifact of one or '
    'more green runs, then\n'
    '  dart run tool/perf_budget.dart --update --tag $tag '
    '--report a.json [--report b.json ...] --note "runs ..."\n'
    'The baseline keeps the worst each metric did across them - the more '
    'runs, the less it fails on noise.';

String _round(num v) => v is int ? '$v' : v.toStringAsFixed(2);

String? _flag(List<String> args, String name) {
  final i = args.indexOf(name);
  return i >= 0 && i + 1 < args.length ? args[i + 1] : null;
}

/// Every value given for a flag that may repeat.
List<String> _flags(List<String> args, String name) => [
  for (var i = 0; i < args.length - 1; i++)
    if (args[i] == name) args[i + 1],
];
