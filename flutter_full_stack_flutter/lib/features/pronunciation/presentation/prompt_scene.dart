import 'package:flutter/material.dart';
import 'package:flutter_full_stack_flutter/core/audio/sound.dart';
import 'package:flutter_full_stack_flutter/core/pronunciation/lexicon.dart';
import 'package:flutter_full_stack_flutter/features/pronunciation/presentation/scenes/beach_scene.dart';
import 'package:flutter_full_stack_flutter/features/pronunciation/presentation/scenes/birds_scene.dart';
import 'package:flutter_full_stack_flutter/features/pronunciation/presentation/scenes/cat.dart';
import 'package:flutter_full_stack_flutter/features/pronunciation/presentation/scenes/coffee_scene.dart';
import 'package:flutter_full_stack_flutter/features/pronunciation/presentation/scenes/help_scene.dart';
import 'package:flutter_full_stack_flutter/features/pronunciation/presentation/scenes/hotel_scene.dart';
import 'package:flutter_full_stack_flutter/features/pronunciation/presentation/scenes/iso_stage.dart';
import 'package:flutter_full_stack_flutter/features/pronunciation/presentation/scenes/scene_painter.dart';
import 'package:flutter_full_stack_flutter/features/pronunciation/presentation/scenes/script.dart';
import 'package:flutter_full_stack_flutter/features/pronunciation/presentation/scenes/thinking_scene.dart';
import 'package:flutter_full_stack_flutter/features/pronunciation/presentation/scenes/time_scene.dart';
import 'package:flutter_full_stack_flutter/features/pronunciation/presentation/scenes/traffic_scene.dart';
import 'package:flutter_full_stack_flutter/features/pronunciation/presentation/scenes/travel_scene.dart';
import 'package:flutter_full_stack_flutter/features/pronunciation/presentation/scenes/weather_scene.dart';
import 'package:flutter_full_stack_flutter/theme/app_tokens.dart';
import 'package:flutter_full_stack_flutter/theme/motion.dart';
import 'package:flutter_full_stack_flutter/theme/passing.dart';
import 'package:flutter_full_stack_flutter/theme/scene_tone.dart';

/// The world the prompt on screen describes, painted behind the whole page:
/// a small floating island in isometric view, in a sky of its own - a cottage
/// on a clear morning, a red car pulling up to the light, a clock tower whose
/// hand comes round to three.
///
/// It plays in two acts (see [Act]). The world assembles itself, quickly -
/// the island rises, things drop onto it and spring up - and then the
/// sentence is acted out on its own, in a light that leaves the rest of the
/// island in the shade: the car drives in, the light turns red, the car
/// stops. The light is what points the learner at what the sentence says;
/// the card is left alone, because colour on its words means how they were
/// said.
///
/// Then it holds still, for the same reason `AuroraBackdrop` does: the deck
/// sits on a `GlassSurface`, and a `BackdropFilter` re-rasterises whatever
/// moves behind it. Arrival is paid once per prompt; a scene that kept moving
/// would cost a blur every frame for as long as the learner reads.
///
/// It is heard the same way it moves: a few sounds while the story is told,
/// each on the beat it belongs to - the clock's bell as it strikes, a cup
/// as it lands - and nothing once it is at rest ([SceneScript.sounds]).
/// Under reduced motion the story is not played, so it is not heard either.
///
/// Every colour comes from the theme's [SceneTone], a band of lightness
/// derived from the text colours, so a scene can be as colourful as it likes
/// and the text on the glass stays legible over it. Decoration and nothing
/// else: it takes no touches, has no semantics - the sentence is the
/// content, not its picture - and is absent under high contrast.
class PromptScene extends StatelessWidget {
  const PromptScene({
    required this.topic,
    this.clear = EdgeInsets.zero,
    this.cat = const AlwaysStoppedAnimation(CatPose.hidden),
    this.onSound,
    super.key,
  });

  /// What to draw. `null` draws nothing and leaves the aurora on its own.
  final PromptTopic? topic;

  /// Where the black cat hiding in every scene is - see `HidingCat`.
  final Animation<CatPose> cat;

  /// How much of the page, from each edge, its own controls cover. The sky
  /// runs under them; the island stands in the rest.
  final EdgeInsets clear;

  /// Plays a sound the story makes as it is told. `null` keeps it silent.
  final ValueChanged<Sound>? onSound;

  /// How long one scene takes to hand over to the next.
  static const fade = Duration(milliseconds: 450);

  /// How long both acts take, together. Nothing moves after that.
  static const arrival = Duration(milliseconds: 3600);

  /// The scene for [topic], and the story it tells.
  static SceneScript scriptOf(PromptTopic topic) =>
      // Exhaustive on purpose: a topic added to the enum without a scene is
      // a compile error here, not a prompt that silently shows nothing.
      switch (topic) {
        PromptTopic.weather => weatherScene,
        PromptTopic.thinking => thinkingScene,
        PromptTopic.coffee => coffeeScene,
        PromptTopic.beach => beachScene,
        PromptTopic.birds => birdsScene,
        PromptTopic.hotel => hotelScene,
        PromptTopic.help => helpScene,
        PromptTopic.traffic => trafficScene,
        PromptTopic.time => timeScene,
        PromptTopic.travel => travelScene,
      };

  @override
  Widget build(BuildContext context) {
    final topic = this.topic;
    return IgnorePointer(
      child: AnimatedSwitcher(
        duration: context.motion(fade),
        // The default layout centres a loose stack. A backdrop has to fill.
        layoutBuilder: (current, previous) => Stack(
          fit: StackFit.expand,
          children: [...previous, ?current],
        ),
        child: topic == null
            ? const SizedBox.expand()
            : _Scene(
                key: ValueKey(topic),
                topic: topic,
                clear: clear,
                cat: cat,
                onSound: onSound,
              ),
      ),
    );
  }
}

class _Scene extends StatefulWidget {
  const _Scene({
    required this.topic,
    required this.clear,
    required this.cat,
    this.onSound,
    super.key,
  });

  final PromptTopic topic;
  final EdgeInsets clear;
  final Animation<CatPose> cat;
  final ValueChanged<Sound>? onSound;

  @override
  State<_Scene> createState() => _SceneState();
}

class _SceneState extends State<_Scene> with SingleTickerProviderStateMixin {
  late final AnimationController _arrival = AnimationController(
    vsync: this,
    duration: PromptScene.arrival,
  )..addListener(_hear);
  final Passing _passing = Passing();

  /// Plays each of the story's sounds on the frame the arrival reaches it -
  /// and none of them under reduced motion, where the story is not played.
  void _hear() {
    final due = _passing.passed(
      _arrival,
      PromptScene.scriptOf(widget.topic).soundsIn(PromptScene.arrival),
    );
    final play = widget.onSound;
    if (play != null) due.forEach(play);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reduced motion gets the story already told, with nothing travelling.
    context.playOnce(_arrival);
  }

  @override
  void dispose() {
    _arrival.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).appTokens;
    // Isolated so a scene assembling itself cannot drag the deck into its
    // repaints, and driven by `repaint:` so a frame of it rebuilds nothing.
    // At rest it is one unchanging picture, which is what `isComplex` tells
    // the engine it may cache.
    return RepaintBoundary(
      child: CustomPaint(
        isComplex: true,
        painter: ScenePainter(
          script: PromptScene.scriptOf(widget.topic),
          clear: widget.clear,
          progress: _arrival,
          cat: widget.cat,
          tone: tokens.sceneTone,
          world: tokens.worldTone,
          haze: Theme.of(context).colorScheme.surface,
          opacity: tokens.sceneOpacity,
        ),
      ),
    );
  }
}
