import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Fades [child] in or out with [opacity] - without ever fading glass the
/// way that breaks it.
///
/// A `BackdropFilter` under an opacity layer blurs nothing: the layer is
/// drawn on its own, so the backdrop the filter sees is the layer's empty
/// canvas rather than the screen behind it. A `GlassSurface` faded in that
/// way shows as a clear, darkened pane for the whole fade, and then - on the
/// last frame, when the opacity reaches one and the layer goes away -
/// suddenly frosts. Every pane that rose in or switched did it.
///
/// So this fades its child as usual, unless there is glass in it. Glass
/// claims the reveal around it ([of]) and fades itself instead - its blur,
/// its tint and its content, all beneath the filter - and the reveal then
/// leaves the opacity to it. Put glass in a reveal of its own: anything
/// else in a reveal that glass has claimed stops fading with it.
class Reveal extends StatefulWidget {
  const Reveal({required this.opacity, required this.child, super.key});

  final Animation<double> opacity;
  final Widget child;

  /// For an `AnimatedSwitcher` over glass:
  /// `transitionBuilder: Reveal.transition`.
  static Widget transition(Widget child, Animation<double> animation) =>
      Reveal(opacity: animation, child: child);

  /// How far revealed [context] is, `0` to `1`, through every reveal around
  /// it - or `null` outside any. Glass calls this: it claims those reveals,
  /// so that none of them fades it with an opacity layer, and it rebuilds as
  /// the value changes.
  static Animation<double>? of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_RevealScope>();
    if (scope == null) return null;
    scope.owner._claim();
    return scope.notifier;
  }

  @override
  State<Reveal> createState() => _RevealState();
}

class _RevealState extends State<Reveal> {
  /// Whether glass in the subtree has taken the fading over.
  bool _claimed = false;
  _RevealState? _outer;

  void _claim() {
    _outer?._claim();
    if (_claimed) return;
    _claimed = true;
    // Found while the subtree builds, which is too late to change this
    // frame's tree above it. The first frame of a reveal is fully faded
    // out, so nothing is seen of it either way.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final outer = context.dependOnInheritedWidgetOfExactType<_RevealScope>();
    _outer = outer?.owner;
    final combined = outer == null
        ? widget.opacity
        : _Product(outer.notifier!, widget.opacity);
    // One shape whether or not glass has claimed it, so the subtree is kept
    // rather than rebuilt from scratch when it does; a fade held at one
    // draws no layer at all.
    return FadeTransition(
      opacity: _claimed ? kAlwaysCompleteAnimation : widget.opacity,
      child: _RevealScope(owner: this, notifier: combined, child: widget.child),
    );
  }
}

class _RevealScope extends InheritedNotifier<Animation<double>> {
  const _RevealScope({
    required this.owner,
    required super.notifier,
    required super.child,
  });

  final _RevealState owner;
}

/// Two fades at once: a reveal inside another.
class _Product extends CompoundAnimation<double> {
  _Product(Animation<double> outer, Animation<double> inner)
    : super(first: outer, next: inner);

  @override
  double get value => first.value * next.value;
}
