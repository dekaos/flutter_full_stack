import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_full_stack_flutter/app/app_mark.dart';
import 'package:flutter_full_stack_flutter/app/cna_logo.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('draws at rest - the logo alone - and in every pose the splash '
      'passes through', () {
    for (final mark in [
      const AppMark(),
      // Speaking, gathering into the tick, drawing it, and popping.
      for (final (tick, burst) in const [(0.0, 0.0), (0.3, 0.0), (0.7, 0.4)])
        AppMark(
          pose: MarkPose(
            bubble: 1.1,
            levels: const [0, 0.2, 1, 0.4, 0.1],
            tick: tick,
            burst: burst,
          ),
        ),
    ]) {
      final recorder = ui.PictureRecorder();
      mark.paint(Canvas(recorder), const Size.square(200));
      expect(recorder.endRecording(), isNotNull);
    }
  });

  test("the logo is CNA's own, read whole from its outlines", () {
    final bounds = CnaLogo.path.getBounds();
    // Every outline read, so the letters reach the logo's own canvas.
    expect(bounds.left, closeTo(0, 0.5));
    expect(bounds.top, closeTo(0, 0.5));
    expect(bounds.right, closeTo(CnaLogo.width, 0.5));
    expect(bounds.bottom, closeTo(CnaLogo.height, 0.5));
  });

  test('a pose is a value: the splash repaints only when it moves', () {
    // Equal by value, not by identity: a list built afresh still matches.
    expect(MarkPose(levels: List.of(MarkPose.rest)), const MarkPose());
    expect(const MarkPose(), isNot(const MarkPose(tick: 1)));
    expect(const MarkPose(), isNot(const MarkPose(burst: 0.5)));
    expect(
      const AppMark().shouldRepaint(const AppMark(pose: MarkPose(tick: 1))),
      isTrue,
    );
    expect(const AppMark().shouldRepaint(const AppMark()), isFalse);
  });
}
