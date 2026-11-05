import 'dart:async';
import 'dart:math' as math;

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_full_stack_flutter/features/word_hunt/providers/hunt_records.dart';
import 'package:flutter_full_stack_flutter/features/word_hunt/providers/word_bank.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'mission_controller.g.dart';

/// Where a mission's luck comes from: which words, in which order, among
/// which decoys. Overridden in tests with a seeded one.
@Riverpod(keepAlive: true)
math.Random missionRandom(Ref ref) => math.Random();

/// How long each part of a mission lasts.
abstract final class MissionPace {
  /// "3, 2, 1" before the first word.
  static const countdown = Duration(milliseconds: 2400);

  /// How long a word is asked for before its answer is shown. Generous: the
  /// time bonus is the pressure, not the clock running out.
  static const answer = Duration(seconds: 15);

  /// From the answer being hit to the next word: the explosion, the word
  /// read aloud, and the ships leaving.
  static const afterHit = Duration(milliseconds: 1700);

  /// From a word running out of time to the next one: long enough to read
  /// what the answer was.
  static const afterTimeout = Duration(milliseconds: 2600);

  /// From the last shield going to the results.
  static const afterWreck = Duration(milliseconds: 1600);
}

/// What a mission is worth, and what it costs.
abstract final class MissionRules {
  /// Wrong shots a ship can take before the mission ends.
  static const shields = 3;

  /// Hints per mission: each lights up the answer, for half its points.
  static const hints = 3;

  /// Points for finding a word, before the time bonus.
  static const base = 100;

  /// Points on top for finding it at once, falling to none at the deadline.
  static const timeBonus = 50;

  /// The score multiplier, in percent, after [streak] words found in a row:
  /// a quarter more for each, up to double.
  static int multiplier(int streak) => 100 + 25 * math.min(streak, 4);

  /// What finding a word is worth with [left] of its time to go.
  static int points({
    required Duration left,
    required bool hinted,
    required int streak,
  }) {
    final share = (left.inMicroseconds / MissionPace.answer.inMicroseconds)
        .clamp(0.0, 1.0);
    final raw = (hinted ? base ~/ 2 : base) + timeBonus * share;
    return (raw * multiplier(streak) / 100).round();
  }

  /// Stars for finding [found] of [total] words: three for nine in ten, two
  /// for seven, one for four.
  static int stars(int found, int total) {
    if (total == 0) return 0;
    final share = found / total;
    return share >= 0.9
        ? 3
        : share >= 0.7
        ? 2
        : share >= 0.4
        ? 1
        : 0;
  }
}

enum MissionPhase {
  /// "3, 2, 1": nothing to shoot at yet.
  countdown,

  /// A word is asked for, or the next one is on its way.
  playing,

  /// Stopped, with every clock held where it was.
  paused,

  /// Every word asked for, or every shield gone: the results.
  over,
}

/// How a round ended.
enum RoundOutcome {
  /// The answer was hit.
  hit,

  /// Its time ran out, and the answer is shown.
  timedOut,

  /// The last shield went on a wrong shot.
  wrecked,
}

/// One word asked for, and the ships it is hunted among.
@immutable
class Round {
  const Round({
    required this.number,
    required this.target,
    required this.choices,
    this.missed = const {},
    this.hinted = false,
    this.outcome,
  });

  /// `1` for the mission's first word.
  final int number;

  /// What is asked for: its Portuguese is the prompt, its English is on one
  /// of the ships.
  final WordPair target;

  /// What is on the ships, one per ship, in the order they fly in.
  final List<WordPair> choices;

  /// The ships shot that were not the answer: each cost a shield, and none
  /// can be shot again.
  final Set<int> missed;

  /// Whether a hint lit the answer up.
  final bool hinted;

  /// `null` while the word is still being hunted.
  final RoundOutcome? outcome;

  /// The answer's ship.
  int get answer => choices.indexOf(target);

  bool get live => outcome == null;

  Round _with({Set<int>? missed, bool? hinted, RoundOutcome? outcome}) => Round(
    number: number,
    target: target,
    choices: choices,
    missed: missed ?? this.missed,
    hinted: hinted ?? this.hinted,
    outcome: outcome ?? this.outcome,
  );
}

/// How one word of the mission went, for the results.
@immutable
class WordResult {
  const WordResult({
    required this.pair,
    required this.found,
    this.misses = 0,
    this.hinted = false,
    this.points = 0,
  });

  final WordPair pair;
  final bool found;

  /// Wrong ships shot while it was asked for.
  final int misses;
  final bool hinted;
  final int points;
}

@immutable
class MissionState {
  const MissionState({
    required this.deck,
    required this.phase,
    required this.total,
    this.round,
    this.score = 0,
    this.streak = 0,
    this.bestStreak = 0,
    this.shields = MissionRules.shields,
    this.hints = MissionRules.hints,
    this.results = const [],
    this.timeLeft = MissionPace.answer,
    this.previousBest,
  });

  final WordDeck deck;
  final MissionPhase phase;

  /// Words the mission asks for.
  final int total;

  /// The word being asked for, or the last one; `null` until the countdown
  /// is over.
  final Round? round;

  final int score;

  /// Words found in a row, up to now.
  final int streak;
  final int bestStreak;
  final int shields;
  final int hints;

  /// Every word done with, in the order it was asked - and, once the
  /// mission is over, every word it had, found or not.
  final List<WordResult> results;

  /// How long the round being hunted had to go when this state was made.
  /// While [phase] is [MissionPhase.playing] it counts down from there.
  final Duration timeLeft;

  /// The deck's best score before this mission, if it had one.
  final int? previousBest;

  int get found => results.where((result) => result.found).length;

  int get stars => MissionRules.stars(found, total);

  /// The multiplier, in percent, the next word found would score at.
  int get multiplier => MissionRules.multiplier(streak);

  bool get wrecked => shields == 0;

  /// Whether this mission beat the deck's best, once it is over.
  bool get newBest =>
      phase == MissionPhase.over && score > 0 && score > (previousBest ?? 0);

  MissionState _with({
    MissionPhase? phase,
    Round? round,
    int? score,
    int? streak,
    int? bestStreak,
    int? shields,
    int? hints,
    List<WordResult>? results,
    Duration? timeLeft,
  }) => MissionState(
    deck: deck,
    phase: phase ?? this.phase,
    total: total,
    round: round ?? this.round,
    score: score ?? this.score,
    streak: streak ?? this.streak,
    bestStreak: bestStreak ?? this.bestStreak,
    shields: shields ?? this.shields,
    hints: hints ?? this.hints,
    results: results ?? this.results,
    timeLeft: timeLeft ?? this.timeLeft,
    previousBest: previousBest,
  );
}

/// One mission on one deck, from its countdown to its results: which word is
/// asked for, which ships fly, what each shot is worth, and when the next
/// thing happens.
///
/// The ships, their lasers and explosions are only drawn by the screen; what
/// a shot *means* is decided here, once, when it lands ([shoot]). That is
/// what the web version got wrong in several ways at once: there, a hit
/// scored, and then for most of a second the word was still the one just
/// found, and the game - seeing no ship carry it - sent another, which could
/// be shot for the same points again. Here a round takes one answer, a
/// shot at a round that is over or at a ship already missed counts for
/// nothing, and the next word is chosen only once its predecessor is done.
///
/// Every clock - the countdown, a word's time, the pause before the next -
/// is one timer at a time, so pausing holds all of them, and disposing the
/// mission (leaving the screen) stops all of them.
@riverpod
class MissionController extends _$MissionController {
  late List<WordPair> _plan;
  late math.Random _random;

  Timer? _timer;
  void Function()? _then;
  DateTime _due = DateTime(0);

  /// What [_timer] had left when the mission was paused, and the phase to
  /// go back to.
  Duration _held = Duration.zero;
  MissionPhase _resumeTo = MissionPhase.playing;

  @override
  MissionState build(WordDeck deck) {
    _random = ref.watch(missionRandomProvider);
    _plan = MissionPlan.targets(deck, _random);
    ref.onDispose(() => _timer?.cancel());
    final best = ref.read(huntRecordsProvider).value?[deck]?.score;
    _after(MissionPace.countdown, () => _ask(0));
    return MissionState(
      deck: deck,
      phase: MissionPhase.countdown,
      total: _plan.length,
      previousBest: best,
    );
  }

  /// Lands a shot on ship [choice] of round [round]. A shot at a round that
  /// is over, at a ship already missed, or while paused counts for nothing:
  /// lasers fly for a moment, and the world can move on under them.
  void shoot(int round, int choice) {
    final current = state.round;
    if (state.phase != MissionPhase.playing ||
        current == null ||
        current.number != round ||
        !current.live ||
        choice < 0 ||
        choice >= current.choices.length ||
        current.missed.contains(choice)) {
      return;
    }

    if (choice == current.answer) {
      final points = MissionRules.points(
        left: _left,
        hinted: current.hinted,
        streak: state.streak,
      );
      final streak = state.streak + 1;
      state = state._with(
        round: current._with(outcome: RoundOutcome.hit),
        score: state.score + points,
        streak: streak,
        bestStreak: math.max(streak, state.bestStreak),
        results: [
          ...state.results,
          WordResult(
            pair: current.target,
            found: true,
            misses: current.missed.length,
            hinted: current.hinted,
            points: points,
          ),
        ],
      );
      _after(MissionPace.afterHit, _next);
      return;
    }

    final missed = current._with(missed: {...current.missed, choice});
    final shields = state.shields - 1;
    if (shields > 0) {
      // The word's clock keeps running: a miss is not a free retry.
      state = state._with(round: missed, shields: shields, streak: 0);
      return;
    }
    state = state._with(
      round: missed._with(outcome: RoundOutcome.wrecked),
      shields: 0,
      streak: 0,
      results: [
        ...state.results,
        WordResult(
          pair: current.target,
          found: false,
          misses: missed.missed.length,
          hinted: current.hinted,
        ),
        // The words never reached are part of the mission too: the results
        // show them, and they count against its stars.
        for (final pair in _plan.skip(state.results.length + 1))
          WordResult(pair: pair, found: false),
      ],
    );
    _after(MissionPace.afterWreck, _finish);
  }

  /// Lights the answer up, for half its points. Once per word, and only
  /// while there are hints left.
  void hint() {
    final current = state.round;
    if (state.phase != MissionPhase.playing ||
        current == null ||
        !current.live ||
        current.hinted ||
        state.hints == 0) {
      return;
    }
    state = state._with(
      round: current._with(hinted: true),
      hints: state.hints - 1,
    );
  }

  /// Holds every clock where it is. Nothing happens until [resume].
  void pause() {
    if (state.phase != MissionPhase.countdown &&
        state.phase != MissionPhase.playing) {
      return;
    }
    _held = _left;
    _resumeTo = state.phase;
    _timer?.cancel();
    _timer = null;
    state = state._with(
      phase: MissionPhase.paused,
      timeLeft: (state.round?.live ?? false) ? _held : null,
    );
  }

  void resume() {
    if (state.phase != MissionPhase.paused) return;
    final then = _then;
    if (then != null) _after(_held, then);
    state = state._with(
      phase: _resumeTo,
      timeLeft: (state.round?.live ?? false) ? _held : null,
    );
  }

  /// A new mission on the same deck: new words, from the countdown.
  void restart() => ref.invalidateSelf();

  /// How long the pending timer has to go - the word's time, while a word
  /// is being hunted.
  Duration get _left {
    if (_timer == null) return _held;
    final left = _due.difference(clock.now());
    return left.isNegative ? Duration.zero : left;
  }

  void _after(Duration delay, void Function() then) {
    _timer?.cancel();
    _then = then;
    _due = clock.now().add(delay);
    _timer = Timer(delay, () {
      _timer = null;
      _then = null;
      then();
    });
  }

  /// Asks for word [index] of the plan.
  void _ask(int index) {
    final target = _plan[index];
    final number = index + 1;
    state = state._with(
      phase: MissionPhase.playing,
      round: Round(
        number: number,
        target: target,
        choices: MissionPlan.choices(
          state.deck,
          target,
          MissionPlan.shipsIn(number) - 1,
          _random,
        ),
      ),
      timeLeft: MissionPace.answer,
    );
    _after(MissionPace.answer, _timeUp);
  }

  void _timeUp() {
    final current = state.round;
    if (current == null || !current.live) return;
    state = state._with(
      round: current._with(outcome: RoundOutcome.timedOut),
      streak: 0,
      results: [
        ...state.results,
        WordResult(
          pair: current.target,
          found: false,
          misses: current.missed.length,
          hinted: current.hinted,
        ),
      ],
    );
    _after(MissionPace.afterTimeout, _next);
  }

  void _next() {
    if (state.results.length >= _plan.length) {
      _finish();
    } else {
      _ask(state.results.length);
    }
  }

  void _finish() {
    state = state._with(phase: MissionPhase.over);
    unawaited(
      ref
          .read(huntRecordsProvider.notifier)
          .submit(
            state.deck,
            DeckRecord(score: state.score, stars: state.stars),
          ),
    );
  }
}
