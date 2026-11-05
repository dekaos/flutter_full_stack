import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// Captures one spoken attempt at the rate the acoustic model expects.
///
/// 16 kHz mono PCM is not a preference: the model was trained on it, and
/// resampling after the fact would cost quality on the very detail being
/// measured.
class AttemptRecorder {
  AttemptRecorder({AudioRecorder? recorder})
    : _recorder = recorder ?? AudioRecorder();

  static const sampleRate = 16000;

  final AudioRecorder _recorder;
  String? _path;

  /// Whether the microphone may be used. With [request], asks for it when
  /// the answer is not settled yet; without, only looks - which is what
  /// checking again after a visit to settings needs, so that coming back does
  /// not throw another dialog at the learner.
  Future<bool> hasPermission({bool request = true}) =>
      _recorder.hasPermission(request: request);

  Future<void> start() async {
    final directory = await getTemporaryDirectory();
    _path = '${directory.path}/attempt.pcm';
    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: sampleRate,
        numChannels: 1,
      ),
      path: _path!,
    );
  }

  /// Stops and returns the recording as the float samples the model takes.
  Future<Float32List> stop() async {
    final path = await _recorder.stop() ?? _path;
    if (path == null) return Float32List(0);
    final file = File(path);
    if (!file.existsSync()) return Float32List(0);
    final bytes = await file.readAsBytes();
    await file.delete();
    return decodePcm16(bytes);
  }

  Future<void> cancel() async {
    await _recorder.cancel();
    _path = null;
  }

  void dispose() => _recorder.dispose();

  /// Signed 16-bit little-endian samples to floats in -1..1.
  ///
  /// A WAV header is skipped when one is present: `record` writes raw PCM for
  /// `pcm16bits`, but not every platform implementation agrees on that, and 44
  /// stray bytes at the front shift every frame of the alignment.
  static Float32List decodePcm16(Uint8List bytes) {
    var offset = 0;
    if (bytes.length > 44 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46) {
      offset = 44;
    }
    final count = (bytes.length - offset) ~/ 2;
    final view = ByteData.sublistView(bytes, offset, offset + count * 2);
    final samples = Float32List(count);
    for (var i = 0; i < count; i++) {
      samples[i] = view.getInt16(i * 2, Endian.little) / 32768.0;
    }
    return samples;
  }
}
