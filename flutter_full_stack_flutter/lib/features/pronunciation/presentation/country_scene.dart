import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_full_stack_flutter/core/audio/sound.dart';
import 'package:flutter_full_stack_flutter/features/pronunciation/presentation/prompt_scene.dart';
import 'package:flutter_full_stack_flutter/features/pronunciation/presentation/scenes/iso_stage.dart';
import 'package:flutter_full_stack_flutter/features/pronunciation/presentation/scenes/new_york_scene.dart';
import 'package:flutter_full_stack_flutter/features/pronunciation/presentation/scenes/scene_painter.dart';
import 'package:flutter_full_stack_flutter/features/pronunciation/presentation/scenes/script.dart';
import 'package:flutter_full_stack_flutter/features/pronunciation/presentation/scenes/seville_scene.dart';
import 'package:flutter_full_stack_flutter/features/pronunciation/presentation/scenes/temple_bell_scene.dart';
import 'package:flutter_full_stack_flutter/theme/app_tokens.dart';
import 'package:flutter_full_stack_flutter/theme/motion.dart';
import 'package:flutter_full_stack_flutter/theme/passing.dart';

/// A picturesque place in a country where a language is spoken, filling the
/// chooser's page for that language: the Statue of Liberty in New York's
/// harbour sending up a firework from her torch, a flamenco dancer
/// spinning in Seville's Plaza de España, a temple bell struck under cherry
/// blossom in Seoul.
///
/// Made the way the prompts' scenes are (`PromptScene`): a floating island in
/// isometric view that assembles itself and tells one short story, in the
/// same two acts and the same time, heard on its beats
/// ([SceneScript.sounds]) - and then holds still, since glass sits over it
/// and a picture that kept moving would cost a blur every frame.
///
/// It waits until it is [shown] - its page come into view, if only at the
/// edge of a swipe - and then arrives, after [delay]: the island rises as
/// the learner swipes towards it. It is only [heard] while its page is the
/// one in view, so a page only peeked at is never heard from the next one;
/// and each time its page is brought back into view it tells its story
/// again, over the world as it is - the place answering the visit. Under
/// reduced motion the story is not told, so it is not heard either: the
/// place is simply there, finished.
///
/// Painted in the world's band of colour, sky included - a place to go to
/// should look like one - so whatever is read over it brings its own scrim
/// (the chooser's headline does). Decoration: it has no semantics, and is
/// gone under high contrast.
class CountryScene extends StatefulWidget {
  const CountryScene({
    required this.script,
    this.shown = true,
    this.heard = true,
    this.delay = Duration.zero,
    this.clear = EdgeInsets.zero,
    this.onSound,
    super.key,
  });

  /// The place, and the story told in it.
  final SceneScript script;

  /// Whether its page has come into view at all: from then on it arrives.
  final bool shown;

  /// Whether its page is the one in view: only then is it heard.
  final bool heard;

  /// How long to wait, once [shown], before it starts to assemble.
  final Duration delay;

  /// How much of it, from each edge, the page covers with its own things:
  /// the island stands whole in what is left.
  final EdgeInsets clear;

  /// Plays a sound the story makes. `null` keeps it silent.
  final ValueChanged<Sound>? onSound;

  /// The place for [lang], or `null` for a language without one.
  static SceneScript? of(String lang) => switch (lang) {
    'en' => newYorkScene,
    'es' => sevilleScene,
    'ko' => templeBellScene,
    _ => null,
  };

  @override
  State<CountryScene> createState() => _CountrySceneState();
}

class _CountrySceneState extends State<CountryScene>
    with SingleTickerProviderStateMixin {
  late final AnimationController _arrival = AnimationController(
    vsync: this,
    duration: PromptScene.arrival,
  )..addListener(_hear);
  Passing _passing = Passing();
  Timer? _start;
  bool _still = false;

  /// Plays each of the story's sounds on the frame the arrival reaches it.
  void _hear() {
    final due = _passing.passed(
      _arrival,
      widget.script.soundsIn(PromptScene.arrival),
    );
    final play = widget.onSound;
    if (play != null && widget.heard) due.forEach(play);
  }

  /// Tells the story again, from its first beat, over the world as it
  /// stands. Asked before the story has begun, it only makes sure the
  /// place is on its way.
  void _again() {
    if (_still) return;
    if (_arrival.value < Act.setting) {
      // On its way already - running, or waiting out its delay.
      if (!_arrival.isAnimating && !(_start?.isActive ?? false)) {
        _arrival.forward().ignore();
      }
      return;
    }
    _passing = Passing();
    _arrival.forward(from: Act.setting).ignore();
  }

  @override
  void didUpdateWidget(CountryScene old) {
    super.didUpdateWidget(old);
    if (widget.shown && !old.shown) _arrive();
    if (widget.heard && !old.heard) _again();
  }

  /// Starts the arrival after [CountryScene.delay], if it has not started.
  void _arrive() {
    if (_still || _start != null || _arrival.value > 0) return;
    _start = Timer(widget.delay, () => _arrival.forward().ignore());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _still = context.still;
    if (_still) {
      // The finished place, with nothing travelling and nothing heard.
      _start?.cancel();
      _arrival.value = 1;
      return;
    }
    if (widget.shown) _arrive();
  }

  @override
  void dispose() {
    _start?.cancel();
    _arrival.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.appTokens;
    return ExcludeSemantics(
      // Isolated so a place assembling itself repaints nothing round it,
      // and cached once it is still.
      child: RepaintBoundary(
        child: CustomPaint(
          isComplex: true,
          size: Size.infinite,
          painter: ScenePainter(
            script: widget.script,
            progress: _arrival,
            clear: widget.clear,
            // The place is what its page is about: in the middle of it.
            centred: true,
            tone: tokens.worldTone,
            world: tokens.worldTone,
            haze: theme.colorScheme.surface,
            opacity: tokens.sceneOpacity,
          ),
        ),
      ),
    );
  }
}
