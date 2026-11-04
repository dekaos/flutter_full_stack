import 'dart:async';
import 'dart:ui' show TextRange;

import 'package:flutter/foundation.dart';
import 'package:flutter_full_stack_flutter/core/audio/quietly.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// The voice that reads a prompt aloud: the model for the learner to copy.
///
/// An interface so tests can stand in for the platform's speech engine.
abstract interface class PhraseVoice {
  /// Whether this device has a voice for [lang] in the accent it is scored
  /// against. A learner shown a button that reads in another accent, or
  /// not at all, is worse off than one shown no button.
  Future<bool> speaks(String lang);

  /// Reads [text] in [lang]. Completes once it has been read, or stopped.
  Future<void> say(String text, {required String lang});

  /// Stops reading, if it is.
  Future<void> stop();

  /// Whether it is reading now.
  ValueListenable<bool> get speaking;

  /// Which word it is saying, as it says it: the text being read and the
  /// range of it being spoken, from the engine's own word-by-word
  /// progress - so a prompt can light up in step with the reading. `null`
  /// between readings.
  ValueListenable<({String text, TextRange range})?> get spoken;

  /// Finds the voices for [langs] ahead of time, so that [speaks] answers
  /// at once when practice opens instead of asking the engine then.
  Future<void> warm(Iterable<String> langs);

  Future<void> dispose();
}

/// [PhraseVoice] on the platform's own text to speech: AVSpeechSynthesizer
/// on iOS, the system's engine on Android. Nothing to download and nothing
/// to license, and it works offline - like everything else in practice.
///
/// Anything that fails here fails quietly, as not speaking: a voice that
/// cannot read must not stop the learner practising.
class PlatformPhraseVoice implements PhraseVoice {
  PlatformPhraseVoice() {
    _tts
      ..setStartHandler(() => _speaking.value = true)
      ..setProgressHandler(
        (text, start, end, _) => _spoken.value = (
          text: text,
          range: TextRange(start: start, end: end),
        ),
      )
      ..setCompletionHandler(_finished)
      ..setCancelHandler(_finished)
      ..setErrorHandler((_) => _finished());
  }

  /// The locales each language's prompts are read in, best first: the
  /// accents their phonemes come from, which are what an attempt is scored
  /// against - US English, Latin American Spanish and Seoul Korean (the
  /// espeak-ng voices in docs/pronunciation-models.md). A Castilian voice
  /// would read "cerveza" with a sound the Spanish lexicon marks wrong.
  static const accents = {
    'en': ['en-US'],
    'es': ['es-MX', 'es-US', 'es-419'],
    'ko': ['ko-KR'],
  };

  /// A little slower than conversation: a model to copy, not one to keep
  /// up with. On the plugin's scale, where `0.5` is normal on both
  /// platforms.
  static const rate = 0.42;

  /// How the platforms rate their voices, best first. iOS has premium and
  /// enhanced voices the learner may have downloaded; Android rates them
  /// from very high down.
  static const _quality = [
    'premium',
    'enhanced',
    'very high',
    'high',
    'default',
    'normal',
  ];

  final FlutterTts _tts = FlutterTts();
  final ValueNotifier<bool> _speaking = ValueNotifier(false);
  final ValueNotifier<({String text, TextRange range})?> _spoken =
      ValueNotifier(null);
  final Map<String, Future<_Choice?>> _choices = {};
  Future<List<Map<String, String>>>? _voices;
  Completer<void>? _reading;

  @override
  ValueListenable<bool> get speaking => _speaking;

  @override
  ValueListenable<({String text, TextRange range})?> get spoken => _spoken;

  void _finished() {
    _speaking.value = false;
    _spoken.value = null;
    final reading = _reading;
    _reading = null;
    if (reading != null && !reading.isCompleted) reading.complete();
  }

  @override
  Future<bool> speaks(String lang) async => await _choose(lang) != null;

  @override
  Future<void> warm(Iterable<String> langs) async {
    for (final lang in langs) {
      await _choose(lang);
    }
  }

  /// Every voice the engine has, asked for once. It is one call, but on
  /// Android a long one, answered on the main thread - where it would hold
  /// up frames if it came while a scene was arriving.
  Future<List<Map<String, String>>> _list() async {
    final voices = await (_voices ??= _fetchVoices());
    if (voices.isEmpty) _voices = null;
    return voices;
  }

  Future<List<Map<String, String>>> _fetchVoices() async =>
      await quietly('list the voices', () async {
        return [
          for (final voice in (await _tts.getVoices as List?) ?? const [])
            if (voice is Map)
              voice.map((key, value) => MapEntry('$key', '$value')),
        ];
      }) ??
      const [];

  /// Found once and kept - but not a failure to find one: on Android the
  /// engine binds in the background, and asking before it has may find
  /// nothing that is there a moment later.
  Future<_Choice?> _choose(String lang) async {
    final choice = await (_choices[lang] ??= _find(lang));
    if (choice == null) unawaited(_choices.remove(lang));
    return choice;
  }

  /// The best voice there is for [lang]'s accents, on the device and not
  /// over the network; or, where voices cannot be listed, the first of its
  /// accents the engine says it has.
  Future<_Choice?> _find(String lang) =>
      quietly<_Choice?>('find a voice for $lang', () async {
        final wanted = accents[lang] ?? const <String>[];
        final voices = await _list();
        for (final accent in wanted) {
          final matching = [
            for (final voice in voices)
              if (_sameLocale(voice['locale'], accent) &&
                  voice['network_required'] != '1')
                voice,
          ]..sort((a, b) => _rank(a).compareTo(_rank(b)));
          if (matching.isNotEmpty) {
            final voice = matching.first;
            return _Choice(accent, {
              'name': voice['name'] ?? '',
              'locale': voice['locale'] ?? accent,
              'identifier': ?voice['identifier'],
            });
          }
        }
        for (final accent in wanted) {
          if (await _tts.isLanguageAvailable(accent) == true) {
            return _Choice(accent, null);
          }
        }
        return null;
      });

  static bool _sameLocale(String? locale, String accent) =>
      locale != null &&
      locale.replaceAll('_', '-').toLowerCase() == accent.toLowerCase();

  static int _rank(Map<String, String> voice) {
    final rank = _quality.indexOf(voice['quality'] ?? '');
    return rank < 0 ? _quality.length : rank;
  }

  @override
  Future<void> say(String text, {required String lang}) async {
    final choice = await _choose(lang);
    if (choice == null) return;
    await stop();
    final reading = _reading = Completer<void>();
    final started = await quietly('read "$text" aloud', () async {
      final voice = choice.voice;
      if (voice != null) {
        await _tts.setVoice(voice);
      } else {
        await _tts.setLanguage(choice.locale);
      }
      await _tts.setSpeechRate(rate);
      await _tts.setVolume(1);
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        // Again every time: the sounds and the microphone each set the
        // session to suit themselves. Playback, so it is heard with the
        // ring switch on silent - the learner asked for it, as they would
        // press play on a video - and ducking anything else playing
        // underneath until it is done.
        await _tts.setSharedInstance(true);
        await _tts.setIosAudioCategory(
          IosTextToSpeechAudioCategory.playback,
          [IosTextToSpeechAudioCategoryOptions.duckOthers],
        );
      }
      _speaking.value = true;
      return await _tts.speak(text) == 1;
    });
    if (started != true) _finished();
    await reading.future;
  }

  @override
  Future<void> stop() async {
    if (_reading == null && !_speaking.value) return;
    await quietly('stop reading', () async {
      await _tts.stop();
    });
    // Not left to the cancel handler: not every engine calls it when told
    // to stop, and a reading that never finishes leaves its button stuck.
    _finished();
  }

  @override
  Future<void> dispose() async {
    await stop();
    _speaking.dispose();
    _spoken.dispose();
  }
}

/// A voice for a language: one listed by the engine, or failing that just
/// its [locale], for the engine to pick from.
class _Choice {
  const _Choice(this.locale, this.voice);

  final String locale;
  final Map<String, String>? voice;
}
