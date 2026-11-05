import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_full_stack_flutter/core/audio/sound.dart';
import 'package:flutter_full_stack_flutter/core/pronunciation/gop_scorer.dart';
import 'package:flutter_full_stack_flutter/features/pronunciation/presentation/scenes/cat.dart';
import 'package:flutter_full_stack_flutter/features/pronunciation/presentation/score_band.dart';
import 'package:flutter_full_stack_flutter/features/pronunciation/providers/practice_controller.dart';
import 'package:flutter_full_stack_flutter/theme/motion.dart';
import 'package:flutter_full_stack_flutter/theme/passing.dart';

/// Decides when the black cat hiding in the scene comes out, and plays its
/// visit; the scene draws it (`IsoStage.catHideout`).
///
/// Every scene has the cat behind a bush, only its ears showing: an easter
/// egg to be found, not a mascot to be watched. It stays hidden, like
/// everything on this screen is still at rest - a cat that wandered about
/// would pull the eye off the sentence and cost a blur of the glass every
/// frame. It comes out only to answer the learner, for a moment: it washes
/// a paw when they have been looking at a prompt a while without starting
/// ([patience]), gives them a slow blink when an attempt goes badly, and
/// swishes its tail when one goes well. Speaking is the hard part of
/// learning a language, and the cat is there to make the hard moments a
/// little softer.
///
/// It is heard as it does each, softly and on the moment ([CatGesture.sounds]):
/// a meow as it starts to wash, a soft murmur through the blink, a trill as
/// it hops.
///
/// It never comes out while the microphone is open or the attempt is being
/// scored - then the sentence is the only thing that matters - and under
/// reduced motion it stays hidden, and so silent.
class HidingCat extends StatefulWidget {
  const HidingCat({
    required this.prompt,
    required this.stage,
    required this.builder,
    this.result,
    this.walks = false,
    this.onSound,
    super.key,
  });

  /// Which prompt is up, or `null` when there is no scene for the cat to
  /// hide in. It washes at most once per prompt.
  final Object? prompt;

  /// Where the attempt is.
  final PracticeStage? stage;

  /// The last attempt's score, which the cat answers once, when it arrives.
  final PronunciationResult? result;

  /// Builds the scene, which draws the cat where the pose says it is.
  final Widget Function(BuildContext context, Animation<CatPose> cat) builder;

  /// Whether, in the scene it hides in, it comes out on foot - which is
  /// what times its gesture, and so its sounds, through a visit.
  final bool walks;

  /// Plays what it says. `null` keeps it silent.
  final ValueChanged<Sound>? onSound;

  /// How long a learner may look at a prompt before the cat, unhurried,
  /// comes out to wash a paw.
  static const patience = Duration(seconds: 8);

  /// What the cat answers [result] with: a slow blink for an attempt below
  /// the line where an error starts, a swish for a strong one, and nothing
  /// in between - not every attempt needs a comment.
  static CatGesture? answerTo(PronunciationResult result) =>
      switch (ScoreBand.of(result.overall, result.errorThreshold)) {
        ScoreBand.weak => CatGesture.blink,
        ScoreBand.fair => null,
        ScoreBand.strong => CatGesture.swish,
      };

  @override
  State<HidingCat> createState() => _HidingCatState();
}

class _HidingCatState extends State<HidingCat>
    with SingleTickerProviderStateMixin {
  late final AnimationController _visit = AnimationController(vsync: this)
    ..addListener(_hear);
  late final _Pose _pose = _Pose(_visit);
  final Passing _passing = Passing();

  /// Plays what the cat says on the frame its visit reaches it. Sent back
  /// early - the learner started speaking - it goes quietly.
  void _hear() {
    final gesture = _pose.gesture;
    final due = _passing.passed(_visit, [
      for (final (g, sound) in gesture?.sounds ?? const <(double, Sound)>[])
        (CatPose.at(g, walks: widget.walks), sound),
    ]);
    final play = widget.onSound;
    if (play != null) due.forEach(play);
  }

  Timer? _patience;
  Object? _washedFor;

  bool get _listening => switch (widget.stage) {
    PracticeStage.recording || PracticeStage.scoring => true,
    _ => false,
  };

  void _come(CatGesture gesture) {
    if (widget.prompt == null || _listening || context.still) {
      return;
    }
    _pose.gesture = gesture;
    _visit
      ..duration = gesture.duration
      ..forward(from: 0);
  }

  /// Back behind the bush, at once, and no washing pending.
  void _hide() {
    _patience?.cancel();
    _patience = null;
    if (_visit.isAnimating) {
      _visit
        ..stop()
        ..value = 1;
    }
  }

  /// Starts counting the learner's pause, if they are on a prompt they have
  /// not started and the cat has not washed for yet.
  void _wait() {
    final waiting =
        widget.prompt != null &&
        widget.stage == PracticeStage.ready &&
        _washedFor != widget.prompt;
    if (!waiting) {
      _patience?.cancel();
      _patience = null;
      return;
    }
    _patience ??= Timer(HidingCat.patience, () {
      _patience = null;
      if (!mounted) return;
      _washedFor = widget.prompt;
      _come(CatGesture.lick);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _wait();
  }

  @override
  void didUpdateWidget(HidingCat old) {
    super.didUpdateWidget(old);
    if (old.prompt != widget.prompt || _listening) _hide();
    final result = widget.result;
    if (result != null && !identical(result, old.result)) {
      if (HidingCat.answerTo(result) case final gesture?) _come(gesture);
    }
    _wait();
  }

  @override
  void dispose() {
    _patience?.cancel();
    _visit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _pose);
}

/// The visit as a pose: out doing [gesture] while it plays, hidden once it
/// is over.
class _Pose extends Animation<CatPose> with AnimationWithParentMixin<double> {
  _Pose(this.parent);

  @override
  final AnimationController parent;

  CatGesture? gesture;

  @override
  CatPose get value =>
      parent.isAnimating ? CatPose(gesture, parent.value) : CatPose.hidden;
}
