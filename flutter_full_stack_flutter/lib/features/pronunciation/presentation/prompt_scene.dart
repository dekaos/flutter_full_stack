import 'package:flutter/material.dart';
import 'package:flutter_full_stack_flutter/core/pronunciation/lexicon.dart';
import 'package:flutter_full_stack_flutter/features/pronunciation/presentation/scenes/beach_scene.dart';
import 'package:flutter_full_stack_flutter/features/pronunciation/presentation/scenes/birds_scene.dart';
import 'package:flutter_full_stack_flutter/features/pronunciation/presentation/scenes/coffee_scene.dart';
import 'package:flutter_full_stack_flutter/features/pronunciation/presentation/scenes/help_scene.dart';
import 'package:flutter_full_stack_flutter/features/pronunciation/presentation/scenes/hotel_scene.dart';
import 'package:flutter_full_stack_flutter/features/pronunciation/presentation/scenes/iso_stage.dart';
import 'package:flutter_full_stack_flutter/features/pronunciation/presentation/scenes/thinking_scene.dart';
import 'package:flutter_full_stack_flutter/features/pronunciation/presentation/scenes/time_scene.dart';
import 'package:flutter_full_stack_flutter/features/pronunciation/presentation/scenes/traffic_scene.dart';
import 'package:flutter_full_stack_flutter/features/pronunciation/presentation/scenes/travel_scene.dart';
import 'package:flutter_full_stack_flutter/features/pronunciation/presentation/scenes/weather_scene.dart';
import 'package:flutter_full_stack_flutter/theme/app_tokens.dart';
import 'package:flutter_full_stack_flutter/theme/scene_tone.dart';

/// The world the prompt on screen describes, painted behind the whole page:
/// a small floating island in isometric view, in a sky of its own - a cottage
/// on a clear morning, a red car pulling up to the light, a clock tower whose
/// hand comes round to three.
///
/// It assembles itself when its prompt arrives - the island rises, things
/// drop onto it and spring up - and then holds still, for the same reason
/// `AuroraBackdrop` does: the deck sits on a `GlassSurface`, and a
/// `BackdropFilter` re-rasterises whatever moves behind it. Arrival is paid
/// once per prompt; a scene that kept moving would cost a blur every frame for
/// as long as the learner reads.
///
/// Every colour comes from the theme's [SceneTone], a band of lightness
/// derived from the text colours, so a scene can be as colourful as it likes
/// and the headline and the glass stay legible over it. Decoration and
/// nothing else: it takes no touches, has no semantics - the sentence is the
/// content, not its picture - and is absent under high contrast.
class PromptScene extends StatelessWidget {
  const PromptScene({
    required this.topic,
    this.clear = EdgeInsets.zero,
    super.key,
  });

  /// What to draw. `null` draws nothing and leaves the aurora on its own.
  final PromptTopic? topic;

  /// How much of the page, from each edge, its own controls cover. The sky
  /// runs under them; the island stands in the rest.
  final EdgeInsets clear;

  /// How long one scene takes to hand over to the next.
  static const fade = Duration(milliseconds: 450);

  /// How long a scene takes to assemble itself. Nothing moves after that.
  static const arrival = Duration(milliseconds: 2400);

  @override
  Widget build(BuildContext context) {
    final topic = this.topic;
    return IgnorePointer(
      child: AnimatedSwitcher(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : fade,
        // The default layout centres a loose stack. A backdrop has to fill.
        layoutBuilder: (current, previous) => Stack(
          fit: StackFit.expand,
          children: [...previous, ?current],
        ),
        child: topic == null
            ? const SizedBox.expand()
            : _Scene(key: ValueKey(topic), topic: topic, clear: clear),
      ),
    );
  }
}

class _Scene extends StatefulWidget {
  const _Scene({required this.topic, required this.clear, super.key});

  final PromptTopic topic;
  final EdgeInsets clear;

  @override
  State<_Scene> createState() => _SceneState();
}

class _SceneState extends State<_Scene> with SingleTickerProviderStateMixin {
  late final AnimationController _arrival = AnimationController(
    vsync: this,
    duration: PromptScene.arrival,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reduced motion gets the finished picture, with nothing travelling.
    if (MediaQuery.disableAnimationsOf(context)) {
      _arrival.value = 1;
    } else if (!_arrival.isAnimating && _arrival.value == 0) {
      _arrival.forward();
    }
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
        painter: _ScenePainter(
          topic: widget.topic,
          clear: widget.clear,
          arrival: _arrival,
          tone: tokens.sceneTone,
          world: tokens.worldTone,
          opacity: tokens.sceneOpacity,
        ),
      ),
    );
  }
}

class _ScenePainter extends CustomPainter {
  _ScenePainter({
    required this.topic,
    required this.clear,
    required this.arrival,
    required this.tone,
    required this.world,
    required this.opacity,
  }) : super(repaint: arrival);

  final PromptTopic topic;
  final EdgeInsets clear;
  final Animation<double> arrival;
  final SceneTone tone;
  final SceneTone world;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    if (opacity <= 0) return;

    // Exhaustive on purpose: a topic added to the enum without a scene is a
    // compile error here, not a prompt that silently shows nothing.
    final draw = switch (topic) {
      PromptTopic.weather => paintWeather,
      PromptTopic.thinking => paintThinking,
      PromptTopic.coffee => paintCoffee,
      PromptTopic.beach => paintBeach,
      PromptTopic.birds => paintBirds,
      PromptTopic.hotel => paintHotel,
      PromptTopic.help => paintHelp,
      PromptTopic.traffic => paintTraffic,
      PromptTopic.time => paintTime,
      PromptTopic.travel => paintTravel,
    };
    final stage = IsoStage(
      canvas,
      size,
      arrival.value,
      tone,
      clear: clear,
      world: world,
    );
    // Only while a theme change fades the scene out for high contrast.
    stage.faded(opacity, () => draw(stage));
  }

  @override
  bool shouldRepaint(_ScenePainter old) =>
      old.topic != topic ||
      old.clear != clear ||
      old.arrival != arrival ||
      old.tone != tone ||
      old.world != world ||
      old.opacity != opacity;
}
