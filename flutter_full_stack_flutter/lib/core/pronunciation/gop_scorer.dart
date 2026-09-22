import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_full_stack_flutter/core/pronunciation/calibration.dart';
import 'package:flutter_full_stack_flutter/core/pronunciation/ctc_aligner.dart';
import 'package:flutter_full_stack_flutter/core/pronunciation/lexicon.dart';

/// How one phoneme came out.
class PhoneScore {
  const PhoneScore({
    required this.symbol,
    required this.start,
    required this.end,
    required this.logPosterior,
    required this.margin,
    required this.score,
    this.heardInstead,
  });

  final String symbol;

  /// Seconds from the start of the recording.
  final double start;
  final double end;

  /// Mean log posterior of the canonical phoneme over its own frames.
  final double logPosterior;

  /// How far ahead the canonical phoneme was of its best competitor. A
  /// negative margin means the model heard something else more strongly.
  final double margin;

  /// 0-100, from this phoneme's curve in [GopCalibration].
  final double score;

  /// The phoneme the model heard instead - present only when this one scored
  /// badly *and* the measurement separates it from its usual substitute well
  /// enough to say so. Null covers both "it was fine" and "we cannot tell",
  /// and the caller must not read it as the first.
  final String? heardInstead;
}

class WordScore {
  const WordScore({
    required this.word,
    required this.start,
    required this.end,
    required this.score,
    required this.phones,
    this.weakest,
  });

  final String word;
  final double start;
  final double end;
  final double score;
  final List<PhoneScore> phones;

  /// The phoneme that dragged the word down, if any did. Set by the scorer,
  /// which is what knows where an error begins on the calibrated scale.
  final PhoneScore? weakest;
}

class PronunciationResult {
  const PronunciationResult({
    required this.overall,
    required this.accuracy,
    required this.fluency,
    required this.speechRate,
    required this.pauses,
    required this.words,
    this.errorThreshold = 60,
  });

  final double overall;
  final double accuracy;

  /// Null when the prompt is a single word: rate and pauses are measured
  /// *between* words, so there is nothing there to measure. Reporting a number
  /// anyway would be reporting the absence of evidence as evidence.
  final double? fluency;

  /// The score below which an attempt counts as an error rather than an
  /// accent, on the scale this result was produced with. Carried along so the
  /// UI colours against the same scale that produced the numbers.
  final double errorThreshold;

  /// Phonemes per second across the spoken span.
  final double speechRate;
  final int pauses;
  final List<WordScore> words;
}

/// Goodness of Pronunciation over a CTC alignment.
///
/// For each phoneme the aligner says *when* it was said; this says *how well*.
/// The measure is the mean log posterior of the canonical phoneme over its own
/// frames, plus the margin to the best competing phoneme - which is what
/// identifies a substitution, the error learners actually make.
class GopScorer {
  const GopScorer({this.pauseThreshold = 0.30});

  /// A gap between two words longer than this counts as a hesitation.
  final double pauseThreshold;

  PronunciationResult score({
    required Exercise exercise,
    required GopCalibration calibration,
    required List<TokenSpan> spans,
    required Float32List logProbs,
    required int vocabSize,
    required double frameSeconds,
    required List<String> symbolForId,
    required Set<int> specialIds,
  }) {
    final phoneScores = <PhoneScore>[];
    var cursor = 0;

    for (final phone in exercise.phones) {
      final mine = spans.skip(cursor).take(phone.tokenIds.length).toList();
      cursor += phone.tokenIds.length;
      if (mine.isEmpty) continue;

      // Every token of the phoneme is judged inside its own window: a
      // decomposed diphthong has two, and averaging them over the union would
      // score each token against frames that are not its own.
      var logPosterior = 0.0;
      final meanByToken = Float64List(vocabSize);
      for (var i = 0; i < mine.length; i++) {
        final span = mine[i];
        final end = math.max(span.end, span.start + 1);
        final frames = end - span.start;
        for (var v = 0; v < vocabSize; v++) {
          var sum = 0.0;
          for (var t = span.start; t < end; t++) {
            sum += logProbs[t * vocabSize + v];
          }
          meanByToken[v] += sum / frames / mine.length;
        }
        var own = 0.0;
        for (var t = span.start; t < end; t++) {
          own += logProbs[t * vocabSize + phone.tokenIds[i]];
        }
        logPosterior += own / frames / mine.length;
      }

      final excluded = {...specialIds, ...phone.tokenIds};
      var bestId = -1;
      var bestValue = double.negativeInfinity;
      for (var v = 0; v < vocabSize; v++) {
        if (excluded.contains(v)) continue;
        if (meanByToken[v] > bestValue) {
          bestValue = meanByToken[v];
          bestId = v;
        }
      }

      final score = calibration.toScore(phone.symbol, logPosterior);
      // The score is always reported. The name of the error is not: on a
      // phoneme whose medians sit close together, a competitor winning is
      // weak evidence, and a confident wrong diagnosis sends the learner to
      // practise the wrong thing.
      final failed = score < calibration.errorThreshold;
      phoneScores.add(
        PhoneScore(
          symbol: phone.symbol,
          start: mine.first.start * frameSeconds,
          end: mine.last.end * frameSeconds,
          logPosterior: logPosterior,
          margin: logPosterior - bestValue,
          score: score,
          heardInstead:
              failed && bestId >= 0 && calibration.canNameError(phone.symbol)
              ? symbolForId[bestId]
              : null,
        ),
      );
    }

    final words = <WordScore>[];
    for (final word in exercise.words) {
      if (word.phoneStart >= phoneScores.length) continue;
      final end = math.min(word.phoneEnd, phoneScores.length);
      final group = phoneScores.sublist(word.phoneStart, end);
      if (group.isEmpty) continue;
      words.add(
        WordScore(
          word: word.word,
          start: group.first.start,
          end: group.last.end,
          score:
              group.map((p) => p.score).reduce((a, b) => a + b) / group.length,
          phones: group,
        ),
      );
    }

    return _aggregate(words, exercise.kind, calibration.errorThreshold);
  }

  PronunciationResult _aggregate(
    List<WordScore> words,
    ExerciseKind kind,
    double errorThreshold,
  ) {
    if (words.isEmpty) {
      return PronunciationResult(
        overall: 0,
        accuracy: 0,
        fluency: null,
        speechRate: 0,
        pauses: 0,
        words: const [],
        errorThreshold: errorThreshold,
      );
    }

    var weighted = 0.0;
    var total = 0;
    for (final word in words) {
      weighted += word.score * word.phones.length;
      total += word.phones.length;
    }
    final accuracy = weighted / total;

    var pauses = 0;
    for (var i = 1; i < words.length; i++) {
      if (words[i].start - words[i - 1].end > pauseThreshold) pauses++;
    }

    final spoken = math.max(1e-6, words.last.end - words.first.start);
    final rate = total / spoken;
    // Running speech sits around 9-15 phonemes per second; outside that band
    // the learner is either reading word by word or rushing.
    var penalty = pauses.toDouble() * 8;
    if (rate < 9) penalty += (9 - rate) * 6;
    if (rate > 15) penalty += (rate - 15) * 4;
    final fluency = kind == ExerciseKind.word
        ? null
        : (100 - penalty).clamp(0, 100).toDouble();

    return PronunciationResult(
      // The score *is* the pronunciation score. [fluency] is reported beside
      // it but deliberately kept out: it can only lose points for a pause or
      // a rate outside its band, so it sits near 100 on almost any attempt
      // and, blended in, quietly lifted a bad reading - 45 accuracy and 92
      // fluency came out as 57. Worse, its inputs are the alignment's
      // durations, and the alignment is *forced*: every canonical phoneme is
      // placed somewhere however badly it was said, so the timing stays
      // plausible exactly when the pronunciation is not. It earns a place in
      // the score once it measures within-word hesitation, lengthened vowels
      // and stress - and once the bands come from recordings rather than
      // from a guess.
      overall: accuracy,
      accuracy: accuracy,
      fluency: fluency,
      speechRate: rate,
      pauses: pauses,
      words: words,
      errorThreshold: errorThreshold,
    );
  }
}
