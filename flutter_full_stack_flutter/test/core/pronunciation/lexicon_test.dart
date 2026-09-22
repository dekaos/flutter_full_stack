import 'dart:convert';

import 'package:flutter_full_stack_flutter/core/pronunciation/lexicon.dart';
import 'package:flutter_test/flutter_test.dart';

/// The shape `scorer/tool/build_lexicon.py` writes. This is the seam where
/// measured calibration reaches the app, so it is worth pinning: a silently
/// dropped `calibration` block would fall back to the guessed curve and score
/// every learner with it, with nothing failing.
const _json = '''
{
  "lang": "en",
  "model": "phoneme_en_r2.int8.onnx",
  "vocab": ["<pad>", "|", "a", "b"],
  "blankId": 0,
  "calibration": {
    "center": -1.9,
    "scale": 0.7,
    "phones": { "b": { "center": -0.8, "scale": 0.4 } }
  },
  "exercises": [
    {
      "id": "en-001",
      "text": "ab",
      "words": [{ "w": "ab", "p": [0, 2] }],
      "phones": [{ "s": "a", "t": [2] }, { "s": "b", "t": [3] }]
    }
  ]
}
''';

void main() {
  test('a lexicon carries the measured calibration', () {
    final lexicon = Lexicon.fromJson(
      json.decode(_json) as Map<String, dynamic>,
    );

    expect(lexicon.calibration.center, -1.9);
    expect(lexicon.calibration.isMeasured('b'), isTrue);
    expect(lexicon.calibration.phones['b']!.scale, 0.4);
    // A phoneme nobody has measured yet is not silently given someone
    // else's curve.
    expect(lexicon.calibration.isMeasured('a'), isFalse);
  });

  test('a lexicon with no calibration falls back rather than crashing', () {
    final raw = json.decode(_json) as Map<String, dynamic>
      ..remove('calibration');
    final lexicon = Lexicon.fromJson(raw);

    expect(lexicon.calibration.center, -1.75);
    expect(lexicon.calibration.phones, isEmpty);
  });

  test('the flat CTC target keeps every token of every phoneme', () {
    final lexicon = Lexicon.fromJson(
      json.decode(_json) as Map<String, dynamic>,
    );

    expect(lexicon.exercises.single.targetIds, [2, 3]);
    expect(lexicon.vocabSize, 4);
    expect(lexicon.specialIds, containsAll([0, 1]));
  });
}
