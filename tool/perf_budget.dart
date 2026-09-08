// Compares a perf report against a committed baseline and fails on a cliff.
//
// Why a baseline file and not a fixed threshold: the thing worth catching is
// *drift*. No single feature blows a frame budget - each one adds a
// millisecond, and after twenty of them the app is slow with no commit to
// blame. A fixed threshold only catches the cliff; a baseline that is updated
// deliberately, in a reviewable diff, is what makes twenty milliseconds of
// drift visible as twenty separate refusals to update it.
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
// which is worse than no gate.

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

Future<void> main(List<String> args) async {
  final update = args.contains('--update');
  final tag =
      _flag(args, '--tag') ?? Platform.environment['PERF_TAG'] ?? 'local';
  final reportPath =
      _flag(args, '--report') ??
      'flutter_full_stack_flutter/build/perf_report.json';
  final baselinePath = _flag(args, '--baseline') ?? 'tool/perf_baseline.json';

  final reportFile = File(reportPath);
  if (!reportFile.existsSync()) {
    stderr.writeln(
      'perf_budget: no report at $reportPath. Run `melos run perf` first.',
    );
    exit(2);
  }

  final report =
      jsonDecode(reportFile.readAsStringSync()) as Map<String, dynamic>;
  final mode = report['build_mode'] as String? ?? 'unknown';
  final summary = report['greeting_screen'];
  if (summary is! Map<String, dynamic>) {
    stderr.writeln(
      'perf_budget: the report carries no greeting_screen summary',
    );
    exit(2);
  }

  final key = '$tag/$mode';
  final measured = <String, num>{
    for (final metric in _gated.keys)
      if (summary[metric] is num) metric: summary[metric] as num,
  };
  final missing = _gated.keys.where((m) => !measured.containsKey(m)).toList();

  stdout.writeln('perf_budget: $key, ${summary['frame_count'] ?? '?'} frames');
  if (mode == 'debug') {
    stdout.writeln(
      '  note: debug build. These numbers say nothing about how the app '
      'performs on a device - they are only comparable to other debug runs.',
    );
  }
  if (missing.isNotEmpty) {
    stderr.writeln('perf_budget: the report is missing ${missing.join(', ')}');
    exit(2);
  }

  final baselineFile = File(baselinePath);
  final baselines = baselineFile.existsSync()
      ? (jsonDecode(baselineFile.readAsStringSync()) as Map<String, dynamic>)
      : <String, dynamic>{};

  if (update) {
    baselines[key] = {
      'recorded': DateTime.now().toUtc().toIso8601String(),
      for (final e in measured.entries) e.key: e.value,
    };
    baselineFile.writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(baselines)}\n',
    );
    for (final e in measured.entries) {
      stdout.writeln('  recorded ${e.key} = ${_round(e.value)}');
    }
    stdout.writeln(
      'perf_budget: baseline for $key written to $baselinePath. Commit it, '
      'and say in the message what made the numbers move.',
    );
    return;
  }

  final baseline = baselines[key];
  if (baseline is! Map<String, dynamic>) {
    stdout.writeln('  no baseline for $key yet. Measured:');
    for (final e in measured.entries) {
      stdout.writeln('    ${e.key} = ${_round(e.value)}');
    }
    stdout.writeln(
      '  Record it with `melos run perf:baseline` once you believe the '
      'numbers, then a later run has something to fail against.',
    );
    return;
  }

  final regressions = <String>[];
  for (final entry in measured.entries) {
    final was = baseline[entry.key];
    if (was is! num) continue;
    final now = entry.value;
    final kind = _gated[entry.key]!;
    final over = switch (kind) {
      _Metric.relative => now > was * (1 + _tolerance) && now - was > 0.2,
      _Metric.absolute => now > was + _missedFrameSlack,
    };
    final change = was == 0 ? null : (now - was) / was * 100;
    final delta = change == null
        ? ''
        : ' (${change >= 0 ? '+' : ''}${change.toStringAsFixed(0)}%)';
    stdout.writeln(
      '  ${over ? 'OVER ' : 'ok   '}${entry.key}: '
      '${_round(now)} vs ${_round(was)}$delta',
    );
    if (over) regressions.add(entry.key);
  }

  if (regressions.isEmpty) {
    stdout.writeln('perf_budget: within budget.');
    return;
  }

  stderr.writeln(
    '\nperf_budget: ${regressions.length} metric(s) beyond budget for $key.\n'
    'Either the change made the app slower, or the baseline is genuinely out '
    'of date - and only one of those is fixed by `melos run perf:baseline`.',
  );
  exit(1);
}

String _round(num v) => v is int ? '$v' : v.toStringAsFixed(2);

String? _flag(List<String> args, String name) {
  final i = args.indexOf(name);
  return i >= 0 && i + 1 < args.length ? args[i + 1] : null;
}
