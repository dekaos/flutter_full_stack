import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_full_stack_flutter/core/audio/phrase_voice.dart';
import 'package:flutter_test/flutter_test.dart';

/// The speech engine's side of the plugin's channel: the voices a device
/// has, and every call the app makes.
class _Engine {
  _Engine(this.voices, {this.languages = const []});

  final List<Map<String, String>> voices;
  final List<String> languages;
  final List<MethodCall> calls = [];

  Future<Object?> handle(MethodCall call) async {
    calls.add(call);
    return switch (call.method) {
      'getVoices' => voices,
      'isLanguageAvailable' => languages.contains(call.arguments),
      _ => 1,
    };
  }

  /// What was said, and in which voice.
  List<Object?> argumentsOf(String method) => [
    for (final call in calls)
      if (call.method == method) call.arguments,
  ];
}

const _channel = MethodChannel('flutter_tts');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  _Engine engine(
    List<Map<String, String>> voices, {
    List<String> languages = const [],
  }) {
    final engine = _Engine(voices, languages: languages);
    messenger.setMockMethodCallHandler(_channel, engine.handle);
    addTearDown(() => messenger.setMockMethodCallHandler(_channel, null));
    return engine;
  }

  /// The engine saying it has finished reading.
  Future<void> finished() => messenger.handlePlatformMessage(
    _channel.name,
    _channel.codec.encodeMethodCall(const MethodCall('speak.onComplete')),
    (_) {},
  );

  test('reads in the best voice on the device in the accent the language '
      'is scored against', () async {
    final device = engine([
      // The wrong accent, however good: Castilian, not Latin American.
      {'name': 'es-ES-premium', 'locale': 'es-ES', 'quality': 'premium'},
      // The right one, but only over the network.
      {
        'name': 'es-MX-network',
        'locale': 'es-MX',
        'quality': 'very high',
        'network_required': '1',
      },
      {'name': 'es-MX-compact', 'locale': 'es-MX', 'quality': 'default'},
      {'name': 'es-MX-enhanced', 'locale': 'es_MX', 'quality': 'enhanced'},
      {'name': 'es-US-premium', 'locale': 'es-US', 'quality': 'premium'},
    ]);
    final voice = PlatformPhraseVoice();
    addTearDown(voice.dispose);

    expect(await voice.speaks('es'), isTrue);
    final reading = voice.say('¿Dónde está la playa?', lang: 'es');
    await pumpEventQueue();

    // Mexican first, as the most widely shipped Latin American voice; the
    // best of those that need no connection.
    final chosen = device.argumentsOf('setVoice').single! as Map;
    expect(chosen['name'], 'es-MX-enhanced');
    expect(device.argumentsOf('setSpeechRate'), [PlatformPhraseVoice.rate]);
    expect(device.argumentsOf('speak'), ['¿Dónde está la playa?']);
    expect(voice.speaking.value, isTrue);

    await finished();
    await reading;
    expect(voice.speaking.value, isFalse);
  });

  test('has nothing to read in when only another accent is there', () async {
    engine(
      [
        {'name': 'en-GB', 'locale': 'en-GB', 'quality': 'enhanced'},
      ],
      languages: ['en-GB'],
    );
    final voice = PlatformPhraseVoice();
    addTearDown(voice.dispose);

    expect(await voice.speaks('en'), isFalse);
    expect(await voice.speaks('ko'), isFalse);
  });

  test('falls back to the language where voices cannot be listed', () async {
    final device = engine(const [], languages: ['ko-KR']);
    final voice = PlatformPhraseVoice();
    addTearDown(voice.dispose);

    expect(await voice.speaks('ko'), isTrue);
    unawaited(voice.say('안녕하세요', lang: 'ko'));
    await pumpEventQueue();
    expect(device.argumentsOf('setLanguage'), ['ko-KR']);
  });

  test('stopping ends the reading even if the engine never says so', () async {
    final device = engine([
      {'name': 'en-US', 'locale': 'en-US', 'quality': 'default'},
    ]);
    final voice = PlatformPhraseVoice();
    addTearDown(voice.dispose);

    final reading = voice.say('Can you help me', lang: 'en');
    await pumpEventQueue();
    await voice.stop();
    await reading;

    expect(device.argumentsOf('stop'), hasLength(1));
    expect(voice.speaking.value, isFalse);
  });

  test('a device with no speech engine at all is simply silent', () async {
    final voice = PlatformPhraseVoice();
    addTearDown(voice.dispose);

    expect(await voice.speaks('en'), isFalse);
    await voice.say('Hello', lang: 'en');
    expect(voice.speaking.value, isFalse);
  });

  test('asks the engine for its voices once, however many languages', () async {
    final device = engine([
      {'name': 'en-US', 'locale': 'en-US', 'quality': 'default'},
      {'name': 'ko-KR', 'locale': 'ko-KR', 'quality': 'default'},
    ]);
    final voice = PlatformPhraseVoice();
    addTearDown(voice.dispose);

    await voice.warm(['en', 'es', 'ko']);
    expect(await voice.speaks('en'), isTrue);
    expect(await voice.speaks('ko'), isTrue);
    expect(device.calls.where((c) => c.method == 'getVoices'), hasLength(1));
  });

  test('says which word it is reading, as it reads it', () async {
    engine([
      {'name': 'en-US', 'locale': 'en-US', 'quality': 'default'},
    ]);
    final voice = PlatformPhraseVoice();
    addTearDown(voice.dispose);

    final reading = voice.say('The weather', lang: 'en');
    await pumpEventQueue();
    await messenger.handlePlatformMessage(
      _channel.name,
      _channel.codec.encodeMethodCall(
        const MethodCall('speak.onProgress', {
          'text': 'The weather',
          'start': 4,
          'end': 11,
          'word': 'weather',
        }),
      ),
      (_) {},
    );
    expect(voice.spoken.value?.text, 'The weather');
    expect(voice.spoken.value?.range, const TextRange(start: 4, end: 11));

    await finished();
    await reading;
    expect(voice.spoken.value, isNull);
  });
}
