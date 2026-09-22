import 'dart:async';

import 'package:flutter_full_stack_flutter/core/pronunciation/attempt_recorder.dart';
import 'package:flutter_full_stack_flutter/core/pronunciation/gop_scorer.dart';
import 'package:flutter_full_stack_flutter/core/pronunciation/lexicon.dart';
import 'package:flutter_full_stack_flutter/core/pronunciation/model_store.dart';
import 'package:flutter_full_stack_flutter/core/pronunciation/phoneme_model.dart';
import 'package:flutter_full_stack_flutter/core/pronunciation/pronunciation_engine.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'practice_controller.g.dart';

/// Where one practice session is.
enum PracticeStage {
  /// The language pack is not on the device yet.
  needsModel,

  downloading,
  ready,
  recording,
  scoring,
  scored,

  /// The microphone was refused, so nothing else can happen.
  noMicrophone,
}

class PracticeState {
  const PracticeState({
    required this.stage,
    required this.kind,
    required this.items,
    required this.index,
    this.download,
    this.result,
    this.scoringTime,
  });

  final PracticeStage stage;

  /// Which deck is open: single words or running phrases.
  final ExerciseKind kind;

  /// The prompts of [kind], in order. The screen pages through these.
  final List<Exercise> items;
  final int index;

  final DownloadProgress? download;
  final PronunciationResult? result;

  /// How long the last attempt took to score. Almost all of it is the
  /// acoustic pass; the rest of the pipeline is arithmetic over a few hundred
  /// thousand values. Shown only in debug builds - it is a number for whoever
  /// is choosing the model, not for the learner.
  final Duration? scoringTime;

  Exercise get exercise => items[index];
  bool get hasPrevious => index > 0;
  bool get hasNext => index < items.length - 1;

  PracticeState copyWith({
    PracticeStage? stage,
    ExerciseKind? kind,
    List<Exercise>? items,
    int? index,
    DownloadProgress? download,
    PronunciationResult? result,
    Duration? scoringTime,
    bool clearResult = false,
  }) => PracticeState(
    stage: stage ?? this.stage,
    kind: kind ?? this.kind,
    items: items ?? this.items,
    index: index ?? this.index,
    download: download ?? this.download,
    result: clearResult ? null : (result ?? this.result),
    scoringTime: clearResult ? null : (scoringTime ?? this.scoringTime),
  );
}

@Riverpod(keepAlive: true)
ModelStore modelStore(Ref ref) => const ModelStore();

/// The microphone, for as long as the app is running.
///
/// Deliberately not auto-disposed. `AudioRecorder` wraps a native recorder,
/// and an auto-disposed provider is torn down the moment the `ref.read` that
/// created it returns - so `start()` would be called on a recorder the
/// platform side had already released, which surfaces as "Recorder has not
/// yet been created or has already been disposed".
@Riverpod(keepAlive: true)
AttemptRecorder attemptRecorder(Ref ref) {
  final recorder = AttemptRecorder();
  ref.onDispose(recorder.dispose);
  return recorder;
}

/// Opens the acoustic model at a path. Overridden in tests, which must never
/// load 355 MB of weights.
@Riverpod(keepAlive: true)
Future<PhonemeAcousticModel> Function(String path) phonemeModelLoader(
  Ref ref,
) => OnnxPhonemeModel.load;

/// Whether a language's pack is already on the device.
///
/// Auto-disposed on purpose: it is read by the chooser, which has to see the
/// pack appear after a download without the app being restarted.
@riverpod
Future<bool> packDownloaded(Ref ref, String lang) async {
  final lexicon = await Lexicon.load(lang);
  return await ref.read(modelStoreProvider).isDownloaded(lexicon.model);
}

/// Drives read-aloud practice for one language.
///
/// Everything here happens on the device. The one thing that reaches the
/// network is the first download of the language pack, and only because a
/// 355 MB model cannot ship inside the app.
@riverpod
class PracticeController extends _$PracticeController {
  PronunciationEngine? _engine;
  Lexicon? _lexicon;

  @override
  FutureOr<PracticeState> build(String lang) async {
    final lexicon = await Lexicon.load(lang);
    _lexicon = lexicon;
    ref.onDispose(() => unawaited(_engine?.dispose() ?? Future.value()));

    final downloaded = await ref
        .read(modelStoreProvider)
        .isDownloaded(lexicon.model);
    return PracticeState(
      stage: downloaded ? PracticeStage.ready : PracticeStage.needsModel,
      kind: ExerciseKind.word,
      items: lexicon.byKind(ExerciseKind.word),
      index: 0,
    );
  }

  PracticeState get _now => state.requireValue;

  /// Switches deck. The score on screen belongs to the prompt that produced
  /// it, so it goes with the prompt.
  void selectKind(ExerciseKind kind) {
    final lexicon = _lexicon;
    if (lexicon == null || kind == _now.kind) return;
    state = AsyncData(
      _now.copyWith(
        kind: kind,
        items: lexicon.byKind(kind),
        index: 0,
        stage: _readyStage(),
        clearResult: true,
      ),
    );
  }

  void goTo(int index) {
    if (index < 0 || index >= _now.items.length || index == _now.index) return;
    state = AsyncData(
      _now.copyWith(index: index, stage: _readyStage(), clearResult: true),
    );
  }

  void next() => goTo(_now.index + 1);
  void previous() => goTo(_now.index - 1);

  /// Moving between prompts must not clear a download prompt or a refused
  /// microphone: those are about the device, not about which prompt is up.
  PracticeStage _readyStage() => switch (_now.stage) {
    PracticeStage.needsModel ||
    PracticeStage.downloading ||
    PracticeStage.noMicrophone => _now.stage,
    _ => PracticeStage.ready,
  };

  Future<void> downloadModel() async {
    final lexicon = _lexicon;
    if (lexicon == null) return;
    state = AsyncData(_now.copyWith(stage: PracticeStage.downloading));
    state = await AsyncValue.guard(() async {
      await ref
          .read(modelStoreProvider)
          .ensure(
            lexicon.model,
            onProgress: (progress) {
              if (state.hasValue) {
                state = AsyncData(_now.copyWith(download: progress));
              }
            },
          );
      return _now.copyWith(stage: PracticeStage.ready);
    });
  }

  Future<void> startRecording() async {
    final recorder = ref.read(attemptRecorderProvider);
    if (!await recorder.hasPermission()) {
      state = AsyncData(_now.copyWith(stage: PracticeStage.noMicrophone));
      return;
    }
    state = await AsyncValue.guard(() async {
      await recorder.start();
      return _now.copyWith(stage: PracticeStage.recording, clearResult: true);
    });
  }

  Future<void> stopAndScore() async {
    final recorder = ref.read(attemptRecorderProvider);
    final exercise = _now.exercise;
    state = AsyncData(_now.copyWith(stage: PracticeStage.scoring));
    state = await AsyncValue.guard(() async {
      final samples = await recorder.stop();
      final engine = await _ensureEngine();
      final started = Stopwatch()..start();
      final result = await engine.score(exercise: exercise, samples: samples);
      return _now.copyWith(
        stage: PracticeStage.scored,
        result: result,
        scoringTime: started.elapsed,
      );
    });
  }

  Future<PronunciationEngine> _ensureEngine() async {
    final existing = _engine;
    if (existing != null) return existing;
    final lexicon = _lexicon!;
    final file = await ref.read(modelStoreProvider).ensure(lexicon.model);
    final load = ref.read(phonemeModelLoaderProvider);
    final engine = PronunciationEngine(
      lexicon: lexicon,
      model: await load(file.path),
    );
    _engine = engine;
    return engine;
  }
}
