/// The three bands an attempt's score falls in. Everything that answers a
/// score follows the same three - its colour, its chime, the hiding cat -
/// so they can never disagree about how an attempt went.
enum ScoreBand {
  /// Below the line where an error starts.
  weak,

  fair,

  /// 80 and over.
  strong;

  /// The band [score] is in, on a scale whose errors start at
  /// [errorThreshold]. That line comes from the calibration, so
  /// recalibrating moves the bands with the numbers instead of leaving them
  /// pointing at an old scale.
  static ScoreBand of(double score, double errorThreshold) {
    if (score >= 80) return strong;
    if (score >= errorThreshold) return fair;
    return weak;
  }
}
