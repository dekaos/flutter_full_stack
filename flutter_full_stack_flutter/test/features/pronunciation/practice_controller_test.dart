import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_full_stack_flutter/core/pronunciation/attempt_recorder.dart';
import 'package:flutter_full_stack_flutter/core/pronunciation/model_store.dart';
import 'package:flutter_full_stack_flutter/core/pronunciation/phoneme_model.dart';
import 'package:flutter_full_stack_flutter/features/pronunciation/providers/practice_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// A microphone that hands back whatever the test put in it.
class _FakeRecorder implements AttemptRecorder {
  bool permitted = true;
  Float32List samples = Float32List(16000);
  bool recording = false;

  @override
  Future<bool> hasPermission() async => permitted;

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory packs;
  late _FakeRecorder recorder;

  setUp(() async {
    packs = await Directory.systemTemp.createTemp('practice_controller_test');
    recorder = _FakeRecorder();
  });

  tearDown(() {
    if (packs.existsSync()) packs.deleteSync(recursive: true);
  });

  /// A container whose pack is on disk unless [downloaded] says otherwise,
  /// and whose downloads go to a port nothing listens on.
  ProviderContainer container({bool downloaded = true}) {
    if (downloaded) File('${packs.path}/phoneme_en_r2.int8.onnx').createSync();
    final container = ProviderContainer(
      overrides: [
        modelStoreProvider.overrideWithValue(
          ModelStore(directory: packs, baseUrl: 'http://127.0.0.1:1'),
        ),
        attemptRecorderProvider.overrideWithValue(recorder),
        phonemeModelLoaderProvider.overrideWithValue(
          (_) async => _BrokenModel(),
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
}
