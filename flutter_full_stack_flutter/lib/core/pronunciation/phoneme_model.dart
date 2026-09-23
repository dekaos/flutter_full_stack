import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';

/// Per-frame log posteriors over the phoneme vocabulary.
class Emissions {
  const Emissions({
    required this.logProbs,
    required this.frames,
    required this.vocabSize,
    required this.frameSeconds,
  });

  /// Row-major `frames x vocabSize`.
  final Float32List logProbs;
  final int frames;
  final int vocabSize;

  /// How much audio one frame covers. wav2vec2 strides 320 samples, so this
  /// is 20 ms at 16 kHz - derived from the real output length rather than
  /// assumed, because the convolutional front end drops a few samples.
  final double frameSeconds;
}

/// What the scorer needs from an acoustic model. The GOP core is written
/// against this, so it can be exercised in tests with canned emissions and
/// never has to load 355 MB of weights.
abstract interface class PhonemeAcousticModel {
  Future<Emissions> emissions(Float32List samples);
  Future<void> dispose();
}

/// The phoneme CTC model, quantised to int8 and run through ONNX Runtime.
///
/// The weights are not bundled: `melos run size` holds the release APK to a
/// byte budget, and one language pack is 355 MB. They are downloaded once
/// into the app's support directory by `ModelStore`, after which everything
/// here runs with no network at all. Which models these are, and where they
/// come from: docs/pronunciation-models.md.
class OnnxPhonemeModel implements PhonemeAcousticModel {
  OnnxPhonemeModel._(this._session, this._sampleRate);

  /// How many threads the acoustic pass gets.
  ///
  /// Measured on the exported int8 model: one thread runs 3 s of audio in
  /// 571 ms, four in 167 ms. Past four the curve flattens and the extra
  /// threads land on efficiency cores, so this is where the win is.
  static int get _threads => math.min(4, Platform.numberOfProcessors);

  static Future<OnnxPhonemeModel> load(
    String modelPath, {
    int sampleRate = 16000,
  }) async {
    final runtime = OnnxRuntime();
    OrtSession session;
    try {
      session = await runtime.createSession(
        modelPath,
        options: OrtSessionOptions(
          intraOpNumThreads: _threads,
          // XNNPACK is the one that pays on quantised CPU inference. It falls
          // back per-operator, but a provider the build does not carry can
          // fail the whole session - hence the retry below, which is cheaper
          // than a model that will not open on somebody's phone.
          providers: [OrtProvider.XNNPACK, OrtProvider.CPU],
        ),
      );
    } on Object {
      session = await runtime.createSession(
        modelPath,
        options: OrtSessionOptions(intraOpNumThreads: _threads),
      );
    }
    return OnnxPhonemeModel._(session, sampleRate);
  }

  final OrtSession _session;
  final int _sampleRate;

  @override
  Future<Emissions> emissions(Float32List samples) async {
    final normalised = normalise(samples);
    final input = await OrtValue.fromList(
      normalised,
      [1, normalised.length],
    );
    try {
      final outputs = await _session.run({'input_values': input});
      final logits = outputs.values.first;
      final shape = logits.shape;
      final frames = shape[shape.length - 2];
      final vocabSize = shape[shape.length - 1];
      final flat = (await logits.asFlattenedList()).cast<num>();
      return Emissions(
        logProbs: logSoftmax(flat, frames, vocabSize),
        frames: frames,
        vocabSize: vocabSize,
        frameSeconds: samples.length / _sampleRate / frames,
      );
    } finally {
      await input.dispose();
    }
  }

  @override
  Future<void> dispose() => _session.close();

  /// Zero mean, unit variance over the whole utterance - the same
  /// normalisation `Wav2Vec2FeatureExtractor` applies with `do_normalize`.
  /// Skipping it does not fail loudly; it just makes every score worse.
  static Float32List normalise(Float32List samples) {
    if (samples.isEmpty) return samples;
    var sum = 0.0;
    for (final s in samples) {
      sum += s;
    }
    final mean = sum / samples.length;
    var variance = 0.0;
    for (final s in samples) {
      variance += (s - mean) * (s - mean);
    }
    variance /= samples.length;
    final scale = 1 / math.sqrt(variance + 1e-7);
    final out = Float32List(samples.length);
    for (var i = 0; i < samples.length; i++) {
      out[i] = (samples[i] - mean) * scale;
    }
    return out;
  }

  /// Log-softmax per frame, in place of the one the exported graph leaves out.
  static Float32List logSoftmax(List<num> logits, int frames, int vocabSize) {
    final out = Float32List(frames * vocabSize);
    for (var t = 0; t < frames; t++) {
      final base = t * vocabSize;
      var max = double.negativeInfinity;
      for (var v = 0; v < vocabSize; v++) {
        final value = logits[base + v].toDouble();
        if (value > max) max = value;
      }
      var sum = 0.0;
      for (var v = 0; v < vocabSize; v++) {
        sum += math.exp(logits[base + v].toDouble() - max);
      }
      final logSum = max + math.log(sum);
      for (var v = 0; v < vocabSize; v++) {
        out[base + v] = logits[base + v].toDouble() - logSum;
      }
    }
    return out;
  }
}
