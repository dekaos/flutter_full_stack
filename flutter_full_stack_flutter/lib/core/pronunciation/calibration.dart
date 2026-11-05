import 'dart:math' as math;

/// The curve for one phoneme.
class PhoneCalibration {
  const PhoneCalibration({required this.center, required this.scale});

  factory PhoneCalibration.fromJson(Map<String, dynamic> json) =>
      PhoneCalibration(
        center: (json['center'] as num).toDouble(),
        scale: (json['scale'] as num).toDouble(),
      );

  /// The log posterior that comes out as 50.
  final double center;

  /// How harsh the curve is. Smaller is steeper.
  final double scale;
}

/// Maps a log posterior onto 0-100, per phoneme.
///
/// One curve for every phoneme would be wrong even with perfect data. A GOP
/// value is not comparable across phonemes: the model is near-certain about a
/// /s/, which has no close neighbour, and structurally unsure about a /ə/,
/// which is confusable with half the vowel inventory. A single curve therefore
/// punishes schwa for being schwa and flatters every sibilant.
///
/// So the numbers live in the lexicon, not here: each phoneme's [center] is
/// meant to be the median log posterior of *native* speakers saying it, which
/// is a measurement, and measurements do not belong in source. [fallback] is
/// what a phoneme with no measurement yet gets.
class GopCalibration {
  const GopCalibration({
    required this.center,
    required this.scale,
    this.targetNative = 0.90,
    this.targetWrong = 0.30,
    this.phones = const {},
  });

  factory GopCalibration.fromJson(Map<String, dynamic>? json) {
    if (json == null) return fallback;
    final phones = (json['phones'] as Map<String, dynamic>? ?? {}).map(
      (symbol, value) => MapEntry(
        symbol,
        PhoneCalibration.fromJson(value as Map<String, dynamic>),
      ),
    );
    return GopCalibration(
      center: (json['center'] as num?)?.toDouble() ?? fallback.center,
      scale: (json['scale'] as num?)?.toDouble() ?? fallback.scale,
      targetNative:
          (json['targetNative'] as num?)?.toDouble() ?? fallback.targetNative,
      targetWrong:
          (json['targetWrong'] as num?)?.toDouble() ?? fallback.targetWrong,
      phones: phones,
    );
  }

  /// Educated guesses, for a language with no calibration file at all. Both
  /// shipped languages have one, measured, whose global curve stands in for
  /// any phoneme without its own - Spanish /ð/ today. So these two numbers
  /// score nothing the app shows; they are the floor under a new language.
  static const fallback = GopCalibration(center: -1.75, scale: 0.80);

  final double center;
  final double scale;

  /// The anchors the curves were fitted against: the native median comes out
  /// as [targetNative], the typical learner error as [targetWrong]. They
  /// travel with the data because everything derived from the scale - where
  /// an error begins, how many nats a curve is worth - only means anything
  /// relative to them. Hard-coding a threshold in the app would silently stop
  /// matching the day these move.
  final double targetNative;
  final double targetWrong;

  /// Per-phoneme curves, keyed by IPA symbol. Empty until measured.
  final Map<String, PhoneCalibration> phones;

  /// Below this score, an attempt counts as an error rather than an accent.
  /// Midway between the two anchors, so recalibrating moves it too.
  double get errorThreshold => (targetNative + targetWrong) * 50;

  /// How far apart the native and error medians were, in nats, for [symbol].
  ///
  /// The fit divides that distance by the logit gap between the anchors, so
  /// multiplying back recovers what was actually measured.
  double? separationOf(String symbol) {
    final tuned = phones[symbol];
    if (tuned == null) return null;
    final gap =
        math.log(targetNative / (1 - targetNative)) -
        math.log(targetWrong / (1 - targetWrong));
    return tuned.scale * gap;
  }

  /// Whether [symbol] has a measured curve of its own.
  bool isMeasured(String symbol) => phones.containsKey(symbol);

  /// Whether the model separates this phoneme from its usual substitute well
  /// enough to say *what* was heard instead.
  ///
  /// The score always comes out; naming the substitution does not. Where the
  /// two medians sit close together - /ɪ/ and /ʌ/ in English, /ɾ/ and /r/ in
  /// Spanish, which are exactly the contrasts learners drill - a competitor
  /// winning is weak evidence, and telling someone they said a specific wrong
  /// sound on weak evidence is worse than telling them nothing. The colour on
  /// the word already says where the trouble is.
  bool canNameError(String symbol) =>
      (separationOf(symbol) ?? 0) >= minSeparationToName;

  /// In nats. Below this, the verdict is not reported.
  static const minSeparationToName = 5.0;

  double toScore(String symbol, double logPosterior) {
    final tuned = phones[symbol];
    final phoneCenter = tuned?.center ?? center;
    final phoneScale = tuned?.scale ?? scale;
    return 100 / (1 + math.exp(-(logPosterior - phoneCenter) / phoneScale));
  }
}
