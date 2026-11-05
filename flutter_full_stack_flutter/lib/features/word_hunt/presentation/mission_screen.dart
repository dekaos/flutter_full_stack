import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_full_stack_flutter/core/audio/sound.dart';
import 'package:flutter_full_stack_flutter/features/pronunciation/providers/practice_audio.dart';
import 'package:flutter_full_stack_flutter/features/word_hunt/presentation/deck_look.dart';
import 'package:flutter_full_stack_flutter/features/word_hunt/presentation/hunt_theme.dart';
import 'package:flutter_full_stack_flutter/features/word_hunt/presentation/mission_panels.dart';
import 'package:flutter_full_stack_flutter/features/word_hunt/presentation/space/space_view.dart';
import 'package:flutter_full_stack_flutter/features/word_hunt/presentation/space/space_world.dart';
import 'package:flutter_full_stack_flutter/features/word_hunt/providers/mission_controller.dart';
import 'package:flutter_full_stack_flutter/features/word_hunt/providers/word_bank.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// A mission on one deck: the word asked for at the top, the ships carrying
/// English words in the middle, the learner's rocket at the bottom. Tap the
/// ship whose word is the one asked for.
///
/// Mobile first: everything is played with one thumb - a tap on a ship
/// fires at it, the hint is a thumb's reach from the bottom corner - and
/// the play area is whatever the panels leave, upright or on its side.
///
/// The screen decides nothing. It shows what [MissionController] says has
/// happened - by telling the [SpaceWorld] to fly a wave in, explode a ship,
/// shield one - and plays the sounds that go with it; and when a laser
/// lands, it hands the shot to the controller to be judged.
class MissionScreen extends ConsumerStatefulWidget {
  const MissionScreen({required this.deck, super.key});

  final WordDeck deck;

  /// How long after the answer is hit its word is read aloud: once the
  /// explosion's sparkle has rung, which the reading would otherwise cut.
  static const readAfter = Duration(milliseconds: 450);

  @override
  ConsumerState<MissionScreen> createState() => _MissionScreenState();
}

class _MissionScreenState extends ConsumerState<MissionScreen>
    with WidgetsBindingObserver {
  late final SpaceWorld _world = SpaceWorld(
    palette: widget.deck.palette,
    seed: widget.deck.index + 1,
  )..onImpact = _land;

  double _hud = 0;
  Timer? _reading;

  MissionControllerProvider get _mission =>
      missionControllerProvider(widget.deck);

  MissionController get _controller => ref.read(_mission.notifier);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // A call, the home button, the notification shade: the clocks stop.
    if (state != AppLifecycleState.resumed) _controller.pause();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _reading?.cancel();
    _world.dispose();
    super.dispose();
  }

  /// A laser reached ship [index] of round [round]: the mission judges it.
  void _land(int round, int index) => _controller.shoot(round, index);

  /// The learner tapped ship [index]: fire, if there is anything to fire at.
  void _aim(int index) {
    final state = ref.read(_mission);
    final round = state.round;
    if (state.phase != MissionPhase.playing ||
        round == null ||
        !round.live ||
        round.missed.contains(index)) {
      return;
    }
    if (_world.fire(index)) {
      ref.read(soundBoardProvider).play(Sound.laser);
      HapticFeedback.selectionClick().ignore();
    }
  }

  /// Shows what changed between [before] and [now].
  void _show(MissionState? before, MissionState now) {
    final board = ref.read(soundBoardProvider);
    final was = before?.round;
    final round = now.round;

    if (round != null && round.number != was?.number) {
      // A new word: its ships fly in, and whatever was here leaves.
      _world.launch(round.number, [
        for (final choice in round.choices)
          (label: choice.en, meaning: choice.pt),
      ], pace: now.total > 1 ? (round.number - 1) / (now.total - 1) : 0);
      board.play(Sound.warp);
    } else if (round != null && was != null) {
      for (final index in round.missed.difference(was.missed)) {
        _world.miss(index);
        board.play(Sound.bonk);
        HapticFeedback.heavyImpact().ignore();
      }
      if (round.hinted && !was.hinted) {
        _world.hint(round.answer);
        board.play(Sound.sparkle);
      }
      if (was.live && !round.live) {
        switch (round.outcome!) {
          case RoundOutcome.hit:
            _world.hit(round.answer, now.results.last.points);
            board.play(Sound.burst);
            HapticFeedback.mediumImpact().ignore();
            // The word, said as it should be: what the learner takes away.
            _reading?.cancel();
            _reading = Timer(
              MissionScreen.readAfter,
              () => unawaited(board.say(round.target.en, lang: 'en')),
            );
          case RoundOutcome.timedOut:
            _world.reveal(round.answer);
            board.play(Sound.scoreWeak);
          case RoundOutcome.wrecked:
            _world.reveal(round.answer);
        }
      }
    }

    if (now.phase != before?.phase) {
      if (now.phase == MissionPhase.countdown) _world.depart();
      if (now.phase == MissionPhase.over) {
        _world.depart();
        board.play(switch (now.stars) {
          3 => Sound.fanfare,
          2 => Sound.scoreStrong,
          1 => Sound.scoreFair,
          _ => Sound.scoreWeak,
        });
      }
    }
  }

  void _themes() => context.goNamed('wordHunt');

  @override
  Widget build(BuildContext context) {
    ref.listen(_mission, _show);
    final state = ref.watch(_mission);
    final board = ref.watch(soundBoardProvider);
    final speaks = ref.watch(phraseVoiceAvailableProvider('en')).value ?? false;

    return HuntTheme(
      child: Builder(
        builder: (context) {
          final media = MediaQuery.of(context);
          final size = media.size;
          final padding = media.padding;
          // A phone on its side has no height to spare above the ships, so
          // the panel goes to the side instead.
          final side = size.width > size.height * 1.25 && size.height < 600;
          final panel = side ? math.min<double>(320, size.width * 0.38) : 0.0;
          final rocket = side
              ? math.max<double>(96, size.height * 0.24)
              : math.max<double>(128, size.height * 0.19);
          final clear = side
              ? EdgeInsets.only(
                  left: padding.left + panel + 16,
                  right: padding.right,
                  top: padding.top + 8,
                  bottom: padding.bottom + rocket,
                )
              : EdgeInsets.only(
                  top: padding.top + _hud + 10,
                  bottom: padding.bottom + rocket,
                );
          final round = state.round;
          final hud = Measured(
            onSize: (measured) {
              if (!side && measured.height != _hud) {
                setState(() => _hud = measured.height);
              }
            },
            child: MissionHud(state: state, onPause: _controller.pause),
          );

          return PopScope(
            // Back pauses: leaving mid-word by accident would lose the
            // mission. The pause panel has the way out.
            canPop: state.phase == MissionPhase.over,
            onPopInvokedWithResult: (popped, _) {
              if (!popped) _controller.pause();
            },
            child: Scaffold(
              backgroundColor: Theme.of(context).colorScheme.surface,
              body: Stack(
                fit: StackFit.expand,
                children: [
                  SpaceView(
                    world: _world,
                    clear: clear,
                    running: state.phase != MissionPhase.paused,
                    onShip: _aim,
                  ),
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                      child: side
                          ? Align(
                              alignment: Alignment.topLeft,
                              child: SizedBox(
                                width: panel,
                                child: SingleChildScrollView(child: hud),
                              ),
                            )
                          : Column(children: [hud, const Spacer()]),
                    ),
                  ),
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (media.accessibleNavigation &&
                              round != null &&
                              round.live &&
                              state.phase == MissionPhase.playing)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: SizedBox(
                                width: double.infinity,
                                child: ChoiceBar(round: round, onChoose: _aim),
                              ),
                            ),
                          if (state.phase != MissionPhase.over)
                            HintButton(state: state, onHint: _controller.hint),
                        ],
                      ),
                    ),
                  ),
                  if (round == null && state.phase != MissionPhase.over)
                    CountdownOverlay(
                      state: state,
                      onBeat: (beat) {
                        if (beat > 0) {
                          board.play(CountdownOverlay.soundOf(beat));
                        }
                      },
                    ),
                  if (state.phase == MissionPhase.paused)
                    PausePanel(
                      onResume: _controller.resume,
                      onQuit: _themes,
                    ),
                  if (state.phase == MissionPhase.over)
                    ResultsPanel(
                      state: state,
                      onAgain: _controller.restart,
                      onThemes: _themes,
                      onHear: speaks
                          ? (word) => unawaited(board.say(word, lang: 'en'))
                          : null,
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
