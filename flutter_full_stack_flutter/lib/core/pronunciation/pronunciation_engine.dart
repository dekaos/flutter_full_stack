import 'dart:typed_data';

import 'package:flutter_full_stack_flutter/core/pronunciation/ctc_aligner.dart';
import 'package:flutter_full_stack_flutter/core/pronunciation/gop_scorer.dart';
import 'package:flutter_full_stack_flutter/core/pronunciation/lexicon.dart';
import 'package:flutter_full_stack_flutter/core/pronunciation/phoneme_model.dart';

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

  Future<PronunciationResult> score({
    required Exercise exercise,
    required Float32List samples,
  }) async {
    final emissions = await model.emissions(samples);
    final spans = aligner.align(
      logProbs: emissions.logProbs,
      frames: emissions.frames,
      vocabSize: emissions.vocabSize,
      targets: exercise.targetIds,
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
}
