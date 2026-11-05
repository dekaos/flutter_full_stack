import 'dart:math' as math;

import 'package:fake_async/fake_async.dart';
import 'package:flutter_full_stack_flutter/features/word_hunt/providers/hunt_records.dart';
import 'package:flutter_full_stack_flutter/features/word_hunt/providers/mission_controller.dart';
import 'package:flutter_full_stack_flutter/features/word_hunt/providers/word_bank.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

const WordDeck _deck = WordDeck.animals;
final MissionControllerProvider _mission = missionControllerProvider(_deck);

typedef _Flight = void Function(
  FakeAsync time,
  ProviderContainer container,
  MemoryRecords records,
);

/// A mission on [_deck] on fake time, with its records in memory, handed to
/// [body] already counting down.
void _fly(
  _Flight body, {
  Map<WordDeck, DeckRecord> best = const {},
}) {
  fakeAsync((time) {
    final records = MemoryRecords(best);
    // The records are read when a mission starts: have them ready. And the
    // mission is disposed with its last listener, as it is when its screen
    // goes; this one keeps it for the test.
    final container = ProviderContainer(
      overrides: [
        missionRandomProvider.overrideWithValue(math.Random(7)),
        huntRecordsProvider.overrideWith(() => records),
      ],
    )..listen(huntRecordsProvider, (_, _) {});
    time.flushMicrotasks();
    container.listen(_mission, (_, _) {});
    body(time, container, records);
    container.dispose();
  });
}

extension on ProviderContainer {
  MissionState get mission => read(_mission);
  MissionController get pilot => read(_mission.notifier);

  /// Shoots the answer of the round being asked.
  void hitIt() => pilot.shoot(mission.round!.number, mission.round!.answer);

  /// Shoots a ship of the round being asked that is not its answer, and has
  /// not been shot yet.
  void missIt() {
    final round = mission.round!;
    final wrong = [
      for (var i = 0; i < round.choices.length; i++)
        if (i != round.answer && !round.missed.contains(i)) i,
    ].first;
    pilot.shoot(round.number, wrong);
  }
}

void main() {
  test('a mission counts down, then asks for its first word among four '
      'ships', () {
    _fly((time, container, _) {
      expect(container.mission.phase, MissionPhase.countdown);
      expect(container.mission.round, isNull);

      time.elapse(MissionPace.countdown);
      final round = container.mission.round!;
      expect(container.mission.phase, MissionPhase.playing);
      expect(round.number, 1);
      expect(round.choices, hasLength(4));
      expect(round.choices, contains(round.target));
      expect(_deck.words, containsAll(round.choices));
      expect(container.mission.timeLeft, MissionPace.answer);
    });
  });

  test('it asks for ten different words, adding ships as it goes, and ends '
      'with three stars for all ten', () {
    _fly((time, container, records) {
      time.elapse(MissionPace.countdown);
      final asked = <WordPair>[];
      final ships = <int>[];
      while (container.mission.phase == MissionPhase.playing) {
        asked.add(container.mission.round!.target);
        ships.add(container.mission.round!.choices.length);
        container.hitIt();
        time.elapse(MissionPace.afterHit);
      }

      expect(asked.toSet(), hasLength(MissionPlan.words));
      expect(ships, [4, 4, 4, 5, 5, 5, 5, 6, 6, 6]);
      final over = container.mission;
      expect(over.phase, MissionPhase.over);
      expect(over.found, MissionPlan.words);
      expect(over.stars, 3);
      expect(over.bestStreak, MissionPlan.words);
      time.flushMicrotasks();
      expect(records.submitted, [
        (_deck, DeckRecord(score: over.score, stars: 3)),
      ]);
    });
  });

  test('a word found at once scores its whole time bonus, and a streak '
      'multiplies what comes after', () {
    _fly((time, container, _) {
      time.elapse(MissionPace.countdown);
      container.hitIt();
      expect(container.mission.score, 150);
      expect(container.mission.results.single.points, 150);

      time
        ..elapse(MissionPace.afterHit)
        // Half the time gone: half the bonus, at a quarter more for the
        // word found before it.
        ..elapse(MissionPace.answer ~/ 2);
      container.hitIt();
      expect(container.mission.results.last.points, (125 * 1.25).round());
      expect(container.mission.multiplier, 150);
    });
  });

  test('a round takes one answer: a second shot at it, or a late one at '
      'the round before, counts for nothing', () {
    _fly((time, container, _) {
      time.elapse(MissionPace.countdown);
      final first = container.mission.round!;
      container.hitIt();
      final scored = container.mission.score;

      // The web version's bug: for most of a second after a hit, the word
      // just found could be shot again for the same points.
      container.pilot.shoot(first.number, first.answer);
      expect(container.mission.score, scored);
      expect(container.mission.results, hasLength(1));

      time.elapse(MissionPace.afterHit);
      // A laser fired at round one, landing in round two.
      container.pilot.shoot(first.number, first.answer);
      expect(container.mission.score, scored);
      expect(container.mission.round!.number, 2);
      expect(container.mission.round!.live, isTrue);
    });
  });

  test('a wrong ship costs a shield and the streak, once - and the word '
      'keeps its clock', () {
    _fly((time, container, _) {
      time.elapse(MissionPace.countdown);
      container.hitIt();
      time.elapse(MissionPace.afterHit);
      expect(container.mission.streak, 1);

      container.missIt();
      final round = container.mission.round!;
      expect(container.mission.shields, MissionRules.shields - 1);
      expect(container.mission.streak, 0);
      expect(round.missed, hasLength(1));
      expect(round.live, isTrue);

      // The same ship again is no second penalty.
      container.pilot.shoot(round.number, round.missed.single);
      expect(container.mission.shields, MissionRules.shields - 1);

      time.elapse(MissionPace.answer);
      expect(container.mission.round!.outcome, RoundOutcome.timedOut);
    });
  });

  test('with its shields gone, the mission ends - and counts every word it '
      'had', () {
    _fly((time, container, records) {
      time.elapse(MissionPace.countdown);
      container.hitIt();
      time.elapse(MissionPace.afterHit);
      for (var i = 0; i < MissionRules.shields; i++) {
        container.missIt();
      }

      final wrecked = container.mission;
      expect(wrecked.round!.outcome, RoundOutcome.wrecked);
      expect(wrecked.wrecked, isTrue);
      expect(wrecked.phase, MissionPhase.playing, reason: 'a moment to see');
      expect(wrecked.results, hasLength(MissionPlan.words));
      expect(wrecked.found, 1);
      expect(wrecked.results.last.found, isFalse);

      time.elapse(MissionPace.afterWreck);
      expect(container.mission.phase, MissionPhase.over);
      expect(container.mission.stars, 0);
      time.flushMicrotasks();
      expect(records.submitted.single.$2.stars, 0);
    });
  });

  test('when time runs out, the answer is shown and the next word follows', () {
    _fly((time, container, _) {
      time.elapse(MissionPace.countdown);
      final first = container.mission.round!;

      time.elapse(MissionPace.answer);
      expect(container.mission.round!.outcome, RoundOutcome.timedOut);
      expect(container.mission.results.single.found, isFalse);
      expect(container.mission.results.single.pair, first.target);
      // Shooting it now is too late.
      container.pilot.shoot(first.number, first.answer);
      expect(container.mission.score, 0);

      time.elapse(MissionPace.afterTimeout);
      expect(container.mission.round!.number, 2);
    });
  });

  test('a hint lights the answer up for half its points, once a word', () {
    _fly((time, container, _) {
      time.elapse(MissionPace.countdown);
      container.pilot.hint();
      expect(container.mission.round!.hinted, isTrue);
      expect(container.mission.hints, MissionRules.hints - 1);

      container.pilot.hint();
      expect(container.mission.hints, MissionRules.hints - 1);

      container.hitIt();
      expect(container.mission.score, 50 + 50);
      expect(container.mission.results.single.hinted, isTrue);

      // Nothing to light up between words.
      container.pilot.hint();
      expect(container.mission.hints, MissionRules.hints - 1);
    });
  });

  test('hints run out', () {
    _fly((time, container, _) {
      time.elapse(MissionPace.countdown);
      for (var i = 0; i < MissionRules.hints; i++) {
        container
          ..pilot.hint()
          ..hitIt();
        time.elapse(MissionPace.afterHit);
      }
      expect(container.mission.hints, 0);
      container.pilot.hint();
      expect(container.mission.round!.hinted, isFalse);
    });
  });

  test('a pause holds every clock where it is', () {
    _fly((time, container, _) {
      // In the countdown...
      time.elapse(MissionPace.countdown ~/ 2);
      container.pilot.pause();
      expect(container.mission.phase, MissionPhase.paused);
      time.elapse(const Duration(minutes: 1));
      expect(container.mission.round, isNull);
      container.pilot.resume();
      expect(container.mission.phase, MissionPhase.countdown);
      time.elapse(MissionPace.countdown ~/ 2);
      expect(container.mission.round!.number, 1);

      // ...and in a word, whose time is held with it.
      time.elapse(const Duration(seconds: 5));
      container.pilot.pause();
      expect(container.mission.timeLeft, const Duration(seconds: 10));
      // Nothing lands while paused.
      container.hitIt();
      expect(container.mission.score, 0);
      time.elapse(const Duration(minutes: 1));
      expect(container.mission.round!.live, isTrue);

      container.pilot.resume();
      expect(container.mission.phase, MissionPhase.playing);
      expect(container.mission.timeLeft, const Duration(seconds: 10));
      time.elapse(const Duration(milliseconds: 9900));
      expect(container.mission.round!.live, isTrue);
      time.elapse(const Duration(milliseconds: 200));
      expect(container.mission.round!.outcome, RoundOutcome.timedOut);

      // Pausing or resuming twice is pausing or resuming once.
      container.pilot
        ..resume()
        ..pause()
        ..pause();
      expect(container.mission.phase, MissionPhase.paused);
    });
  });

  test('a new mission starts from the countdown, with new words', () {
    _fly((time, container, _) {
      time.elapse(MissionPace.countdown);
      container.hitIt();
      final first = container.mission.results.single.pair;

      container.pilot.restart();
      expect(container.mission.phase, MissionPhase.countdown);
      expect(container.mission.score, 0);
      expect(container.mission.results, isEmpty);
      expect(container.mission.shields, MissionRules.shields);
      time.elapse(MissionPace.countdown);
      expect(container.mission.round!.number, 1);
      expect(first, isNotNull);
    });
  });

  test('a mission knows the best it has to beat', () {
    _fly(
      (time, container, _) {
        expect(container.mission.previousBest, 400);
        time.elapse(MissionPace.countdown);
        while (container.mission.phase == MissionPhase.playing) {
          container.hitIt();
          time.elapse(MissionPace.afterHit);
        }
        expect(container.mission.score, greaterThan(400));
        expect(container.mission.newBest, isTrue);
      },
      best: {_deck: const DeckRecord(score: 400, stars: 1)},
    );
  });

  group('the rules', () {
    test('stars: three for nine in ten, two for seven, one for four', () {
      expect(
        [for (var n = 0; n <= 10; n++) MissionRules.stars(n, 10)],
        [0, 0, 0, 0, 1, 1, 1, 2, 2, 3, 3],
      );
      expect(MissionRules.stars(0, 0), 0);
    });

    test('the multiplier tops out at double', () {
      expect(
        [for (var n = 0; n <= 6; n++) MissionRules.multiplier(n)],
        [100, 125, 150, 175, 200, 200, 200],
      );
    });

    test('points fall with the time used, and halve with a hint', () {
      expect(
        MissionRules.points(left: MissionPace.answer, hinted: false, streak: 0),
        150,
      );
      expect(
        MissionRules.points(left: Duration.zero, hinted: false, streak: 0),
        100,
      );
      expect(
        MissionRules.points(left: Duration.zero, hinted: true, streak: 4),
        100,
      );
    });
  });
}
