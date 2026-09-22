import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_full_stack_flutter/core/pronunciation/calibration.dart';
import 'package:flutter_full_stack_flutter/core/pronunciation/ctc_aligner.dart';
import 'package:flutter_full_stack_flutter/core/pronunciation/gop_scorer.dart';
import 'package:flutter_full_stack_flutter/core/pronunciation/lexicon.dart';
import 'package:flutter_test/flutter_test.dart';

/// Two phonemes, four frames each. `confident` picks which token the model is
/// sure about in the second half, so a test can make the learner say the right
/// sound or the wrong one without a model in the loop.
Float32List _emissions({required int saidInSecondHalf, int vocabSize = 6}) {
  const frames = 8;
  final logits = List.generate(
    frames,
    (t) => List<double>.filled(vocabSize, 0),
  );
  for (var t = 0; t < frames; t++) {
    final token = t < 4 ? 2 : saidInSecondHalf;
    logits[t][token] = 6;
  }
  final out = Float32List(frames * vocabSize);
  for (var t = 0; t < frames; t++) {
    final max = logits[t].reduce(math.max);
    final sum = logits[t].fold<double>(0, (a, v) => a + math.exp(v - max));
    for (var v = 0; v < vocabSize; v++) {
      out[t * vocabSize + v] = logits[t][v] - (max + math.log(sum));
    }
  }
  return out;
}

const _word = Exercise(
  id: 'w',
  kind: ExerciseKind.word,
  text: 'ab',
  words: [LexiconWord(word: 'ab', phoneStart: 0, phoneEnd: 2)],
  phones: [
    LexiconPhone(symbol: 'a', tokenIds: [2]),
    LexiconPhone(symbol: 'b', tokenIds: [3]),
  ],
);

const _exercise = Exercise(
  id: 'x',
  text: 'ab',
  words: [LexiconWord(word: 'ab', phoneStart: 0, phoneEnd: 2)],
  phones: [
    LexiconPhone(symbol: 'a', tokenIds: [2]),
    LexiconPhone(symbol: 'b', tokenIds: [3]),
  ],
);

const _spans = [
  TokenSpan(tokenId: 2, start: 0, end: 4),
  TokenSpan(tokenId: 3, start: 4, end: 8),
];

const _vocab = ['<pad>', '|', 'a', 'b', 'c', 'd'];

PronunciationResult _score(
  Float32List logProbs, {
  GopCalibration calibration = GopCalibration.fallback,
}) => const GopScorer().score(
  exercise: _exercise,
  spans: _spans,
  calibration: calibration,
  logProbs: logProbs,
  vocabSize: _vocab.length,
  frameSeconds: 0.02,
  symbolForId: _vocab,
  specialIds: const {0, 1},
);

void main() {
  test('the right phoneme, said clearly, scores high', () {
    final result = _score(_emissions(saidInSecondHalf: 3));

    expect(result.words.single.phones[1].score, greaterThan(80));
    expect(result.words.single.phones[1].heardInstead, isNull);
    expect(result.words.single.phones[1].margin, greaterThan(0));
  });

  test('a phoneme we cannot separate is scored but not diagnosed', () {
    // /b/ is told its two medians sit almost on top of each other, which is
    // the situation of /ɪ/ and /ʌ/ in English and /ɾ/ and /r/ in Spanish. The
    // learner said /c/, so the score must still fall - but claiming *which*
    // sound came out would be a confident guess.
    final result = _score(
      _emissions(saidInSecondHalf: 4),
      calibration: const GopCalibration(
        center: -1.75,
        scale: 0.80,
        phones: {'b': PhoneCalibration(center: -1.75, scale: 0.5)},
      ),
    );
    final phone = result.words.single.phones[1];

    expect(phone.score, lessThan(result.errorThreshold));
    expect(phone.heardInstead, isNull);
  });

  test('the error threshold follows the anchors it was fitted with', () {
    final strict = _score(
      _emissions(saidInSecondHalf: 3),
      calibration: const GopCalibration(
        center: -1.75,
        scale: 0.80,
        targetWrong: 0.10,
      ),
    );

    // Anchors of 0.90 and 0.10 put the boundary at 50, not at the 60 that
    // used to be typed into the scorer.
    expect(strict.errorThreshold, 50);
  });

  test('a substitution scores low and names what was heard', () {
    // /b/ carries a measured, well separated curve, which is what earns the
    // right to name the substitution. The learner said /c/ where /b/ was
    // written.
    final result = _score(
      _emissions(saidInSecondHalf: 4),
      calibration: const GopCalibration(
        center: -1.75,
        scale: 0.80,
        phones: {'b': PhoneCalibration(center: -1.75, scale: 2)},
      ),
    );
    final phone = result.words.single.phones[1];

    expect(phone.symbol, 'b');
    expect(phone.score, lessThan(result.errorThreshold));
    expect(phone.heardInstead, 'c');
    // Negative margin is the signal: a competitor beat the canonical phoneme.
    expect(phone.margin, lessThan(0));
  });

  test('an unmeasured phoneme is scored but never diagnosed', () {
    // Spanish /ð/ is in this bucket today: it appears in the prompts and the
    // calibration run could not fit it. A score still comes out; a claim
    // about what was said does not.
    final result = _score(_emissions(saidInSecondHalf: 4));

    expect(result.words.single.phones[1].score, isNotNull);
    expect(result.words.single.phones[1].heardInstead, isNull);
  });

  test('special tokens are never offered as what was heard', () {
    final result = _score(_emissions(saidInSecondHalf: 0));

    expect(result.words.single.phones[1].heardInstead, isNot('<pad>'));
  });

  test('the score is the pronunciation score, and fluency stays out', () {
    final result = _score(_emissions(saidInSecondHalf: 4));

    expect(result.overall, result.accuracy);
    // The substitution wrecked accuracy, yet the forced alignment still puts
    // every phoneme somewhere plausible in time - so fluency is high. That is
    // exactly the pair that used to inflate the score.
    expect(result.accuracy, lessThan(60));
    expect(result.fluency, greaterThan(result.accuracy));
  });

  test('each phoneme is scored on its own curve', () {
    final emissions = _emissions(saidInSecondHalf: 3);

    // The same audio, the same log posterior - but /b/ is told it is an easy
    // phoneme the model should be confident about, so the identical evidence
    // is worth less. That is the whole point: a GOP value is not comparable
    // across phonemes, so one curve for all of them mis-scores both ends.
    final strict = _score(
      emissions,
      calibration: const GopCalibration(
        center: -1.75,
        scale: 0.80,
        phones: {'b': PhoneCalibration(center: -0.05, scale: 0.05)},
      ),
    );
    final flat = _score(emissions);

    expect(
      strict.words.single.phones[1].score,
      lessThan(flat.words.single.phones[1].score),
    );
    // /a/ has no measured curve, so it falls back and is unaffected.
    expect(
      strict.words.single.phones[0].score,
      flat.words.single.phones[0].score,
    );
  });

  test('a single word reports no fluency at all', () {
    final phrase = _score(_emissions(saidInSecondHalf: 3));
    final word = const GopScorer().score(
      exercise: _word,
      spans: _spans,
      calibration: GopCalibration.fallback,
      logProbs: _emissions(saidInSecondHalf: 3),
      vocabSize: _vocab.length,
      frameSeconds: 0.02,
      symbolForId: _vocab,
      specialIds: const {0, 1},
    );

    // Rate and pauses are measured *between* words. On one word there is
    // nothing there, and a number would be the absence of evidence dressed
    // up as evidence.
    expect(word.fluency, isNull);
    expect(word.accuracy, phrase.accuracy);
    expect(phrase.fluency, isNotNull);
  });

  test('an empty result does not divide by zero', () {
    const empty = Exercise(id: 'e', text: '', words: [], phones: []);
    final result = const GopScorer().score(
      exercise: empty,
      spans: const [],
      calibration: GopCalibration.fallback,
      logProbs: Float32List(0),
      vocabSize: _vocab.length,
      frameSeconds: 0.02,
      symbolForId: _vocab,
      specialIds: const {0},
    );

    expect(result.overall, 0);
    expect(result.words, isEmpty);
  });
}
