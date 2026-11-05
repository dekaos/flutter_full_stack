import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_full_stack_flutter/features/word_hunt/presentation/space/geometry.dart';
import 'package:flutter_full_stack_flutter/features/word_hunt/presentation/space/mesh.dart';
import 'package:flutter_full_stack_flutter/features/word_hunt/presentation/space/models.dart';
import 'package:flutter_full_stack_flutter/features/word_hunt/presentation/space/palette.dart';
import 'package:flutter_full_stack_flutter/features/word_hunt/presentation/space/renderer.dart';
import 'package:flutter_test/flutter_test.dart';

/// Light that leaves a face turned to the camera its own colour, but for
/// tone mapping: no fog, no sky, no rim, nothing reflected.
const _flat = Lighting(
  sun: V3(0, 0, 1),
  key: Rgb(1, 1, 1),
  sky: Rgb(0, 0, 0),
  ground: Rgb(0, 0, 0),
  rim: Rgb(0, 0, 0),
  fog: Rgb(0, 0, 0),
  fogDensity: 0,
  skyEnv: Rgb(0, 0, 0),
  groundEnv: Rgb(0, 0, 0),
);

final Camera _camera = Camera(
  eye: V3.zero,
  rotation: Rot.identity,
  size: const Size(100, 100),
);

/// A thin, matte square tile facing the camera, two units across.
Mesh _tile(Rgb colour) =>
    (MeshBuilder()..box(
          const V3(-1, -1, -0.001),
          const V3(1, 1, 0.001),
          colour,
          finish: Finish.matte,
        ))
        .build();

/// The colour in the middle of what [draw] puts on the canvas.
Future<Color> _middle(void Function(Renderer renderer) draw) async {
  final renderer = Renderer()..begin(_camera, _flat);
  draw(renderer);
  final recorder = ui.PictureRecorder();
  renderer.flush(Canvas(recorder));
  final image = await recorder.endRecording().toImage(100, 100);
  final pixels = (await image.toByteData())!;
  const at = (50 * 100 + 50) * 4;
  return Color.fromARGB(
    255,
    pixels.getUint8(at),
    pixels.getUint8(at + 1),
    pixels.getUint8(at + 2),
  );
}

/// Whether [seen] is the near tile's blue, not the red one behind it.
bool _blue(Color seen) => seen.b > 0.6 && seen.r < 0.3;

void main() {
  final near = _tile(const Rgb(0, 0, 1));
  final behind = _tile(const Rgb(1, 0, 0));
  final far = _tile(const Rgb(0, 1, 0));

  test('a face just in front of another stays in front', () async {
    final seen = await _middle(
      (renderer) => renderer
        ..draw(near, at: const V3(0, 0, -5))
        ..draw(behind, at: const V3(0, 0, -5.01)),
    );
    expect(_blue(seen), isTrue, reason: '$seen');
  });

  // The flicker as the words changed: ships leaving for the far distance,
  // and the next wave coming in from it, stretched the depths a frame was
  // sorted over, and faces a hair apart - a fin and the rocket's body, a
  // dome and its hull - came out in either order, changing frame to frame.
  test('...however far away the rest of the scene goes', () async {
    // Something nearer still off to one side, as the rocket is, so the two
    // are sorted somewhere in the middle of the scene's depths.
    for (final distance in [20.0, 52.0, 80.0, 400.0]) {
      for (final apart in [0.002, 0.005, 0.01, 0.02]) {
        final seen = await _middle(
          (renderer) => renderer
            ..draw(near, at: const V3(0, 0, -5))
            ..draw(behind, at: V3(0, 0, -5 - apart))
            ..draw(far, at: const V3(-3, 0, -3), scale: 0.2)
            ..draw(far, at: V3(distance, 0, -distance)),
        );
        expect(
          _blue(seen),
          isTrue,
          reason: '$seen: $apart apart, with a face at $distance',
        );
      }
    }
  });

  test('...and whichever order they are drawn in', () async {
    final seen = await _middle(
      (renderer) => renderer
        ..draw(behind, at: const V3(0, 0, -5.01))
        ..draw(near, at: const V3(0, 0, -5))
        ..draw(far, at: const V3(-3, 0, -3), scale: 0.2)
        ..draw(far, at: const V3(80, 0, -80)),
    );
    expect(_blue(seen), isTrue, reason: '$seen');
  });

  // A wide lens stretches what is off to the side of it - on an upright
  // phone, whose view is wide across its long side, a ball in a corner came
  // out half as long again one way as the other. Each solid is now seen as
  // if looked at straight on, and only placed where the lens puts it.
  test('a ball far off to the side of the view is still drawn round', () async {
    const size = Size(300, 600);
    final camera = Camera(eye: V3.zero, rotation: Rot.identity, size: size);
    final palette = SpacePalette(200);
    for (final corner in const [Offset(230, 90), Offset(60, 540)]) {
      final at = camera.unproject(corner, 30);
      final renderer = Renderer()..begin(camera, palette.lighting);
      final recorder = ui.PictureRecorder();
      renderer
        ..draw(Models.moon(palette), at: at, scale: 2, fog: 0)
        ..flush(Canvas(recorder));
      final image = await recorder.endRecording().toImage(300, 600);
      final pixels = (await image.toByteData())!;
      var (left, top, right, bottom) = (300, 600, -1, -1);
      for (var y = 0; y < 600; y++) {
        for (var x = 0; x < 300; x++) {
          if (pixels.getUint8((y * 300 + x) * 4 + 3) == 0) continue;
          left = left < x ? left : x;
          right = right > x ? right : x;
          top = top < y ? top : y;
          bottom = bottom > y ? bottom : y;
        }
      }
      final width = right - left + 1;
      final height = bottom - top + 1;
      expect(
        width / height,
        closeTo(1, 0.08),
        reason: 'at $corner: $width x $height',
      );
      // And it is where the lens puts its middle.
      expect((left + right) / 2, closeTo(corner.dx, 2));
      expect((top + bottom) / 2, closeTo(corner.dy, 2));
    }
  });
}
