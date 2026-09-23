import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_full_stack_flutter/core/pronunciation/ctc_aligner.dart';
import 'package:flutter_full_stack_flutter/core/pronunciation/gop_scorer.dart';
import 'package:flutter_full_stack_flutter/core/pronunciation/lexicon.dart';
import 'package:flutter_full_stack_flutter/core/pronunciation/phoneme_model.dart';

/// Why an attempt was turned away before being scored.
enum RejectedBecause {
  /// Too little audio to hold the prompt - Stop tapped straight after Record.
  tooShort,

  /// The model heard next to no speech in it: silence, noise, or the learner
  /// reading a fraction of the prompt.
  notHeard,
}

/// An attempt that is not scored, because any number it got would be about
/// something other than the learner's pronunciation.
///
/// Forced alignment always succeeds: it places every canonical phoneme
/// somewhere, whatever the audio holds. Without this check, two seconds of
/// silence come back as a score, and a low score on silence reads to the
/// learner as a verdict on how they speak.
class AttemptRejected implements Exception {
  const AttemptRejected(this.reason);

  final RejectedBecause reason;

  @override
  String toString() => 'attempt rejected: ${reason.name}';
}

/// Scores one read-aloud attempt, end to end and entirely on the device.
///
/// The prompt is known, so there is no recognition step: the audio is aligned
/// against the phonemes the learner was *supposed* to say, and each one is
/// then judged on its own frames. Everything after the model call is plain
/// Dart arithmetic over a few hundred thousand values, which is why it runs on
/// the main isolate without dropping frames.
class PronunciationEngine {
  const PronunciationEngine({
    required this.lexicon,
    required this.model,
    this.aligner = const CtcAligner(),
    this.scorer = const GopScorer(),
  });

  final Lexicon lexicon;
  final PhonemeAcousticModel model;
  final CtcAligner aligner;
  final GopScorer scorer;

  /// Below this there is not enough audio for the model's front end to
  /// produce a frame worth aligning, let alone a word.
  static const minSamples = 4000;

  /// The share of the prompt's phonemes the model must hear for the attempt
  /// to count as a reading of it.
  ///
  /// CTC is peaky: a spoken phoneme wins roughly one frame, and blank takes
  /// the rest. Measured on the shipped int8 models, a full phrase - native or
  /// Brazilian-accented - heard 110-120% of its phonemes and single words at
  /// least 50%, while silence, room noise, loud white noise and mains hum all
  /// heard none. The acoustic model normalises its input, so this holds for
  /// quiet speech too, which is why the check is here and not on the
  /// microphone level: speech 30 dB down was heard frame for frame the same.
  static const minHeardShare = 0.4;

  Future<PronunciationResult> score({
    required Exercise exercise,
    required Float32List samples,
  }) async {
    if (samples.length < minSamples) {
      throw const AttemptRejected(RejectedBecause.tooShort);
    }
    final emissions = await model.emissions(samples);
    final targets = exercise.targetIds;
    if (emissions.frames < targets.length) {
      throw const AttemptRejected(RejectedBecause.tooShort);
    }
    final needed = math.max(1, (targets.length * minHeardShare).floor());
    if (heardFrames(emissions, lexicon.specialIds) < needed) {
      throw const AttemptRejected(RejectedBecause.notHeard);
    }
    final spans = aligner.align(
      logProbs: emissions.logProbs,
      frames: emissions.frames,
      vocabSize: emissions.vocabSize,
      targets: targets,
      blankId: lexicon.blankId,
    );
    return scorer.score(
      exercise: exercise,
      calibration: lexicon.calibration,
      spans: spans,
      logProbs: emissions.logProbs,
      vocabSize: emissions.vocabSize,
      frameSeconds: emissions.frameSeconds,
      symbolForId: lexicon.vocab,
      specialIds: lexicon.specialIds,
    );
  }

  Future<void> dispose() => model.dispose();

  /// Frames where the model's best guess is a phoneme rather than blank,
  /// padding or a word boundary - how much of the recording it heard as
  /// speech at all.
  static int heardFrames(Emissions emissions, Set<int> specialIds) {
    final logProbs = emissions.logProbs;
    final vocabSize = emissions.vocabSize;
    var heard = 0;
    for (var t = 0; t < emissions.frames; t++) {
      var best = 0;
      var bestValue = double.negativeInfinity;
      for (var v = 0; v < vocabSize; v++) {
        final value = logProbs[t * vocabSize + v];
        if (value > bestValue) {
          bestValue = value;
          best = v;
        }
      }
      if (!specialIds.contains(best)) heard++;
    }
    return heard;
  }
}
