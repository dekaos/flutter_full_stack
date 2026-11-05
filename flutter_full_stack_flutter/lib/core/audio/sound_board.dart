import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_full_stack_flutter/core/audio/phrase_voice.dart';
import 'package:flutter_full_stack_flutter/core/audio/quietly.dart';
import 'package:flutter_full_stack_flutter/core/audio/sound.dart';
import 'package:flutter_full_stack_flutter/core/audio/synth.dart';
import 'package:path_provider/path_provider.dart';

/// Everything practice plays - its [Sound]s and the [voice] that reads a
/// prompt aloud - and the rules about when.
///
/// The rule that matters most: **nothing plays while the microphone is
/// open**. [hush] stops everything, the voice too, and refuses anything new
/// until [unhush]. A sound in a recording is a sound in its score, and the
/// speaker sits a few centimetres from the microphone.
///
/// Then, nothing that is part of the lesson is talked over: a sound cued
/// while a prompt is being read, or while the learner's own attempt is
/// played back to them ([replay]), is dropped rather than played across
/// it; and the reading and the playback each stop the other. Sounds can be
/// turned off ([effects]) without losing either, as neither is decoration.
class SoundBoard {
  SoundBoard({required this.output, required this.voice});

  final SoundOutput output;
  final PhraseVoice voice;

  bool _effects = true;
  bool _hushed = false;
  bool _replaying = false;

  /// Counts what has asked to be heard - a reading, a playback - or to
  /// stop everything. Starting one takes a moment, stopping what was
  /// playing first; one overtaken in that moment by a later request gives
  /// way to it, instead of starting late on top of it.
  int _turn = 0;

  /// Whether the scenes, the cat and the score are heard.
  bool get effects => _effects;
  set effects(bool on) {
    _effects = on;
    if (!on) unawaited(output.stopAll());
  }

  /// Whether the microphone has silenced everything.
  bool get hushed => _hushed;

  /// Plays [sound], unless it should not be heard now.
  void play(Sound sound) {
    if (!_effects || _hushed || _replaying || voice.speaking.value) return;
    unawaited(output.play(sound, sound.volume));
  }

  /// Plays a recording back - the learner's attempt, or a word cut from it
  /// ([excerpt]) - at [rate], over silence. Completes once it has played,
  /// or been stopped.
  Future<void> replay(Float32List samples, {required int rate}) async {
    if (_hushed) return;
    final turn = ++_turn;
    await _stopAll();
    if (turn != _turn) return;
    _replaying = true;
    try {
      await output.playClip(wav(samples, rate: rate));
    } finally {
      _replaying = false;
    }
  }

  /// Stops whatever is playing - sounds, a reading, a playback - and
  /// whatever was about to, without keeping anything quiet afterwards, as
  /// [hush] does.
  Future<void> silence() async {
    _turn++;
    await _stopAll();
  }

  Future<void> _stopAll() => Future.wait([output.stopAll(), voice.stop()]);

  /// Reads [text] aloud in [lang], over silence. Completes once it is read,
  /// or stopped.
  Future<void> say(String text, {required String lang}) async {
    if (_hushed) return;
    final turn = ++_turn;
    await _stopAll();
    if (turn != _turn) return;
    await voice.say(text, lang: lang);
  }

  /// Silences everything, and keeps it silent until [unhush]. Returns once
  /// it is silent - which is when the microphone may open.
  Future<void> hush() async {
    _hushed = true;
    _turn++;
    await _stopAll();
  }

  void unhush() => _hushed = false;

  /// Gets everything ready ahead of time: makes the sounds, sets up the
  /// players and finds the voices for [langs]. All of it costs, so it is
  /// done before practice opens - while the learner picks a language -
  /// rather than as the first scene arrives, where it would compete with
  /// the animation. Done once; later calls wait on the first.
  Future<void> warm(Iterable<String> langs) => _warming ??= () async {
    await output.warm();
    await voice.warm(langs);
  }();

  Future<void>? _warming;

  Future<void> dispose() async {
    await output.dispose();
    await voice.dispose();
  }
}

/// Where sounds come out: the platform's players, or a fake in tests.
abstract interface class SoundOutput {
  /// Gets ready to play, so the first sound starts on its cue.
  Future<void> warm();

  /// Starts [sound] at [volume], over anything already playing - or drops
  /// it, if the output is not ready yet. A sound is cued to a moment, and
  /// one heard late is worse than one not heard.
  Future<void> play(Sound sound, double volume);

  /// Plays [wav] - a recording, not one of the [Sound]s - at full volume,
  /// getting ready first if it has to: the learner asked for it, and a
  /// moment's wait is better than nothing. Completes once it has played,
  /// or been stopped by [stopAll].
  Future<void> playClip(Uint8List wav);

  /// Stops everything, the clip too, returning once it has.
  Future<void> stopAll();

  Future<void> dispose();
}

/// [SoundOutput] on the platform's players, through audioplayers.
///
/// The sounds are made on the device, off the UI isolate, the first time
/// they are wanted, and kept as WAV files in the temporary directory - a
/// file is what every platform's player can open. A few players take turns,
/// so sounds overlap as they would: a bell's second stroke rings over its
/// first.
///
/// Anything that fails here fails quietly. A sound is decoration, and a
/// phone that cannot play one must still let the learner practise.
class PlatformSoundOutput implements SoundOutput {
  /// How many sounds can ring at once.
  static const _players = 6;

  /// The audio session each sound plays in.
  ///
  /// On iOS, ambient: it mixes with whatever else is playing - the
  /// learner's music carries on - and the ring switch on silent silences it,
  /// as it should a decoration. On Android, a game's sound effects: at the
  /// media volume, and without taking audio focus from anything else.
  static final _context = AudioContext(
    iOS: AudioContextIOS(category: AVAudioSessionCategory.ambient),
    android: const AudioContextAndroid(
      contentType: AndroidContentType.sonification,
      usageType: AndroidUsageType.game,
      audioFocus: AndroidAudioFocus.none,
    ),
  );

  /// The session a recording is played back in: as the reading is, since
  /// it is part of the lesson. On iOS, playback - heard with the ring
  /// switch on silent, as the learner asked for it - ducking anything else
  /// playing; on Android, speech on the media volume, ducking the rest.
  static final _clipContext = AudioContext(
    // Playback is the default category; ducking is what is added.
    iOS: AudioContextIOS(options: const {AVAudioSessionOptions.duckOthers}),
    android: const AudioContextAndroid(
      contentType: AndroidContentType.speech,
      audioFocus: AndroidAudioFocus.gainTransientMayDuck,
    ),
  );

  Future<void>? _warming;

  /// Where each sound's file is, once they are all written.
  Map<Sound, String>? _paths;
  final List<AudioPlayer> _ready = [];
  int _next = 0;

  /// The player recordings are played back on, and the folder they are
  /// written to.
  AudioPlayer? _clip;
  String? _clips;

  /// How many recordings have been played back: they take turns between
  /// two files. A player handed the path it already has loaded keeps what
  /// it loaded from it - on iOS and Android alike - so a recording written
  /// over the last one played for the last one's length: the whole attempt
  /// cut off where the word heard before it ended.
  int _clipsPlayed = 0;

  /// Writes the sounds, then sets up the players. Setting up a player is a
  /// native object on the platform's main thread - cheap once, but not
  /// something to do on a sound's cue, in the middle of an animation.
  @override
  Future<void> warm() => _warming ??= () async {
    final paths = await quietly('make the sounds', _write);
    if (paths == null) return;
    await quietly('set up the players', () async {
      while (_ready.length < _players) {
        _ready.add(await _player(_context));
      }
      _clip = await _player(_clipContext);
      _paths = paths;
    });
  }();

  Future<Map<Sound, String>> _write() async {
    final temporary = await getTemporaryDirectory();
    final directory = Directory('${temporary.path}/sounds');
    await directory.create(recursive: true);
    final made = await compute(_renderAll, null);
    _clips = directory.path;
    final files = <Sound, String>{};
    for (final sound in Sound.values) {
      final file = File('${directory.path}/${sound.name}.wav');
      await file.writeAsBytes(made[sound.index], flush: true);
      files[sound] = file.path;
    }
    return files;
  }

  /// A player that plays in [context], and stops - rather than looping -
  /// at the end of what it plays.
  static Future<AudioPlayer> _player(AudioContext context) async {
    final player = AudioPlayer();
    await player.setReleaseMode(ReleaseMode.stop);
    await player.setAudioContext(context);
    return player;
  }

  /// Puts iOS's one audio session in [context] - again before every use:
  /// the microphone and the voice each set it to suit themselves, and it
  /// keeps whatever was set last. Elsewhere each player has its own, set
  /// once ([_player]).
  static Future<void> _useSession(AudioContext context) async {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      await AudioPlayer.global.setAudioContext(context);
    }
  }

  @override
  Future<void> play(Sound sound, double volume) async {
    // Not ready is not now: the sound is dropped rather than played late.
    final path = _paths?[sound];
    if (path == null || _ready.isEmpty) return;
    await quietly('play ${sound.name}', () async {
      await _useSession(_context);
      final player = _ready[_next++ % _ready.length];
      await player.stop();
      await player.play(DeviceFileSource(path), volume: volume);
    });
  }

  @override
  Future<void> playClip(Uint8List wav) async {
    await warm();
    final player = _clip;
    final clips = _clips;
    if (player == null || clips == null) return;
    final path = '$clips/attempt-${_clipsPlayed++ % 2}.wav';
    await quietly('play the recording back', () async {
      await File(path).writeAsBytes(wav, flush: true);
      await _useSession(_clipContext);
      await player.stop();
      final done = Completer<void>();
      final states = player.onPlayerStateChanged.listen((state) {
        if (state == PlayerState.completed || state == PlayerState.stopped) {
          if (!done.isCompleted) done.complete();
        }
      });
      // How long it lasts, from the WAV's own header: 16-bit, one channel.
      final rate = ByteData.sublistView(wav).getUint32(24, Endian.little);
      final lasts = Duration(
        microseconds: (wav.lengthInBytes - 44) ~/ 2 * 1000000 ~/ rate,
      );
      try {
        await player.play(DeviceFileSource(path));
        // Not left waiting on a player that never says it finished: the
        // playback would be stuck showing as playing.
        await done.future.timeout(
          lasts + const Duration(seconds: 2),
          onTimeout: () {},
        );
      } finally {
        await states.cancel();
      }
    });
  }

  @override
  Future<void> stopAll() async {
    await quietly(
      'stop the sounds',
      () => Future.wait([
        for (final player in [..._ready, ?_clip]) player.stop(),
      ]),
    );
  }

  @override
  Future<void> dispose() async {
    final players = [..._ready, ?_clip];
    _ready.clear();
    _clip = null;
    for (final player in players) {
      await quietly('let a player go', player.dispose);
    }
  }
}

/// Every sound as a WAV file, in [Sound] order. Top level, to run on
/// another isolate.
List<Uint8List> _renderAll(void _) => [
  for (final sound in Sound.values) wav(sound.render()),
];
