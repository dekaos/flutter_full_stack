import 'dart:async';

import 'package:flutter_full_stack_flutter/core/audio/phrase_voice.dart';
import 'package:flutter_full_stack_flutter/core/audio/sound_board.dart';
import 'package:flutter_full_stack_flutter/core/pronunciation/lexicon.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'practice_audio.g.dart';

/// Everything practice plays, for as long as the app runs: the sounds are
/// made once, and the platform's players are not worth setting up again
/// for every visit. Overridden in tests, which have no speakers.
@Riverpod(keepAlive: true)
SoundBoard soundBoard(Ref ref) {
  final board = SoundBoard(
    output: PlatformSoundOutput(),
    voice: PlatformPhraseVoice(),
  );
  ref
    ..onDispose(board.dispose)
    ..listen(
      soundEffectsProvider,
      (_, on) => board.effects = on,
      fireImmediately: true,
    );
  return board;
}

/// Whether the scenes, the cat and the score make their sounds. The voice
/// reading a prompt aloud is not one of them: the learner asks for that,
/// and it is part of the lesson.
///
/// On to begin with, and not persisted - like the theme and the language,
/// for the same reason: that needs a storage dependency nothing here has
/// yet. Restarting the app turns the sounds back on.
@Riverpod(keepAlive: true)
class SoundEffects extends _$SoundEffects {
  @override
  bool build() => true;

  void toggle() => state = !state;
}

/// Gets practice's sound ready, for every language it is offered in, once
/// [delay] is up - unless the timer this returns is cancelled first, as a
/// screen that goes away does.
///
/// Waited for, rather than done at once, because it is work - the sounds
/// made, the players set up, the voices found - that must not compete with
/// an entrance: the language screen's, or a scene's (`SoundBoard.warm`).
Timer warmPracticeSoundAfter(WidgetRef ref, Duration delay) => Timer(
  delay,
  () => unawaited(ref.read(soundBoardProvider).warm(practiceLanguages)),
);

/// Whether this device has a voice to read [lang]'s prompts in, in the
/// accent they are scored against.
@riverpod
Future<bool> phraseVoiceAvailable(Ref ref, String lang) =>
    ref.watch(soundBoardProvider).voice.speaks(lang);
