import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_full_stack_flutter/core/audio/sound.dart';
import 'package:flutter_full_stack_flutter/core/audio/sound_board.dart';
import 'package:flutter_full_stack_flutter/core/pronunciation/attempt_recorder.dart';
import 'package:flutter_full_stack_flutter/core/pronunciation/gop_scorer.dart';
import 'package:flutter_full_stack_flutter/core/pronunciation/lexicon.dart';
import 'package:flutter_full_stack_flutter/core/pronunciation/model_store.dart';
import 'package:flutter_full_stack_flutter/core/pronunciation/phoneme_model.dart';
import 'package:flutter_full_stack_flutter/core/pronunciation/pronunciation_engine.dart';
import 'package:flutter_full_stack_flutter/features/pronunciation/providers/language_pack.dart';
import 'package:flutter_full_stack_flutter/features/pronunciation/providers/practice_audio.dart';
import 'package:flutter_full_stack_flutter/features/pronunciation/providers/practice_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_audio.dart';

/// A microphone that hands back whatever the test put in it.
class _FakeRecorder implements AttemptRecorder {
  bool permitted = true;
  Float32List samples = Float32List(16000);
  bool recording = false;

  /// Every time the permission dialog would have been shown.
  int requests = 0;

  /// Called as the microphone opens - or, set to throw, as it fails to.
  void Function()? onStart;

  @override
  Future<bool> hasPermission({bool request = true}) async {
    if (request) requests++;
    return permitted;
  }

  @override
  Future<void> start() async {
    onStart?.call();
    recording = true;
  }

  @override
  Future<Float32List> stop() async {
    recording = false;
    return samples;
  }

  @override
  Future<void> cancel() async => recording = false;

  @override
  void dispose() {}
}

/// An acoustic model that fails, so a test can reach the scoring error path
/// without 355 MB of weights.
class _BrokenModel implements PhonemeAcousticModel {
  @override
  Future<Emissions> emissions(Float32List samples) =>
      Future.error(StateError('the model is broken'));

  @override
  Future<void> dispose() async {}
}

/// A model that hears nothing but blank, which is what silence looks like.
class _SilentModel implements PhonemeAcousticModel {
  @override
  Future<Emissions> emissions(Float32List samples) async {
    const frames = 50;
    const vocabSize = 392;
    final logProbs = Float32List(frames * vocabSize)
      ..fillRange(0, frames * vocabSize, -20);
    for (var t = 0; t < frames; t++) {
      logProbs[t * vocabSize] = 0;
    }
    return Emissions(
      logProbs: logProbs,
      frames: frames,
      vocabSize: vocabSize,
      frameSeconds: 0.02,
    );
  }

  @override
  Future<void> dispose() async {}
}

/// Practice that has just scored an attempt: [attempt] is two seconds of
/// recording, "The" said over its first half second and "weather" from
/// 0.6 s to 1.2 s.
class _Scored extends PracticeController {
  static final attempt = Float32List(2 * AttemptRecorder.sampleRate);

  static PronunciationResult get result => const PronunciationResult(
    overall: 57,
    accuracy: 57,
    fluency: 90,
    speechRate: 12,
    pauses: 0,
    words: [
      WordScore(word: 'The', start: 0.1, end: 0.5, score: 48, phones: []),
      WordScore(word: 'weather', start: 0.6, end: 1.2, score: 22, phones: []),
    ],
  );

  @override
  FutureOr<PracticeState> build(String lang) => PracticeState(
    stage: PracticeStage.scored,
    kind: ExerciseKind.phrase,
    items: const [
      Exercise(
        id: 'en-p01',
        text: 'The weather',
        words: [],
        phones: [],
      ),
      Exercise(id: 'en-p02', text: 'Another', words: [], phones: []),
    ],
    index: 0,
    result: result,
    attempt: attempt,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory packs;
  late _FakeRecorder recorder;
  late FakeSoundOutput speakers;
  late FakeVoice voice;
  late SoundBoard board;

  setUp(() async {
    packs = await Directory.systemTemp.createTemp('practice_controller_test');
    recorder = _FakeRecorder();
    speakers = FakeSoundOutput();
    voice = FakeVoice();
    board = SoundBoard(output: speakers, voice: voice);
  });

  tearDown(() {
    if (packs.existsSync()) packs.deleteSync(recursive: true);
  });

  /// A container whose pack is on disk, as it always is by the time
  /// practice opens: the chooser downloads it, and the router lets practice
  /// open on nothing less.
  ProviderContainer container({PhonemeAcousticModel? model}) {
    File('${packs.path}/phoneme_en_r2.int8.onnx').createSync();
    final container = ProviderContainer(
      overrides: [
        modelStoreProvider.overrideWithValue(ModelStore(directory: packs)),
        attemptRecorderProvider.overrideWithValue(recorder),
        soundBoardProvider.overrideWithValue(board),
        phonemeModelLoaderProvider.overrideWithValue(
          (_) async => model ?? _BrokenModel(),
        ),
      ],
    );
    addTearDown(container.dispose);
    // Keeps the auto-disposed controller alive between reads, the way the
    // screen watching it does.
    container.listen(practiceControllerProvider('en'), (_, _) {});
    return container;
  }

  test('a failed attempt keeps the deck and can be recorded again', () async {
    final c = container();
    final practice = c.read(practiceControllerProvider('en').notifier);
    await c.read(practiceControllerProvider('en').future);

    await practice.startRecording();
    await practice.stopAndScore();

    final failed = c.read(practiceControllerProvider('en'));
    // The error is there, and so is the deck it happened on - on a stage the
    // learner can go on from, not a spinner stuck on `scoring`.
    expect(failed.error, isA<PracticeFailure>());
    expect((failed.error! as PracticeFailure).step, PracticeStep.score);
    expect(failed.value?.stage, PracticeStage.ready);
    expect(failed.value?.items, isNotEmpty);

    await practice.startRecording();

    final retried = c.read(practiceControllerProvider('en'));
    expect(retried.hasError, isFalse);
    expect(retried.value?.stage, PracticeStage.recording);
  });

  test('moving to another prompt clears the failure', () async {
    final c = container();
    final practice = c.read(practiceControllerProvider('en').notifier);
    await c.read(practiceControllerProvider('en').future);

    await practice.startRecording();
    await practice.stopAndScore();
    practice.next();

    final moved = c.read(practiceControllerProvider('en'));
    expect(moved.hasError, isFalse);
    expect(moved.value?.index, 1);
  });

  test('silence is turned away as not heard, not graded', () async {
    final c = container(model: _SilentModel());
    final practice = c.read(practiceControllerProvider('en').notifier);
    await c.read(practiceControllerProvider('en').future);

    await practice.startRecording();
    await practice.stopAndScore();

    final failed = c.read(practiceControllerProvider('en'));
    final cause = (failed.error! as PracticeFailure).cause;
    expect((cause as AttemptRejected).reason, RejectedBecause.notHeard);
    expect(failed.value?.result, isNull);
    expect(failed.value?.stage, PracticeStage.ready);
  });

  test(
    'swiping to another prompt mid-recording closes the microphone',
    () async {
      final c = container();
      final practice = c.read(practiceControllerProvider('en').notifier);
      await c.read(practiceControllerProvider('en').future);

      await practice.startRecording();
      practice.next();
      await Future<void>.delayed(Duration.zero);

      expect(recorder.recording, isFalse);
      expect(
        c.read(practiceControllerProvider('en')).value?.stage,
        PracticeStage.ready,
      );
    },
  );

  group('the speakers and the microphone', () {
    test('everything is silent before the microphone opens, and may be '
        'heard again once it closes', () async {
      final c = container(model: _SilentModel());
      final practice = c.read(practiceControllerProvider('en').notifier);
      await c.read(practiceControllerProvider('en').future);
      final stops = speakers.stops;
      bool? silentAtStart;
      recorder.onStart = () => silentAtStart = board.hushed;

      await practice.startRecording();
      expect(silentAtStart, isTrue, reason: 'opened over a sound');
      expect(speakers.stops, stops + 1);
      board.play(Sound.meow);
      await pumpEventQueue();
      expect(speakers.played, isEmpty, reason: 'played into the recording');

      await practice.stopAndScore();
      expect(board.hushed, isFalse);
      board.play(Sound.scoreWeak);
      await pumpEventQueue();
      expect(speakers.sounds, [Sound.scoreWeak]);
    });

    test('a recording thrown away, or that never started, gives the '
        'speakers back', () async {
      final c = container();
      final practice = c.read(practiceControllerProvider('en').notifier);
      await c.read(practiceControllerProvider('en').future);

      await practice.startRecording();
      practice.next();
      expect(board.hushed, isFalse, reason: 'swiped away');

      recorder.onStart = () => throw StateError('no microphone');
      await practice.startRecording();
      expect(
        (c.read(practiceControllerProvider('en')).error! as PracticeFailure)
            .step,
        PracticeStep.record,
      );
      expect(board.hushed, isFalse, reason: 'failed to start');
    });

    test('leaving mid-recording gives the speakers back', () async {
      final c = container();
      final screen = c.listen(practiceControllerProvider('en'), (_, _) {});
      await c.read(practiceControllerProvider('en').future);

      await c.read(practiceControllerProvider('en').notifier).startRecording();
      screen.close();
      c.invalidate(practiceControllerProvider('en'));
      await Future<void>.delayed(Duration.zero);

      expect(board.hushed, isFalse);
    });
  });

  group('listening', () {
    test('reads the prompt aloud in its language, and says when it is '
        'done', () async {
      final c = container();
      final practice = c.read(practiceControllerProvider('en').notifier);
      final ready = await c.read(practiceControllerProvider('en').future);

      final reading = practice.listen();
      await pumpEventQueue();
      expect(voice.said, [ready.exercise.text]);
      expect(voice.langs, ['en']);
      expect(c.read(practiceControllerProvider('en')).value?.speaking, isTrue);

      voice.finish();
      await reading;
      expect(c.read(practiceControllerProvider('en')).value?.speaking, isFalse);
    });

    test('again, or on to another prompt, stops the reading', () async {
      final c = container();
      final practice = c.read(practiceControllerProvider('en').notifier);
      await c.read(practiceControllerProvider('en').future);

      final first = practice.listen();
      await pumpEventQueue();
      await practice.listen();
      await first;
      expect(voice.speaking.value, isFalse);
      expect(c.read(practiceControllerProvider('en')).value?.speaking, isFalse);
      expect(voice.said, hasLength(1), reason: 'read it again');

      final second = practice.listen();
      await pumpEventQueue();
      practice.next();
      await second;
      expect(voice.speaking.value, isFalse);
      expect(c.read(practiceControllerProvider('en')).value?.speaking, isFalse);
    });

    test('a word read over the sentence cuts it off, and is not marked '
        'finished by it', () async {
      final c = container();
      final practice = c.read(practiceControllerProvider('en').notifier);
      await c.read(practiceControllerProvider('en').future);

      final sentence = practice.listen();
      await pumpEventQueue();
      final word = practice.hear('weather');
      await sentence;
      // The word starts once the sentence has stopped.
      await pumpEventQueue();
      expect(voice.said.last, 'weather');
      expect(
        c.read(practiceControllerProvider('en')).value?.speaking,
        isTrue,
        reason: 'the sentence ending marked the word done',
      );

      voice.finish();
      await word;
      expect(c.read(practiceControllerProvider('en')).value?.speaking, isFalse);
    });

    test('recording stops a reading, and nothing is read over the '
        'microphone', () async {
      final c = container();
      final practice = c.read(practiceControllerProvider('en').notifier);
      await c.read(practiceControllerProvider('en').future);

      final reading = practice.listen();
      await pumpEventQueue();
      await practice.startRecording();
      await reading;
      expect(voice.speaking.value, isFalse);

      await practice.listen();
      expect(voice.said, hasLength(1), reason: 'read over the microphone');
      final now = c.read(practiceControllerProvider('en')).value!;
      expect(now.speaking, isFalse);
      expect(now.stage, PracticeStage.recording);
    });
  });

  test('leaving mid-recording closes the microphone', () async {
    final c = container();
    final screen = c.listen(practiceControllerProvider('en'), (_, _) {});
    await c.read(practiceControllerProvider('en').future);

    await c.read(practiceControllerProvider('en').notifier).startRecording();
    screen.close();
    c.invalidate(practiceControllerProvider('en'));
    await Future<void>.delayed(Duration.zero);

    expect(recorder.recording, isFalse);
  });

  testWidgets('a recording left running stops itself at the limit', (
    tester,
  ) async {
    // Built under real time: loading the lexicon is real I/O, which never
    // completes inside the fake clock. The timer that matters is started
    // afterwards, on the fake one.
    final c = (await tester.runAsync(() async {
      final c = container(model: _SilentModel());
      await c.read(practiceControllerProvider('en').future);
      return c;
    }))!;
    final practice = c.read(practiceControllerProvider('en').notifier);

    await practice.startRecording();
    await tester.pump(
      PracticeController.maxRecording - const Duration(seconds: 1),
    );
    expect(recorder.recording, isTrue);

    await tester.pump(const Duration(seconds: 1));
    await tester.pump();

    expect(recorder.recording, isFalse);
    // It went on to scoring rather than just cutting off: the silent model
    // is what turns this particular attempt away.
    final after = c.read(practiceControllerProvider('en'));
    expect(
      ((after.error! as PracticeFailure).cause as AttemptRejected).reason,
      RejectedBecause.notHeard,
    );
  });

  test('granting the microphone in settings is seen on return', () async {
    recorder.permitted = false;
    final c = container();
    final practice = c.read(practiceControllerProvider('en').notifier);
    await c.read(practiceControllerProvider('en').future);

    await practice.startRecording();
    expect(
      c.read(practiceControllerProvider('en')).value?.stage,
      PracticeStage.noMicrophone,
    );
    final asked = recorder.requests;

    // The learner goes to settings, allows the microphone and comes back.
    recorder.permitted = true;
    await practice.recheckMicrophone();

    expect(
      c.read(practiceControllerProvider('en')).value?.stage,
      PracticeStage.ready,
    );
    // Looking is not asking: coming back must not raise another dialog.
    expect(recorder.requests, asked);
  });

  test('coming back still refused leaves the way to settings up', () async {
    recorder.permitted = false;
    final c = container();
    final practice = c.read(practiceControllerProvider('en').notifier);
    await c.read(practiceControllerProvider('en').future);

    await practice.startRecording();
    await practice.recheckMicrophone();

    expect(
      c.read(practiceControllerProvider('en')).value?.stage,
      PracticeStage.noMicrophone,
    );
  });

  group('hearing yourself', () {
    ProviderContainer scored() {
      final c = ProviderContainer(
        overrides: [
          attemptRecorderProvider.overrideWithValue(recorder),
          soundBoardProvider.overrideWithValue(board),
          practiceControllerProvider.overrideWith2((_) => _Scored()),
        ],
      );
      addTearDown(c.dispose);
      c.listen(practiceControllerProvider('en'), (_, _) {});
      return c;
    }

    /// The samples in a WAV the board was handed.
    int samplesIn(Uint8List wav) => (wav.lengthInBytes - 44) ~/ 2;

    test('plays the whole attempt back, and says when it is done', () async {
      final c = scored();
      final practice = c.read(practiceControllerProvider('en').notifier);
      await c.read(practiceControllerProvider('en').future);

      final playback = practice.replay();
      await pumpEventQueue();
      expect(samplesIn(speakers.clips.single), _Scored.attempt.length);
      expect(
        c.read(practiceControllerProvider('en')).value?.replaying,
        (from: 0.0, to: 2.0, word: null),
      );

      speakers.finishClip();
      await playback;
      expect(c.read(practiceControllerProvider('en')).value?.replaying, isNull);
    });

    test('plays one word back on its own, with a breath either side', () async {
      final c = scored();
      final practice = c.read(practiceControllerProvider('en').notifier);
      await c.read(practiceControllerProvider('en').future);

      unawaited(practice.replay(word: 1));
      await pumpEventQueue();
      // 0.6 to 1.2 s, and 0.08 s either side of it.
      expect(
        samplesIn(speakers.clips.single),
        closeTo(0.76 * AttemptRecorder.sampleRate, 1),
      );
      final span = c.read(practiceControllerProvider('en')).value?.replaying;
      expect(span?.word, 1);
      expect(span?.from, closeTo(0.52, 1e-9));
    });

    test('a reading cuts the playback off, and the other way round', () async {
      final c = scored();
      final practice = c.read(practiceControllerProvider('en').notifier);
      await c.read(practiceControllerProvider('en').future);

      final playback = practice.replay();
      await pumpEventQueue();
      unawaited(practice.hear('weather'));
      await playback;
      var now = c.read(practiceControllerProvider('en')).value!;
      expect(speakers.clipping, isFalse);
      expect(now.replaying, isNull);
      expect(now.speaking, isTrue);

      unawaited(practice.replay());
      await pumpEventQueue();
      now = c.read(practiceControllerProvider('en')).value!;
      expect(voice.speaking.value, isFalse);
      expect(now.speaking, isFalse);
      expect(now.replaying, isNotNull);
    });

    test('moving on, or recording again, lets the attempt go', () async {
      final c = scored();
      final practice = c.read(practiceControllerProvider('en').notifier);
      await c.read(practiceControllerProvider('en').future);

      final playback = practice.replay();
      await pumpEventQueue();
      practice.next();
      await playback;
      expect(speakers.clipping, isFalse, reason: 'still playing');
      final moved = c.read(practiceControllerProvider('en')).value!;
      expect(moved.attempt, isNull);
      expect(moved.replaying, isNull);

      practice.previous();
      await practice.replay();
      expect(speakers.clips, hasLength(1), reason: 'played a stale attempt');
    });
  });
}
