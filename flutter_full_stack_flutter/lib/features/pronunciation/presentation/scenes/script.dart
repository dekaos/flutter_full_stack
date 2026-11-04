import 'dart:ui' show TextRange;

import 'package:flutter/foundation.dart' show immutable;

import 'package:flutter_full_stack_flutter/core/audio/sound.dart';
import 'package:flutter_full_stack_flutter/features/pronunciation/presentation/scenes/iso_stage.dart';

/// One beat of a scene's story: the moment something the sentence says
/// happens in the picture, and the [words] of the sentence that say it.
///
/// The scene times that something by [at]. The [words] are what keeps the
/// picture honest to its sentence: a test checks every cue's words are still
/// in it, so a reworded sentence cannot leave its scene acting out another.
@immutable
class Cue {
  const Cue(this.words, this.at);

  /// The words as they are written in the sentence, one or a run of them.
  /// Matched whole and ignoring case.
  final String words;

  /// When, as a fraction of the arrival. Inside act two.
  final double at;

  /// Where [words] first stand in [text], or `null` if they do not.
  TextRange? findIn(String text) {
    final match = RegExp(
      '\\b${RegExp.escape(words)}\\b',
      caseSensitive: false,
    ).firstMatch(text);
    return match == null ? null : TextRange(start: match.start, end: match.end);
  }
}

/// A sound a scene makes as its story is told: [sound], at [at] of the
/// arrival - the same clock, and so the same constants, its drawing keeps
/// time by, so the bell is heard as the clock strikes and not near it.
@immutable
class SceneSound {
  const SceneSound(this.sound, this.at);

  final Sound sound;

  /// When, as a fraction of the arrival. Inside act two.
  final double at;

  /// When to start it, as a fraction of an [arrival] that long: ahead of
  /// [at] by however long the sound takes to reach the moment it marks
  /// ([Sound.hit]) - a wave's swell before its break.
  double startIn(Duration arrival) =>
      at - sound.hit.inMicroseconds / arrival.inMicroseconds;
}

/// A scene: how to paint it, the [cues] of the story it tells, and the
/// [sounds] it makes telling it.
@immutable
class SceneScript {
  const SceneScript(
    this.paint, {
    required this.cues,
    this.sounds = const [],
    this.catWalks = false,
  });

  /// Paints the scene at the stage's moment of the arrival.
  final void Function(IsoStage stage) paint;

  /// The story's beats, in the order they happen.
  final List<Cue> cues;

  /// What is heard while the story is told, in the order it happens. A
  /// scene is heard only as it arrives, as it only moves then: at rest it
  /// is as quiet as it is still.
  final List<SceneSound> sounds;

  /// Whether the hiding cat comes out on foot rather than rising out of its
  /// hiding place (`IsoStage.hidingCat`) - which also decides when, through
  /// its visit, it is heard.
  final bool catWalks;
}
