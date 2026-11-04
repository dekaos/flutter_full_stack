import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
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

  test('a prompt carries its topic, and loses only that to an unknown one', () {
    Exercise parse(Map<String, dynamic> extra) {
      final raw = json.decode(_json) as Map<String, dynamic>;
      ((raw['exercises'] as List).single as Map<String, dynamic>).addAll(extra);
      return Lexicon.fromJson(raw).exercises.single;
    }

    expect(parse({'topic': 'coffee'}).topic, PromptTopic.coffee);
    expect(parse({}).topic, isNull);
    // A lexicon built for a newer app must still open on this one: the
    // prompt stays, the picture goes.
    final newer = parse({'topic': 'volcano'});
    expect(newer.topic, isNull);
    expect(newer.text, 'ab');
  });

  testWidgets('only the English phrases have a scene', (tester) async {
    // The product rule, pinned where the content lives. Giving a Spanish
    // phrase or an English word a topic is a decision, so it should fail
    // here and be changed on purpose rather than slip in.
    //
    // rootBundle caches the *future* of every asset it loads, and these were
    // created in this test's fake clock. A later test awaiting the cached
    // Korean lexicon would wait on a clock nobody advances any more - forever.
    addTearDown(rootBundle.clear);
    final english = await Lexicon.load('en');
    for (final exercise in english.exercises) {
      if (exercise.kind == ExerciseKind.phrase) {
        // Also what catches a typo in scorer/exercises/en.json: an unknown
        // topic parses to null rather than failing anywhere else.
        expect(exercise.topic, isNotNull, reason: '${exercise.id}: no topic');
      } else {
        expect(exercise.topic, isNull, reason: '${exercise.id}: a word');
      }
    }
    for (final lang in ['es', 'ko']) {
      final lexicon = await Lexicon.load(lang);
      expect(
        lexicon.exercises.where((e) => e.topic != null),
        isEmpty,
        reason: '$lang has no scenes',
      );
    }
  });

  testWidgets('the bundled Korean lexicon parses fully resolved', (
    tester,
  ) async {
    // Pins the contract with scorer/tool/build_lexicon.py: a phoneme the
    // G2P could not map would arrive with empty token ids and be scored as
    // silence, and nothing would fail.
    final lexicon = await Lexicon.load('ko');

    expect(lexicon.lang, 'ko');
    expect(lexicon.model, 'phoneme_ko_r2.int8.onnx');
    expect(lexicon.exercises, isNotEmpty);
    for (final exercise in lexicon.exercises) {
      for (final phone in exercise.phones) {
        expect(
          phone.tokenIds,
          isNotEmpty,
          reason: '${exercise.id}: /${phone.symbol}/ sem id no vocabulario',
        );
      }
    }
    // The Korean calibration is measured (22 of 23 phonemes), so the global
    // curve must not be the guessed fallback.
    expect(lexicon.calibration.isMeasured('ɔ'), isTrue);
  });
}
