import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_full_stack_flutter/app/app_bar_actions.dart';
import 'package:flutter_full_stack_flutter/core/audio/sound.dart';
import 'package:flutter_full_stack_flutter/features/word_hunt/presentation/deck_look.dart';
import 'package:flutter_full_stack_flutter/features/word_hunt/presentation/hunt_theme.dart';
import 'package:flutter_full_stack_flutter/features/word_hunt/providers/mission_controller.dart';
import 'package:flutter_full_stack_flutter/l10n/app_localizations.dart';
import 'package:flutter_full_stack_flutter/theme/app_tokens.dart';
import 'package:flutter_full_stack_flutter/theme/motion.dart';
import 'package:intl/intl.dart';

/// A pane the mission's text sits on: frosted-dense, but without a blur.
/// The space behind it moves every frame, and a `BackdropFilter` over a
/// moving scene is a blur of the whole pane every frame, for the life of
/// the mission.
class HuntPanel extends StatelessWidget {
  const HuntPanel({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.accent,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  /// An edge in this colour instead of the glass's own.
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.appTokens;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.glassDense,
        borderRadius: BorderRadius.circular(tokens.radiusLarge),
        border: Border.all(
          color: accent ?? tokens.glassBorder,
          width: accent == null ? 1 : 1.6,
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withValues(alpha: 0.3),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

String _number(BuildContext context, int value) => NumberFormat.decimalPattern(
  Localizations.localeOf(context).toLanguageTag(),
).format(value);

// ------------------------------------------------------------------ HUD --

/// What is always on screen while a mission is flown: the way to pause,
/// how far through it is, the shields left, and the word asked for.
class MissionHud extends StatelessWidget {
  const MissionHud({required this.state, required this.onPause, super.key});

  final MissionState state;
  final VoidCallback onPause;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton.filledTonal(
              key: const Key('hunt-pause'),
              onPressed: state.phase == MissionPhase.over ? null : onPause,
              icon: const Icon(Icons.pause_rounded),
              tooltip: l10n.huntPause,
            ),
            const SizedBox(width: 12),
            Expanded(child: _Progress(state: state)),
            const SizedBox(width: 12),
            _Shields(count: state.shields),
          ],
        ),
        const SizedBox(height: 10),
        PromptCard(state: state),
      ],
    );
  }
}

/// One mark per word of the mission: gold for found, dim for missed, the
/// one being hunted lit up.
class _Progress extends StatelessWidget {
  const _Progress({required this.state});

  final MissionState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final current = state.round?.number ?? 0;
    return Semantics(
      label: l10n.huntWordOf(math.max(current, 1), state.total),
      child: ExcludeSemantics(
        child: Row(
          children: [
            for (var i = 0; i < state.total; i++)
              Expanded(
                child: AnimatedContainer(
                  duration: context.motion(const Duration(milliseconds: 300)),
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: i < state.results.length
                        ? state.results[i].found
                              ? HuntColours.gold
                              : scheme.error.withValues(alpha: 0.6)
                        : i == current - 1
                        ? scheme.onSurface
                        : scheme.onSurface.withValues(alpha: 0.18),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Shields extends StatelessWidget {
  const _Shields({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final lost = Theme.of(context).colorScheme.onSurface.withValues(
      alpha: 0.22,
    );
    return Semantics(
      label: l10n.huntShields(count),
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < MissionRules.shields; i++)
              // The shield going is a little pop, so it is seen go.
              TweenAnimationBuilder<double>(
                key: ValueKey('shield-$i-${i < count}'),
                tween: Tween(begin: i < count ? 1 : 1.5, end: 1),
                duration: context.motion(const Duration(milliseconds: 380)),
                curve: Curves.easeOutBack,
                builder: (context, scale, child) =>
                    Transform.scale(scale: scale, child: child),
                child: Icon(
                  i < count ? Icons.shield_rounded : Icons.shield_outlined,
                  size: 24,
                  color: i < count ? HuntColours.shield : lost,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The word asked for, in Portuguese, the score beside it, and the time
/// left under it.
class PromptCard extends StatelessWidget {
  const PromptCard({required this.state, super.key});

  final MissionState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final round = state.round;
    final missed =
        round != null && !round.live && round.outcome != RoundOutcome.hit;
    final found = round != null && round.outcome == RoundOutcome.hit;
    return HuntPanel(
      accent: found ? HuntColours.gold : null,
      padding: const EdgeInsets.fromLTRB(18, 12, 16, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      round == null
                          ? state.deck.title(l10n)
                          : missed
                          ? l10n.huntAnswerWas
                          : l10n.huntFind,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    AnimatedSwitcher(
                      duration: context.motion(
                        const Duration(milliseconds: 260),
                      ),
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: ScaleTransition(
                          scale: Tween<double>(
                            begin: 0.9,
                            end: 1,
                          ).animate(animation),
                          alignment: Alignment.centerLeft,
                          child: child,
                        ),
                      ),
                      layoutBuilder: (current, previous) => Stack(
                        alignment: Alignment.centerLeft,
                        children: [...previous, ?current],
                      ),
                      child: Text(
                        round?.target.pt ?? l10n.huntReady,
                        key: ValueKey(round?.number ?? 0),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                    if (missed)
                      Text(
                        round.target.en,
                        key: const Key('hunt-answer'),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: HuntColours.gold,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _Score(state: state),
            ],
          ),
          const SizedBox(height: 10),
          TimeBar(state: state),
        ],
      ),
    );
  }
}

class _Score extends StatelessWidget {
  const _Score({required this.state});

  final MissionState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          l10n.huntScore,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        // Counting up to it, so a hit is seen to add up.
        TweenAnimationBuilder<double>(
          tween: Tween(end: state.score.toDouble()),
          duration: context.motion(const Duration(milliseconds: 650)),
          curve: Curves.easeOutCubic,
          builder: (context, value, _) => Text(
            _number(context, value.round()),
            key: const Key('hunt-score'),
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: theme.colorScheme.onSurface,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        AnimatedSwitcher(
          duration: context.motion(const Duration(milliseconds: 220)),
          child: state.streak > 0
              ? Container(
                  key: ValueKey(state.multiplier),
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: HuntColours.gold),
                    color: HuntColours.gold.withValues(alpha: 0.14),
                  ),
                  child: Text(
                    l10n.huntCombo(state.multiplier / 100),
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: HuntColours.gold,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

/// The time left on the word: a bar draining from the deck's colour to
/// amber to red. It only shows the mission's clock - the mission decides
/// when time is up.
class TimeBar extends StatefulWidget {
  const TimeBar({required this.state, super.key});

  final MissionState state;

  @override
  State<TimeBar> createState() => _TimeBarState();
}

class _TimeBarState extends State<TimeBar> with SingleTickerProviderStateMixin {
  late final AnimationController _left = AnimationController(
    vsync: this,
    value: 1,
  );

  @override
  void initState() {
    super.initState();
    _follow();
  }

  @override
  void didUpdateWidget(TimeBar old) {
    super.didUpdateWidget(old);
    final was = old.state;
    final now = widget.state;
    if (was.round?.number != now.round?.number ||
        was.phase != now.phase ||
        was.round?.live != now.round?.live ||
        was.timeLeft != now.timeLeft) {
      _follow();
    }
  }

  void _follow() {
    final state = widget.state;
    final round = state.round;
    final answer = MissionPace.answer.inMicroseconds;
    if (round == null) {
      _left.value = 1;
      return;
    }
    if (!round.live) {
      _left.stop();
      return;
    }
    _left.value = state.timeLeft.inMicroseconds / answer;
    if (state.phase == MissionPhase.playing) {
      _left.animateTo(0, duration: state.timeLeft).ignore();
    } else {
      _left.stop();
    }
  }

  @override
  void dispose() {
    _left.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = widget.state.deck.accent;
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        height: 6,
        child: AnimatedBuilder(
          animation: _left,
          builder: (context, _) {
            final left = _left.value;
            final colour = left > 0.5
                ? accent
                : left > 0.22
                ? Color.lerp(HuntColours.gold, accent, (left - 0.22) / 0.28)!
                : Color.lerp(scheme.error, HuntColours.gold, left / 0.22)!;
            return Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(color: scheme.onSurface.withValues(alpha: 0.12)),
                FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: left.clamp(0.0, 1.0),
                  child: ColoredBox(color: colour),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ------------------------------------------------------------ controls --

class HintButton extends StatelessWidget {
  const HintButton({required this.state, required this.onHint, super.key});

  final MissionState state;
  final VoidCallback onHint;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final round = state.round;
    final usable =
        state.phase == MissionPhase.playing &&
        round != null &&
        round.live &&
        !round.hinted &&
        state.hints > 0;
    return Tooltip(
      message: l10n.huntHintsLeft(state.hints),
      child: Badge.count(
        count: state.hints,
        isLabelVisible: state.hints > 0,
        backgroundColor: HuntColours.gold,
        textColor: theme.colorScheme.surface,
        child: FilledButton.tonalIcon(
          key: const Key('hunt-hint'),
          onPressed: usable ? onHint : null,
          icon: const Icon(Icons.lightbulb_rounded),
          label: Text(l10n.huntHint),
          style: FilledButton.styleFrom(
            minimumSize: const Size(48, 48),
            padding: const EdgeInsets.symmetric(horizontal: 18),
          ),
        ),
      ),
    );
  }
}

/// The ships as a row of buttons, for a learner using a screen reader: a
/// ship flying round a canvas cannot be found by touch exploration, and a
/// button can. Shooting one is the same as tapping its ship.
class ChoiceBar extends StatelessWidget {
  const ChoiceBar({required this.round, required this.onChoose, super.key});

  final Round round;
  final ValueChanged<int> onChoose;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Semantics(
      label: l10n.huntShipsLabel,
      container: true,
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final (i, choice) in round.choices.indexed)
            if (!round.missed.contains(i))
              Semantics(
                button: true,
                label: l10n.huntShoot(choice.en),
                excludeSemantics: true,
                child: OutlinedButton(
                  key: Key('hunt-choice-$i'),
                  onPressed: round.live ? () => onChoose(i) : null,
                  child: Text(choice.en),
                ),
              ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------ overlays --

/// "3, 2, 1, Go!" over the deck's name, as the mission's countdown runs.
class CountdownOverlay extends StatefulWidget {
  const CountdownOverlay({
    required this.state,
    required this.onBeat,
    super.key,
  });

  final MissionState state;

  /// Each number as it comes up: `3`, `2`, `1`, then `0` for "Go".
  final ValueChanged<int> onBeat;

  /// The sound of each number, rising to the start.
  static Sound soundOf(int beat) => switch (beat) {
    3 => Sound.countOne,
    2 => Sound.countTwo,
    _ => Sound.countThree,
  };

  @override
  State<CountdownOverlay> createState() => _CountdownOverlayState();
}

class _CountdownOverlayState extends State<CountdownOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: MissionPace.countdown,
  )..addListener(_tick);
  int _beat = 4;

  @override
  void initState() {
    super.initState();
    _run();
  }

  @override
  void didUpdateWidget(CountdownOverlay old) {
    super.didUpdateWidget(old);
    if (old.state.phase != widget.state.phase) _run();
  }

  void _run() {
    if (widget.state.phase == MissionPhase.countdown) {
      _clock.forward().ignore();
    } else {
      _clock.stop();
    }
  }

  void _tick() {
    final beat = 3 - (_clock.value * 4).floor().clamp(0, 3);
    if (beat == _beat) return;
    setState(() => _beat = beat);
    widget.onBeat(beat);
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final deck = widget.state.deck;
    final beat = _beat.clamp(0, 3);
    return IgnorePointer(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: deck.accent,
                boxShadow: [
                  BoxShadow(
                    color: deck.accent.withValues(alpha: 0.6),
                    blurRadius: 30,
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Icon(
                  deck.icon,
                  size: 34,
                  color: theme.colorScheme.surface,
                ),
              ),
            ),
            const SizedBox(height: 10),
            AnimatedSwitcher(
              duration: context.motion(const Duration(milliseconds: 220)),
              transitionBuilder: (child, animation) => ScaleTransition(
                scale: CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOutBack,
                ),
                child: FadeTransition(opacity: animation, child: child),
              ),
              child: Text(
                beat == 0 ? l10n.huntGo : '$beat',
                key: ValueKey(beat),
                style: theme.textTheme.displayLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: beat == 0
                      ? HuntColours.gold
                      : theme.colorScheme.onSurface,
                  shadows: [
                    Shadow(
                      color: deck.accent.withValues(alpha: 0.8),
                      blurRadius: 24,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Scrim extends StatelessWidget {
  const _Scrim({required this.child, this.scrolls = true});

  final Widget child;

  /// Whether the scrim scrolls [child] when it is too tall. A child that
  /// lays itself out to the height it is given - the results, with their
  /// list scrolling between a fixed head and fixed buttons - does not.
  final bool scrolls;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Theme.of(context).colorScheme.scrim.withValues(alpha: 0.55),
    child: SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: scrolls ? SingleChildScrollView(child: child) : child,
          ),
        ),
      ),
    ),
  );
}

class PausePanel extends StatelessWidget {
  const PausePanel({required this.onResume, required this.onQuit, super.key});

  final VoidCallback onResume;
  final VoidCallback onQuit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return _Scrim(
      child: HuntPanel(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.huntPaused,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const AppBarActions(theme: false, licenses: false),
              ],
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              key: const Key('hunt-resume'),
              onPressed: onResume,
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(l10n.huntResume),
              style: FilledButton.styleFrom(minimumSize: const Size(0, 52)),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              key: const Key('hunt-quit'),
              onPressed: onQuit,
              icon: const Icon(Icons.grid_view_rounded),
              label: Text(l10n.huntQuit),
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 52)),
            ),
          ],
        ),
      ),
    );
  }
}

/// How the mission went: its stars, its score, and every word it asked for
/// with its answer - each a tap away from being heard.
class ResultsPanel extends StatelessWidget {
  const ResultsPanel({
    required this.state,
    required this.onAgain,
    required this.onThemes,
    this.onHear,
    super.key,
  });

  final MissionState state;
  final VoidCallback onAgain;
  final VoidCallback onThemes;

  /// Reads an English word aloud; `null` when the device has no voice to
  /// read it in.
  final ValueChanged<String>? onHear;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final title = state.wrecked
        ? l10n.huntResultsWrecked
        : state.stars > 0
        ? l10n.huntResultsDone
        : l10n.huntResultsAlmost;
    // The way on is always in reach, at the bottom; the words scroll
    // between it and the score, however short the screen.
    return _Scrim(
      scrolls: false,
      child: HuntPanel(
        accent: state.stars == 3 ? HuntColours.gold : null,
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      title,
                      key: const Key('hunt-results-title'),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Semantics(
                      label: l10n.huntStars(state.stars),
                      child: ExcludeSemantics(
                        child: _EarnedStars(stars: state.stars),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _number(context, state.score),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: HuntColours.gold,
                      ),
                    ),
                    if (state.newBest)
                      Center(
                        child: Container(
                          key: const Key('hunt-new-best'),
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: HuntColours.gold,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            l10n.huntNewBest,
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: theme.colorScheme.surface,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _Stat(
                          icon: Icons.track_changes_rounded,
                          text: l10n.huntFoundOf(state.found, state.total),
                        ),
                        _Stat(
                          icon: Icons.local_fire_department_rounded,
                          text: l10n.huntBestStreak(state.bestStreak),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l10n.huntMissionWords,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    for (final result in state.results)
                      _WordRow(result: result, onHear: onHear),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              key: const Key('hunt-again'),
              onPressed: onAgain,
              icon: const Icon(Icons.replay_rounded),
              label: Text(l10n.huntPlayAgain),
              style: FilledButton.styleFrom(minimumSize: const Size(0, 52)),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              key: const Key('hunt-themes'),
              onPressed: onThemes,
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
              child: Text(l10n.huntOtherThemes),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: HuntColours.gold),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                text,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The stars, landing one after another.
class _EarnedStars extends StatelessWidget {
  const _EarnedStars({required this.stars});

  final int stars;

  @override
  Widget build(BuildContext context) {
    final empty = Theme.of(context).colorScheme.onSurface.withValues(
      alpha: 0.25,
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < 3; i++)
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: context.motion(Duration(milliseconds: 500 + i * 260)),
            builder: (context, t, child) {
              final local = ((t * (500 + i * 260) - i * 260) / 500).clamp(
                0.0,
                1.0,
              );
              return Transform.scale(
                scale: i < stars ? Curves.elasticOut.transform(local) : 1,
                child: child,
              );
            },
            child: Icon(
              i < stars ? Icons.star_rounded : Icons.star_outline_rounded,
              size: i == 1 ? 64 : 52,
              color: i < stars ? HuntColours.gold : empty,
            ),
          ),
      ],
    );
  }
}

class _WordRow extends StatelessWidget {
  const _WordRow({required this.result, required this.onHear});

  final WordResult result;
  final ValueChanged<String>? onHear;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final hear = onHear;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            result.found ? Icons.check_circle_rounded : Icons.cancel_rounded,
            size: 20,
            color: result.found ? HuntColours.gold : theme.colorScheme.error,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: result.pair.pt,
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  const TextSpan(text: '  →  '),
                  TextSpan(
                    text: result.pair.en,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              style: theme.textTheme.bodyLarge,
            ),
          ),
          if (hear != null)
            IconButton(
              onPressed: () => hear(result.pair.en),
              icon: const Icon(Icons.volume_up_rounded),
              tooltip: l10n.huntHear(result.pair.en),
            ),
        ],
      ),
    );
  }
}
