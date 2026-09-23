import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_full_stack_flutter/core/pronunciation/attempt_recorder.dart';
import 'package:flutter_full_stack_flutter/core/pronunciation/model_store.dart';
import 'package:flutter_full_stack_flutter/core/pronunciation/phoneme_model.dart';
import 'package:flutter_full_stack_flutter/core/pronunciation/pronunciation_engine.dart';
import 'package:flutter_full_stack_flutter/features/pronunciation/providers/practice_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// A microphone that hands back whatever the test put in it.
class _FakeRecorder implements AttemptRecorder {
  bool permitted = true;
  Float32List samples = Float32List(16000);
  bool recording = false;

  /// Every time the permission dialog would have been shown.
  int requests = 0;

  @override
  Future<bool> hasPermission({bool request = true}) async {
    if (request) requests++;
    return permitted;
  }

  @override
  Future<void> start() async => recording = true;

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory packs;
  late _FakeRecorder recorder;

  setUp(() async {
    // The test binding answers every HTTP request with a 400, which is right
    // for widget tests and wrong for one that serves a pack from loopback.
    HttpOverrides.global = null;
    packs = await Directory.systemTemp.createTemp('practice_controller_test');
    recorder = _FakeRecorder();
  });

  tearDown(() {
    if (packs.existsSync()) packs.deleteSync(recursive: true);
  });

  /// A container whose pack is on disk unless [downloaded] says otherwise,
  /// and whose downloads go to [baseUrl] - by default a port nothing listens
  /// on.
  ProviderContainer container({
    bool downloaded = true,
    String baseUrl = 'http://127.0.0.1:1',
    PhonemeAcousticModel? model,
  }) {
    if (downloaded) File('${packs.path}/phoneme_en_r2.int8.onnx').createSync();
    final container = ProviderContainer(
      overrides: [
        modelStoreProvider.overrideWithValue(
          ModelStore(directory: packs, baseUrl: baseUrl),
        ),
        attemptRecorderProvider.overrideWithValue(recorder),
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

  /// Serves a pack slowly enough that a test can leave in the middle of it.
  Future<(HttpServer, List<String>)> slowServer() async {
    final requests = <String>[];
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      requests.add(request.uri.path);
      request.response.headers.contentLength = 20 * 1024;
      for (var i = 0; i < 20; i++) {
        request.response.add(Uint8List(1024));
        await request.response.flush();
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      await request.response.close();
    });
    addTearDown(() => server.close(force: true));
    return (server, requests);
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

  test('a failed download goes back to offering the download', () async {
    final c = container(downloaded: false);
    final practice = c.read(practiceControllerProvider('en').notifier);
    await c.read(practiceControllerProvider('en').future);

    await practice.downloadModel();

    final failed = c.read(practiceControllerProvider('en'));
    expect((failed.error! as PracticeFailure).step, PracticeStep.download);
    // The download button is the retry.
    expect(failed.value?.stage, PracticeStage.needsModel);
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

  test('leaving mid-download neither aborts it nor starts a second', () async {
    final (server, requests) = await slowServer();
    final c = container(
      downloaded: false,
      baseUrl: 'http://${server.address.host}:${server.port}',
    );
    final store = c.read(modelStoreProvider);
    final screen = c.listen(practiceControllerProvider('en'), (_, _) {});
    await c.read(practiceControllerProvider('en').future);

    unawaited(
      c.read(practiceControllerProvider('en').notifier).downloadModel(),
    );
    await Future<void>.delayed(const Duration(milliseconds: 100));

    // Leaving the screen: the listener from `container` is the only one
    // left, so drop both to let the controller go.
    screen.close();
    c.invalidate(practiceControllerProvider('en'));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(store.isDownloading('phoneme_en_r2.int8.onnx'), isTrue);

    // Coming back finds the download under way instead of offering it again.
    final back = await c.read(practiceControllerProvider('en').future);
    expect(back.stage, PracticeStage.downloading);

    while (store.isDownloading('phoneme_en_r2.int8.onnx')) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    await Future<void>.delayed(Duration.zero);

    expect(requests, hasLength(1));
    expect(
      File('${packs.path}/phoneme_en_r2.int8.onnx').lengthSync(),
      20 * 1024,
    );
    expect(
      c.read(practiceControllerProvider('en')).value?.stage,
      PracticeStage.ready,
    );
  });

  test('the chooser sees a pack that landed while it was underneath', () async {
    final (server, _) = await slowServer();
    // The chooser stays mounted under the practice route, so it never lets go
    // of this provider and auto-disposal alone would keep it stale.
    final c = container(
      downloaded: false,
      baseUrl: 'http://${server.address.host}:${server.port}',
    )..listen(packDownloadedProvider('en'), (_, _) {});
    expect(await c.read(packDownloadedProvider('en').future), isFalse);

    await c.read(modelStoreProvider).ensure('phoneme_en_r2.int8.onnx');
    await Future<void>.delayed(Duration.zero);

    expect(await c.read(packDownloadedProvider('en').future), isTrue);
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
}
