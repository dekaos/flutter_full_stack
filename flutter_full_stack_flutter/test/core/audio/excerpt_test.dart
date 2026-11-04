import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_full_stack_flutter/core/audio/synth.dart';
import 'package:flutter_test/flutter_test.dart';

/// A second of a quiet 200 Hz hum at [rate], as a phone held at arm's
/// length might record a voice.
Float32List _hum({int rate = 16000, double level = 0.05}) =>
    Float32List.fromList([
      for (var i = 0; i < rate; i++)
        level * math.sin(2 * math.pi * 200 * i / rate),
    ]);

double _peak(Float32List samples) =>
    samples.map((s) => s.abs()).reduce(math.max);

void main() {
  group('a recording played back', () {
    test('is cut where it is asked to be', () {
      final cut = excerpt(_hum(), rate: 16000, from: 0.25, to: 0.5);
      expect(cut.length, 4000);
    });

    test('is brought up to a clear level - but a whisper is not turned into '
        'a roar', () {
      // 0.2 needs 4.5 times to reach the level a playback is made at.
      expect(_peak(excerpt(_hum(level: 0.2), rate: 16000)), closeTo(0.9, 0.01));
      // 0.05 would need 18 times; it gets the most it may have.
      expect(_peak(excerpt(_hum(), rate: 16000)), closeTo(0.4, 0.01));
      final faint = excerpt(_hum(level: 0.001), rate: 16000);
      expect(_peak(faint), closeTo(0.008, 0.001));
    });

    test('starts and ends without a click, even cut mid-word', () {
      final cut = excerpt(_hum(), rate: 16000, from: 0.1003, to: 0.4007);
      expect(cut.first.abs(), lessThan(1e-6));
      expect(cut.last.abs(), lessThan(1e-6));
    });

    test('is written at its own rate', () {
      final bytes = ByteData.sublistView(wav(Float32List(160), rate: 16000));
      expect(bytes.getUint32(24, Endian.little), 16000);
      expect(bytes.getUint32(28, Endian.little), 32000);
    });
  });

  test('a voice message is outlined by how loud it is along its length', () {
    final samples = Float32List(16000);
    // Loud in its second half only.
    for (var i = 8000; i < 16000; i++) {
      samples[i] = math.sin(i / 3);
    }
    final bars = envelope(samples, bars: 10);
    expect(bars, hasLength(10));
    expect(bars.reduce(math.max), 1);
    expect(bars.take(5), everyElement(0));
    expect(bars.skip(5), everyElement(greaterThan(0.9)));
  });
}
