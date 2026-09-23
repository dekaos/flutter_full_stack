import 'dart:async';

import 'package:flutter_full_stack_flutter/core/app_settings.dart';
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

/// What the learner was doing when something went wrong.
enum PracticeStep { download, record, score }

/// A failed action, carried as the error of the controller's [AsyncValue]
/// while the deck it happened on stays on screen.
///
/// The message the learner sees is chosen by [step], never by [cause]: the
/// exception is written for whoever reads the log, and "SocketException:
/// Connection refused" on a phone is not something a learner can act on.
class PracticeFailure implements Exception {
  const PracticeFailure(this.step, this.cause);

  final PracticeStep step;
  final Object cause;

  @override
  String toString() => '${step.name} failed: $cause';
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

/// Kept alive because the downloads it runs must outlive the screen that
/// started them.
@Riverpod(keepAlive: true)
ModelStore modelStore(Ref ref) {
  final store = ModelStore();
  ref.onDispose(store.dispose);
  return store;
}

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

/// The way back from a refused microphone. Overridden in tests, which have no
/// settings screen to open.
@Riverpod(keepAlive: true)
AppSettings appSettings(Ref ref) => const AppSettings();

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
/// Auto-disposal alone is not enough, because the chooser stays mounted under
/// the practice route and so never lets go of this. It is invalidated instead
/// whenever a pack lands or leaves - including a download that finished after
/// the learner walked away from it.
@riverpod
Future<bool> packDownloaded(Ref ref, String lang) async {
  final store = ref.watch(modelStoreProvider);
  final changes = store.changes.listen((_) => ref.invalidateSelf());
  ref.onDispose(changes.cancel);
  final lexicon = await Lexicon.load(lang);
  return await store.isDownloaded(lexicon.model);
}

/// Drives read-aloud practice for one language.
///
/// Everything here happens on the device. The one thing that reaches the
/// network is the first download of the language pack, and only because a
/// 355 MB model cannot ship inside the app.
@riverpod
class PracticeController extends _$PracticeController {
  /// The longest attempt recorded before it is stopped and scored on its own.
  ///
  /// The longest prompt takes a native speaker about three seconds, so this
  /// leaves a slow reader room several times over. The cap is about the
  /// device: the acoustic model's attention grows with the square of the
  /// audio's length, and a recording left running would eventually take more
  /// memory than a small phone has.
  static const maxRecording = Duration(seconds: 15);

  PronunciationEngine? _engine;
  Lexicon? _lexicon;

  /// Set only while the microphone is open.
  AttemptRecorder? _live;
  Timer? _limit;

  @override
  FutureOr<PracticeState> build(String lang) async {
    final lexicon = await Lexicon.load(lang);
    _lexicon = lexicon;
    ref.onDispose(() {
      // The recorder outlives this controller, so leaving mid-attempt would
      // otherwise keep the microphone - and the system's recording
      // indicator - on after the screen is gone.
      _limit?.cancel();
      unawaited(_live?.cancel() ?? Future.value());
      unawaited(_engine?.dispose() ?? Future.value());
    });

    final store = ref.read(modelStoreProvider);
    // A download started on an earlier visit is still running: pick it up
    // where it is instead of offering to start it again.
    if (store.isDownloading(lexicon.model)) {
      unawaited(_rejoinDownload());
      return PracticeState(
        stage: PracticeStage.downloading,
        kind: ExerciseKind.word,
        items: lexicon.byKind(ExerciseKind.word),
        index: 0,
        download: store.progressOf(lexicon.model),
      );
    }
    final downloaded = await store.isDownloaded(lexicon.model);
    return PracticeState(
      stage: downloaded ? PracticeStage.ready : PracticeStage.needsModel,
      kind: ExerciseKind.word,
      items: lexicon.byKind(ExerciseKind.word),
      index: 0,
    );
  }

  Future<void> _rejoinDownload() async {
    // Waits for build to hand over the state this reports into.
    await future;
    await _followDownload();
  }

  PracticeState get _now => state.requireValue;

  /// Switches deck. The score on screen belongs to the prompt that produced
  /// it, so it goes with the prompt.
  void selectKind(ExerciseKind kind) {
    final lexicon = _lexicon;
    if (lexicon == null || kind == _now.kind) return;
    _discardRecording();
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
    _discardRecording();
    state = AsyncData(
      _now.copyWith(index: index, stage: _readyStage(), clearResult: true),
    );
  }

  void next() => goTo(_now.index + 1);
  void previous() => goTo(_now.index - 1);

  /// Throws away an attempt in progress. Swiping to another prompt while
  /// recording used to leave the microphone running under a Record button.
  void _discardRecording() {
    final live = _live;
    if (live == null) return;
    _limit?.cancel();
    _live = null;
    unawaited(live.cancel());
  }

  /// Moving between prompts must not clear a download prompt or a refused
  /// microphone: those are about the device, not about which prompt is up.
  PracticeStage _readyStage() => switch (_now.stage) {
    PracticeStage.needsModel ||
    PracticeStage.downloading ||
    PracticeStage.noMicrophone => _now.stage,
    _ => PracticeStage.ready,
  };

  Future<void> downloadModel() async {
    if (_lexicon == null) return;
    state = AsyncData(_now.copyWith(stage: PracticeStage.downloading));
    await _followDownload();
  }

  /// Starts the download, or joins the one already running. The store owns
  /// it, so if the learner leaves, it carries on without this controller.
  Future<void> _followDownload() async {
    final lexicon = _lexicon!;
    await _attempt(PracticeStep.download, PracticeStage.needsModel, () async {
      await ref
          .read(modelStoreProvider)
          .ensure(
            lexicon.model,
            onProgress: (progress) {
              // Called by the store for as long as the download runs, which
              // can be long after this controller is gone.
              if (ref.mounted && state.hasValue) {
                state = AsyncData(_now.copyWith(download: progress));
              }
            },
          );
      return _now.copyWith(stage: PracticeStage.ready);
    });
  }

  Future<void> startRecording() async {
    final recorder = ref.read(attemptRecorderProvider);
    await _attempt(PracticeStep.record, PracticeStage.ready, () async {
      if (!await recorder.hasPermission()) {
        return _now.copyWith(stage: PracticeStage.noMicrophone);
      }
      await recorder.start();
      _live = recorder;
      _limit = Timer(maxRecording, () => unawaited(stopAndScore()));
      return _now.copyWith(stage: PracticeStage.recording, clearResult: true);
    });
  }

  /// Looks at the microphone permission again, without asking for it.
  ///
  /// Called when the app comes back to the foreground, which is how the
  /// learner returns from the settings page the refusal sent them to. Having
  /// to leave and reopen practice to see the change would read as the
  /// setting not having worked.
  Future<void> recheckMicrophone() async {
    if (!state.hasValue || _now.stage != PracticeStage.noMicrophone) return;
    final granted = await ref
        .read(attemptRecorderProvider)
        .hasPermission(request: false);
    if (!ref.mounted || !granted) return;
    if (_now.stage != PracticeStage.noMicrophone) return;
    state = AsyncData(_now.copyWith(stage: PracticeStage.ready));
  }

  Future<void> stopAndScore() async {
    // Both the Stop button and the time limit land here; whichever comes
    // second finds nothing to stop.
    if (_live == null) return;
    _limit?.cancel();
    _live = null;
    final recorder = ref.read(attemptRecorderProvider);
    final exercise = _now.exercise;
    state = AsyncData(_now.copyWith(stage: PracticeStage.scoring));
    await _attempt(PracticeStep.score, PracticeStage.ready, () async {
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

  /// Runs one action of the learner's. If it fails, the deck stays up with
  /// the error over it, on [fallback] - a stage the same action can be tried
  /// again from - instead of the error replacing the page.
  ///
  /// The deck survives because Riverpod keeps the previous value when a
  /// notifier's state becomes an [AsyncError]; setting [fallback] first is
  /// what makes that previous value one the learner can move on from, rather
  /// than a spinner stuck on `scoring`.
  Future<void> _attempt(
    PracticeStep step,
    PracticeStage fallback,
    Future<PracticeState> Function() action,
  ) async {
    final outcome = await AsyncValue.guard(action);
    // The learner may have left while this ran. Nothing is waiting for the
    // result, and touching the state of a disposed notifier throws.
    if (!ref.mounted) return;
    if (outcome case AsyncError(:final error, :final stackTrace)) {
      state = AsyncData(_now.copyWith(stage: fallback));
      state = AsyncError(PracticeFailure(step, error), stackTrace);
    } else {
      state = outcome;
    }
  }

  Future<PronunciationEngine> _ensureEngine() async {
    final existing = _engine;
    if (existing != null) return existing;
    final lexicon = _lexicon!;
    final file = await ref.read(modelStoreProvider).ensure(lexicon.model);
    final load = ref.read(phonemeModelLoaderProvider);
    final model = await load(file.path);
    // Left while the session opened: [build]'s onDispose has already run and
    // found no engine, so this one would hold its weights until the process
    // died.
    if (!ref.mounted) {
      await model.dispose();
      throw StateError('practice closed while the model was loading');
    }
    final engine = PronunciationEngine(lexicon: lexicon, model: model);
    _engine = engine;
    return engine;
  }
}
