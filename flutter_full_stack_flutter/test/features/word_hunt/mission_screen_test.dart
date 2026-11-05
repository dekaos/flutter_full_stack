import 'package:flutter/material.dart';
import 'package:flutter_full_stack_flutter/app/router.dart';
import 'package:flutter_full_stack_flutter/core/audio/sound.dart';
import 'package:flutter_full_stack_flutter/features/word_hunt/presentation/mission_panels.dart';
import 'package:flutter_full_stack_flutter/features/word_hunt/presentation/mission_screen.dart';
import 'package:flutter_full_stack_flutter/features/word_hunt/presentation/space/space_view.dart';
import 'package:flutter_full_stack_flutter/features/word_hunt/presentation/word_hunt_screen.dart';
import 'package:flutter_full_stack_flutter/features/word_hunt/providers/hunt_records.dart';
import 'package:flutter_full_stack_flutter/features/word_hunt/providers/mission_controller.dart';
import 'package:flutter_full_stack_flutter/features/word_hunt/providers/word_bank.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_support.dart';

const WordDeck _deck = WordDeck.animals;

/// Opens the app straight into a mission on [_deck], its first word asked.
Future<HuntApp> _flying(
  WidgetTester tester, {
  Map<WordDeck, DeckRecord> records = const {},
}) async {
  final app = HuntApp(records: records);
  await app.open(tester);
  app.container.read(routerProvider).go('/mission/${_deck.name}');
  await frames(tester, MissionPace.countdown + const Duration(seconds: 1));
  expect(app.mission(_deck).round?.number, 1);
  return app;
}

/// Taps the ship with [choice] of the round being asked, where it is in the
/// sky, once it has flown in - and lets the laser land.
Future<void> _shoot(WidgetTester tester, int choice) async {
  final world = tester.widget<SpaceView>(find.byType(SpaceView)).world;
  final ship = world.ships.firstWhere((ship) => ship.index == choice);
  for (var i = 0; i < 120 && !ship.shootable; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
  await tester.tapAt(ship.labelRect!.center);
  await frames(tester, const Duration(milliseconds: 320));
}

int _wrong(Round round) => [
  for (var i = 0; i < round.choices.length; i++)
    if (i != round.answer && !round.missed.contains(i)) i,
].first;

void main() {
  testWidgets('the ship with the word asked for is the one to hit', (
    tester,
  ) async {
    final app = await _flying(tester);
    final round = app.mission(_deck).round!;
    // The prompt is the Portuguese; the ships carry the English.
    expect(find.text(round.target.pt), findsOneWidget);
    expect(app.output.sounds, contains(Sound.warp));

    // A wrong ship first: its shield takes it, and shows what it means.
    await _shoot(tester, _wrong(round));
    expect(app.mission(_deck).shields, MissionRules.shields - 1);
    expect(app.output.sounds, containsAllInOrder([Sound.laser, Sound.bonk]));
    expect(find.bySemanticsLabel('2 shields left'), findsOneWidget);

    // A hint lights the answer up.
    await tester.tap(find.byKey(const Key('hunt-hint')));
    await frames(tester, const Duration(milliseconds: 100));
    expect(app.mission(_deck).round!.hinted, isTrue);
    expect(app.output.sounds.last, Sound.sparkle);

    await _shoot(tester, round.answer);
    final hit = app.mission(_deck);
    expect(hit.round!.outcome, RoundOutcome.hit);
    expect(hit.score, greaterThan(0));
    expect(app.output.sounds.last, Sound.burst);

    // And then it is said, as it should be.
    await frames(tester, MissionScreen.readAfter);
    expect(app.voice.said, [round.target.en]);
    expect(app.voice.langs, ['en']);
    app.voice.finish();

    // The next word comes in.
    await frames(tester, MissionPace.afterHit);
    expect(app.mission(_deck).round!.number, 2);
    expect(find.text(app.mission(_deck).round!.target.pt), findsOneWidget);
  });

  testWidgets('with a screen reader on, the ships are buttons too', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(accessibleNavigation: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final app = await _flying(tester);

    final round = app.mission(_deck).round!;
    expect(find.byType(ChoiceBar), findsOneWidget);
    expect(find.text(round.target.en), findsWidgets);

    await tester.tap(find.byKey(Key('hunt-choice-${round.answer}')));
    await frames(tester, const Duration(milliseconds: 320));
    expect(app.mission(_deck).round!.outcome, RoundOutcome.hit);
    expect(find.byType(ChoiceBar), findsNothing, reason: 'nothing to shoot');
  });

  testWidgets('a whole mission, its results, and another go', (tester) async {
    final app = await _flying(
      tester,
      records: {_deck: const DeckRecord(score: 10, stars: 1)},
    );
    while (app.mission(_deck).phase == MissionPhase.playing) {
      await _shoot(tester, app.mission(_deck).round!.answer);
      // Each word is read aloud after its hit; a reading takes a moment,
      // and nothing else is heard over it.
      await frames(tester, MissionScreen.readAfter);
      expect(app.voice.speaking.value, isTrue);
      app.voice.finish();
      await frames(tester, MissionPace.afterHit - MissionScreen.readAfter);
    }
    await frames(tester, const Duration(seconds: 2));

    final over = app.mission(_deck);
    expect(over.phase, MissionPhase.over);
    expect(over.stars, 3);
    expect(find.text('Mission complete!'), findsOneWidget);
    expect(find.byKey(const Key('hunt-new-best')), findsOneWidget);
    expect(find.text('10 of 10 words found'), findsOneWidget);
    expect(app.output.sounds, contains(Sound.fanfare));
    expect(app.records.submitted.single, (
      _deck,
      DeckRecord(score: over.score, stars: 3),
    ));

    // Every word of it, each a tap from being heard.
    final first = over.results.first.pair;
    expect(find.text('${first.pt}  →  ${first.en}'), findsOneWidget);
    await tester.tap(find.byTooltip('Hear “${first.en}”'));
    await frames(tester, const Duration(milliseconds: 100));
    expect(app.voice.said.last, first.en);
    app.voice.finish();

    await tester.tap(find.byKey(const Key('hunt-again')));
    await frames(tester, const Duration(milliseconds: 100));
    expect(app.mission(_deck).phase, MissionPhase.countdown);
    expect(find.byType(ResultsPanel), findsNothing);
    await frames(tester, MissionPace.countdown + const Duration(seconds: 1));
    expect(app.mission(_deck).round!.number, 1);
  });

  testWidgets('out of shields, the mission ends, gently', (tester) async {
    final app = await _flying(tester);
    for (var i = 0; i < MissionRules.shields; i++) {
      await _shoot(tester, _wrong(app.mission(_deck).round!));
    }
    // The answer is shown before the results.
    expect(find.byKey(const Key('hunt-answer')), findsOneWidget);
    await frames(tester, MissionPace.afterWreck + const Duration(seconds: 1));
    expect(find.text('Out of shields!'), findsOneWidget);
    expect(find.bySemanticsLabel('No stars'), findsOneWidget);
  });

  testWidgets('time running out shows the answer', (tester) async {
    final app = await _flying(tester);
    final round = app.mission(_deck).round!;
    await frames(tester, MissionPace.answer);
    expect(app.mission(_deck).round!.outcome, RoundOutcome.timedOut);
    expect(
      find.text('The answer was ${round.target.en}', findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets('the word asked for is always on a card of one height', (
    tester,
  ) async {
    // The ships fly in what the card leaves: were it to grow a line, the
    // whole play area would move under them as the words changed.
    final app = await _flying(tester);
    double height() => tester.getSize(find.byType(PromptCard)).height;
    final heights = <String, double>{'asked': height()};

    await _shoot(tester, _wrong(app.mission(_deck).round!));
    heights['missed'] = height();
    await _shoot(tester, app.mission(_deck).round!.answer);
    await frames(tester, MissionScreen.readAfter);
    app.voice.finish();
    heights['found'] = height();
    await frames(tester, MissionPace.afterHit);
    await frames(tester, const Duration(milliseconds: 400));
    heights['in a streak'] = height();
    await frames(tester, MissionPace.answer);
    heights['out of time'] = height();
    await frames(tester, MissionPace.afterTimeout);
    heights['next'] = height();

    expect(heights.values.toSet(), hasLength(1), reason: '$heights');
  });

  testWidgets('Back pauses, and the pause has the way out', (tester) async {
    final app = await _flying(tester);

    await tester.binding.handlePopRoute();
    await frames(tester, const Duration(milliseconds: 200));
    expect(app.mission(_deck).phase, MissionPhase.paused);
    expect(find.byType(PausePanel), findsOneWidget);
    expect(find.byType(MissionScreen), findsOneWidget, reason: 'not left');

    await tester.tap(find.byKey(const Key('hunt-resume')));
    await frames(tester, const Duration(milliseconds: 200));
    expect(app.mission(_deck).phase, MissionPhase.playing);

    await tester.tap(find.byKey(const Key('hunt-pause')));
    await frames(tester, const Duration(milliseconds: 200));
    await tester.tap(find.byKey(const Key('hunt-quit')));
    await frames(tester, const Duration(milliseconds: 600));
    expect(find.byType(WordHuntScreen), findsOneWidget);
    expect(find.byType(MissionScreen), findsNothing);
  });

  testWidgets('the app going to the background pauses the mission', (
    tester,
  ) async {
    final app = await _flying(tester);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await frames(tester, const Duration(milliseconds: 100));
    expect(app.mission(_deck).phase, MissionPhase.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await frames(tester, const Duration(milliseconds: 100));
    expect(app.mission(_deck).phase, MissionPhase.paused, reason: 'waits');
  });

  testWidgets('on its side, the word asked for moves beside the ships', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(844 * 3, 390 * 3)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final app = await _flying(tester);
    final card = tester.getRect(find.byType(PromptCard));
    expect(card.left, lessThan(844 / 2));
    expect(card.width, lessThan(844 / 2));
    await _shoot(tester, app.mission(_deck).round!.answer);
    expect(app.mission(_deck).round!.outcome, RoundOutcome.hit);
  });
}
