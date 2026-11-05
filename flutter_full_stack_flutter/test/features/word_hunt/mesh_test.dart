import 'dart:math' as math;

import 'package:flutter_full_stack_flutter/features/word_hunt/presentation/space/geometry.dart';
import 'package:flutter_full_stack_flutter/features/word_hunt/presentation/space/mesh.dart';
import 'package:flutter_full_stack_flutter/features/word_hunt/presentation/space/models.dart';
import 'package:flutter_test/flutter_test.dart';

V3 _normal(Mesh mesh, int i) => V3(
  mesh.normals[i * 3],
  mesh.normals[i * 3 + 1],
  mesh.normals[i * 3 + 2],
);

V3 _position(Mesh mesh, int i) => V3(
  mesh.positions[i * 3],
  mesh.positions[i * 3 + 1],
  mesh.positions[i * 3 + 2],
);

void main() {
  test('a smooth surface shares each corner, facing as the surface does', () {
    // The facets showed because every triangle was lit as a flat plate. A
    // ball's corners are now shared by the faces round them, each with the
    // ball's own direction there, so the light blends across them.
    final ball =
        (MeshBuilder()
              ..sphere(radius: 1, detail: 2, color: (_) => const Rgb(1, 1, 1)))
            .build();
    expect(ball.vertexCount, 162, reason: 'one per point of the ball');
    for (var i = 0; i < ball.vertexCount; i++) {
      // The faces' own normals, averaged: the ball's direction, to within
      // what flat faces can give.
      final along = _normal(ball, i).dot(_position(ball, i).unit);
      expect(along, closeTo(1, 1e-3));
    }
  });

  test('an edge sharper than its part allows stays sharp', () {
    final box =
        (MeshBuilder()..box(
              const V3(-1, -1, -1),
              const V3(1, 1, 1),
              const Rgb(1, 1, 1),
            ))
            .build();
    expect(box.vertexCount, 24, reason: 'four corners for each side');
    for (var i = 0; i < box.vertexCount; i++) {
      final n = _normal(box, i);
      expect(
        [n.x.abs(), n.y.abs(), n.z.abs()].reduce(math.max),
        closeTo(1, 1e-9),
        reason: 'square to its side',
      );
    }
  });

  test('a change of colour splits a corner, but not the light across it', () {
    // A red nose on a white body: two colours meet on one ring, and the
    // ring is still one smooth surface.
    final rod =
        (MeshBuilder()..lathe(
              const [(0, 1), (0.5, 0.6), (0.5, 0), (0.5, -0.6), (0, -1)],
              segments: 16,
              smooth: 60,
              color: (band, _) =>
                  band < 2 ? const Rgb(1, 0, 0) : const Rgb(1, 1, 1),
            ))
            .build();
    final ring = <String, List<int>>{};
    for (var i = 0; i < rod.vertexCount; i++) {
      final p = _position(rod, i);
      if (p.y.abs() > 1e-9) continue;
      ring
          .putIfAbsent(
            '${p.x.toStringAsFixed(6)},${p.z.toStringAsFixed(6)}',
            () => [],
          )
          .add(i);
    }
    expect(ring, isNotEmpty);
    for (final corners in ring.values) {
      expect(corners, hasLength(2), reason: 'one red, one white');
      final (a, b) = (corners[0], corners[1]);
      expect(
        rod.colors[a * 3 + 1],
        isNot(rod.colors[b * 3 + 1]),
        reason: 'different colours',
      );
      expect((_normal(rod, a) - _normal(rod, b)).length, lessThan(1e-9));
    }
  });

  test('a corner can carry a colour of its own, blended across its faces', () {
    final ball =
        (MeshBuilder()..sphere(
              radius: 1,
              detail: 2,
              blend: true,
              color: (d) => Rgb(d.y * 0.5 + 0.5, 0, 0),
            ))
            .build();
    expect(ball.vertexCount, 162, reason: 'no corner split by colour');
    for (var i = 0; i < ball.vertexCount; i++) {
      final red = _position(ball, i).y * 0.5 + 0.5;
      // Stored as linear light.
      expect(ball.colors[i * 3], closeTo(red * red, 1e-9));
    }
  });

  test(
    'the fighter and every kind of word ship fit, and are not too heavy',
    () {
      for (final mesh in [
        Models.fighter,
        for (final style in ShipStyle.values) Models.ship(style),
      ]) {
        expect(mesh.faceCount, lessThan(2600), reason: 'a frame has a budget');
        // About two units across, as the layout of a wave expects.
        expect(mesh.radius, inInclusiveRange(0.8, 1.3));
      }
    },
  );

  test('the curved ships are smooth', () {
    // Fewer corners than three per face: corners are shared, which is what
    // smooth shading is. (The hauler and the probe are boxes and panels,
    // flat-faced on purpose.)
    for (final style in [ShipStyle.saucer, ShipStyle.orb, ShipStyle.manta]) {
      final mesh = Models.ship(style);
      expect(
        mesh.vertexCount,
        lessThan(mesh.faceCount * 3 ~/ 2),
        reason: style.name,
      );
    }
  });

  test('a ship is coloured as it is drawn: its paint and its trim', () {
    final ship = Models.ship(ShipStyle.saucer);
    final roles = {for (final role in ship.roles) role};
    expect(roles, containsAll([0, 1, 2]), reason: 'its own, paint, trim');
  });
}
