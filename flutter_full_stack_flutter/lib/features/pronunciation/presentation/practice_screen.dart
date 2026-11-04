import 'dart:async';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_full_stack_flutter/app/app_bar_actions.dart';
import 'package:flutter_full_stack_flutter/core/pronunciation/gop_scorer.dart';
import 'package:flutter_full_stack_flutter/core/pronunciation/lexicon.dart';
import 'package:flutter_full_stack_flutter/core/pronunciation/model_store.dart';
import 'package:flutter_full_stack_flutter/core/pronunciation/pronunciation_engine.dart';
import 'package:flutter_full_stack_flutter/features/pronunciation/presentation/language_screen.dart';
import 'package:flutter_full_stack_flutter/features/pronunciation/presentation/prompt_scene.dart';
import 'package:flutter_full_stack_flutter/features/pronunciation/providers/practice_controller.dart';
import 'package:flutter_full_stack_flutter/l10n/app_localizations.dart';
import 'package:flutter_full_stack_flutter/theme/app_tokens.dart';
import 'package:flutter_full_stack_flutter/theme/aurora_backdrop.dart';
import 'package:flutter_full_stack_flutter/theme/glass_surface.dart';
import 'package:flutter_full_stack_flutter/theme/rise_in.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Read-aloud practice for one language.
///
/// Laid out so the world behind the sentence can be seen without the sentence
/// losing the eye. The prompt sits at the top, compact and on glass; the
/// scene's island stands in the open middle; and the one thing to do -
/// record - is a single round button in the footer. Anything else to read (a
/// score, a failure, the download) appears between the two only while there
/// is something to say, and while the learner speaks the world steps back.
class PracticeScreen extends ConsumerWidget {
  const PracticeScreen({required this.lang, super.key});

  final String lang;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final tokens = Theme.of(context).appTokens;
    final state = ref.watch(practiceControllerProvider(lang));
    final value = state.value;
    // From the moment the microphone opens until the score is in, the
    // sentence is the one thing left in focus.
    final hushed = switch (value?.stage) {
      PracticeStage.recording || PracticeStage.scoring => true,
      _ => false,
    };

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(actions: const [AppBarActions()]),
      body: AuroraBackdrop(
        // A Builder because the padding that includes the app bar only
        // exists below the Scaffold, and the scene needs it.
        child: Builder(
          builder: (context) {
            final padding = MediaQuery.paddingOf(context);
            final still = MediaQuery.disableAnimationsOf(context);
            return Stack(
              fit: StackFit.expand,
              children: [
                // On the page, not in the card: fixed while the deck swipes
                // over it, and blurred by the glass like the rest of the
                // backdrop. Told what the deck and the footer cover, so its
                // island stands whole in the open space between them.
                PromptScene(
                  topic: value?.topic,
                  clear: EdgeInsets.only(
                    top: padding.top + _Layout.deckBottom,
                    bottom: padding.bottom + _Layout.footer,
                  ),
                ),
                IgnorePointer(
                  child: AnimatedOpacity(
                    key: const Key('practice-hush'),
                    opacity: hushed ? 1 : 0,
                    duration: still
                        ? Duration.zero
                        : const Duration(milliseconds: 280),
                    curve: Curves.easeOut,
                    child: ColoredBox(color: tokens.sceneHush),
                  ),
                ),
                SafeArea(
                  child: switch (state) {
                    // A failed action keeps its deck: the error travels
                    // beside the value, so the learner can simply try again.
                    AsyncValue(:final value?) => _Practice(
                      lang: lang,
                      state: value,
                      failure: state.error,
                    ),
                    AsyncError(:final error) => Padding(
                      padding: const EdgeInsets.all(_Layout.gutter),
                      child: RiseIn(
                        child: _Failure(
                          message: l10n.practiceUnavailable,
                          detail: error,
                          actionLabel: l10n.practiceTryAgain,
                          onAction: () =>
                              ref.invalidate(practiceControllerProvider(lang)),
                        ),
                      ),
                    ),
                    _ => const Center(child: CircularProgressIndicator()),
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// The page's fixed measures: shared by the layout and by what the scene is
/// told to keep its island clear of, so the two cannot disagree.
abstract final class _Layout {
  static const gutter = 20.0;

  /// Between the app bar and the deck.
  static const top = 8.0;

  /// Two lines of a sentence at the prompt's size, and the glass around
  /// them. The longest prompt in any language takes two.
  static const phraseDeck = 132.0;
  static const wordDeck = 104.0;

  static const dots = 8.0;
  static const gap = 14.0;

  /// From under the app bar to just below the page dots.
  static const double deckBottom = top + phraseDeck + gap + dots + gap;

  /// The footer the record button stands in.
  static const footer = 132.0;
}

/// The deck, what there is to read about the last attempt, and the button.
class _Practice extends ConsumerStatefulWidget {
  const _Practice({required this.lang, required this.state, this.failure});

  final String lang;
  final PracticeState state;

  /// Why the last action did not go through, if it did not.
  final Object? failure;

  @override
  ConsumerState<_Practice> createState() => _PracticeState();
}

class _PracticeState extends ConsumerState<_Practice> {
  late final PageController _pages = PageController(
    initialPage: widget.state.index,
  );

  /// Coming back to the app is how a learner returns from granting the
  /// microphone in settings, so that is when to look again.
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onResume: () => unawaited(
        ref
            .read(practiceControllerProvider(widget.lang).notifier)
            .recheckMicrophone(),
      ),
    );
  }

  @override
  void didUpdateWidget(_Practice old) {
    super.didUpdateWidget(old);
    // Switching decks rebuilds the list under the PageView, so the page has to
    // be put back by hand - otherwise it keeps an index into the old deck.
    if (old.state.kind != widget.state.kind && _pages.hasClients) {
      _pages.jumpToPage(widget.state.index);
    }
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final state = widget.state;
    final controller = ref.read(
      practiceControllerProvider(widget.lang).notifier,
    );
    final words = state.kind == ExerciseKind.word;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        _Layout.gutter,
        _Layout.top,
        _Layout.gutter,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // A deck, not a list: one prompt at a time is what a learner reads
          // aloud, and swiping is how they move on.
          RiseIn(
            child: SizedBox(
              height: words ? _Layout.wordDeck : _Layout.phraseDeck,
              child: PageView.builder(
                controller: _pages,
                itemCount: state.items.length,
                onPageChanged: controller.goTo,
                itemBuilder: (context, index) => GlassSurface(
                  dense: true,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  child: Center(
                    child: _Prompt(
                      text: state.items[index].text,
                      large: words,
                      // The score belongs to the attempt that produced it,
                      // so it is only painted on the prompt it came from.
                      result: index == state.index ? state.result : null,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: _Layout.gap),
          _PageDots(
            index: state.index,
            count: state.items.length,
            label: l10n.practicePosition(state.index + 1, state.items.length),
          ),
          const SizedBox(height: _Layout.gap),
          // Whatever there is to read besides the sentence, and only while
          // there is. Empty, it leaves the world in view.
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (widget.failure case final failure?) ...[
                    _Failure(
                      message: failureMessage(l10n, failure),
                      detail: failure,
                    ),
                    const SizedBox(height: 12),
                  ],
                  switch (state.stage) {
                    PracticeStage.needsModel => _DownloadPrompt(
                      l10n: l10n,
                      onDownload: () => unawaited(controller.downloadModel()),
                    ),
                    PracticeStage.downloading => _Downloading(
                      l10n: l10n,
                      progress: state.download,
                    ),
                    // A refusal is final as far as the system dialog goes, so
                    // the only way forward is the settings page - and it has
                    // to be one tap away.
                    PracticeStage.noMicrophone => _Failure(
                      message: l10n.practiceNoMicrophone,
                      actionLabel: l10n.practiceOpenSettings,
                      onAction: () =>
                          unawaited(ref.read(appSettingsProvider).open()),
                    ),
                    _ => const SizedBox.shrink(),
                  },
                  if (state.result case final result?)
                    RiseIn(
                      delay: const Duration(milliseconds: 60),
                      child: _Score(result: result, l10n: l10n),
                    ),
                  // Not localised and not shipped: this is here so the cost
                  // of the model is a measured number instead of an argument.
                  if (kDebugMode && state.scoringTime != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'scored in ${state.scoringTime!.inMilliseconds} ms',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          SizedBox(
            height: _Layout.footer,
            child: Center(
              child: RiseIn(
                delay: const Duration(milliseconds: 120),
                child: _RecordControl(
                  stage: state.stage,
                  l10n: l10n,
                  onRecord: () => unawaited(controller.startRecording()),
                  onStop: () => unawaited(controller.stopAndScore()),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Where in the deck the learner is, as dots: the sentence keeps the eye, and
/// this only has to be glanced at. A screen reader gets the words.
class _PageDots extends StatelessWidget {
  const _PageDots({
    required this.index,
    required this.count,
    required this.label,
  });

  /// Past this many, dots stop being countable at a glance and the position
  /// is written out instead.
  static const most = 12;

  final int index;
  final int count;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    if (count > most) {
      return Text(
        label,
        textAlign: TextAlign.center,
        style: theme.textTheme.labelMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      );
    }
    final still = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      label: label,
      child: ExcludeSemantics(
        child: SizedBox(
          height: _Layout.dots,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < count; i++)
                AnimatedContainer(
                  duration: still
                      ? Duration.zero
                      : const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == index ? 22 : _Layout.dots,
                  decoration: BoxDecoration(
                    color: i == index
                        ? scheme.primary
                        : scheme.onSurfaceVariant.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(_Layout.dots / 2),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The sentence to read, coloured word by word once there is a score.
///
/// Colour goes on the prompt itself rather than in a separate list, so the
/// learner reads the feedback where they read the words.
class _Prompt extends StatelessWidget {
  const _Prompt({required this.text, this.large = false, this.result});

  final String text;

  /// A single word gets room to be a single word. Setting one word in the
  /// size meant for a sentence reads as a sentence that lost its rest.
  final bool large;
  final PronunciationResult? result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = large
        ? theme.textTheme.displaySmall
        : theme.textTheme.headlineSmall;
    final scored = result;

    // Centred: in a compact card the sentence is the whole of it, and reads
    // as a line to say rather than a paragraph to scan.
    if (scored == null || scored.words.isEmpty) {
      return Text(text, style: style, textAlign: TextAlign.center);
    }

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 4,
      children: [
        for (final word in scored.words)
          Text(
            word.word,
            style: style?.copyWith(
              color: scoreColour(theme, word.score, scored.errorThreshold),
            ),
          ),
      ],
    );
  }
}

/// Maps a 0-100 score onto the three score tokens.
///
/// The weak band starts where the calibration says an error starts, so
/// recalibrating moves the colours with the numbers instead of leaving them
/// pointing at an old scale.
Color scoreColour(ThemeData theme, double score, double errorThreshold) {
  final tokens = theme.appTokens;
  if (score >= 80) return tokens.scoreStrong;
  if (score >= errorThreshold) return tokens.scoreFair;
  return tokens.scoreWeak;
}

class _DownloadPrompt extends StatelessWidget {
  const _DownloadPrompt({required this.l10n, required this.onDownload});

  final AppLocalizations l10n;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassSurface(
      dense: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.practiceDownloadExplainer(packMegabytes),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            key: const Key('practice-download'),
            onPressed: onDownload,
            icon: const Icon(Icons.download_outlined),
            label: Text(l10n.practiceDownloadPack),
          ),
        ],
      ),
    );
  }
}

class _Downloading extends StatelessWidget {
  const _Downloading({required this.l10n, this.progress});

  final AppLocalizations l10n;
  final DownloadProgress? progress;

  @override
  Widget build(BuildContext context) {
    final fraction = progress?.fraction;
    return GlassSurface(
      dense: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.practiceDownloading),
          const SizedBox(height: 12),
          // An indeterminate bar when the server sent no length: a bar that
          // pretends to know how far along it is, is worse than one that does
          // not claim to.
          LinearProgressIndicator(value: fraction),
        ],
      ),
    );
  }
}

/// The one thing to do on this screen, as one round button: record, stop,
/// or wait while the attempt is scored.
///
/// Absent while there is nothing to record with - the pane above then
/// carries the way forward, the download or the settings page - so the
/// footer never offers a button that cannot work.
class _RecordControl extends StatelessWidget {
  const _RecordControl({
    required this.stage,
    required this.l10n,
    required this.onRecord,
    required this.onStop,
  });

  final PracticeStage stage;
  final AppLocalizations l10n;
  final VoidCallback onRecord;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) => switch (stage) {
    PracticeStage.ready || PracticeStage.scored => _RoundButton(
      key: const Key('practice-record'),
      label: stage == PracticeStage.scored
          ? l10n.practiceTryAgain
          : l10n.practiceRecord,
      icon: Icons.mic_rounded,
      onPressed: onRecord,
    ),
    PracticeStage.recording => _RoundButton(
      key: const Key('practice-stop'),
      label: l10n.practiceStop,
      icon: Icons.stop_rounded,
      onPressed: onStop,
      live: true,
    ),
    PracticeStage.scoring => _RoundButton(
      key: const Key('practice-scoring'),
      label: l10n.practiceScoring,
      busy: true,
    ),
    PracticeStage.needsModel ||
    PracticeStage.downloading ||
    PracticeStage.noMicrophone => const SizedBox.shrink(),
  };
}

/// A round button in a soft halo of its own colour.
///
/// [live] turns it to the error colour and sets the halo rippling outward:
/// the microphone is open. That ripple is the one motion on this screen that
/// lasts, and it lasts only for as long as it is true - at most the fifteen
/// seconds an attempt may run. Under reduced motion the halo simply holds.
class _RoundButton extends StatefulWidget {
  const _RoundButton({
    required this.label,
    this.icon,
    this.onPressed,
    this.live = false,
    this.busy = false,
    super.key,
  });

  static const size = 76.0;

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool live;
  final bool busy;

  @override
  State<_RoundButton> createState() => _RoundButtonState();
}

class _RoundButtonState extends State<_RoundButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ripple = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  void _sync() {
    final ripple = widget.live && !MediaQuery.disableAnimationsOf(context);
    if (ripple && !_ripple.isAnimating) {
      _ripple.repeat();
    } else if (!ripple && _ripple.isAnimating) {
      _ripple
        ..stop()
        ..value = 0;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(_RoundButton old) {
    super.didUpdateWidget(old);
    _sync();
  }

  @override
  void dispose() {
    _ripple.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fill = widget.live ? scheme.error : scheme.primary;
    final ink = widget.live ? scheme.onError : scheme.onPrimary;
    const size = _RoundButton.size;

    return SizedBox.square(
      dimension: size + 40,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _ripple,
            builder: (context, _) {
              final t = _ripple.value;
              return Container(
                width: size + 20 + 20 * t,
                height: size + 20 + 20 * t,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: fill.withValues(alpha: 0.22 * (1 - t * 0.85)),
                ),
              );
            },
          ),
          IconButton.filled(
            onPressed: widget.busy ? null : widget.onPressed,
            tooltip: widget.label,
            iconSize: 34,
            style: IconButton.styleFrom(
              fixedSize: const Size.square(size),
              backgroundColor: fill,
              foregroundColor: ink,
              // Scoring keeps the button's colour: it is busy, not off.
              disabledBackgroundColor: fill,
              disabledForegroundColor: ink,
              elevation: 3,
              shadowColor: fill,
            ),
            icon: widget.busy
                ? SizedBox.square(
                    dimension: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: ink,
                    ),
                  )
                : Icon(widget.icon),
          ),
        ],
      ),
    );
  }
}

/// What to tell the learner about a failed action.
///
/// Chosen by what they were doing, not by the exception: "Connection refused"
/// or "audio too short: 3 frames for 5 tokens" is written for a log, and on a
/// phone it reads as the app breaking rather than as something to try again.
String failureMessage(AppLocalizations l10n, Object failure) =>
    switch (failure) {
      PracticeFailure(step: PracticeStep.download) =>
        l10n.practiceDownloadFailed,
      PracticeFailure(step: PracticeStep.record) => l10n.practiceRecordFailed,
      PracticeFailure(
        cause: AttemptRejected(reason: RejectedBecause.tooShort),
      ) =>
        l10n.practiceTooShort,
      PracticeFailure(
        cause: AttemptRejected(reason: RejectedBecause.notHeard),
      ) =>
        l10n.practiceNotHeard,
      _ => l10n.practiceScoreFailed,
    };

class _Failure extends StatelessWidget {
  const _Failure({
    required this.message,
    this.detail,
    this.actionLabel,
    this.onAction,
  });

  final String message;

  /// The exception itself, shown in debug builds only: it is what whoever is
  /// chasing the failure needs, and nothing a learner can use.
  final Object? detail;

  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassSurface(
      dense: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
          if (kDebugMode && detail != null) ...[
            const SizedBox(height: 8),
            Text(
              '$detail',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 16),
            FilledButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}

/// The numbers, and then the part that is actually actionable: which phoneme
/// went wrong and what it sounded like instead.
class _Score extends StatelessWidget {
  const _Score({required this.result, required this.l10n});

  final PronunciationResult result;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Only the phonemes we can actually name. A word that scored badly on a
    // phoneme we cannot separate from its substitute still shows red in the
    // prompt above; it just does not get a sentence claiming what was said.
    final missed = [
      for (final word in result.words)
        if (word.weakest case final phone?)
          if (phone.heardInstead != null) (word: word, phone: phone),
    ];

    return GlassSurface(
      dense: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                result.overall.round().toString(),
                key: const Key('practice-overall'),
                style: theme.textTheme.displayMedium?.copyWith(
                  color: scoreColour(
                    theme,
                    result.overall,
                    result.errorThreshold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                l10n.practiceAccuracy.toUpperCase(),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          // Fluency sits beside the score, never inside it, and says so.
          // Reporting it as part of the grade made a weak reading look
          // middling; reporting it as a measurement keeps the information
          // without the false precision. On a single word there is nothing to
          // report at all, and the block is simply absent.
          if (result.fluency case final fluency?) ...[
            const SizedBox(height: 12),
            Text(
              '${l10n.practiceFluency} ${fluency.round()}'
              '  ·  ${l10n.practiceFluencyDiagnostic}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              l10n.practiceRhythmDetail(
                result.speechRate.toStringAsFixed(1),
                result.pauses,
              ),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          if (missed.isNotEmpty) ...[
            const SizedBox(height: 16),
            for (final entry in missed)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: entry.word.word,
                        style: theme.textTheme.bodyLarge,
                      ),
                      TextSpan(
                        text: '  /${entry.phone.symbol}/  ',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.appTokens.scoreWeak,
                        ),
                      ),
                      TextSpan(
                        text: l10n.practiceHeardInstead(
                          '/${entry.phone.heardInstead}/',
                        ),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
