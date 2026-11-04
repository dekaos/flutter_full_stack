import 'dart:async';
import 'dart:ui' show TextRange;

import 'package:flutter/foundation.dart';
import 'package:flutter_full_stack_flutter/core/audio/phrase_voice.dart';
import 'package:flutter_full_stack_flutter/core/audio/sound.dart';
import 'package:flutter_full_stack_flutter/core/audio/sound_board.dart';

/// Speakers that write down what they were asked to play.
class FakeSoundOutput implements SoundOutput {
  /// Every sound started, with the volume it was started at.
  final List<(Sound, double)> played = [];

  /// How many times everything was stopped.
  int stops = 0;

  bool warmed = false;

  /// Every recording played back, as the WAV bytes it was handed.
  final List<Uint8List> clips = [];
  Completer<void>? _clip;

  /// Whether a recording is playing back now.
  bool get clipping => _clip != null;

  List<Sound> get sounds => [for (final (sound, _) in played) sound];

  /// The recording playing back comes to its end.
  void finishClip() {
    _clip?.complete();
    _clip = null;
  }

  @override
  Future<void> playClip(Uint8List wav) {
    clips.add(wav);
    return (_clip = Completer()).future;
  }

  @override
  Future<void> warm() async => warmed = true;

  @override
  Future<void> play(Sound sound, double volume) async =>
      played.add((sound, volume));

  @override
  Future<void> stopAll() async {
    stops++;
    finishClip();
  }

  @override
  Future<void> dispose() async {}
}

/// A voice that reads until the test says it has finished, or it is
/// stopped.
class FakeVoice implements PhraseVoice {
  FakeVoice({this.available = true});

  bool available;

  /// Every text read, and the language each was read in.
  final List<String> said = [];
  final List<String> langs = [];

  final ValueNotifier<bool> _speaking = ValueNotifier(false);
  final ValueNotifier<({String text, TextRange range})?> _spoken =
      ValueNotifier(null);
  Completer<void>? _reading;

  @override
  ValueListenable<bool> get speaking => _speaking;

  @override
  ValueListenable<({String text, TextRange range})?> get spoken => _spoken;

  /// The engine reaching the word at [start] to [end] of what it reads.
  void reach(int start, int end) => _spoken.value = (
    text: said.last,
    range: TextRange(start: start, end: end),
  );

  @override
  Future<bool> speaks(String lang) async => available;

  /// The languages it was asked to get ready.
  final List<String> warmed = [];

  @override
  Future<void> warm(Iterable<String> langs) async => warmed.addAll(langs);

  @override
  Future<void> say(String text, {required String lang}) {
    // As the platform's does: a new reading cuts off the one before.
    if (_reading != null) finish();
    said.add(text);
    langs.add(lang);
    _speaking.value = true;
    return (_reading = Completer()).future;
  }

  /// The reading comes to its end.
  void finish() {
    _speaking.value = false;
    _spoken.value = null;
    _reading?.complete();
    _reading = null;
  }

  @override
  Future<void> stop() async {
    if (_reading != null) finish();
  }

  @override
  Future<void> dispose() async {}
}

/// A board on fakes, for tests that do not look at it.
SoundBoard fakeSoundBoard() =>
    SoundBoard(output: FakeSoundOutput(), voice: FakeVoice());
