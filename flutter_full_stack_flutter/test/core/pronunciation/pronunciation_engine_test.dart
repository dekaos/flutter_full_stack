import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_full_stack_flutter/core/pronunciation/calibration.dart';
import 'package:flutter_full_stack_flutter/core/pronunciation/lexicon.dart';
import 'package:flutter_full_stack_flutter/core/pronunciation/phoneme_model.dart';
import 'package:flutter_full_stack_flutter/core/pronunciation/pronunciation_engine.dart';
import 'package:flutter_test/flutter_test.dart';

const _vocab = ['<pad>', '|', 'a', 'b', 'c', 'd'];

const _exercise = Exercise(
  id: 'x',
  text: 'ab',
  words: [LexiconWord(word: 'ab', phoneStart: 0, phoneEnd: 2)],
  phones: [
    LexiconPhone(symbol: 'a', tokenIds: [2]),
    LexiconPhone(symbol: 'b', tokenIds: [3]),
  ],
);

const _lexicon = Lexicon(
  lang: 'x',
  model: 'model.onnx',
  vocab: _vocab,
  blankId: 0,
  calibration: GopCalibration.fallback,
  exercises: [_exercise],
);

/// Log-softmaxed emissions in which frame `t` is won by `winners[t]`, the way
/// a CTC model's output looks: one confident token per frame.
Emissions _emissions(List<int> winners) {
  final vocabSize = _vocab.length;
  final out = Float32List(winners.length * vocabSize);
  for (var t = 0; t < winners.length; t++) {
    final logits = List<double>.filled(vocabSize, 0);
    logits[winners[t]] = 6;
    final sum = logits.fold<double>(0, (a, v) => a + math.exp(v));
    for (var v = 0; v < vocabSize; v++) {
      out[t * vocabSize + v] = logits[v] - math.log(sum);
    }
  }
  return Emissions(
    logProbs: out,
    frames: winners.length,
    vocabSize: vocabSize,
    frameSeconds: 0.02,
  );
}

class _CannedModel implements PhonemeAcousticModel {
  _CannedModel(this.output);

  final Emissions output;
  int calls = 0;

  @override
  Future<Emissions> emissions(Float32List samples) async {
    calls++;
    return output;
  }

  @override
  Future<void> dispose() async {}
}

Future<Object?> _rejection(PronunciationEngine engine, int samples) async {
  try {
    await engine.score(exercise: _exercise, samples: Float32List(samples));
    return null;
  } on AttemptRejected catch (rejected) {
    return rejected.reason;
  }
}

void main() {
  test('silence is not scored', () async {
    // Forced alignment would place /a/ and /b/ somewhere in these frames
    // anyway, and the learner would be graded on nothing.
    final engine = PronunciationEngine(
      lexicon: _lexicon,
      model: _CannedModel(_emissions(List.filled(40, 0))),
    );

    expect(await _rejection(engine, 16000), RejectedBecause.notHeard);
  });

  test('a recording stopped straight away is too short', () async {
    final model = _CannedModel(_emissions(List.filled(40, 0)));
    final engine = PronunciationEngine(lexicon: _lexicon, model: model);

    expect(await _rejection(engine, 800), RejectedBecause.tooShort);
    // Turned away before the expensive part.
    expect(model.calls, 0);
  });

  test('fewer frames than phonemes is too short, not a crash', () async {
    // The aligner cannot fit two tokens into one frame and says so with an
    // ArgumentError, which used to reach the learner as-is.
    final engine = PronunciationEngine(
      lexicon: _lexicon,
      model: _CannedModel(_emissions([2])),
    );

    expect(await _rejection(engine, 16000), RejectedBecause.tooShort);
  });

  test('speech is scored', () async {
    final engine = PronunciationEngine(
      lexicon: _lexicon,
      model: _CannedModel(
        _emissions([0, 0, 2, 2, 0, 0, 3, 3, 0, 0]),
      ),
    );

    final result = await engine.score(
      exercise: _exercise,
      samples: Float32List(16000),
    );

    expect(result.words.single.phones, hasLength(2));
  });

  test('only phonemes count as heard, not blank or boundaries', () {
    expect(
      PronunciationEngine.heardFrames(
        _emissions([0, 1, 2, 0, 3, 1, 0]),
        _lexicon.specialIds,
      ),
      2,
    );
  });
}
