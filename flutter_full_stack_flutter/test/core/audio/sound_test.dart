import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_full_stack_flutter/core/audio/sound.dart';
import 'package:flutter_full_stack_flutter/core/audio/synth.dart';
import 'package:flutter_test/flutter_test.dart';

/// The loudest 50 ms of [samples], as root mean square in dBFS.
double _loudest(Float32List samples) {
  final window = (0.05 * sampleRate).round();
  var sum = 0.0;
  var loudest = 0.0;
  for (var i = 0; i < samples.length; i++) {
    sum += samples[i] * samples[i];
    if (i >= window) sum -= samples[i - window] * samples[i - window];
    loudest = math.max(loudest, sum / math.min(i + 1, window));
  }
  return 10 * math.log(loudest) / math.ln10;
}

void main() {
  final rendered = {for (final sound in Sound.values) sound: sound.render()};

  group('every sound', () {
    test('is short, and over before the next thing happens', () {
      for (final MapEntry(key: sound, value: samples) in rendered.entries) {
        final seconds = samples.length / sampleRate;
        expect(seconds, inInclusiveRange(0.1, 2.5), reason: sound.name);
        // Its moment is inside it.
        expect(
          sound.hit.inMicroseconds / 1e6,
          lessThan(seconds),
          reason: sound.name,
        );
      }
    });

    test('never clips, and starts and ends in silence', () {
      for (final MapEntry(key: sound, value: samples) in rendered.entries) {
        final peak = samples.map((s) => s.abs()).reduce(math.max);
        expect(peak, lessThanOrEqualTo(0.95), reason: sound.name);
        expect(samples.every((s) => s.isFinite), isTrue, reason: sound.name);
        // A sample far from zero at either end is a click.
        expect(samples.first.abs(), lessThan(1e-3), reason: sound.name);
        expect(samples.last.abs(), lessThan(1e-2), reason: sound.name);
      }
    });

    test('is made as loud as the rest, and played softer than a voice', () {
      for (final MapEntry(key: sound, value: samples) in rendered.entries) {
        // Made at -18 dBFS where it is loudest, unless that would clip.
        expect(
          _loudest(samples),
          inInclusiveRange(-30, -16.5),
          reason: sound.name,
        );
        expect(sound.volume, inExclusiveRange(0, 0.8), reason: sound.name);
      }
    });

    test('is the same every time it is made', () {
      for (final sound in Sound.values) {
        expect(sound.render(), rendered[sound], reason: sound.name);
      }
    });
  });

  test('a WAV file says what it holds', () {
    final samples = Float32List.fromList([0, 0.5, -0.5, 1, -1]);
    final bytes = ByteData.sublistView(wav(samples));

    String text(int at) => String.fromCharCodes(
      bytes.buffer.asUint8List(bytes.offsetInBytes + at, 4),
    );
    expect(text(0), 'RIFF');
    expect(text(8), 'WAVE');
    expect(bytes.getUint16(20, Endian.little), 1, reason: 'PCM');
    expect(bytes.getUint16(22, Endian.little), 1, reason: 'one channel');
    expect(bytes.getUint32(24, Endian.little), sampleRate);
    expect(bytes.getUint16(34, Endian.little), 16, reason: 'bits');
    expect(bytes.getUint32(40, Endian.little), samples.length * 2);
    expect(bytes.lengthInBytes, 44 + samples.length * 2);
    expect(bytes.getInt16(44 + 2, Endian.little), 16384);
    expect(bytes.getInt16(44 + 8, Endian.little), -32767);
  });
}
