import 'dart:typed_data';

/// The frames a single CTC target token occupies, after alignment.
class TokenSpan {
  const TokenSpan({
    required this.tokenId,
    required this.start,
    required this.end,
  });

  final int tokenId;

  /// First frame, inclusive.
  final int start;

  /// Last frame, exclusive.
  final int end;
}

/// Viterbi forced alignment of an emission matrix against a known token
/// sequence.
///
/// This is the same algorithm as `torchaudio.functional.forced_align`, which
/// the Python reference scorer in `scorer/` uses: the target is expanded to
/// `blank, t0, blank, t1, ... blank` and the best monotonic path through that
/// lattice is taken. Because the prompt is known, there is no search over what
/// was said - only over *when* each phoneme was said.
///
/// `logProbs` is row-major `frames x vocabSize`, already log-softmaxed.
class CtcAligner {
  const CtcAligner();

  List<TokenSpan> align({
    required Float32List logProbs,
    required int frames,
    required int vocabSize,
    required List<int> targets,
    required int blankId,
  }) {
    if (targets.isEmpty || frames == 0) return const [];

    // Expanded sequence: blank between every target, and at both ends.
    final states = 2 * targets.length + 1;
    if (frames < targets.length) {
      throw ArgumentError(
        'audio too short: $frames frames for ${targets.length} tokens',
      );
    }

    int symbolAt(int s) => s.isOdd ? targets[(s - 1) ~/ 2] : blankId;
    double emission(int t, int s) => logProbs[t * vocabSize + symbolAt(s)];

    const negInf = -1e30;
    var previous = Float64List(states)..fillRange(0, states, negInf);
    var current = Float64List(states);
    // Which of the three incoming transitions was taken, per frame and state.
    final back = Uint8List(frames * states);

    previous[0] = emission(0, 0);
    if (states > 1) previous[1] = emission(0, 1);

    for (var t = 1; t < frames; t++) {
      current.fillRange(0, states, negInf);
      for (var s = 0; s < states; s++) {
        // Staying in the same state is always allowed.
        var best = previous[s];
        var hop = 0;
        if (s > 0 && previous[s - 1] > best) {
          best = previous[s - 1];
          hop = 1;
        }
        // Skipping a blank is allowed only between two *different* symbols;
        // otherwise CTC would merge the repeated pair into one.
        final canSkip = s > 1 && s.isOdd && symbolAt(s) != symbolAt(s - 2);
        if (canSkip && previous[s - 2] > best) {
          best = previous[s - 2];
          hop = 2;
        }
        if (best <= negInf) continue;
        current[s] = best + emission(t, s);
        back[t * states + s] = hop;
      }
      final swap = previous;
      previous = current;
      current = swap;
    }

    // The path must end on the last symbol or on the trailing blank.
    var state = states - 1;
    if (states > 1 && previous[states - 2] > previous[states - 1]) {
      state = states - 2;
    }

    final path = Int32List(frames);
    for (var t = frames - 1; t >= 0; t--) {
      path[t] = state;
      if (t > 0) state -= back[t * states + state];
    }

    // Collapse the frame path into one span per target token.
    final spans = <TokenSpan>[];
    var index = 0;
    var start = -1;
    for (var t = 0; t < frames; t++) {
      final s = path[t];
      final isTarget = s.isOdd;
      final which = isTarget ? (s - 1) ~/ 2 : -1;
      if (isTarget && which == index && start < 0) {
        start = t;
      } else if (start >= 0 && which != index) {
        spans.add(
          TokenSpan(tokenId: targets[index], start: start, end: t),
        );
        index++;
        start = isTarget && which == index ? t : -1;
      }
    }
    if (start >= 0 && index < targets.length) {
      spans.add(
        TokenSpan(tokenId: targets[index], start: start, end: frames),
      );
    }
    return spans;
  }
}
