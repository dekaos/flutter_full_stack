import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_full_stack_flutter/core/pronunciation/lexicon.dart';
import 'package:flutter_full_stack_flutter/features/pronunciation/presentation/prompt_scene.dart';
import 'package:flutter_full_stack_flutter/theme/app_theme.dart';
import 'package:flutter_full_stack_flutter/theme/app_tokens.dart';
import 'package:flutter_full_stack_flutter/theme/scene_tone.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(
  PromptTopic? topic, {
  ThemeData? theme,
  bool reduceMotion = false,
}) => MaterialApp(
  theme: theme ?? AppTheme.light(),
  home: Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
      child: PromptScene(topic: topic),
    ),
  ),
);

/// The painted layer of the scene, which is what the `paints` matchers read.
Finder _canvas() => find.descendant(
  of: find.byType(PromptScene),
  matching: find.byType(CustomPaint),
);

/// Every call the scene makes on the canvas.
List<RecordedInvocation> _recorded(WidgetTester tester) {
  final canvas = TestRecordingCanvas();
  tester
      .renderObject<RenderCustomPaint>(_canvas())
      .paint(TestRecordingPaintingContext(canvas), Offset.zero);
  return canvas.invocations;
}

/// Every call the scene makes on the canvas, as text, so two pictures can be
/// compared call for call.
List<String> _calls(WidgetTester tester) => [
  for (final call in _recorded(tester)) '$call',
];

void main() {
  for (final theme in [
    (name: 'light', build: AppTheme.light),
    (name: 'dark', build: AppTheme.dark),
  ]) {
    testWidgets('every topic draws itself in, then holds still — '
        '${theme.name}', (tester) async {
      for (final topic in PromptTopic.values) {
        await tester.pumpWidget(_host(topic, theme: theme.build()));
        // Through the arrival, so every beat of every scene is painted at
        // least once mid-flight - a throw in any of them fails here.
        for (var i = 0; i < 6; i++) {
          await tester.pump(PromptScene.arrival ~/ 6);
        }
        await tester.pumpAndSettle();

        // Settling at all is the point: a scene that kept moving would keep
        // the frame scheduler busy, and pumpAndSettle would time out.
        expect(tester.hasRunningAnimations, isFalse, reason: topic.name);
        expect(_canvas(), isNot(paintsNothing), reason: topic.name);
      }
    });
  }

  // The contrast guard proves that anything inside the band is legible; this
  // proves the scenes stay inside it. A colour written as a literal, or one
  // a helper made outside the palette, lands outside the band and fails
  // here, named by scene and theme.
  for (final theme in [
    (name: 'light', build: AppTheme.light),
    (name: 'dark', build: AppTheme.dark),
  ]) {
    testWidgets('every scene paints inside the legible band — '
        '${theme.name}', (tester) async {
      final data = theme.build();
      // The sky's band sits inside the world's, so the world's bounds hold
      // both: anything outside them came from somewhere other than a Tint.
      final tone = data.extension<AppTokens>()!.worldTone;
      for (final topic in PromptTopic.values) {
        await tester.pumpWidget(_host(topic, theme: data, reduceMotion: true));
        await tester.pump();

        var checked = 0;
        for (final call in _recorded(tester)) {
          for (final paint
              in call.invocation.positionalArguments.whereType<Paint>()) {
            // Gradients are built from palette colours by the kit; a flat
            // paint is where a stray colour would show.
            if (paint.shader != null) continue;
            final lightness = SceneTone.lightnessOf(
              paint.color.computeLuminance(),
            );
            expect(
              lightness,
              inInclusiveRange(tone.low - 0.5, tone.high + 0.5),
              reason: '${topic.name}: ${paint.color} in ${call.invocation}',
            );
            checked++;
          }
        }
        // A scene that painted nothing would pass the loop above vacuously.
        expect(checked, greaterThan(50), reason: '${topic.name}: too few');
      }
    });
  }

  testWidgets('under reduced motion the finished scene is simply there', (
    tester,
  ) async {
    await tester.pumpWidget(_host(PromptTopic.traffic));
    await tester.pumpAndSettle();
    final settled = _calls(tester);
    await tester.pumpWidget(const SizedBox());

    await tester.pumpWidget(_host(PromptTopic.traffic, reduceMotion: true));

    // The very first frame is the end of the story - the car already at the
    // light - and nothing is left running to get it anywhere else.
    expect(_calls(tester), settled);
    expect(tester.hasRunningAnimations, isFalse);

    // Moving to the next prompt does not travel either.
    await tester.pumpWidget(_host(PromptTopic.time, reduceMotion: true));
    await tester.pump();
    expect(tester.hasRunningAnimations, isFalse);
    expect(_canvas(), findsOneWidget);
  });

  testWidgets('the next prompt hands over to its own scene', (tester) async {
    await tester.pumpWidget(_host(PromptTopic.weather));
    await tester.pumpAndSettle();

    await tester.pumpWidget(_host(PromptTopic.coffee));
    await tester.pump(PromptScene.fade ~/ 2);
    // Mid-way, the old scene is fading out under the new one.
    expect(_canvas(), findsNWidgets(2));

    await tester.pumpAndSettle();
    expect(_canvas(), findsOneWidget);
  });

  testWidgets('a prompt without a topic draws nothing', (tester) async {
    await tester.pumpWidget(_host(null));
    await tester.pumpAndSettle();

    expect(_canvas(), findsNothing);
  });

  testWidgets('it is gone under high contrast, without being asked', (
    tester,
  ) async {
    for (final build in [
      AppTheme.highContrastLight,
      AppTheme.highContrastDark,
    ]) {
      await tester.pumpWidget(_host(PromptTopic.birds, theme: build()));
      await tester.pumpAndSettle();

      expect(_canvas(), paintsNothing);
    }
  });

  testWidgets('a tap goes to whatever is under it', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Stack(
          fit: StackFit.expand,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => taps++,
            ),
            const PromptScene(topic: PromptTopic.help),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(tester.getCenter(find.byType(PromptScene)));
    expect(taps, 1);
  });
}
