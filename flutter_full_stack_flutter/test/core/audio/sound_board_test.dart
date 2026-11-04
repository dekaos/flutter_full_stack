import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_full_stack_flutter/core/audio/phrase_voice.dart';
import 'package:flutter_full_stack_flutter/core/audio/sound.dart';
import 'package:flutter_full_stack_flutter/core/audio/sound_board.dart';
import 'package:flutter_full_stack_flutter/core/pronunciation/lexicon.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_audio.dart';

void main() {
  late FakeSoundOutput output;
  late FakeVoice voice;
  late SoundBoard board;

  setUp(() {
    output = FakeSoundOutput();
    voice = FakeVoice();
    board = SoundBoard(output: output, voice: voice);
  });

  test('plays a sound at its own volume', () async {
    board.play(Sound.clink);
    await pumpEventQueue();
    expect(output.played, [(Sound.clink, Sound.clink.volume)]);
  });

  test('is silent while the microphone is open, and only then', () async {
    board.play(Sound.meow);
    await pumpEventQueue();
    final stops = output.stops;

    await board.hush();
    expect(output.stops, stops + 1, reason: 'what was playing stopped');
    board.play(Sound.murmur);
    await pumpEventQueue();
    expect(output.sounds, [Sound.meow]);

    board
      ..unhush()
      ..play(Sound.murmur);
    await pumpEventQueue();
    expect(output.sounds, [Sound.meow, Sound.murmur]);
  });

  test('stops a reading when the microphone opens, and will not start '
      'one over it', () async {
    final reading = board.say('Hello', lang: 'en');
    await pumpEventQueue();
    expect(voice.speaking.value, isTrue);

    await board.hush();
    await reading;
    expect(voice.speaking.value, isFalse);

    await board.say('Hello again', lang: 'en');
    expect(voice.said, ['Hello'], reason: 'read over the microphone');
  });

  test('never talks over a reading', () async {
    board.play(Sound.wave);
    await pumpEventQueue();
    final stops = output.stops;

    unawaited(board.say('Near the beach', lang: 'en'));
    await pumpEventQueue();
    expect(output.stops, stops + 1, reason: 'the wave went on under it');

    board.play(Sound.chirp);
    await pumpEventQueue();
    expect(output.sounds, [Sound.wave]);

    voice.finish();
    board.play(Sound.chirp);
    await pumpEventQueue();
    expect(output.sounds, [Sound.wave, Sound.chirp]);
  });

  test('turned off, makes no sound - but still reads aloud', () async {
    board.play(Sound.horn);
    await pumpEventQueue();
    final stops = output.stops;

    board.effects = false;
    expect(output.stops, stops + 1, reason: 'kept playing once turned off');
    board.play(Sound.horn);
    await pumpEventQueue();
    expect(output.played, hasLength(1));

    unawaited(board.say('The red car', lang: 'en'));
    await pumpEventQueue();
    expect(voice.said, ['The red car']);
  });

  test('every language practised has an accent to be read in', () {
    for (final lang in practiceLanguages) {
      expect(PlatformPhraseVoice.accents[lang], isNotEmpty, reason: lang);
    }
  });

  test('gets the sounds and the voices ready, once', () async {
    await Future.wait([
      board.warm(['en', 'ko']),
      board.warm(['en', 'ko']),
    ]);
    expect(output.warmed, isTrue);
    expect(voice.warmed, ['en', 'ko'], reason: 'warmed twice');
  });

  test('a sound cued before the speakers are ready is dropped, not played '
      'late', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final calls = <String>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final name in [
      'xyz.luan/audioplayers',
      'xyz.luan/audioplayers.global',
    ]) {
      final channel = MethodChannel(name);
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call.method);
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    }

    await PlatformSoundOutput().play(Sound.clockBell, 0.5);
    expect(calls, isEmpty);
  });

  group('playing an attempt back', () {
    final take = Float32List(1600);

    test('stops a reading and every sound first, and keeps them quiet while '
        'it plays', () async {
      board.play(Sound.wave);
      unawaited(board.say('The weather', lang: 'en'));
      await pumpEventQueue();

      final playback = board.replay(take, rate: 16000);
      await pumpEventQueue();
      expect(voice.speaking.value, isFalse);
      expect(output.clips, hasLength(1));
      expect(output.clips.single.lengthInBytes, 44 + 2 * take.length);

      board.play(Sound.chirp);
      await pumpEventQueue();
      expect(output.sounds, [Sound.wave], reason: 'played over the attempt');

      output.finishClip();
      await playback;
      board.play(Sound.chirp);
      await pumpEventQueue();
      expect(output.sounds, [Sound.wave, Sound.chirp]);
    });

    test(
      'stops when the microphone opens, and will not start over it',
      () async {
        final playback = board.replay(take, rate: 16000);
        await pumpEventQueue();
        await board.hush();
        await playback;
        expect(output.clipping, isFalse);

        await board.replay(take, rate: 16000);
        expect(
          output.clips,
          hasLength(1),
          reason: 'played over the microphone',
        );
      },
    );
  });

  test('a reading overtaken while it starts gives way, instead of starting '
      'on top of what overtook it', () async {
    final reading = board.say('The weather', lang: 'en');
    final playback = board.replay(Float32List(160), rate: 16000);
    await reading;
    await pumpEventQueue();
    expect(voice.said, isEmpty);
    expect(output.clipping, isTrue);
    output.finishClip();
    await playback;
  });
}
