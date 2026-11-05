import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_full_stack_flutter/core/audio/sound.dart';
import 'package:flutter_full_stack_flutter/core/pronunciation/lexicon.dart';
import 'package:flutter_full_stack_flutter/features/pronunciation/presentation/prompt_scene.dart';
import 'package:flutter_full_stack_flutter/features/pronunciation/presentation/scenes/cat.dart';
import 'package:flutter_full_stack_flutter/features/pronunciation/presentation/scenes/iso_stage.dart';
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

/// Every call the scene makes on the canvas - the scene [of], if there are
/// two mid-handover.
List<RecordedInvocation> _recorded(WidgetTester tester, [Finder? of]) {
  final canvas = TestRecordingCanvas();
  tester
      .renderObject<RenderCustomPaint>(of ?? _canvas())
      .paint(TestRecordingPaintingContext(canvas), Offset.zero);
  return canvas.invocations;
}

/// Every call the scene makes on the canvas, as text, so two pictures can be
/// compared call for call.
List<String> _calls(WidgetTester tester, [Finder? of]) => [
  for (final call in _recorded(tester, of)) '$call',
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
    final finished = _calls(tester);

    await tester.pumpWidget(_host(PromptTopic.coffee));
    await tester.pump(PromptScene.fade ~/ 2);
    // Mid-way, the old scene is fading out under the new one - finished,
    // not starting its own story over.
    expect(_canvas(), findsNWidgets(2));
    expect(_calls(tester, _canvas().first), finished);

    await tester.pumpAndSettle();
    expect(_canvas(), findsOneWidget);
  });

  testWidgets('the story waits for the world, and the light stays on it', (
    tester,
  ) async {
    // The traffic scene's spotlight - the one full-canvas paint it makes -
    // is off while the crossroads assembles, on once the car is in, and
    // still on, gentler, at rest.
    bool lit(WidgetTester tester) => _recorded(
      tester,
    ).any((call) => call.invocation.memberName == #drawPaint);

    await tester.pumpWidget(_host(PromptTopic.traffic));
    await tester.pump(PromptScene.arrival * (Act.setting * 0.8));
    expect(lit(tester), isFalse, reason: 'lit during act one');

    await tester.pump(PromptScene.arrival * 0.4);
    expect(lit(tester), isTrue, reason: 'dark during the story');

    await tester.pumpAndSettle();
    expect(lit(tester), isTrue, reason: 'dark at rest');
  });

  testWidgets('the cat comes out on a visit, and leaves the picture as it '
      'found it', (tester) async {
    final visit = AnimationController(
      vsync: const TestVSync(),
      duration: CatGesture.blink.duration,
    );
    addTearDown(visit.dispose);
    // The same pose `HidingCat` hands over: out while the visit plays.
    final cat = visit.drive(
      _PoseOf(CatGesture.blink, () => visit.isAnimating),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: PromptScene(topic: PromptTopic.hotel, cat: cat),
      ),
    );
    await tester.pumpAndSettle();
    final hidden = _calls(tester);

    visit.forward();
    await tester.pump();
    await tester.pump(CatGesture.blink.duration ~/ 2);
    expect(_calls(tester), isNot(hidden), reason: 'never came out');

    await tester.pumpAndSettle();
    expect(_calls(tester), hidden);
  });

  testWidgets('every scene has the cat hiding in it', (tester) async {
    Future<List<String>> drawn(PromptTopic topic, CatPose cat) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: PromptScene(
              key: UniqueKey(),
              topic: topic,
              cat: AlwaysStoppedAnimation(cat),
            ),
          ),
        ),
      );
      return _calls(tester);
    }

    for (final topic in PromptTopic.values) {
      expect(
        await drawn(topic, const CatPose(CatGesture.blink, 0.5)),
        isNot(await drawn(topic, CatPose.hidden)),
        reason: '${topic.name} has no cat to come out',
      );
    }
  });

  testWidgets('a cat that walks out walks all the way home', (tester) async {
    Future<List<String>> drawn(PromptTopic topic, CatPose cat) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: PromptScene(
              key: UniqueKey(),
              topic: topic,
              cat: AlwaysStoppedAnimation(cat),
            ),
          ),
        ),
      );
      return _calls(tester);
    }

    // The three that hide at ground level and come out on foot.
    for (final topic in PromptTopic.values.where(
      (topic) => PromptScene.scriptOf(topic).catWalks,
    )) {
      final hidden = await drawn(topic, CatPose.hidden);
      expect(
        await drawn(topic, const CatPose(CatGesture.lick, 0.12)),
        isNot(hidden),
        reason: '${topic.name}: not on its way out',
      );
      // Back where it started, sitting out of sight, before the visit ends.
      expect(
        await drawn(topic, const CatPose(CatGesture.lick, 0.98)),
        hidden,
        reason: '${topic.name}: not home',
      );
    }
  });

  testWidgets('every scene is heard on its beats as it arrives - each sound '
      'once, and nothing once it is at rest', (tester) async {
    const step = Duration(milliseconds: 10);
    for (final topic in PromptTopic.values) {
      final heard = <(Sound, Duration)>[];
      var elapsed = Duration.zero;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: PromptScene(
            key: UniqueKey(),
            topic: topic,
            onSound: (sound) => heard.add((sound, elapsed)),
          ),
        ),
      );
      while (elapsed < PromptScene.arrival * 2) {
        await tester.pump(step);
        elapsed += step;
      }

      final script = PromptScene.scriptOf(topic).sounds;
      expect(
        heard.map((h) => h.$1),
        script.map((cue) => cue.sound),
        reason: topic.name,
      );
      for (final (i, (sound, at)) in heard.indexed) {
        final due = PromptScene.arrival * script[i].at - sound.hit;
        expect(
          (at - due).inMilliseconds.abs(),
          lessThanOrEqualTo(step.inMilliseconds),
          reason: '${topic.name}: ${sound.name} at $at, due at $due',
        );
      }
    }
  });

  testWidgets('under reduced motion, where the story is not played, it is '
      'not heard either', (tester) async {
    final heard = <Sound>[];
    for (final topic in PromptTopic.values) {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: PromptScene(
              key: UniqueKey(),
              topic: topic,
              onSound: heard.add,
            ),
          ),
        ),
      );
      await tester.pump(PromptScene.arrival);
    }
    expect(heard, isEmpty);
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

/// A visit of [gesture] as poses: out while [playing], hidden once not.
class _PoseOf extends Animatable<CatPose> {
  _PoseOf(this.gesture, this.playing);

  final CatGesture gesture;
  final bool Function() playing;

  @override
  CatPose transform(double t) =>
      playing() ? CatPose(gesture, t) : CatPose.hidden;
}
