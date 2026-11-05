import 'package:flutter/painting.dart';

/// CNA's logo: the official vector, as cna.com.br serves it
/// (`https://media.cna.com.br/cna_logo_3ff9a4f2fc.svg`) - its outlines,
/// unchanged, on its own 233 x 62.8796 canvas. Not a redrawing: the brand's
/// letters are its own, and they are reproduced, not imitated.
///
/// To update it, replace [_outlines] with the `d` of each `<path>` in a new
/// copy of that file, in order, and [width] and [height] with its
/// `viewBox`.
abstract final class CnaLogo {
  /// The logo's own canvas.
  static const width = 233;
  static const height = 62.8796;

  /// Width over height: the logo is a wordmark, much wider than tall.
  static const double aspect = width / height;

  /// The whole logo as one path, in its own units.
  static final Path path = _parse(_outlines);

  /// Each letter's outline - two strokes each, the double line CNA's
  /// letters are drawn in - as SVG path data.
  static const List<String> _outlines = [_c1, _c2, _n1, _n2, _a1, _a2, _a3];

  // The C, in two strokes; the N, in two; the A, its outer stroke, its
  // inner one and its bar.
  static const _c1 =
      'M32.6726 55.7192C18.4199 55.7192 6.82268 44.8 6.82268 '
      '31.3798C6.82268 17.9595 18.4199 7.04493 32.6726 '
      '7.04493H67.4596V2.89264C67.4596 1.31555 66.1969 0.0348913 64.6419 '
      '0.0348913H32.7982C14.7117 0.0348913 0 14.1106 0 31.4214C0 48.7323 '
      '14.7117 62.808 32.7982 62.808H64.6419C66.1969 62.808 67.4596 '
      '61.525 67.4596 59.9503V55.7215H32.6726V55.7192Z';
  static const _c2 =
      'M32.7982 17.1719H64.6419C66.1969 17.1719 67.4596 15.8867 67.4596 '
      '14.3119V10.0044H32.6749C20.0296 10.0044 9.74081 19.5943 9.74081 '
      '31.3796C9.74081 43.1649 20.0296 52.7594 32.6749 '
      '52.7594H67.4596V48.5307C67.4596 46.9536 66.1992 45.673 64.6419 '
      '45.673H32.7982C24.0301 45.673 16.8969 39.2813 16.8969 '
      '31.4213C16.8969 23.5613 24.0301 17.1743 32.7982 17.1743';
  static const _n1 =
      'M144.998 4.14138e-06H140.411V49.5288C140.411 50.1564 139.737 '
      '50.5501 139.203 50.2352L85.1397 18.2465C84.6031 17.9269 83.9295 '
      '18.3206 83.9295 18.9505V62.8704L88.5556 62.8796C89.6036 62.8796 '
      '90.453 62.0158 90.453 60.9575V29.652L144.032 61.9649C144.756 '
      '62.4049 145.715 62.2845 146.315 61.7009C146.692 61.335 146.898 '
      '60.844 146.898 60.3114V1.9291C146.898 0.866128 146.046 0.00232047 '
      '145 0.00232047';
  static const _n2 =
      'M81.0113 13.8047C81.0113 13.1748 81.6849 12.7811 82.2215 '
      '13.0984L136.285 45.0894C136.821 45.4043 137.495 45.0153 137.495 '
      '44.383V4.14138e-06H132.773C131.725 4.14138e-06 130.875 0.863813 '
      '130.875 1.92678V33.2624L77.4927 1.1695C77.1981 0.993499 76.8625 '
      '0.89855 76.5245 0.89855C75.4765 0.89855 74.6248 1.76467 74.6248 '
      '2.82301V60.8209C74.6248 62.0714 75.4673 62.8519 76.8168 '
      '62.8519L81.0091 62.8611V13.8047H81.0113Z';
  static const _a1 =
      'M214.551 49.0309C214.424 48.8295 214.204 48.7044 213.962 '
      '48.7044H172.567C172.332 48.7044 172.111 48.8295 171.983 '
      '49.0309L163.473 62.8241H169.889C170.478 62.8241 171.015 62.5276 '
      '171.33 62.0205L176.275 54.0355L210.019 54.0053L215.067 '
      '62.0274C215.383 62.5253 215.921 62.8241 216.504 '
      '62.8241H223.16L214.549 49.0309H214.551Z';
  static const _a2 =
      'M232.729 60.1632L195.161 0.842972C194.848 0.345067 194.309 '
      '0.0486393 193.729 0.0486393C193.149 0.0486393 192.631 0.335803 '
      '192.316 0.815181L153.024 60.1354C152.675 60.668 152.638 61.3466 '
      '152.935 61.9093C153.232 62.479 153.807 62.8241 154.437 '
      '62.8241H160.002L192.855 10.727C193.131 10.2985 193.755 10.2985 '
      '194.029 10.7362L226.651 62.8264H231.298C231.921 62.8264 232.492 '
      '62.4813 232.791 61.9278C233.09 61.3744 233.067 60.6981 232.729 '
      '60.1655';
  static const _a3 =
      'M211.802 44.6447L194.01 16.2502C193.739 15.8149 193.113 15.8149 '
      '192.837 16.2456L174.775 44.6401C174.476 45.1102 174.809 45.7262 '
      '175.36 45.7262H211.215C211.763 45.7262 212.097 45.1125 211.802 '
      '44.6447ZM200.075 39.1794H186.902C186.258 39.1794 185.861 38.4614 '
      '186.201 37.908L192.613 27.3547C192.928 26.8313 193.675 26.822 '
      '194.003 27.3385L200.767 37.8918C201.121 38.4452 200.73 39.1794 '
      '200.075 39.1794Z';

  /// SVG path data to a [Path]. The logo uses only absolute moves, lines,
  /// horizontals, verticals, cubic curves and closes, so that is all this
  /// reads.
  static Path _parse(List<String> outlines) {
    final path = Path();
    final token = RegExp(r'[MLHVCZ]|-?\d*\.?\d+(?:e[-+]?\d+)?');
    for (final outline in outlines) {
      final tokens = [for (final m in token.allMatches(outline)) m[0]!];
      var i = 0;
      var x = 0.0;
      var y = 0.0;
      double next() => double.parse(tokens[i++]);
      var command = 'M';
      while (i < tokens.length) {
        if (RegExp('[MLHVCZ]').hasMatch(tokens[i])) command = tokens[i++];
        switch (command) {
          case 'M':
            path.moveTo(x = next(), y = next());
            command = 'L';
          case 'L':
            path.lineTo(x = next(), y = next());
          case 'H':
            path.lineTo(x = next(), y);
          case 'V':
            path.lineTo(x, y = next());
          case 'C':
            path.cubicTo(
              next(),
              next(),
              next(),
              next(),
              x = next(),
              y = next(),
            );
          case 'Z':
            path.close();
        }
      }
    }
    return path;
  }
}
