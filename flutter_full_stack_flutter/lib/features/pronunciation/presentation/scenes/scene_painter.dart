import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_full_stack_flutter/features/pronunciation/presentation/scenes/cat.dart';
import 'package:flutter_full_stack_flutter/features/pronunciation/presentation/scenes/iso_stage.dart';
import 'package:flutter_full_stack_flutter/features/pronunciation/presentation/scenes/script.dart';
import 'package:flutter_full_stack_flutter/theme/scene_tone.dart';

/// Paints a [script] on an [IsoStage] at the moment [progress] has reached:
/// what every scene is drawn with, behind a prompt (`PromptScene`) and
/// behind a language's page in the chooser (`CountryScene`) alike.
///
/// Driven by `repaint:`, so a frame of a scene rebuilds no widget, and
/// [clear] keeps the island out from under whatever the page lays over the
/// scene.
class ScenePainter extends CustomPainter {
  ScenePainter({
    required this.script,
    required this.progress,
    required this.tone,
    required this.world,
    required this.haze,
    required this.opacity,
    this.clear = EdgeInsets.zero,
    this.centred = false,
    this.cat = const AlwaysStoppedAnimation(CatPose.hidden),
  }) : super(repaint: Listenable.merge([progress, cat]));

  final SceneScript script;
  final EdgeInsets clear;

  /// Whether the island stands in the middle of the clear stretch
  /// (`IsoStage.centred`).
  final bool centred;
  final Animation<double> progress;
  final Animation<CatPose> cat;
  final SceneTone tone;
  final SceneTone world;
  final Color haze;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    // Nothing to paint on - and a stage sized to nothing would have every
    // loop that steps across it by its unit never get anywhere.
    if (opacity <= 0 || size.isEmpty) return;
    final stage = IsoStage(
      canvas,
      size,
      progress.value,
      tone,
      clear: clear,
      centred: centred,
      world: world,
      haze: haze,
      cat: cat.value,
      catWalks: script.catWalks,
    );
    // Only while a theme change fades the scene out for high contrast.
    stage.faded(opacity, () => script.paint(stage));
  }

  @override
  bool shouldRepaint(ScenePainter old) =>
      old.script != script ||
      old.clear != clear ||
      old.centred != centred ||
      old.progress != progress ||
      old.cat != cat ||
      old.tone != tone ||
      old.world != world ||
      old.haze != haze ||
      old.opacity != opacity;
}
