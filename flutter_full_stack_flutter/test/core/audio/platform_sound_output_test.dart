import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_full_stack_flutter/core/audio/sound_board.dart';
import 'package:flutter_full_stack_flutter/core/audio/synth.dart';
import 'package:flutter_test/flutter_test.dart';

/// The platform's side of audioplayers and path_provider, on fake channels:
/// every player prepares what it is handed and plays it to the end at once,
/// noting the path it was handed and what the file held then.
class _Platform {
  _Platform(this.temporary) {
    _messenger
      ..setMockMethodCallHandler(_global, (_) async => null)
      ..setMockStreamHandler(
        _globalEvents,
        MockStreamHandler.inline(onListen: (_, _) {}),
      )
      ..setMockMethodCallHandler(_paths, (call) async => temporary.path)
      ..setMockMethodCallHandler(_players, _player);
  }

  static const _global = MethodChannel('xyz.luan/audioplayers.global');
  static const _globalEvents = EventChannel(
    'xyz.luan/audioplayers.global/events',
  );
  static const _players = MethodChannel('xyz.luan/audioplayers');
  static const _paths = MethodChannel('plugins.flutter.io/path_provider');

  final Directory temporary;
  final played = <({String path, Uint8List bytes})>[];
  final _events = <String, MockStreamHandlerEventSink>{};

  TestDefaultBinaryMessenger get _messenger =>
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  Future<Object?> _player(MethodCall call) async {
    final arguments = (call.arguments as Map).cast<String, Object?>();
    final id = arguments['playerId']! as String;
    switch (call.method) {
      case 'create':
        _messenger.setMockStreamHandler(
          EventChannel('xyz.luan/audioplayers/events/$id'),
          MockStreamHandler.inline(
            onListen: (_, events) => _events[id] = events,
          ),
        );
      case 'setSourceUrl':
        final path = arguments['url']! as String;
        played.add((path: path, bytes: File(path).readAsBytesSync()));
        _send(id, {'event': 'audio.onPrepared', 'value': true});
      case 'resume':
        _send(id, {'event': 'audio.onComplete'});
    }
    return null;
  }

  void _send(String id, Map<String, Object?> event) =>
      Future<void>.delayed(Duration.zero, () => _events[id]?.success(event));

  void close() {
    _messenger
      ..setMockMethodCallHandler(_global, null)
      ..setMockStreamHandler(_globalEvents, null)
      ..setMockMethodCallHandler(_paths, null)
      ..setMockMethodCallHandler(_players, null);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory temporary;
  late _Platform platform;

  setUp(() {
    temporary = Directory.systemTemp.createTempSync('sound_output_test');
    platform = _Platform(temporary);
  });

  tearDown(() {
    platform.close();
    temporary.deleteSync(recursive: true);
  });

  // A player handed the path it already has loaded keeps what it loaded
  // from it, on iOS and Android alike - so a recording written over the
  // last one played for the last one's length: the whole attempt cut off
  // where the word heard before it ended.
  test('each recording is handed to the player under a path it does not '
      'have loaded, so it plays all the way through', () async {
    final output = PlatformSoundOutput();
    addTearDown(output.dispose);
    final word = wav(Float32List(1600), rate: 16000);
    final attempt = wav(Float32List(48000), rate: 16000);

    await output.playClip(word);
    await output.playClip(attempt);
    await output.playClip(word);
    await output.playClip(attempt);

    expect(platform.played.map((clip) => clip.bytes), [
      word,
      attempt,
      word,
      attempt,
    ]);
    for (var i = 1; i < platform.played.length; i++) {
      expect(
        platform.played[i].path,
        isNot(platform.played[i - 1].path),
        reason: 'clip $i is handed over under the path of the one before',
      );
    }
  });
}
