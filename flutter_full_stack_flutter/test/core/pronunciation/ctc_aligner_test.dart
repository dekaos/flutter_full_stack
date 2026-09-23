import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_full_stack_flutter/core/pronunciation/ctc_aligner.dart';
import 'package:flutter_test/flutter_test.dart';

/// The fixture is produced by `scorer/tool/make_align_fixture.py` from
/// `torchaudio.functional.forced_align`, which is what the Python reference
/// scorer uses. Locking the Dart port to it frame by frame is the only way to
/// know the two agree - a score can look plausible and still come from a
/// misaligned phoneme.
void main() {
  const aligner = CtcAligner();

  final fixture = json.decode(
    File('test/fixtures/ctc_alignment.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final cases = (fixture['cases'] as List).cast<Map<String, dynamic>>();

  group('CtcAligner matches the torchaudio reference', () {
    for (var i = 0; i < cases.length; i++) {
      final testCase = cases[i];
      final targets = (testCase['targets'] as List).cast<int>();

      test('case $i, targets $targets', () {
        final spans = aligner.align(
          logProbs: Float32List.fromList(
            (testCase['logProbs'] as List)
                .cast<num>()
                .map((v) => v.toDouble())
                .toList(),
          ),
          frames: testCase['frames'] as int,
          vocabSize: testCase['vocabSize'] as int,
          targets: targets,
          blankId: 0,
        );

        final expected = (testCase['expected'] as List)
            .cast<Map<String, dynamic>>();
        expect(spans.length, expected.length);
        for (var s = 0; s < spans.length; s++) {
          expect(spans[s].tokenId, expected[s]['tokenId'], reason: 'token $s');
          expect(spans[s].start, expected[s]['start'], reason: 'start $s');
          expect(spans[s].end, expected[s]['end'], reason: 'end $s');
        }
      });
    }
  });

  test('rejects audio shorter than the prompt', () {
    expect(
      () => aligner.align(
        logProbs: Float32List(8),
        frames: 2,
        vocabSize: 4,
        targets: const [1, 2, 3],
        blankId: 0,
      ),
      throwsArgumentError,
    );
  });
}
