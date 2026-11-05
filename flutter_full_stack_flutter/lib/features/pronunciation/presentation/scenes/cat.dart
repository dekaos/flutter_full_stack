import 'dart:math' as math;

import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_full_stack_flutter/core/audio/sound.dart';

/// Something the hiding cat comes out to do.
///
/// Each one is a visit: the cat comes out of its hiding place, does it,
/// and goes back - so every gesture ends where it began, hidden.
enum CatGesture {
  /// Washes a paw: unhurried, so there is no hurry. For a learner who has
  /// been looking at a prompt a while without starting.
  lick(Duration(milliseconds: 4400)),

  /// The slow blink, both eyes - how a cat says it trusts you. For an
  /// attempt that did not come out right: it is all right, try again.
  blink(Duration(milliseconds: 3800)),

  /// A happy swish of the tail. For an attempt that came out well.
  swish(Duration(milliseconds: 3400));

  CatGesture(this.duration);

  /// How long the visit takes, out and back.
  final Duration duration;

  /// What the cat says while it does this, and when: `(g, sound)`, `g` of
  /// the way through the gesture (see [CatPose.through]).
  ///
  /// Each fits what it is for. A meow is how a cat asks for attention, so
  /// it calls the quiet learner as it starts to wash; the washing itself is
  /// silent, as a cat's is - made up, a lick only ever sounded like a
  /// glitch on a phone's speaker. A soft murmur goes with the slow blink,
  /// the comfort after an attempt that did not come out. The trill, a cat's
  /// happy greeting, goes with the hop of the swish.
  List<(double, Sound)> get sounds => switch (this) {
    lick => const [(0, Sound.meow)],
    blink => const [(0.12, Sound.murmur)],
    swish => const [(0.06, Sound.trill)],
  };
}

/// Where the hiding cat is at a moment: out doing [gesture], [t] of the way
/// through the visit, or hidden.
@immutable
class CatPose {
  const CatPose(this.gesture, this.t);

  /// Behind its bush, ears showing - how it spends most of its time.
  static const hidden = CatPose(null, 0);

  final CatGesture? gesture;
  final double t;

  /// How far out from behind the bush it is, `0` to `1`.
  double get out => gesture == null ? 0 : _span(0, 0.16) - _span(0.86, 1);

  /// When, through a visit, the gesture itself plays: once it is out, and
  /// before it goes back. A cat that [walks] out takes longer coming and
  /// going, so its gesture is a shorter part of the visit.
  static ({double begin, double end}) gestureSpan({required bool walks}) =>
      walks ? (begin: 0.34, end: 0.72) : (begin: 0.18, end: 0.84);

  /// How far through the gesture itself, once it is out.
  double through({required bool walks}) {
    final span = gestureSpan(walks: walks);
    return ((t - span.begin) / (span.end - span.begin)).clamp(0.0, 1.0);
  }

  /// When, through a visit, the cat is [g] of the way through its gesture.
  static double at(double g, {required bool walks}) {
    final span = gestureSpan(walks: walks);
    return span.begin + g * (span.end - span.begin);
  }

  double _span(double begin, double end) => Curves.easeInOut.transform(
    ((t - begin) / (end - begin)).clamp(0.0, 1.0),
  );

  @override
  bool operator ==(Object other) =>
      other is CatPose && other.gesture == gesture && other.t == t;

  @override
  int get hashCode => Object.hash(gesture, t);
}

/// How the cat holds itself at a moment: which way it faces, how far it has
/// sat down, where it is in its stride and in its gesture. [CatFigure] works
/// out the shape of it.
@immutable
class CatBody {
  const CatBody({
    this.yaw = math.pi / 2,
    this.sit = 1,
    this.phase = 0,
    this.step = 0,
    this.tail = 1,
    this.lid = 0,
    this.tilt = 0,
    this.paw = 0,
    this.tongue = 0,
    this.dip = 0,
    this.swing = 0,
    this.hop = 0,
  });

  /// Sitting facing the learner, [g] of the way through [gesture].
  factory CatBody.gesturing(
    CatGesture? gesture,
    double g, {
    required double tail,
  }) {
    double span(double begin, double end) => Curves.easeInOut.transform(
      ((g - begin) / (end - begin)).clamp(0.0, 1.0),
    );
    switch (gesture) {
      case CatGesture.blink:
        // Slowly shut, held a moment, slowly open - with the head tipped a
        // little, which is most of what makes it read as fond.
        return CatBody(
          tail: tail,
          lid: span(0.1, 0.36) - span(0.62, 0.9),
          tilt: 0.12 * math.sin(math.pi * g),
        );
      case CatGesture.lick:
        final paw = span(0, 0.18) - span(0.82, 1);
        final licking = ((g - _licking.begin) / (_licking.end - _licking.begin))
            .clamp(0.0, 1.0);
        final tongue = g > _licking.begin && g < _licking.end
            ? math.max(0, math.sin(licking * _beats * math.pi)).toDouble()
            : 0.0;
        return CatBody(
          tail: tail,
          paw: paw,
          tongue: tongue,
          // Eyes half shut while it washes, as cats do.
          lid: 0.7 * (span(0.12, 0.24) - span(0.76, 0.88)),
          dip: 3 * paw + 2.5 * tongue,
          tilt: -0.08 * paw,
        );
      case CatGesture.swish:
        return CatBody(
          tail: tail,
          swing: math.sin(g * 4 * math.pi) * (1 - g),
          hop: 4 * math.sin(math.pi * span(0, 0.35)),
        );
      case null:
        return CatBody(tail: tail);
    }
  }

  /// While it washes, its tongue goes out twice, between these points of
  /// the gesture - its paw up at its mouth.
  static const ({double begin, double end}) _licking = (
    begin: 0.22,
    end: 0.78,
  );

  /// The tongue goes out on every other half beat of a sine, and is in for
  /// the ones between: three half beats, two strokes.
  static const _beats = 3;

  /// Which way it faces: `0` screen right, `pi / 2` the learner, `pi`
  /// screen left. It never turns its back.
  final double yaw;

  /// `0` standing, `1` sitting.
  final double sit;

  /// How far through its stride it is, in radians, and how much it is
  /// stepping at all (`0` standing still).
  final double phase;
  final double step;

  /// Which side its tail curls to when it sits facing the learner: `1`
  /// screen right, `-1` screen left.
  final double tail;

  /// How far its eyelids are down, `0` to `1`.
  final double lid;

  /// How far its head is tipped, in radians, and how far it is bowed.
  final double tilt;
  final double dip;

  /// How far its paw is up at its mouth, and its tongue out to it, `0` to
  /// `1`.
  final double paw;
  final double tongue;

  /// The tail's swish, `-1` to `1`, and how high it hops, in grid units.
  final double swing;
  final double hop;
}

/// One of the cat's legs as drawn: from [hip], bent through [knee], to the
/// paw, an oval [pawSize] across, at [paw].
@immutable
class CatLeg {
  const CatLeg(this.hip, this.knee, this.paw, this.pawSize, this.depth);

  final Offset hip;
  final Offset knee;
  final Offset paw;
  final Size pawSize;

  /// How near the learner it is: drawn before the body when below `0`.
  final double depth;
}

/// The shape of the cat at a moment, for the stage to paint: where each part
/// of it is on its grid - 100 wide and 112 tall, its feet at (50, 110) - for
/// how it holds itself ([CatBody]).
///
/// It is one cat, modelled in three dimensions and seen from in front and a
/// little above, the way the scenes are. Every part of it is one size: the
/// head is the same head standing, sitting, side on or face on. Turning,
/// walking and sitting down move the parts and turn them, and nothing else
/// - so the cat stays in proportion through all of it, because no part is
/// ever drawn at a size of its own.
@immutable
class CatFigure {
  factory CatFigure(CatBody body) {
    final b = body;
    final cos = math.cos(b.yaw);
    final sin = math.sin(b.yaw);
    final sit = Curves.easeInOut.transform(b.sit.clamp(0.0, 1.0));
    double mix(double standing, double sitting) =>
        standing + (sitting - standing) * sit;
    // The body rides up a little on each footfall.
    final bob = 1.4 * math.sin(2 * b.phase).abs() * b.step;

    // [f]orward, the cat's [r]ight, [u]p - to the grid, seen from in front
    // and a little above: what is nearer the learner sits a little lower.
    double depth(double f, double r) => f * sin + r * cos;
    Offset at(double f, double r, double u) => Offset(
      50 + f * cos - r * sin,
      110 - u - b.hop + _above * depth(f, r),
    );
    Rect part(double f, double u, _Part size) => Rect.fromCenter(
      center: at(f, 0, u),
      width:
          2 *
          math.sqrt(
            math.pow(size.along * cos, 2) + math.pow(size.across * sin, 2),
          ),
      height: 2 * size.up,
    );

    final ride = bob * (1 - sit);
    final haunch = part(
      mix(-15, -6),
      mix(44, 22) + ride,
      _Part.lerp(_Part.haunch, _Part.haunchSitting, sit),
    );
    final barrel = part(
      mix(0, 3),
      mix(44, 32) + ride,
      _Part.lerp(_Part.barrel, _Part.barrelSitting, sit),
    );
    final chest = part(
      mix(15, 9),
      mix(45, 45) + ride,
      _Part.lerp(_Part.chest, _Part.chestSitting, sit),
    );

    // The head, and what is on it, all placed from its middle.
    final headF = mix(38, 14);
    final headU = mix(62, 71) + ride - b.dip;
    Offset onHead(double f, double r, double u) => at(headF + f, r, headU + u);
    final head = part(headF, headU, _Part.head);
    final muzzle = part(headF + 15, headU - 5, _Part.muzzle);

    // An ear is a cone, not a flat triangle: seen edge on it still has
    // some width, so it never thins to a line as the cat turns.
    final ears = <List<Offset>>[];
    final earInsides = <List<Offset>>[];
    for (final side in const [-1.0, 1.0]) {
      final ear = [
        for (final (f, r, u) in _ear) onHead(f, side * r, u),
      ];
      ears.add(_hull(ear));
      // Its inside shows only from the side it faces: forward and out.
      if (math.sin(b.yaw + side * 0.5) > 0.05) {
        final face = ear.sublist(0, 3);
        final mid = (face[0] + face[1] + face[2]) / 3;
        earInsides.add([for (final p in face) mid + (p - mid) * 0.55]);
      }
    }

    // An eye is seen as wide as it faces the learner, and not at all from
    // the far side of the head.
    final eyes = <Rect>[];
    for (final side in const [-1.0, 1.0]) {
      final facing = math.sin(b.yaw + side * _eyeAngle);
      if (facing <= 0.08) continue;
      eyes.add(
        Rect.fromCenter(
          center: onHead(15.9, side * 9, 1),
          width: 9 * facing / math.cos(_eyeAngle),
          height: 11,
        ),
      );
    }

    // The legs. Walking, diagonal pairs swing together; sitting, the front
    // legs stand straight and the hind ones fold away under the haunch,
    // only their paws showing.
    final legs = <CatLeg>[];
    CatLeg? washing;
    for (final fore in const [true, false]) {
      for (final right in const [true, false]) {
        final side = right ? 1.0 : -1.0;
        final beat = b.phase + (fore == right ? 0 : math.pi);
        final reach = 9 * math.sin(beat) * b.step;
        final raise = 5 * math.max(0, math.cos(beat)) * b.step;
        final hipF = fore ? mix(16, 11) : mix(-17, 0);
        final hipR = side * (fore ? 7 : mix(8, 13));
        final hipU = (fore ? mix(34, 34) : mix(34, 10)) + ride;
        final pawF = (fore ? mix(16, 13) : mix(-17, 7)) + reach;
        final pawR = side * (fore ? 7 : mix(8, 15));
        // The elbow is barely bent; the hock points back.
        final bend = fore ? mix(2, 0) : mix(-7, 0);
        final paw = Size(
          2 * math.sqrt(math.pow(6 * cos, 2) + math.pow(6 * sin, 2)),
          7 + 2 * sit,
        );
        // Its sole on the ground, unless the stride has it lifted.
        final pawU = paw.height / 2 + raise;
        var foot = at(pawF, pawR, pawU);
        final washes = fore && right && b.paw > 0;
        if (washes) {
          // Up to its mouth, in front of its face.
          foot = Offset.lerp(foot, onHead(19, 3, -10), b.paw)!;
        }
        final leg = CatLeg(
          at(hipF, hipR, hipU),
          at((hipF + pawF) / 2 + bend, (hipR + pawR) / 2, (hipU + pawU) / 2),
          foot,
          paw,
          depth((hipF + pawF) / 2, (hipR + pawR) / 2),
        );
        if (washes) {
          washing = leg;
        } else {
          legs.add(leg);
        }
      }
    }
    legs.sort((x, y) => x.depth.compareTo(y.depth));

    // The tail: held up and swaying with the walk standing; sitting, curled
    // round to the side [CatBody.tail] says, swishing.
    final sway = 3 * math.sin(b.phase) * b.step;
    final curl = -b.tail;
    final sw = b.swing;
    // Standing it is up, its tip hooked over to that side; sitting it
    // comes round the haunch and up beside it.
    final standing = [
      (-33.0, 0.0, 54 + bob),
      (-46.0, 0.0, 58 + bob),
      (-50 + sway, sway + curl * 3, 76.0),
      (-42 + 2 * sway, 2 * sway + curl * 9, 87.0),
    ];
    final sitting = [
      (-22.0, curl * 14, 10.0),
      (-30.0, curl * (40 + 6 * sw), 4.0),
      (-16.0, curl * (49 + 12 * sw), 30.0),
      (-8.0, curl * (36 + 18 * sw), 48 - 4 * sw.abs()),
    ];
    final tail = [
      for (var i = 0; i < 4; i++)
        at(
          mix(standing[i].$1, sitting[i].$1),
          mix(standing[i].$2, sitting[i].$2),
          mix(standing[i].$3, sitting[i].$3),
        ),
    ];

    return CatFigure._(
      haunch: haunch,
      barrel: barrel,
      chest: chest,
      head: head,
      muzzle: muzzle,
      ears: ears,
      earInsides: earInsides,
      eyes: eyes,
      nose: onHead(20, 0, -6),
      noseWidth: 6 * math.max(sin, 0.4),
      neck: Offset(head.center.dx, head.bottom),
      tilt: b.tilt,
      farLegs: [
        for (final leg in legs)
          if (leg.depth < 0) leg,
      ],
      nearLegs: [
        for (final leg in legs)
          if (leg.depth >= 0) leg,
      ],
      washing: washing,
      tail: tail,
    );
  }

  const CatFigure._({
    required this.haunch,
    required this.barrel,
    required this.chest,
    required this.head,
    required this.muzzle,
    required this.ears,
    required this.earInsides,
    required this.eyes,
    required this.nose,
    required this.noseWidth,
    required this.neck,
    required this.tilt,
    required this.farLegs,
    required this.nearLegs,
    required this.washing,
    required this.tail,
  });

  /// How much lower what is nearer the learner sits: the scenes are seen
  /// from a little above.
  static const _above = 0.15;

  /// How far round from straight ahead each eye looks, in radians.
  static const _eyeAngle = 0.43;

  /// An ear, on the cat's right of its head, from its middle: the outer
  /// corner, tip and inner corner of its open face, and the back of it.
  static const _ear = [
    (-6.0, 18.0, 7.0),
    (-4.0, 17.0, 31.0),
    (3.0, 5.0, 16.0),
    (-10.0, 11.0, 14.0),
  ];

  /// The outline of [points]: the smallest convex polygon round them.
  static List<Offset> _hull(List<Offset> points) {
    final sorted = [...points]
      ..sort(
        (a, b) => a.dx != b.dx ? a.dx.compareTo(b.dx) : a.dy.compareTo(b.dy),
      );
    double turn(Offset o, Offset a, Offset b) =>
        (a.dx - o.dx) * (b.dy - o.dy) - (a.dy - o.dy) * (b.dx - o.dx);
    final hull = <Offset>[];
    for (final pass in [sorted, sorted.reversed.toList()]) {
      final start = hull.length;
      for (final p in pass) {
        while (hull.length >= start + 2 &&
            turn(hull[hull.length - 2], hull.last, p) <= 0) {
          hull.removeLast();
        }
        hull.add(p);
      }
      hull.removeLast();
    }
    return hull;
  }

  /// The body - haunch, middle and chest - as ellipses.
  final Rect haunch;
  final Rect barrel;
  final Rect chest;

  /// The head, and the muzzle that gives it its profile.
  final Rect head;
  final Rect muzzle;

  /// Both ears, as triangles; and the pink inside each ear that faces the
  /// learner enough to show it.
  final List<List<Offset>> ears;
  final List<List<Offset>> earInsides;

  /// Each eye the learner can see, open: narrow where it is seen from the
  /// side.
  final List<Rect> eyes;

  /// The middle of the nose, and how wide it is seen.
  final Offset nose;
  final double noseWidth;

  /// The point the head tips about, and how far it is tipped: the head,
  /// muzzle, ears, eyes and nose are drawn tipped about it.
  final Offset neck;
  final double tilt;

  /// The legs behind the body, and those in front of it, each furthest
  /// first; and the one up washing, drawn in front of the face.
  final List<CatLeg> farLegs;
  final List<CatLeg> nearLegs;
  final CatLeg? washing;

  /// The tail as a cubic: its root, two controls, its tip. Always behind
  /// the body, so it never jumps from behind to in front as the cat turns.
  final List<Offset> tail;
}

/// Half the size of one of the cat's parts along each of its own axes:
/// forward, across and up.
@immutable
class _Part {
  const _Part(this.along, this.across, this.up);

  _Part.lerp(_Part a, _Part b, double t)
    : along = a.along + (b.along - a.along) * t,
      across = a.across + (b.across - a.across) * t,
      up = a.up + (b.up - a.up) * t;

  /// The head - the one part every view of the cat must agree on.
  static const head = _Part(18, 20, 16.5);
  static const muzzle = _Part(7, 8, 6);

  /// The back half of the body, standing and sitting: sitting, it takes in
  /// the hind legs folded beside it.
  static const haunch = _Part(22, 18, 20);
  static const haunchSitting = _Part(24, 25, 21);

  /// The middle, which keeps the back straight between them.
  static const barrel = _Part(23, 17, 20);
  static const barrelSitting = _Part(14, 19, 17);

  /// The front half: standing, the deep chest; sitting, upright.
  static const chest = _Part(17, 16, 19);
  static const chestSitting = _Part(14, 18, 19);

  final double along;
  final double across;
  final double up;
}
