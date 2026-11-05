import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_full_stack_flutter/features/pronunciation/presentation/scenes/cat.dart';
import 'package:flutter_test/flutter_test.dart';

/// Everything the cat does on a visit: every way it faces, standing,
/// sitting and halfway, walking or still, and every gesture through.
final List<CatBody> _poses = [
  for (var i = 0; i <= 12; i++)
    for (final sit in const [0.0, 0.5, 1.0])
      for (final step in const [0.0, 1.0])
        for (final phase in const [0.0, 1.0, 2.5])
          CatBody(
            yaw: math.pi * i / 12,
            sit: sit,
            step: step * (1 - sit),
            phase: phase,
          ),
  for (final gesture in CatGesture.values)
    for (var g = 0; g <= 10; g++) CatBody.gesturing(gesture, g / 10, tail: 1),
];

const _side = CatBody(yaw: 0, sit: 0);
const _front = CatBody();

/// The top of the cat: the tips of its ears.
double _top(CatFigure cat) =>
    cat.ears.expand((ear) => ear).map((p) => p.dy).reduce(math.min);

Rect _bounds(List<Offset> points) => points
    .map((p) => Rect.fromCenter(center: p, width: 0, height: 0))
    .reduce((a, b) => a.expandToInclude(b));

/// Where every part of [cat] is, as points to compare between two moments.
List<Offset> _landmarks(CatFigure cat) => [
  cat.head.center,
  cat.head.topLeft,
  cat.head.bottomRight,
  cat.haunch.center,
  cat.haunch.topLeft,
  cat.chest.center,
  cat.chest.topLeft,
  cat.muzzle.center,
  for (final ear in cat.ears) ...[
    _bounds(ear).topLeft,
    _bounds(ear).bottomRight,
  ],
  ...cat.tail,
  cat.nose,
];

void main() {
  group('the cat', () {
    test('has one head, whatever it is doing', () {
      final side = CatFigure(_side).head;
      final front = CatFigure(_front).head;
      for (final body in _poses) {
        final head = CatFigure(body).head;
        expect(head.height, closeTo(front.height, 1e-9));
        // Seen from anywhere, between as wide as it is long and as wide as
        // it is broad - never a size of its own.
        expect(
          head.width,
          inInclusiveRange(
            math.min(side.width, front.width) - 1e-9,
            math.max(side.width, front.width) + 1e-9,
          ),
        );
      }
    });

    test('has a head in proportion to its body, walking as well as '
        'sitting', () {
      final walking = CatFigure(_side);
      final body = walking.haunch
          .expandToInclude(walking.barrel)
          .expandToInclude(walking.chest);
      // A little big for a real cat, as a drawn one's is - but smaller than
      // the body is deep, and well under half as long as it is long.
      expect(walking.head.height / body.height, inInclusiveRange(0.7, 0.88));
      expect(walking.head.width / body.width, inInclusiveRange(0.4, 0.55));

      final sitting = CatFigure(_front);
      expect(
        sitting.head.width / sitting.haunch.width,
        inInclusiveRange(0.7, 0.9),
      );
    });

    test('is no smaller walking than it is sitting', () {
      final walking = CatFigure(_side);
      final sitting = CatFigure(_front);
      // Standing, its head is no higher than sitting up, as a cat's is -
      // but it is not shrunk either.
      final ratio = (110 - _top(walking)) / (110 - _top(sitting));
      expect(ratio, inInclusiveRange(0.85, 1));
    });

    test('keeps its feet on the ground', () {
      for (final body in _poses.where((b) => b.hop == 0 && b.paw == 0)) {
        final cat = CatFigure(body);
        for (final leg in [...cat.farLegs, ...cat.nearLegs]) {
          final sole = leg.paw.dy + leg.pawSize.height / 2;
          // Seen from a little above, the ground is a little lower nearer
          // the learner - a few units for a paw a stride towards them - and
          // a paw in the air is lifted, never sunk.
          expect(sole, lessThanOrEqualTo(115), reason: '$body');
          if (body.step == 0) {
            expect(sole, greaterThanOrEqualTo(105), reason: '$body');
          }
        }
      }
    });

    test('shows one eye from the side and two face on', () {
      expect(CatFigure(const CatBody(yaw: 0)).eyes, hasLength(1));
      expect(CatFigure(const CatBody(yaw: math.pi)).eyes, hasLength(1));
      expect(CatFigure(_front).eyes, hasLength(2));
    });

    test('turns without anything jumping', () {
      for (final sit in const [0.0, 1.0]) {
        CatFigure? before;
        for (var i = 0; i <= 200; i++) {
          final cat = CatFigure(CatBody(yaw: math.pi * i / 200, sit: sit));
          if (before != null) {
            final from = _landmarks(before);
            final to = _landmarks(cat);
            for (var p = 0; p < from.length; p++) {
              expect(
                (to[p] - from[p]).distance,
                lessThan(1.5),
                reason: 'landmark $p at step $i, sitting $sit',
              );
            }
            // An eye comes into sight, or goes out of it, only edge on.
            if (cat.eyes.length != before.eyes.length) {
              final changed = cat.eyes.length > before.eyes.length
                  ? cat.eyes
                  : before.eyes;
              expect(
                changed.map((e) => e.width).reduce(math.min),
                lessThan(1.5),
              );
            }
          }
          before = cat;
        }
      }
    });

    test('sits down without anything jumping', () {
      for (final yaw in const [0.0, math.pi / 4, math.pi / 2, math.pi]) {
        CatFigure? before;
        for (var i = 0; i <= 100; i++) {
          final cat = CatFigure(CatBody(yaw: yaw, sit: i / 100));
          if (before != null) {
            final from = _landmarks(before);
            final to = _landmarks(cat);
            for (var p = 0; p < from.length; p++) {
              expect(
                (to[p] - from[p]).distance,
                lessThan(1.5),
                reason: 'landmark $p at step $i, facing $yaw',
              );
            }
          }
          before = cat;
        }
      }
    });
  });
}
