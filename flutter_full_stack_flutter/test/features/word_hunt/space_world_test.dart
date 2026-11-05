import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_full_stack_flutter/features/word_hunt/presentation/deck_look.dart';
import 'package:flutter_full_stack_flutter/features/word_hunt/presentation/space/geometry.dart';
import 'package:flutter_full_stack_flutter/features/word_hunt/presentation/space/space_view.dart';
import 'package:flutter_full_stack_flutter/features/word_hunt/presentation/space/space_world.dart';
import 'package:flutter_full_stack_flutter/features/word_hunt/providers/word_bank.dart';
import 'package:flutter_test/flutter_test.dart';

/// The six longest words of the bank: the hardest to keep apart.
final List<ShipWord> _longest = [
  for (final pair in ([
    for (final deck in WordDeck.values) ...deck.words,
  ]..sort((a, b) => b.en.length.compareTo(a.en.length))).take(6))
    (label: pair.en, meaning: pair.pt),
];

SpaceWorld _world(Size size, EdgeInsets clear, {double text = 1}) {
  final world = SpaceWorld(palette: WordDeck.animals.palette, seed: 3)
    ..layout(size, clear)
    ..typeset(
      const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      TextScaler.linear(text),
    );
  addTearDown(world.dispose);
  return world;
}

void _fly(SpaceWorld world, double seconds) {
  for (var t = 0.0; t < seconds; t += 1 / 60) {
    world.tick(1 / 60);
  }
}

/// Draws a frame, as the screen would, so each ship knows where its label
/// and hull are.
void _draw(SpaceWorld world) {
  final recorder = ui.PictureRecorder();
  world.paint(Canvas(recorder));
  recorder.endRecording().dispose();
}

void main() {
  group('the ships', () {
    const screens = {
      'an upright phone': (
        Size(390, 844),
        EdgeInsets.only(top: 250, bottom: 160),
      ),
      'a phone on its side': (
        Size(844, 390),
        EdgeInsets.only(left: 330, top: 10, bottom: 96),
      ),
      'a tablet': (Size(1024, 1366), EdgeInsets.only(top: 260, bottom: 260)),
    };

    screens.forEach((name, screen) {
      test('keep their words clear of the panels and off each other, on '
          '$name', () {
        final (size, clear) = screen;
        // What the panels leave: no word may be under one.
        final open = Rect.fromLTRB(
          clear.left,
          clear.top,
          size.width - clear.right,
          size.height - clear.bottom,
        );
        // The six longest words, in large text - and in the test font,
        // whose every letter is a full square: far wider than any real
        // word is drawn.
        final world = _world(size, clear, text: 1.3)..launch(8, _longest);
        _fly(world, 1.5);
        for (var second = 0; second < 24; second++) {
          _fly(world, 1);
          _draw(world);
          final labels = [
            for (final ship in world.ships) ?ship.labelRect,
          ];
          expect(labels, hasLength(_longest.length), reason: 'at ${second}s');
          for (final label in labels) {
            expect(
              open.contains(label.topLeft) && open.contains(label.bottomRight),
              isTrue,
              reason: '$label outside $open at ${second}s',
            );
          }
          for (var i = 0; i < labels.length; i++) {
            for (var j = i + 1; j < labels.length; j++) {
              expect(
                labels[i].overlaps(labels[j]),
                isFalse,
                reason: '${labels[i]} over ${labels[j]} at ${second}s',
              );
            }
          }
        }
      });
    });

    test('stay inside a field that changes shape under them', () {
      final world = _world(
        const Size(390, 844),
        const EdgeInsets.only(top: 250, bottom: 160),
      )..launch(1, _longest.take(4).toList());
      _fly(world, 2);
      world.layout(
        const Size(844, 390),
        const EdgeInsets.only(left: 330, top: 10, bottom: 96),
      );
      _fly(world, 1);
      _draw(world);
      for (final ship in world.ships) {
        expect(world.field.inflate(20).contains(ship.hull!), isTrue);
      }
    });
  });

  group('shooting', () {
    late SpaceWorld world;
    final impacts = <(int, int)>[];

    setUp(() {
      impacts.clear();
      world =
          _world(
              const Size(390, 844),
              const EdgeInsets.only(top: 250, bottom: 160),
            )
            ..onImpact = ((round, index) => impacts.add((round, index)))
            ..launch(3, _longest.take(4).toList());
      _fly(world, 2);
      _draw(world);
    });

    test('a tap on a word picks its ship; a tap on empty sky picks none', () {
      for (final ship in world.ships) {
        expect(world.pick(ship.labelRect!.center), ship.index);
        expect(world.pick(ship.hull!), ship.index);
      }
      expect(world.pick(const Offset(4, 4)), isNull);
    });

    test('a laser takes a moment to land, and one is enough', () {
      expect(world.fire(2), isTrue);
      expect(world.fire(2), isFalse, reason: 'one already on its way');
      expect(world.pick(world.ships[2].labelRect!.center), isNull);
      _fly(world, 0.1);
      expect(impacts, isEmpty);
      _fly(world, 0.2);
      expect(impacts, [(3, 2)]);
    });

    test('a ship that was not the answer is shielded, and out of play', () {
      world.miss(1);
      _fly(world, 0.5);
      _draw(world);
      expect(world.ships[1].missed, isTrue);
      expect(world.pick(world.ships[1].labelRect!.center), isNull);
      expect(world.fire(1), isFalse);
    });

    test('the answer explodes, and the others leave', () {
      world.fire(0);
      _fly(world, 0.25);
      world.hit(0, 150);
      _fly(world, 0.2);
      _draw(world);
      expect(world.ships.any((ship) => ship.index == 0), isFalse);
      expect(world.pick(world.ships.first.labelRect!.center), isNull);
      _fly(world, 1.5);
      expect(world.ships, isEmpty);
    });

    test('a laser still flying when its round ends lands on nothing', () {
      world
        ..fire(1)
        ..depart();
      _fly(world, 0.5);
      expect(impacts, isEmpty);
    });

    test('time running out leaves the answer, showing what it means', () {
      world
        ..hint(3)
        ..reveal(3);
      _fly(world, 1.2);
      _draw(world);
      expect(world.ships.map((ship) => ship.index), [3]);
      expect(world.ships.single.revealed, isTrue);
    });

    test('a new wave sends the last one away', () {
      world.launch(4, _longest.skip(1).take(5).toList());
      _fly(world, 1.5);
      expect(world.ships, hasLength(5));
      expect(world.round, 4);
    });
  });

  test('the lobby flies no words and fires nothing', () {
    final world = SpaceWorld(ambient: true)
      ..layout(const Size(390, 844), EdgeInsets.zero);
    addTearDown(world.dispose);
    _fly(world, 1);
    _draw(world);
    expect(world.ships, isEmpty);
    expect(world.fire(0), isFalse);
    expect(world.facesDrawn, greaterThan(500), reason: 'a planet, ships');
  });

  test('every deck draws, moving or still', () {
    for (final deck in WordDeck.values) {
      final world =
          _world(
              const Size(390, 844),
              const EdgeInsets.only(top: 250, bottom: 160),
            )
            ..palette = deck.palette
            ..still = deck.index.isEven
            ..launch(1, _longest.take(4).toList());
      _fly(world, 1);
      world
        ..fire(0)
        ..miss(1);
      _fly(world, 0.3);
      world.hit(0, 100);
      _fly(world, 0.2);
      _draw(world);
      expect(world.facesDrawn, greaterThan(500), reason: deck.name);
    }
  });

  testWidgets('a tap on the view fires at the ship under it', (tester) async {
    final world = _world(
      const Size(800, 600),
      const EdgeInsets.only(top: 100, bottom: 100),
    )..launch(1, _longest.take(4).toList());
    final tapped = <int>[];
    await tester.pumpWidget(
      MaterialApp(
        home: SpaceView(
          world: world,
          clear: const EdgeInsets.only(top: 100, bottom: 100),
          onShip: tapped.add,
        ),
      ),
    );
    for (var i = 0; i < 90; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    final ship = world.ships.first;
    await tester.tapAt(ship.labelRect!.center);
    await tester.tapAt(const Offset(3, 3));
    expect(tapped, [ship.index]);

    // Paused, the world holds still.
    final time = world.time;
    await tester.pumpWidget(
      MaterialApp(home: SpaceView(world: world, running: false)),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(world.time, closeTo(time, 0.05));
  });

  group('geometry', () {
    test('a point unprojected at a depth projects back to where it was', () {
      final camera = Camera(
        eye: const V3(0.3, -0.2, 0.1),
        rotation: Rot.euler(yaw: 0.1, pitch: -0.12, roll: 0.02),
        size: const Size(390, 844),
      );
      const screen = Offset(120, 610);
      final world = camera.unproject(screen, 8);
      expect(camera.depthOf(world), closeTo(8, 1e-9));
      final back = camera.project(world)!;
      expect(back.dx, closeTo(screen.dx, 1e-6));
      expect(back.dy, closeTo(screen.dy, 1e-6));
      expect(camera.project(camera.eye - camera.forward), isNull);
    });

    test('turning to face a direction points the nose along it', () {
      const direction = V3(0.4, 0.5, -1);
      final facing = Rot.facing(direction);
      final turned = Rot.euler(yaw: facing.yaw, pitch: facing.pitch).forward;
      expect((turned - direction.unit).length, lessThan(1e-9));
    });

    test('turns compose in order', () {
      final a = Rot.euler(yaw: 0.7);
      final b = Rot.euler(pitch: 0.3);
      const v = V3(1, 2, 3);
      expect(((a * b).apply(v) - a.apply(b.apply(v))).length, lessThan(1e-9));
    });
  });
}
