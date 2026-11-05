import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_full_stack_flutter/core/pronunciation/attempt_recorder.dart';
import 'package:flutter_full_stack_flutter/core/pronunciation/lexicon.dart';
import 'package:flutter_full_stack_flutter/core/pronunciation/phoneme_model.dart';
import 'package:flutter_test/flutter_test.dart';

/// What the on-device suites put in place of the two things a test cannot
/// have on a device: someone speaking into the microphone, and 355 MB of
/// acoustic model. Everything between them is the app's own - the lexicon
/// from the bundle, the CTC aligner, the GOP scorer and its calibration, the
/// controller, the screens and the router.
///
/// Shared by `integration_test/` (behaviour) and `perf/` (frame timings),
/// which is why it is not a `*_test.dart`: `flutter test integration_test`
/// collects those, and this is not a suite of its own.

/// An acoustic model that hears exactly the prompt being scored, phoneme for
/// phoneme, as a native speaker would say it.
///
/// What it emits has the shape the real model's has: CTC is peaky, so each
/// phoneme wins one frame and blank takes the frames around it. The frames
/// are spread over the whole recording, so the word timings the scorer
/// derives - and the replay of a single word cut out by them - land inside
/// the attempt, as they do with the real model.
class ParrotModel implements PhonemeAcousticModel {
  ParrotModel({required this.lexicon, required this.prompt});

  final Lexicon lexicon;

  /// The prompt being scored, asked for as it is scored.
  final Exercise Function() prompt;

  /// Frames of blank around each phoneme.
  static const _spacing = 3;

  @override
  Future<Emissions> emissions(Float32List samples) async {
    final targets = prompt().targetIds;
    final vocab = lexicon.vocabSize;
    final frames = targets.length * _spacing + _spacing;
    final logProbs = Float32List(frames * vocab)
      ..fillRange(0, frames * vocab, -20);
    for (var t = 0; t < frames; t++) {
      final i = t ~/ _spacing;
      final spoken = t % _spacing == _spacing - 1 && i < targets.length;
      logProbs[t * vocab + (spoken ? targets[i] : lexicon.blankId)] = 0;
    }
    return Emissions(
      logProbs: logProbs,
      frames: frames,
      vocabSize: vocab,
      frameSeconds: samples.length / AttemptRecorder.sampleRate / frames,
    );
  }

  @override
  Future<void> dispose() async {}
}

/// A microphone that is always allowed, and hears a voice: a low hum with
/// four syllables a second in it, so the recording drawn on the attempt's
/// voice message has the outline of speech rather than of a flat tone.
class ScriptedRecorder implements AttemptRecorder {
  ScriptedRecorder({this.seconds = 1.6});

  final double seconds;

  /// How many attempts were recorded, start to stop.
  int recorded = 0;

  @override
  Future<bool> hasPermission({bool request = true}) async => true;

  @override
  Future<void> start() async {}

  @override
  Future<Float32List> stop() async {
    recorded++;
    const rate = AttemptRecorder.sampleRate;
    final samples = Float32List((seconds * rate).round());
    for (var i = 0; i < samples.length; i++) {
      final t = i / rate;
      final syllables = math.pow(math.sin(math.pi * 4 * t), 2);
      final voice =
          math.sin(2 * math.pi * 140 * t) +
          0.5 * math.sin(2 * math.pi * 280 * t) +
          0.25 * math.sin(2 * math.pi * 420 * t);
      samples[i] = 0.3 * syllables * voice / 1.75;
    }
    return samples;
  }

  @override
  Future<void> cancel() async {}

  @override
  void dispose() {}
}

/// Pumps frames until [done] holds, failing with [failure] if it does not
/// within [timeout].
///
/// `pumpAndSettle` is not enough for what these suites wait on: a download,
/// a file stat, a scoring pass. It returns as soon as no frame is scheduled,
/// which is true while any of those is still running.
Future<void> pumpUntil(
  WidgetTester tester,
  bool Function() done, {
  required String failure,
  Duration timeout = const Duration(seconds: 30),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 100));
    if (done()) return;
  }
  fail(failure);
}

/// Pumps until [finder] matches something.
Future<void> pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  required String failure,
  Duration timeout = const Duration(seconds: 30),
}) => pumpUntil(
  tester,
  () => finder.evaluate().isNotEmpty,
  failure: failure,
  timeout: timeout,
);

/// Goes from the word hunt, where the app opens, to the language chooser -
/// the way a learner does, by its button. The word hunt's space moves on
/// every frame, so nothing there settles; the chooser, covering it, does.
Future<void> openPronunciation(WidgetTester tester) async {
  final button = find.byKey(const Key('hunt-pronunciation'));
  await pumpUntilFound(
    tester,
    button,
    failure: 'The word hunt never offered pronunciation practice.',
  );
  await tester.tap(button);
}

/// Presses the record button, holds it for [hold] as a learner does while
/// they read, and lets go.
///
/// A press shorter than `HoldToRecord.tap` is taken for a tap and throws the
/// attempt away, so [hold] stays well clear of it.
Future<void> holdToRecord(
  WidgetTester tester, {
  Duration hold = const Duration(milliseconds: 1600),
}) async {
  final button = find.byKey(const Key('practice-record'));
  final press = await tester.startGesture(tester.getCenter(button));
  final until = DateTime.now().add(hold);
  while (DateTime.now().isBefore(until)) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  await press.up();
  await tester.pump();
}
