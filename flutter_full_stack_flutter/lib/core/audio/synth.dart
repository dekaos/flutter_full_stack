import 'dart:math' as math;
import 'dart:typed_data';

/// The few things every sound in the app is made of: tones, noise, filters
/// and envelopes, mixed onto a [Tape].
///
/// The sounds are made, not recorded. Every one of them is a short recipe
/// over these (see `Sound`), so there is no file to license, nothing for the
/// app to carry, and a sound is changed by changing its recipe - the same
/// way a scene is changed by changing its drawing.
///
/// Pure Dart on purpose: no Flutter, so `tool/render_sounds.dart` can write
/// every sound out to listen to, and tests can measure them.

/// Samples per second. A phone's speaker gives little above 10 kHz, which
/// this still covers, and it halves the work of 44.1 kHz.
const sampleRate = 22050;

const double _tau = 2 * math.pi;

/// A length of sound being made, mixed into a sample at a time.
class Tape {
  Tape(double seconds) : samples = Float64List((seconds * sampleRate).ceil());

  final Float64List samples;

  int get length => samples.length;
  double get seconds => length / sampleRate;

  /// Mixes [other] in from [at] seconds, scaled by [gain].
  void mix(Tape other, {double at = 0, double gain = 1}) {
    final start = (at * sampleRate).round();
    for (var i = 0; i < other.length && start + i < length; i++) {
      if (start + i >= 0) samples[start + i] += gain * other.samples[i];
    }
  }

  /// Multiplies every sample by [envelope] at its time, in seconds.
  void shape(double Function(double t) envelope) {
    for (var i = 0; i < length; i++) {
      samples[i] *= envelope(i / sampleRate);
    }
  }

  /// The tape as it is played: no offset, no click where it starts or
  /// stops, and as loud as [level] says, at most.
  ///
  /// [level] is the loudest 50 ms of it, as root mean square in dBFS - how
  /// loud it sounds, more nearly than its peak, which a click can set alone.
  /// The peak is then kept under full scale so nothing clips.
  Float32List finish({double level = -18}) {
    final out = Float64List.fromList(samples);
    // Off the floor: anything below the speaker's reach is only headroom
    // lost, and a constant offset is a thump at each end.
    _highPassInPlace(out, 60);
    const fadeIn = 0.002;
    const fadeOut = 0.012;
    final n = out.length;
    for (var i = 0; i < n; i++) {
      final t = i / sampleRate;
      final end = (n - i) / sampleRate;
      if (t < fadeIn) out[i] *= t / fadeIn;
      if (end < fadeOut) out[i] *= end / fadeOut;
    }

    final window = (0.05 * sampleRate).round();
    var loudest = 0.0;
    var sum = 0.0;
    for (var i = 0; i < n; i++) {
      sum += out[i] * out[i];
      if (i >= window) sum -= out[i - window] * out[i - window];
      loudest = math.max(loudest, sum / math.min(i + 1, window));
    }
    var peak = 0.0;
    for (final s in out) {
      peak = math.max(peak, s.abs());
    }
    if (loudest <= 0 || peak <= 0) return Float32List(n);

    final wanted = math.pow(10, level / 20) / math.sqrt(loudest);
    final gain = math.min(wanted, 0.94 / peak);
    return Float32List.fromList([for (final s in out) s * gain]);
  }
}

/// White noise, the same every time for the same [seed].
Tape noise(double seconds, {required int seed}) {
  final tape = Tape(seconds);
  final random = math.Random(seed);
  for (var i = 0; i < tape.length; i++) {
    tape.samples[i] = random.nextDouble() * 2 - 1;
  }
  return tape;
}

/// Noise that falls away 6 dB an octave - Brownian, or red - so it is all
/// rumble and no hiss: what surf and wind sound like from a little way off.
/// White noise filtered into a band still hisses at its edges; this has
/// nothing up there to hiss with.
Tape softNoise(double seconds, {required int seed}) {
  final tape = noise(seconds, seed: seed);
  var level = 0.0;
  for (var i = 0; i < tape.length; i++) {
    // A leaky integrator, letting go below about 70 Hz so it cannot wander
    // off the floor.
    level = 0.98 * level + 0.02 * tape.samples[i];
    tape.samples[i] = level;
  }
  return tape;
}

/// A tone whose pitch, in Hz, follows [hz] over time, made of [partials] -
/// multiples of the pitch, with their loudness - each fading as their
/// [decays] say, in seconds (`null` for not at all).
///
/// Phase is carried from one sample to the next, so a sliding pitch slides
/// rather than clicking.
Tape tone(
  double seconds, {
  required double Function(double t) hz,
  List<double> partials = const [1],
  List<double> loudness = const [1],
  List<double?>? decays,
  double attack = 0.002,
}) {
  final tape = Tape(seconds);
  // A phase for each partial: they need not be whole multiples, and a bell's
  // are not.
  final phases = List<double>.filled(partials.length, 0);
  for (var i = 0; i < tape.length; i++) {
    final t = i / sampleRate;
    final f0 = hz(t);
    var sample = 0.0;
    for (var k = 0; k < partials.length; k++) {
      final f = f0 * partials[k];
      if (f < sampleRate / 2) {
        final decay = decays?[k];
        final fade = decay == null ? 1.0 : math.exp(-t / decay);
        sample += loudness[k] * fade * math.sin(phases[k]);
      }
      phases[k] = (phases[k] + _tau * f / sampleRate) % _tau;
    }
    tape.samples[i] = sample * math.min(1, t / attack);
  }
  return tape;
}

/// Something struck - a bar, a bell, a cup - ringing at [hz]: one partial
/// per entry of [ratios], each as loud as [loudness] says and fading over
/// its own [decays], the higher ones sooner, as they do.
Tape strike(
  double hz, {
  required List<double> ratios,
  required List<double> loudness,
  required List<double> decays,
  double? seconds,
}) => tone(
  seconds ?? decays.reduce(math.max) * 5,
  hz: (_) => hz,
  partials: ratios,
  loudness: loudness,
  decays: decays,
  attack: 0.0015,
);

/// A string plucked at [hz] - a guitar's, a harp's - by Karplus-Strong: a
/// burst of noise going round a loop one period long, each time round a
/// little softer and a little duller, which is what a string does to the
/// shape it was plucked into. It rings for about [decay] seconds, falling by
/// `1/e` over that; [brightness], `0` to `1`, is how much of the pluck's top
/// survives it - a nail's against a thumb's.
///
/// The same every time for the same [seed].
Tape string(
  double seconds, {
  required double hz,
  required int seed,
  double decay = 1.2,
  double brightness = 0.6,
}) {
  final tape = Tape(seconds);
  final period = math.max(2, (sampleRate / hz).round());
  final loop = Float64List(period);
  final random = math.Random(seed);
  // The pluck: noise, smoothed as much as [brightness] leaves it.
  var smooth = 0.0;
  for (var i = 0; i < period; i++) {
    final raw = random.nextDouble() * 2 - 1;
    smooth += (raw - smooth) * (0.15 + 0.85 * brightness);
    loop[i] = smooth;
  }
  // Each time round the loop, the average of neighbours - the string's own
  // damping, which takes the top off first - times the loss that makes it
  // fade over [decay].
  final loss = math.exp(-period / (decay * sampleRate));
  for (var i = 0; i < tape.length; i++) {
    final at = i % period;
    final next = (at + 1) % period;
    tape.samples[i] = loop[at];
    loop[at] = loss * 0.5 * (loop[at] + loop[next]);
  }
  return tape;
}

/// A voice, a tone whose loudness by frequency is reshaped as it goes by
/// formants - the resonances of a mouth: [formants] gives their centres in
/// Hz over time, and [widths] how wide each is. Harmonics of [hz] up to the
/// Nyquist frequency, each [tilt] dB per octave quieter than the last.
Tape voice(
  double seconds, {
  required double Function(double t) hz,
  required List<double> Function(double t) formants,
  required List<double> widths,
  List<double> weights = const [1, 0.7, 0.3],
  double tilt = -6,
}) {
  final tape = Tape(seconds);
  var phase = 0.0;
  for (var i = 0; i < tape.length; i++) {
    final t = i / sampleRate;
    final f0 = hz(t);
    final centres = formants(t);
    var sample = 0.0;
    for (var k = 1; k * f0 < sampleRate / 2 - 500; k++) {
      final f = k * f0;
      var shape = 0.0;
      for (var j = 0; j < centres.length; j++) {
        final x = (f - centres[j]) / (widths[j] / 2);
        shape += weights[j] / (1 + x * x);
      }
      final roll = math.pow(10, tilt * math.log(k) / math.ln2 / 20);
      sample += shape * roll * math.sin(phase * k);
    }
    tape.samples[i] = sample;
    phase = (phase + _tau * f0 / sampleRate) % _tau;
  }
  return tape;
}

/// [tape] through a band-pass filter centred on [hz] at each moment, [q]
/// wide - noise through one of these is wind, surf, breath.
Tape bandPass(Tape tape, double Function(double t) hz, {double q = 1}) =>
    _biquad(tape, hz, q, _Kind.band);

/// [tape] with what is above [hz] at each moment taken off.
Tape lowPass(Tape tape, double Function(double t) hz, {double q = 0.707}) =>
    _biquad(tape, hz, q, _Kind.low);

/// [tape] with what is below [hz] at each moment taken off.
Tape highPass(Tape tape, double Function(double t) hz, {double q = 0.707}) =>
    _biquad(tape, hz, q, _Kind.high);

enum _Kind { low, high, band }

/// The audio cookbook's biquad (Robert Bristow-Johnson), its coefficients
/// worked out again every few samples so a sweep is smooth.
Tape _biquad(Tape tape, double Function(double t) hz, double q, _Kind kind) {
  final out = Tape(tape.seconds);
  var x1 = 0.0;
  var x2 = 0.0;
  var y1 = 0.0;
  var y2 = 0.0;
  var b0 = 0.0;
  var b1 = 0.0;
  var b2 = 0.0;
  var a1 = 0.0;
  var a2 = 0.0;
  for (var i = 0; i < tape.length; i++) {
    if (i % 16 == 0) {
      final f = hz(i / sampleRate).clamp(20.0, sampleRate / 2 - 100);
      final w = _tau * f / sampleRate;
      final alpha = math.sin(w) / (2 * q);
      final cos = math.cos(w);
      final a0 = 1 + alpha;
      switch (kind) {
        case _Kind.low:
          b0 = (1 - cos) / 2 / a0;
          b1 = (1 - cos) / a0;
          b2 = b0;
        case _Kind.high:
          b0 = (1 + cos) / 2 / a0;
          b1 = -(1 + cos) / a0;
          b2 = b0;
        case _Kind.band:
          b0 = alpha / a0;
          b1 = 0;
          b2 = -alpha / a0;
      }
      a1 = -2 * cos / a0;
      a2 = (1 - alpha) / a0;
    }
    final x = tape.samples[i];
    final y = b0 * x + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2;
    x2 = x1;
    x1 = x;
    y2 = y1;
    y1 = y;
    out.samples[i] = y;
  }
  return out;
}

void _highPassInPlace(Float64List samples, double hz) {
  final tape = Tape(samples.length / sampleRate)..samples.setAll(0, samples);
  final out = highPass(tape, (_) => hz);
  samples.setAll(0, out.samples.sublist(0, samples.length));
}

/// `0` before [begin], `1` after [end], and an S-curve between.
double ease(double t, double begin, double end) {
  final x = ((t - begin) / (end - begin)).clamp(0.0, 1.0);
  return x * x * (3 - 2 * x);
}

/// Up quickly over [attack] seconds, then fading by `1/e` every [decay].
double pluck(double t, {required double decay, double attack = 0.003}) =>
    t < attack ? t / attack : math.exp(-(t - attack) / decay);

/// Up over [rise], held, and down over [fall] to nothing at [seconds].
double swell(
  double t, {
  required double seconds,
  required double rise,
  required double fall,
}) => ease(t, 0, rise) * (1 - ease(t, seconds - fall, seconds));

/// The value at [t] of the line through [points], `(time, value)` pairs in
/// time order - held flat before the first and after the last.
double through(List<(double, double)> points, double t) {
  if (t <= points.first.$1) return points.first.$2;
  for (var i = 1; i < points.length; i++) {
    final (t1, v1) = points[i];
    if (t <= t1) {
      final (t0, v0) = points[i - 1];
      final x = ease(t, t0, t1);
      return v0 + (v1 - v0) * x;
    }
  }
  return points.last.$2;
}

/// [samples] as a WAV file: 16-bit PCM, one channel, at [rate].
Uint8List wav(Float32List samples, {int rate = sampleRate}) {
  final data = samples.length * 2;
  final bytes = ByteData(44 + data);
  void text(int at, String s) {
    for (var i = 0; i < s.length; i++) {
      bytes.setUint8(at + i, s.codeUnitAt(i));
    }
  }

  text(0, 'RIFF');
  bytes.setUint32(4, 36 + data, Endian.little);
  text(8, 'WAVE');
  text(12, 'fmt ');
  bytes
    ..setUint32(16, 16, Endian.little)
    ..setUint16(20, 1, Endian.little)
    ..setUint16(22, 1, Endian.little)
    ..setUint32(24, rate, Endian.little)
    ..setUint32(28, rate * 2, Endian.little)
    ..setUint16(32, 2, Endian.little)
    ..setUint16(34, 16, Endian.little);
  text(36, 'data');
  bytes.setUint32(40, data, Endian.little);
  for (var i = 0; i < samples.length; i++) {
    final s = (samples[i].clamp(-1.0, 1.0) * 32767).round();
    bytes.setInt16(44 + 2 * i, s, Endian.little);
  }
  return bytes.buffer.asUint8List();
}

/// The part of a recording at [rate] from [from] to [to] seconds, made fit
/// to play back to the person who made it: brought up to a clear level -
/// a phone held at arm's length records quietly - but never by more than
/// [boost] times, so a near-silent take is not turned into roaring hiss;
/// and eased in and out, so a word cut from the middle of a sentence does
/// not start or stop with a click.
Float32List excerpt(
  Float32List samples, {
  required int rate,
  double from = 0,
  double? to,
  double peak = 0.9,
  double boost = 8,
}) {
  final start = (from * rate).round().clamp(0, samples.length);
  final end = ((to ?? samples.length / rate) * rate).round().clamp(
    start,
    samples.length,
  );
  final out = Float32List.fromList(samples.sublist(start, end));
  var loudest = 0.0;
  for (final s in out) {
    loudest = math.max(loudest, s.abs());
  }
  final gain = loudest == 0 ? 1.0 : math.min(boost, peak / loudest);
  final fade = (0.006 * rate).round();
  for (var i = 0; i < out.length; i++) {
    final edge = math.min(i, out.length - 1 - i);
    out[i] *= gain * (edge < fade ? edge / fade : 1);
  }
  return out;
}

/// How loud [samples] is across [bars] equal slices of it, `0` to `1` of
/// its loudest slice: the outline a voice message is drawn with.
List<double> envelope(Float32List samples, {required int bars}) {
  if (samples.isEmpty) return List.filled(bars, 0);
  final levels = <double>[];
  for (var b = 0; b < bars; b++) {
    final start = samples.length * b ~/ bars;
    final end = math.max(start + 1, samples.length * (b + 1) ~/ bars);
    var sum = 0.0;
    for (var i = start; i < end && i < samples.length; i++) {
      sum += samples[i] * samples[i];
    }
    levels.add(math.sqrt(sum / (end - start)));
  }
  final loudest = math.max(levels.reduce(math.max), 1e-9);
  return [for (final l in levels) l / loudest];
}
