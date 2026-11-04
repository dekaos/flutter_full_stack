import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:flutter_full_stack_flutter/core/pronunciation/lexicon.dart';
import 'package:flutter_full_stack_flutter/features/pronunciation/presentation/prompt_scene.dart';
import 'package:flutter_full_stack_flutter/features/pronunciation/presentation/scenes/iso_stage.dart';
import 'package:flutter_full_stack_flutter/features/pronunciation/presentation/scenes/script.dart';
import 'package:flutter_full_stack_flutter/theme/scene_tone.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('a cue', () {
    test('finds its words whole, whatever their case', () {
      const sentence = 'The red car stopped at the traffic light';
      expect(
        const Cue('red car', 0.5).findIn(sentence),
        const TextRange(start: 4, end: 11),
      );
      expect(const Cue('Traffic Light', 0.5).findIn(sentence), isNotNull);
      // Part of a word is not the word.
      expect(const Cue('top', 0.5).findIn(sentence), isNull);
      expect(const Cue('bus', 0.5).findIn(sentence), isNull);
    });
  });

  test('act one has a timeline of its own, and the story the real one', () {
    final stage = IsoStage(
      Canvas(PictureRecorder()),
      const Size(390, 844),
      Act.setting / 2,
      const SceneTone(40, 98),
      haze: const Color(0xFFFFFFFF),
    );
    late double setting;
    late double story;
    stage.setting(() {
      setting = stage.t;
      stage.story(() => story = stage.t);
    });

    expect(setting, closeTo(0.5, 1e-9));
    expect(story, Act.setting / 2);
    expect(stage.t, Act.setting / 2);
  });

  test('the story is lit only once the world is set, and stays lit', () {
    double lightAt(double clock) => IsoStage(
      Canvas(PictureRecorder()),
      const Size(390, 844),
      clock,
      const SceneTone(40, 98),
      haze: const Color(0xFFFFFFFF),
    ).storyLight;

    expect(lightAt(0.2), 0);
    expect(lightAt(0.6), 1);
    expect(lightAt(1), allOf(greaterThan(0.5), lessThan(1)));
  });

  // The scenes are written against the sentences, but the sentences live in
  // the lexicon, as content. This is what notices when one is reworded and
  // its scene still lights words that are no longer there.
  test('every English phrase has a story told on its own words', () async {
    addTearDown(rootBundle.clear);
    final lexicon = await Lexicon.load('en');
    final phrases = lexicon.byKind(ExerciseKind.phrase);
    expect(phrases, isNotEmpty);

    for (final phrase in phrases) {
      final topic = phrase.topic;
      expect(topic, isNotNull, reason: phrase.id);
      final cues = PromptScene.scriptOf(topic!).cues;
      final where = '${topic.name}: "${phrase.text}"';

      expect(cues, isNotEmpty, reason: '$where tells no story');
      for (final (i, cue) in cues.indexed) {
        expect(
          cue.findIn(phrase.text),
          isNotNull,
          reason: '$where has no "${cue.words}"',
        );
        // Act two, after the world is set and before the light settles.
        expect(
          cue.at,
          inExclusiveRange(Act.setting, Act.told),
          reason: '$where: "${cue.words}" at ${cue.at}',
        );
        // In the order they happen, far enough apart to be seen one by one.
        if (i > 0) {
          expect(
            cue.at - cues[i - 1].at,
            greaterThanOrEqualTo(0.08),
            reason: '$where: "${cue.words}" crowds the beat before it',
          );
        }
      }
    }
  });

  test('every scene is heard while its story is told, in order, and not '
      'after', () {
    for (final topic in PromptTopic.values) {
      final sounds = PromptScene.scriptOf(topic).sounds;
      expect(sounds, isNotEmpty, reason: '${topic.name} is silent');
      for (final (i, cue) in sounds.indexed) {
        final where = '${topic.name}: ${cue.sound.name} at ${cue.at}';
        // Started ahead by however long it takes to get to its moment, and
        // still inside act two.
        final start = cue.startIn(PromptScene.arrival);
        expect(start, greaterThanOrEqualTo(Act.setting), reason: where);
        expect(cue.at, lessThan(Act.told), reason: where);
        if (i > 0) {
          expect(cue.at, greaterThanOrEqualTo(sounds[i - 1].at), reason: where);
        }
      }
    }
  });

  test('the cats that walk out are the three that hide at ground level', () {
    expect(
      [
        for (final topic in PromptTopic.values)
          if (PromptScene.scriptOf(topic).catWalks) topic,
      ],
      unorderedEquals([PromptTopic.hotel, PromptTopic.help, PromptTopic.beach]),
    );
  });
}
