import 'package:flutter/material.dart';
import 'package:flutter_full_stack_flutter/core/audio/sound.dart';
import 'package:flutter_full_stack_flutter/core/pronunciation/gop_scorer.dart';
import 'package:flutter_full_stack_flutter/features/pronunciation/presentation/hiding_cat.dart';
import 'package:flutter_full_stack_flutter/features/pronunciation/presentation/scenes/cat.dart';
import 'package:flutter_full_stack_flutter/features/pronunciation/providers/practice_controller.dart';
import 'package:flutter_full_stack_flutter/theme/app_theme.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/practice.dart';

/// The cat's decisions, with the scene stood in for by a line of text that
/// says what the cat is doing.
Widget _host({
  Object? prompt = 'en-p01',
  PracticeStage stage = PracticeStage.ready,
  PronunciationResult? result,
  bool reduceMotion = false,
  bool walks = false,
  ValueChanged<Sound>? onSound,
}) => MaterialApp(
  theme: AppTheme.light(),
  home: Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
      child: HidingCat(
        prompt: prompt,
        stage: stage,
        result: result,
        walks: walks,
        onSound: onSound,
        builder: (context, cat) => AnimatedBuilder(
          animation: cat,
          builder: (context, _) => Text(cat.value.gesture?.name ?? 'hidden'),
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('it stays hidden until the learner has waited a while, then '
      'comes out to wash a paw - once', (tester) async {
    await tester.pumpWidget(_host());
    await tester.pump(HidingCat.patience - const Duration(seconds: 1));
    expect(find.text('hidden'), findsOneWidget);
    expect(tester.hasRunningAnimations, isFalse);

    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(find.text('lick'), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.text('hidden'), findsOneWidget);

    // Still on the same prompt - rebuilt, as the screen is for all sorts
    // of reasons - it has said it, and does not nag.
    await tester.pumpWidget(_host());
    await tester.pump(HidingCat.patience * 3);
    expect(find.text('hidden'), findsOneWidget);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('a new prompt is a fresh pause', (tester) async {
    await tester.pumpWidget(_host());
    await tester.pump(HidingCat.patience);
    await tester.pumpAndSettle();

    await tester.pumpWidget(_host(prompt: 'en-p02'));
    await tester.pump(HidingCat.patience);
    await tester.pump();
    expect(find.text('lick'), findsOneWidget);
    await tester.pumpAndSettle();
  });

  testWidgets('it keeps out of sight while the learner speaks', (
    tester,
  ) async {
    await tester.pumpWidget(_host());
    await tester.pump(HidingCat.patience);
    await tester.pump();
    expect(find.text('lick'), findsOneWidget);

    // The microphone opens mid-visit: back behind the bush, there and then.
    await tester.pumpWidget(_host(stage: PracticeStage.recording));
    expect(find.text('hidden'), findsOneWidget);
    expect(tester.hasRunningAnimations, isFalse);

    // And recording for a long while is no pause to come out in.
    await tester.pump(HidingCat.patience * 2);
    expect(find.text('hidden'), findsOneWidget);
  });

  testWidgets('it answers a weak attempt with a slow blink, a strong one '
      'with a swish, and a middling one not at all', (tester) async {
    for (final (score, answer) in [
      (35.0, 'blink'),
      (92.0, 'swish'),
      (70.0, 'hidden'),
    ]) {
      await tester.pumpWidget(_host(stage: PracticeStage.scoring));
      await tester.pumpWidget(
        _host(stage: PracticeStage.scored, result: scored(score)),
      );
      await tester.pump();
      expect(find.text(answer), findsOneWidget, reason: 'scored $score');
      await tester.pumpAndSettle();
      expect(find.text('hidden'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('it answers each attempt once', (tester) async {
    final result = scored(35);
    await tester.pumpWidget(_host(stage: PracticeStage.scored));
    await tester.pumpWidget(_host(stage: PracticeStage.scored, result: result));
    await tester.pumpAndSettle();

    // Rebuilt with the same score - a theme change, say - it stays put.
    await tester.pumpWidget(_host(stage: PracticeStage.scored, result: result));
    await tester.pump();
    expect(find.text('hidden'), findsOneWidget);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('with no scene to hide in, it never comes out', (tester) async {
    await tester.pumpWidget(_host(prompt: null));
    await tester.pump(HidingCat.patience * 2);
    expect(find.text('hidden'), findsOneWidget);

    await tester.pumpWidget(
      _host(prompt: null, stage: PracticeStage.scored, result: scored(35)),
    );
    await tester.pump();
    expect(find.text('hidden'), findsOneWidget);
  });

  testWidgets('under reduced motion it stays hidden', (tester) async {
    await tester.pumpWidget(_host(reduceMotion: true));
    await tester.pump(HidingCat.patience);
    await tester.pump();
    expect(find.text('hidden'), findsOneWidget);

    await tester.pumpWidget(
      _host(
        stage: PracticeStage.scored,
        result: scored(35),
        reduceMotion: true,
      ),
    );
    await tester.pump();
    expect(find.text('hidden'), findsOneWidget);
    expect(tester.hasRunningAnimations, isFalse);
  });

  group('it is heard', () {
    /// How long into a [gesture]'s visit the cat is [g] through it.
    Duration into(CatGesture gesture, double g, {bool walks = false}) =>
        gesture.duration * CatPose.at(g, walks: walks);

    testWidgets('meowing as it starts to wash - later for a cat that walks '
        'out - and washing quietly', (tester) async {
      for (final walks in [false, true]) {
        final heard = <Sound>[];
        await tester.pumpWidget(_host(walks: walks, onSound: heard.add));
        await tester.pump(HidingCat.patience);
        await tester.pump();
        expect(find.text('lick'), findsOneWidget);

        // The meow, as its gesture begins.
        final meow = into(CatGesture.lick, 0, walks: walks);
        await tester.pump(meow - const Duration(milliseconds: 40));
        expect(heard, isEmpty, reason: 'early, walks: $walks');
        await tester.pump(const Duration(milliseconds: 80));
        expect(heard, [Sound.meow], reason: 'walks: $walks');

        await tester.pumpAndSettle();
        expect(heard, [Sound.meow], reason: 'walks: $walks');
        await tester.pumpWidget(const SizedBox());
      }
    });

    testWidgets('murmuring through a slow blink, trilling as it hops', (
      tester,
    ) async {
      for (final (score, sound) in [
        (35.0, Sound.murmur),
        (92.0, Sound.trill),
      ]) {
        final heard = <Sound>[];
        await tester.pumpWidget(
          _host(stage: PracticeStage.scoring, onSound: heard.add),
        );
        await tester.pumpWidget(
          _host(
            stage: PracticeStage.scored,
            result: scored(score),
            onSound: heard.add,
          ),
        );
        await tester.pumpAndSettle();
        expect(heard, [sound], reason: 'scored $score');
        await tester.pumpWidget(const SizedBox());
      }
    });

    testWidgets('not once it has been sent back for the learner to speak', (
      tester,
    ) async {
      final heard = <Sound>[];
      await tester.pumpWidget(_host(onSound: heard.add));
      await tester.pump(HidingCat.patience);
      await tester.pump(into(CatGesture.lick, 0.1));
      expect(heard, [Sound.meow]);

      await tester.pumpWidget(
        _host(stage: PracticeStage.recording, onSound: heard.add),
      );
      await tester.pump(CatGesture.lick.duration);
      expect(heard, [Sound.meow]);
    });

    testWidgets('not at all under reduced motion', (tester) async {
      final heard = <Sound>[];
      await tester.pumpWidget(_host(reduceMotion: true, onSound: heard.add));
      await tester.pump(HidingCat.patience + CatGesture.lick.duration);
      await tester.pumpWidget(
        _host(
          stage: PracticeStage.scored,
          result: scored(92),
          reduceMotion: true,
          onSound: heard.add,
        ),
      );
      await tester.pumpAndSettle();
      expect(heard, isEmpty);
    });
  });
}
