import 'dart:ui' show PictureRecorder;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_full_stack_flutter/core/audio/sound.dart';
import 'package:flutter_full_stack_flutter/core/pronunciation/lexicon.dart';
import 'package:flutter_full_stack_flutter/features/pronunciation/presentation/country_scene.dart';
import 'package:flutter_full_stack_flutter/features/pronunciation/presentation/prompt_scene.dart';
import 'package:flutter_full_stack_flutter/features/pronunciation/presentation/scenes/iso_stage.dart';
import 'package:flutter_full_stack_flutter/features/pronunciation/presentation/scenes/scene_painter.dart';
import 'package:flutter_full_stack_flutter/features/pronunciation/presentation/scenes/script.dart';
import 'package:flutter_full_stack_flutter/theme/app_theme.dart';
import 'package:flutter_full_stack_flutter/theme/app_tokens.dart';
import 'package:flutter_full_stack_flutter/theme/scene_tone.dart';
import 'package:flutter_test/flutter_test.dart';

/// Every place, by the language it is the place of.
final Map<String, SceneScript> _places = {
  for (final lang in practiceLanguages) lang: CountryScene.of(lang)!,
};

/// Where its page is: come into view at all, and the one in view.
typedef _Page = ({bool shown, bool heard});

Widget _host(
  SceneScript script, {
  ThemeData? theme,
  bool reduceMotion = false,
  Duration delay = Duration.zero,
  ValueListenable<_Page>? page,
  ValueChanged<Sound>? onSound,
}) => MaterialApp(
  theme: theme ?? AppTheme.light(),
  home: Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
      child: ValueListenableBuilder<_Page>(
        valueListenable: page ?? ValueNotifier((shown: true, heard: true)),
        builder: (context, page, _) => CountryScene(
          script: script,
          shown: page.shown,
          heard: page.heard,
          delay: delay,
          clear: const EdgeInsets.only(top: 200, bottom: 260),
          onSound: onSound,
        ),
      ),
    ),
  ),
);

Finder _canvas() => find.descendant(
  of: find.byType(CountryScene),
  matching: find.byType(CustomPaint),
);

List<RecordedInvocation> _recorded(WidgetTester tester) {
  final canvas = TestRecordingCanvas();
  tester
      .renderObject<RenderCustomPaint>(_canvas())
      .paint(TestRecordingPaintingContext(canvas), Offset.zero);
  return canvas.invocations;
}

void main() {
  test('every language practised has a place of its own', () {
    expect(_places.values.toSet(), hasLength(practiceLanguages.length));
    expect(CountryScene.of('xx'), isNull);
  });

  test('every place is heard while its story is told, and not after', () {
    for (final MapEntry(key: lang, value: script) in _places.entries) {
      expect(script.sounds, isNotEmpty, reason: '$lang is silent');
      for (final cue in script.sounds) {
        final where = '$lang: ${cue.sound.name} at ${cue.at}';
        expect(
          cue.startIn(PromptScene.arrival),
          greaterThanOrEqualTo(Act.setting),
          reason: where,
        );
        expect(cue.at, lessThan(Act.told), reason: where);
      }
    }
  });

  for (final theme in [
    (name: 'light', build: AppTheme.light),
    (name: 'dark', build: AppTheme.dark),
  ]) {
    testWidgets('every place draws itself in, then holds still — '
        '${theme.name}', (tester) async {
      for (final MapEntry(key: lang, value: script) in _places.entries) {
        await tester.pumpWidget(_host(script, theme: theme.build()));
        // Through the arrival, so every beat is painted at least once
        // mid-flight - a throw in any of them fails here.
        for (var i = 0; i < 8; i++) {
          await tester.pump(PromptScene.arrival ~/ 6);
        }
        await tester.pumpAndSettle();

        expect(tester.hasRunningAnimations, isFalse, reason: lang);
        expect(_canvas(), isNot(paintsNothing), reason: lang);
      }
    });

    testWidgets('every place paints inside the world band — ${theme.name}', (
      tester,
    ) async {
      final data = theme.build();
      final tone = data.extension<AppTokens>()!.worldTone;
      for (final MapEntry(key: lang, value: script) in _places.entries) {
        await tester.pumpWidget(
          _host(script, theme: data, reduceMotion: true),
        );
        await tester.pump();

        var checked = 0;
        for (final call in _recorded(tester)) {
          for (final paint
              in call.invocation.positionalArguments.whereType<Paint>()) {
            if (paint.shader != null) continue;
            expect(
              SceneTone.lightnessOf(paint.color.computeLuminance()),
              inInclusiveRange(tone.low - 0.5, tone.high + 0.5),
              reason: '$lang: ${paint.color} in ${call.invocation}',
            );
            checked++;
          }
        }
        expect(checked, greaterThan(50), reason: '$lang: too few');
      }
    });
  }

  testWidgets('it waits until its page is shown, then is heard on its '
      'beat - once', (tester) async {
    const delay = Duration(milliseconds: 500);
    const step = Duration(milliseconds: 10);
    for (final MapEntry(key: lang, value: script) in _places.entries) {
      final page = ValueNotifier<_Page>((shown: false, heard: false));
      addTearDown(page.dispose);
      final heard = <(Sound, Duration)>[];
      var elapsed = Duration.zero;
      await tester.pumpWidget(Container());
      await tester.pumpWidget(
        _host(
          script,
          delay: delay,
          page: page,
          onSound: (sound) => heard.add((sound, elapsed)),
        ),
      );
      // Off screen, it waits.
      await tester.pump(PromptScene.arrival);
      expect(heard, isEmpty, reason: lang);

      page.value = (shown: true, heard: true);
      while (elapsed < delay + PromptScene.arrival * 2) {
        await tester.pump(step);
        elapsed += step;
      }

      expect(heard.map((h) => h.$1), [
        for (final cue in script.sounds) cue.sound,
      ], reason: lang);
      for (final (i, (sound, at)) in heard.indexed) {
        // Started ahead of its moment by however long it takes to reach it.
        final due =
            delay + PromptScene.arrival * script.sounds[i].at - sound.hit;
        expect(
          (at - due).inMilliseconds.abs(),
          lessThanOrEqualTo(2 * step.inMilliseconds),
          reason: '$lang: ${sound.name} at $at, due at $due',
        );
      }
    }
  });

  testWidgets('a page only peeked at arrives, but is not heard', (
    tester,
  ) async {
    for (final script in _places.values) {
      final heard = <Sound>[];
      await tester.pumpWidget(Container());
      await tester.pumpWidget(
        _host(
          script,
          page: ValueNotifier((shown: true, heard: false)),
          onSound: heard.add,
        ),
      );
      await tester.pumpAndSettle();

      expect(heard, isEmpty);
      // But it is there, at rest, for when its page comes into view.
      expect(_canvas(), isNot(paintsNothing));
    }
  });

  testWidgets('brought back into view, it tells its story again, over the '
      'world as it is', (tester) async {
    for (final MapEntry(key: lang, value: script) in _places.entries) {
      final page = ValueNotifier<_Page>((shown: true, heard: true));
      addTearDown(page.dispose);
      final heard = <Sound>[];
      await tester.pumpWidget(Container());
      await tester.pumpWidget(_host(script, page: page, onSound: heard.add));
      await tester.pumpAndSettle();
      expect(heard, hasLength(script.sounds.length), reason: lang);
      final atRest = [for (final call in _recorded(tester)) '$call'];

      // Swiped away, and back.
      page.value = (shown: true, heard: false);
      await tester.pump();
      page.value = (shown: true, heard: true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      // The island does not rise again: the story starts with it there.
      expect(
        _recorded(tester).length,
        greaterThan(atRest.length ~/ 2),
        reason: lang,
      );
      await tester.pumpAndSettle();

      expect(heard, hasLength(2 * script.sounds.length), reason: lang);
      // And it comes to rest as it was.
      expect([for (final call in _recorded(tester)) '$call'], atRest);
    }
  });

  testWidgets('under reduced motion it is simply there, and silent', (
    tester,
  ) async {
    for (final script in _places.values) {
      final heard = <Sound>[];
      final page = ValueNotifier<_Page>((shown: true, heard: true));
      addTearDown(page.dispose);
      await tester.pumpWidget(Container());
      await tester.pumpWidget(
        _host(script, reduceMotion: true, page: page, onSound: heard.add),
      );
      await tester.pump();
      expect(tester.hasRunningAnimations, isFalse);
      expect(_canvas(), isNot(paintsNothing));

      page.value = (shown: true, heard: false);
      await tester.pump();
      page.value = (shown: true, heard: true);
      await tester.pump(PromptScene.arrival);
      expect(heard, isEmpty);
    }
  });

  test('a centred island is never sized to nothing, nor less', () {
    // A phone on its side, with the headline and the panel taking more
    // than its height between them.
    final stage = IsoStage(
      Canvas(PictureRecorder()),
      const Size(891, 411),
      1,
      const SceneTone(40, 98),
      haze: const Color(0xFFFFFFFF),
      clear: const EdgeInsets.only(top: 300, bottom: 300, right: 1000),
      centred: true,
    );

    expect(stage.unit, greaterThan(0));
  });

  test('every place finishes painting however little room it is left - '
      'even none', () {
    // An island sized to nothing once had the skyline's loop, which steps
    // across the canvas by the island's unit, never get anywhere.
    final tokens = AppTheme.light().extension<AppTokens>()!;
    for (final script in _places.values) {
      for (final size in const [Size(891, 411), Size(320, 480), Size.zero]) {
        ScenePainter(
          script: script,
          progress: const AlwaysStoppedAnimation(1),
          tone: tokens.worldTone,
          world: tokens.worldTone,
          haze: const Color(0xFFFFFFFF),
          opacity: 1,
          centred: true,
          clear: const EdgeInsets.only(top: 400, bottom: 400, right: 900),
        ).paint(Canvas(PictureRecorder()), size);
      }
    }
  });
}
