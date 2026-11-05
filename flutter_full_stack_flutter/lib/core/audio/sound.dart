import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_full_stack_flutter/core/audio/synth.dart';

/// Every sound the app makes, besides the voice that reads a prompt aloud -
/// the hiding cat's, the score's, and the scenes'.
///
/// Each is a recipe, made on the device the first time it is needed (see
/// `synth.dart`). They are all short, soft and over in a moment: decoration,
/// like the scenes they belong to, and like them they never play while the
/// microphone is open (`SoundBoard`).
enum Sound {
  /// The cat calling softly as it comes out to wash: the learner has been
  /// quiet a while.
  meow(0.45),

  /// The rolled "mrrp" a cat greets with - for an attempt that went well.
  trill(0.62),

  /// A soft, closed-mouthed "mrrm", through a slow blink - for one that did
  /// not. It is a comfort, not a verdict.
  murmur(0.67),

  /// An attempt scored: in the band each colours its score with.
  scoreStrong(0.56),
  scoreFair(0.51),
  scoreWeak(0.52),

  /// The weather scene: the wind gets up, then the sun breaks through.
  wind(0.56),
  sparkle(0.25),

  /// A bubble popping up: a thought, an order.
  pop(0.52),

  /// The thinking scene's count: one, two, three things.
  countOne(0.39),
  countTwo(0.35),
  countThree(0.34),

  /// A cup set down on its saucer.
  clink(0.37),

  /// A wave rolling up the sand: the swell first, so it breaks on its cue.
  wave(0.28, hit: Duration(milliseconds: 500)),

  /// A robin, landing.
  chirp(0.28),

  /// The bell on a hotel's front desk.
  deskBell(0.35),

  /// A jigsaw piece clicking into place.
  click(0.37),

  /// A small car's horn, as a toy's would sound.
  horn(0.38),

  /// A clock tower's bell, striking the hour.
  clockBell(0.47),

  /// A plane taking off.
  takeoff(0.29),

  /// The language chooser's places, each answering in its own way: New
  /// York's - a Broadway brass fanfare, "ba-da... DAAA!", as the firework
  /// from the Statue of Liberty's torch bursts into a heart, and its
  /// sparkle coming down.
  fanfare(0.42, hit: Duration(milliseconds: 550)),

  /// A flamenco guitar, as a dancer in Seville's Plaza de España strikes
  /// her pose: a soft stroke, then the quick flourish of a rasgueado on the
  /// chord a flamenco cadence comes home to.
  guitarStrum(0.42),

  /// A Korean temple bell, struck with a log: deep, soft at the start, and
  /// pulsing slowly as it rings.
  templeBell(0.72),

  /// The word hunt's laser leaving the rocket: a quick, bright "pew", soft
  /// enough to be heard a few times a word.
  laser(0.24),

  /// The answer hit: a sparkle of bells running up a chord, over a soft
  /// thump - the game's one big reward, and it should feel like one.
  burst(0.5),

  /// A wrong ship's shield taking the shot: a rubbery "boing" that falls
  /// away. Like the score's weakest chime, never a buzzer.
  bonk(0.4),

  /// A wave of ships coming out of the dark: a quick shimmer rising up a
  /// scale.
  warp(0.26);

  Sound(this.volume, {this.hit = Duration.zero});

  /// How loud it is played, `0` to `1`: set by ear-weighted measurement,
  /// so the score's chimes are the most present, the cat's voice next, and
  /// the scenes' sounds a step behind - and all of them well under a voice
  /// reading a prompt, which plays at full. Re-measure after changing a
  /// recipe: `tool/render_sounds.dart` writes them out to compare.
  final double volume;

  /// How far into the sound the moment it marks comes - a wave's break,
  /// after its swell. What is struck is heard as it is struck, at once.
  /// It is started this much ahead of its cue, so that moment is on it.
  final Duration hit;

  /// The sound, as samples at [sampleRate].
  Float32List render() => switch (this) {
    Sound.meow => _meow(),
    Sound.trill => _trill(),
    Sound.murmur => _murmur(),
    Sound.scoreStrong => _chord(const [1046.5, 1318.5, 1568, 2093], 0.075),
    Sound.scoreFair => _chord(const [784, 1046.5], 0.1),
    Sound.scoreWeak => _chord(const [659.3], 0, bright: false),
    Sound.wind => _wind(),
    Sound.sparkle => _sparkle(),
    Sound.pop => _pop(),
    Sound.countOne => _count(784),
    Sound.countTwo => _count(987.8),
    Sound.countThree => _count(1174.7),
    Sound.clink => _clink(),
    Sound.wave => _wave(),
    Sound.chirp => _chirp(),
    Sound.deskBell => _deskBell(),
    Sound.click => _click(),
    Sound.horn => _horn(),
    Sound.clockBell => _clockBell(),
    Sound.takeoff => _takeoff(),
    Sound.fanfare => _fanfare(),
    Sound.guitarStrum => _guitarStrum(),
    Sound.templeBell => _templeBell(),
    Sound.laser => _laser(),
    Sound.burst => _burst(),
    Sound.bonk => _bonk(),
    Sound.warp => _warp(),
  };
}

const double _tau = 2 * math.pi;

/// The instant something hard is struck: a hundredth of a second of noise
/// above [above] Hz, gone in [decay] seconds. Laid over a ringing partial,
/// it is what makes a cup, a bell or a jigsaw piece sound hit rather than
/// switched on.
Tape _tick(int seed, {required double above, double decay = 0.0015}) =>
    highPass(noise(0.01, seed: seed), (_) => above)
      ..shape((t) => pluck(t, attack: 0.0003, decay: decay));

// ------------------------------------------------------------------ cat --

/// A smooth wobble, `-1` to `1`, wandering about [rate] times a second:
/// the small unsteadiness of a living voice - in its pitch, cycle to cycle,
/// and in its loudness - that no instrument has, and without which a voice
/// sounds played rather than voiced.
double Function(double t) _wobble(int seed, {required double rate}) {
  final random = math.Random(seed);
  final points = [
    for (var i = 0; i < (3 * rate).ceil() + 2; i++) random.nextDouble() * 2 - 1,
  ];
  return (t) {
    final x = (t * rate).clamp(0, points.length - 1.001).toDouble();
    final i = x.floor();
    final f = x - i;
    return points[i] + (points[i + 1] - points[i]) * f * f * (3 - 2 * f);
  };
}

/// A voice before the mouth shapes it: a puff of air through the vocal
/// folds every period at [hz], each opening slowly and snapping shut
/// (Rosenberg's pulse), heard as the change in the airflow. A throat's
/// sound, rich in harmonics and falling away above them - not a stack of
/// sines in step, which is what makes a made voice sound like an organ.
Tape _glottis(double seconds, double Function(double t) hz) {
  const opening = 0.42;
  const closing = 0.18;
  final tape = Tape(seconds);
  var phase = 0.0;
  var last = 0.0;
  for (var i = 0; i < tape.length; i++) {
    final p = phase;
    final flow = p < opening
        ? 0.5 * (1 - math.cos(math.pi * p / opening))
        : p < opening + closing
        ? math.cos(math.pi * (p - opening) / (2 * closing))
        : 0.0;
    tape.samples[i] = flow - last;
    last = flow;
    phase = (phase + hz(i / sampleRate) / sampleRate) % 1;
  }
  return tape;
}

/// "Mi-a-ow", as a cat says it to someone it knows: a throat's voice,
/// steady as a held note is, shaped by a small mouth.
///
/// Measured against recorded meows, and against the meow of soundgen (a
/// synthesiser of animal and human voices): a cat holds its pitch almost
/// level, about 550 Hz, after one quick lift as the mouth opens, and lets it
/// down a little as the mouth closes - the arch a voice climbs and falls in
/// is a yowl's, and heard from a cat it is a scream. Nor is its pitch what is
/// loudest: a cat's short mouth rings at about 1.6 kHz, on the third
/// harmonic, the first one down at a whisper beside it. The mouth opens wide
/// on the "a" over a sixth of the call, then closes slowly through the "ow",
/// the bright upper harmonics going with it. No vibrato and little
/// unsteadiness - a contented cat's voice is a clean one.
Float32List _meow() {
  const seconds = 0.92;
  final jitter = _wobble(11, rate: 30);
  final drift = _wobble(12, rate: 5);
  final shimmer = _wobble(13, rate: 24);
  double pitch(double t) =>
      through(const [
        (0, 450),
        (0.1, 562),
        (0.22, 572),
        (0.52, 550),
        (0.76, 528),
        (0.92, 480),
      ], t) *
      (1 + 0.003 * jitter(t) + 0.008 * drift(t));

  // The throat's voice, its lowest harmonics thinned as a small throat
  // thins them, with a breath of air through it - a little more as the
  // voice gives out.
  final source = highPass(_glottis(seconds, pitch), (_) => 800)
    ..shape((t) => 1 + 0.04 * shimmer(t))
    ..mix(
      noise(seconds, seed: 14)
        ..shape((t) => 0.003 + 0.005 * ease(t, 0.62, 0.92)),
    );

  // The mouth: shut, wide open by a sixth of the way through, then closing
  // slowly to the end (soundgen's meow opens and closes the same way).
  double open(double t) => through(const [
    (0, 0),
    (0.19, 1),
    (0.45, 0.86),
    (0.84, 0.32),
    (0.92, 0.08),
  ], t);
  final mouth = bandPass(source, (t) => 1100 + 680 * open(t), q: 4)
    ..mix(bandPass(source, (t) => 2900 + 700 * open(t), q: 5), gain: 0.5)
    ..mix(bandPass(source, (t) => 4300 + 500 * open(t), q: 6), gain: 0.18);
  // A closing mouth takes the bright harmonics first: the "ow".
  final tape = lowPass(mouth, (t) => 2600 + 4400 * open(t))
    ..shape(
      (t) =>
          (0.3 + 0.7 * open(t)) *
          swell(t, seconds: seconds, rise: 0.22, fall: 0.18),
    );
  return tape.finish();
}

/// "Mrrp": closed-mouthed and rolled, rising at the end like a question.
Float32List _trill() {
  const seconds = 0.36;
  final tape =
      voice(
        seconds,
        hz: (t) => through(const [
          (0, 400),
          (0.2, 470),
          (0.3, 640),
          (0.36, 620),
        ], t),
        formants: (t) => [
          through(const [(0, 480), (0.24, 680), (0.36, 950)], t),
          through(const [(0, 1500), (0.36, 2100)], t),
          3400,
        ],
        widths: const [300, 420, 700],
      )..shape((t) {
        // The roll: the voice fluttering at a cat's 26 times a second,
        // easing out as the mouth opens.
        final roll = 1 - ease(t, 0.2, 0.28);
        final flutter = 0.5 + 0.5 * math.cos(_tau * 26 * t);
        return (1 - 0.75 * roll * flutter) *
            swell(t, seconds: seconds, rise: 0.03, fall: 0.1);
      });
  return tape.finish();
}

/// "Mrrm": the low, closed-mouthed murmur a contented cat gives someone
/// it trusts - a voice, like the meow, a little lower and softer, and
/// falling away.
///
/// In place of a purr. A purr is a rumble 25 times a second, far lower than
/// a phone's speaker can play: all that is left of it there is the rattle,
/// which sounded like static.
Float32List _murmur() {
  const seconds = 0.75;
  final tape =
      voice(
        seconds,
        hz: (t) =>
            through(const [(0, 400), (0.14, 460), (0.75, 340)], t) *
            (1 + 0.01 * math.sin(_tau * 5 * t)),
        formants: (t) => [
          through(const [(0, 360), (0.2, 520), (0.75, 400)], t),
          through(const [(0, 1100), (0.25, 1450), (0.75, 1150)], t),
          3000,
        ],
        widths: const [240, 380, 600],
        weights: const [1, 0.8, 0.2],
      )..shape((t) {
        // A gentle "rr" at the start, settling into the hum.
        final roll = 1 - ease(t, 0.12, 0.3);
        final flutter = 0.5 + 0.5 * math.cos(_tau * 20 * t);
        return (1 - 0.3 * roll * flutter) *
            swell(t, seconds: seconds, rise: 0.08, fall: 0.35);
      });
  return tape.finish();
}

// ---------------------------------------------------------------- score --

/// Wooden bars struck one after another, [gap] seconds apart, up through
/// [notes]: a marimba's, whose first overtone is near two octaves up.
Float32List _chord(List<double> notes, double gap, {bool bright = true}) {
  final tape = Tape(notes.length * gap + 0.9);
  for (final (i, hz) in notes.indexed) {
    final last = i == notes.length - 1;
    tape.mix(
      strike(
        hz,
        ratios: const [1, 3.93, 9.2],
        loudness: bright ? const [1, 0.28, 0.06] : const [1, 0.12, 0.02],
        decays: [if (last) 0.4 else 0.25, 0.06, 0.02],
        seconds: 0.9,
      ),
      at: i * gap,
      gain: last ? 1 : 0.8,
    );
  }
  return tape.finish(level: -17);
}

// --------------------------------------------------------------- scenes --

/// A breeze getting up: a soft rush, rising and falling away, with a faint
/// hollow note in it. Made of [softNoise] and kept under 1 kHz - a breeze,
/// not a gale, and no hiss.
Float32List _wind() {
  const seconds = 2.2;
  Tape rush(Tape tape) => lowPass(lowPass(tape, (_) => 900), (_) => 900);
  final body = rush(
    bandPass(
      softNoise(seconds, seed: 31),
      (t) => 320 + 300 * ease(t, 0, 0.9) - 180 * ease(t, 1.1, seconds),
      q: 0.6,
    ),
  );
  final note = rush(
    bandPass(
      softNoise(seconds, seed: 32),
      (t) => 640 + 160 * ease(t, 0.3, 1) - 120 * ease(t, 1.2, seconds),
      q: 14,
    ),
  );
  final tape = body
    ..mix(note, gain: 0.35)
    ..shape(
      (t) =>
          swell(t, seconds: seconds, rise: 0.9, fall: 1.1) *
          (1 + 0.12 * math.sin(_tau * 1.6 * t) * ease(t, 0.3, 0.8)),
    );
  return tape.finish();
}

/// Glints of light: soft bell-like pings, unhurried and falling away -
/// pitched where a phone's speaker is round rather than shrill.
Float32List _sparkle() {
  const notes = [1046.5, 1174.7, 1318.5, 1568.0, 1760.0];
  const times = [0.0, 0.07, 0.14, 0.22, 0.31, 0.41];
  final random = math.Random(21);
  final tape = Tape(1.1);
  for (final (i, at) in times.indexed) {
    tape.mix(
      strike(
        notes[random.nextInt(notes.length)],
        ratios: const [1, 2.76],
        loudness: const [1, 0.08],
        decays: const [0.22, 0.04],
        seconds: 0.65,
      ),
      at: at,
      gain: 1 - 0.55 * i / (times.length - 1),
    );
  }
  return tape.finish();
}

/// A bubble: a quick "bloop" rising in pitch.
Float32List _pop() {
  const seconds = 0.16;
  final tape = tone(
    seconds,
    hz: (t) => 380 + 950 * (1 - math.exp(-t / 0.018)),
    partials: const [1, 2],
    loudness: const [1, 0.15],
  )..shape((t) => pluck(t, decay: 0.03));
  return tape.finish();
}

/// A glockenspiel's bar - a clear, bright count.
Float32List _count(double hz) => strike(
  hz,
  ratios: const [1, 2.76, 5.4, 8.93],
  loudness: const [1, 0.4, 0.18, 0.07],
  decays: const [0.6, 0.22, 0.09, 0.04],
  seconds: 1.1,
).finish();

/// Porcelain on porcelain: the cup's ring, high and short, and a softer
/// second as it settles.
Float32List _clink() {
  Tape porcelain(double scale, int seed) =>
      strike(
        2860 * scale,
        ratios: const [1, 1.46, 1.93, 2.46],
        loudness: const [1, 0.7, 0.5, 0.35],
        decays: const [0.11, 0.07, 0.045, 0.03],
        seconds: 0.4,
      )..mix(
        _tick(seed, above: 4000),
        gain: 0.6,
      );
  final tape = Tape(0.5)
    ..mix(porcelain(1, 11))
    ..mix(porcelain(1.04, 12), at: 0.075, gain: 0.45);
  return tape.finish();
}

/// A small wave on a calm day, told in notes rather than noise - noise on a
/// phone's speaker only ever sounds like hiss, or wind. A soft harp runs up
/// the scale as the wave swells, quickening into the break at [Sound.hit],
/// where a few drops splash; then it runs back down, slower and fading, as
/// the water draws back over the sand.
Float32List _wave() {
  // C major pentatonic, G4 to E6: a scale with no wrong note in it.
  const scale = [
    392.0,
    440.0,
    523.3,
    587.3,
    659.3,
    784.0,
    880.0,
    1046.5,
    1174.7,
    1318.5,
  ];
  Tape harp(double hz) => strike(
    hz,
    ratios: const [1, 2, 3],
    loudness: const [1, 0.18, 0.05],
    decays: const [0.45, 0.15, 0.06],
    seconds: 1,
  );
  Tape drop(double hz) => tone(
    0.08,
    hz: (t) => hz * (1 + 0.5 * ease(t, 0, 0.03)),
  )..shape((t) => pluck(t, decay: 0.015));

  const rising = 8;
  const breaks = 0.5;
  final tape = Tape(2.4);
  for (var i = 0; i < rising; i++) {
    // Each note sooner after the last, as a wave gathers pace.
    final at = breaks * 0.9 * math.pow(i / (rising - 1), 0.8);
    tape.mix(harp(scale[i]), at: at, gain: 0.35 + 0.65 * i / rising);
  }
  for (final (at, hz) in const [
    (0.0, 1800.0),
    (0.06, 2300.0),
    (0.13, 2000.0),
  ]) {
    tape.mix(drop(hz), at: breaks + at, gain: 0.22);
  }
  const falling = 7;
  for (var i = 0; i < falling; i++) {
    tape.mix(
      harp(scale[rising - 2 - i]),
      at: breaks + 0.12 + 0.14 * i,
      gain: 0.75 * (1 - i / falling),
    );
  }
  return tape.finish();
}

/// A robin: two quick falling notes and a rising one, warbling.
Float32List _chirp() {
  Tape note(double from, double to, double seconds) => tone(
    seconds,
    hz: (t) =>
        from +
        (to - from) * ease(t, 0, seconds) +
        120 * math.sin(_tau * 38 * t),
    partials: const [1, 2],
    loudness: const [1, 0.12],
  )..shape((t) => math.pow(math.sin(math.pi * t / seconds), 2).toDouble());
  final tape = Tape(0.34)
    ..mix(note(4300, 2900, 0.065))
    ..mix(note(4700, 3200, 0.065), at: 0.1)
    ..mix(note(3000, 3900, 0.05), at: 0.2, gain: 0.7);
  return tape.finish();
}

/// The bell on a front desk: one bright ring, shimmering where two of its
/// partials sit a few hertz apart.
Float32List _deskBell() {
  final tape =
      strike(
        2380,
        ratios: const [1, 1.0028, 2.32, 3.86],
        loudness: const [1, 0.8, 0.45, 0.22],
        decays: const [1, 0.95, 0.35, 0.15],
        seconds: 1.8,
      )..mix(
        _tick(51, above: 5000, decay: 0.001),
        gain: 0.35,
      );
  return tape.finish();
}

/// A jigsaw piece going in: two quick plastic taps, the second the snap.
Float32List _click() {
  Tape tap(double hz, int seed) =>
      strike(
        hz,
        ratios: const [1, 1.8],
        loudness: const [1, 0.5],
        decays: const [0.014, 0.008],
        seconds: 0.1,
      )..mix(
        _tick(seed, above: 2500),
        gain: 0.5,
      );
  final tape = Tape(0.2)
    ..mix(tap(1450, 81), gain: 0.7)
    ..mix(tap(1900, 82), at: 0.028);
  return tape.finish();
}

/// "Beep beep": two short blasts of a small car's two-tone horn, softened
/// into a toy's.
Float32List _horn() {
  Tape blast() {
    const seconds = 0.14;
    Tape reed(double hz) => tone(
      seconds,
      hz: (t) => hz * (0.97 + 0.03 * ease(t, 0, 0.03)),
      partials: const [1, 2, 3, 4, 5, 6, 7],
      loudness: const [1, 0.5, 0.33, 0.25, 0.2, 0.17, 0.14],
    );
    return lowPass(reed(466)..mix(reed(587), gain: 0.8), (_) => 2400)
      ..shape((t) => swell(t, seconds: seconds, rise: 0.012, fall: 0.04));
  }

  final tape = Tape(0.5)
    ..mix(blast())
    ..mix(blast(), at: 0.2);
  return tape.finish();
}

/// A tower bell striking: the hum an octave under, the minor third that
/// makes a bell sound like a bell, and the nominal an octave over that the
/// ear hears as its note.
Float32List _clockBell() {
  final tape =
      strike(
        392,
        ratios: const [0.5, 1, 1.2, 1.5, 2, 2.5, 3, 4, 5.33, 6.7],
        loudness: const [0.35, 0.6, 0.5, 0.25, 1, 0.35, 0.3, 0.15, 0.12, 0.08],
        decays: const [2, 1.4, 1.1, 0.7, 0.9, 0.5, 0.35, 0.25, 0.15, 0.1],
        seconds: 2.4,
      )..mix(
        lowPass(noise(0.02, seed: 61), (_) => 2500)
          ..shape((t) => pluck(t, attack: 0.0005, decay: 0.004)),
        gain: 0.3,
      );
  return tape.finish();
}

/// A plane taking off: a roar rising through the band as it gathers speed,
/// a turbine's whine climbing under it, and gone.
Float32List _takeoff() {
  const seconds = 2.2;
  final tape =
      bandPass(
          noise(seconds, seed: 71),
          (t) => 260 * math.pow(9, ease(t, 0, 1.7)).toDouble(),
          q: 0.8,
        )
        ..mix(
          tone(
            seconds,
            hz: (t) => 900 + 1100 * ease(t, 0.1, 1.8),
            partials: const [1, 2],
            loudness: const [1, 0.3],
          ),
          gain: 0.05,
        )
        ..shape(
          (t) => through(const [(0, 0), (1.1, 1), (1.5, 0.85), (2.2, 0)], t),
        );
  return tape.finish();
}

// ------------------------------------------------------------- the places --

/// One brass note at [hz], [seconds] long: a trumpet's bright stack of
/// harmonics, the brightness opening up as it is blown - the "blat" that
/// makes brass sound like brass - and, held, a [shake]: the vibrato a big
/// band's trumpets put on a long note.
Tape _brass(double seconds, double hz, {double shake = 0}) {
  final note = tone(
    seconds,
    hz: (t) =>
        hz *
        (1 +
            shake *
                0.012 *
                math.sin(2 * math.pi * 5.6 * t) *
                ease(t, 0.12, 0.4)),
    partials: const [1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
    loudness: const [1, 0.85, 0.7, 0.55, 0.42, 0.32, 0.24, 0.18, 0.13, 0.1],
    attack: 0.012,
  );
  return lowPass(note, (t) => 900 + 3000 * ease(t, 0, 0.07))..shape(
    (t) => swell(t, seconds: seconds, rise: 0.015, fall: seconds * 0.35),
  );
}

/// New York's answer: a Broadway brass fanfare. Two trumpet notes lead in,
/// "ba-da...", and as the firework bursts into its heart the band hits the
/// chord - a major with its sixth, the big band's sound - and shakes it,
/// with the sparkle of the firework falling through it. Its [Sound.hit] is
/// the chord.
Float32List _fanfare() {
  // The sparkle: little high pings, here and there, as the sparks fall.
  Tape sparkle(int seed, double seconds, int count) {
    final tape = Tape(seconds);
    final random = math.Random(seed);
    for (var i = 0; i < count; i++) {
      tape.mix(
        strike(
          2600 + random.nextDouble() * 2200,
          ratios: const [1, 2.76],
          loudness: const [1, 0.25],
          decays: const [0.05, 0.02],
          seconds: 0.15,
        ),
        at: random.nextDouble() * seconds * 0.8,
        gain: 0.1 + 0.1 * random.nextDouble(),
      );
    }
    return tape;
  }

  // C major with its sixth, trumpets and trombones spread over it, each a
  // hair off the next so it sounds like a section and not one horn.
  const chord = [261.63, 329.63, 392.0, 440.0, 523.25, 659.26];
  final hit = Tape(1.6);
  for (final (i, hz) in chord.indexed) {
    hit.mix(
      _brass(1.6, hz * (1 + (i.isEven ? 0.002 : -0.002)), shake: 1),
      gain: i < 2 ? 0.5 : 0.36,
    );
  }

  final tape = Tape(2.3)
    ..mix(_brass(0.12, 392), at: 0.26, gain: 0.55)
    ..mix(_brass(0.16, 392), at: 0.4, gain: 0.6)
    ..mix(hit, at: 0.55)
    ..mix(sparkle(131, 1.1, 14), at: 0.6)
    ..shape((t) => 1 - ease(t, 1.85, 2.3));
  return tape.finish();
}

/// A flamenco guitar: a soft down-stroke on F, then a rasgueado - three
/// fingers flicked across the strings one after another - on E, the chord a
/// flamenco cadence comes home to, left to ring.
Float32List _guitarStrum() {
  const f = [87.31, 130.81, 174.61, 220.0, 261.63, 349.23];
  const e = [82.41, 123.47, 164.81, 207.65, 246.94, 329.63];
  var seed = 101;
  Tape stroke(List<double> chord, {required double spread}) {
    final tape = Tape(2);
    for (var i = 0; i < chord.length; i++) {
      tape.mix(
        string(2, hz: chord[i], seed: seed++, decay: 1.1 - i * 0.08),
        at: i * spread,
        // The bass strings carry less on a phone's speaker; the top ones
        // are what is heard.
        gain: 0.7 + i * 0.06,
      );
    }
    return tape;
  }

  final tape = Tape(2.2)
    ..mix(stroke(f, spread: 0.012), gain: 0.55)
    ..mix(stroke(e, spread: 0.007), at: 0.34, gain: 0.5)
    ..mix(stroke(e, spread: 0.006), at: 0.385, gain: 0.6)
    ..mix(stroke(e, spread: 0.005), at: 0.43, gain: 0.85)
    ..shape((t) => 1 - ease(t, 1.7, 2.2));
  return lowPass(tape, (_) => 4200).finish();
}

/// A Korean temple bell, struck with a hanging log: a soft thud, then a
/// deep hum and the partials over it ringing on - and the slow pulse a
/// Korean bell is known for, from pairs of partials a fraction of a hertz
/// apart. Pitched where a phone's speaker can carry it; a real one is
/// lower still.
Float32List _templeBell() {
  const seconds = 2.5;
  final tape =
      tone(
          seconds,
          hz: (_) => 196,
          partials: const [1, 1.0032, 2, 2.0075, 2.76, 3.9, 5.4],
          loudness: const [0.9, 0.8, 0.75, 0.6, 0.55, 0.32, 0.12],
          decays: const [3.2, 3.2, 2, 2, 1.1, 0.6, 0.3],
          attack: 0.012,
        )
        ..mix(
          lowPass(noise(0.06, seed: 111), (_) => 420)
            ..shape((t) => pluck(t, attack: 0.002, decay: 0.012)),
          gain: 0.6,
        )
        // Let it die away inside its length rather than be cut off.
        ..shape((t) => 1 - ease(t, 1.6, seconds));
  return tape.finish();
}

// ------------------------------------------------------------ word hunt --

/// "Pew": a tone diving from high to low in a fifth of a second, with a
/// little of its octave and twelfth for bite.
Float32List _laser() {
  const seconds = 0.22;
  final tape = tone(
    seconds,
    hz: (t) => 1500 * math.exp(-t * 9) + 380,
    partials: const [1, 2, 3],
    loudness: const [1, 0.35, 0.12],
  )..shape((t) => pluck(t, decay: 0.07, attack: 0.002));
  return tape.finish();
}

/// A quick run of bells up a major chord - C, E, G, C, E - each a little
/// softer, over a low thump that falls in pitch as it fades: the hit felt
/// as much as heard.
Float32List _burst() {
  final tape = Tape(1.1)
    ..mix(
      tone(0.45, hz: (t) => 140 * math.exp(-t * 6) + 55)
        ..shape((t) => pluck(t, decay: 0.12)),
      gain: 0.9,
    );
  for (final (i, hz) in const [
    1046.5,
    1318.5,
    1568.0,
    2093.0,
    2637.0,
  ].indexed) {
    tape.mix(
      strike(
        hz,
        ratios: const [1, 2.76, 5.4],
        loudness: const [1, 0.25, 0.06],
        decays: const [0.28, 0.08, 0.03],
        seconds: 0.9,
      ),
      at: 0.03 + i * 0.045,
      gain: 0.55 - i * 0.05,
    );
  }
  return tape.finish();
}

/// "Boing": a round, low tone sliding down, wobbling as a spring does as it
/// settles. Soft at its top, so it reads as a bump rather than an alarm.
Float32List _bonk() {
  const seconds = 0.42;
  final tape =
      tone(
        seconds,
        hz: (t) => 300 * math.exp(-t * 4.5) + 120,
        partials: const [1, 2, 3.1],
        loudness: const [1, 0.18, 0.05],
      )..shape(
        (t) => pluck(t, decay: 0.13) * (1 + 0.25 * math.sin(_tau * 14 * t)),
      );
  return tape.finish();
}

/// Six soft mallet notes rising up a major scale's bright end, a breath
/// apart, the last ringing on: ships arriving out of nowhere.
Float32List _warp() {
  final tape = Tape(0.95);
  for (final (i, hz) in const [
    523.3,
    659.3,
    784.0,
    987.8,
    1174.7,
    1568.0,
  ].indexed) {
    tape.mix(
      strike(
        hz,
        ratios: const [1, 3],
        loudness: const [1, 0.1],
        decays: const [0.18, 0.05],
        seconds: 0.6,
      ),
      at: i * 0.045,
      gain: 0.5 + i * 0.06,
    );
  }
  return tape.finish();
}
