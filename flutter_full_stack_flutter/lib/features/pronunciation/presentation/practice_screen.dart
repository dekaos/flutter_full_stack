import 'dart:async';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_full_stack_flutter/app/app_bar_actions.dart';
import 'package:flutter_full_stack_flutter/core/pronunciation/gop_scorer.dart';
import 'package:flutter_full_stack_flutter/core/pronunciation/lexicon.dart';
import 'package:flutter_full_stack_flutter/core/pronunciation/model_store.dart';
import 'package:flutter_full_stack_flutter/core/pronunciation/pronunciation_engine.dart';
import 'package:flutter_full_stack_flutter/features/pronunciation/presentation/language_screen.dart';
import 'package:flutter_full_stack_flutter/features/pronunciation/providers/practice_controller.dart';
import 'package:flutter_full_stack_flutter/l10n/app_localizations.dart';
import 'package:flutter_full_stack_flutter/theme/app_tokens.dart';
import 'package:flutter_full_stack_flutter/theme/aurora_backdrop.dart';
import 'package:flutter_full_stack_flutter/theme/glass_surface.dart';
import 'package:flutter_full_stack_flutter/theme/rise_in.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Read-aloud practice for one language.
class PracticeScreen extends ConsumerWidget {
  const PracticeScreen({required this.lang, super.key});

  final String lang;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(practiceControllerProvider(lang));

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(actions: const [AppBarActions()]),
      body: AuroraBackdrop(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RiseIn(child: _Headline(l10n: l10n)),
                const SizedBox(height: 32),
                switch (state) {
                  // A failed action keeps its deck: the error travels beside
                  // the value, so the learner can simply try again.
                  AsyncValue(:final value?) => RiseIn(
                    delay: const Duration(milliseconds: 90),
                    child: _Practice(
                      lang: lang,
                      state: value,
                      failure: state.error,
                    ),
                  ),
                  AsyncError(:final error) => RiseIn(
                    delay: const Duration(milliseconds: 90),
                    child: _Failure(
                      message: l10n.practiceUnavailable,
                      detail: error,
                      actionLabel: l10n.practiceTryAgain,
                      onAction: () =>
                          ref.invalidate(practiceControllerProvider(lang)),
                    ),
                  ),
                  _ => const Center(child: CircularProgressIndicator()),
                },
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Headline extends StatelessWidget {
  const _Headline({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.practiceHeadline, style: theme.textTheme.displaySmall),
        const SizedBox(height: 12),
        Text(
          l10n.practiceTagline,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// The deck, the control that fits the current stage, and the last score.
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<ExerciseKind>(
          key: const Key('practice-kind'),
          segments: [
            ButtonSegment(
              value: ExerciseKind.word,
              label: Text(l10n.practiceWords),
            ),
            ButtonSegment(
              value: ExerciseKind.phrase,
              label: Text(l10n.practicePhrases),
            ),
          ],
          selected: {state.kind},
          onSelectionChanged: (selection) =>
              controller.selectKind(selection.first),
        ),
        const SizedBox(height: 20),
        // A deck, not a list: one prompt at a time is what a learner reads
        // aloud, and swiping is how they move on.
        SizedBox(
          height: state.kind == ExerciseKind.word ? 120 : 180,
          child: PageView.builder(
            controller: _pages,
            itemCount: state.items.length,
            onPageChanged: controller.goTo,
            itemBuilder: (context, index) => GlassSurface(
              child: Center(
                child: _Prompt(
                  text: state.items[index].text,
                  large: state.kind == ExerciseKind.word,
                  // The score belongs to the attempt that produced it, so it
                  // is only painted on the prompt it came from.
                  result: index == state.index ? state.result : null,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          l10n.practicePosition(state.index + 1, state.items.length),
          textAlign: TextAlign.center,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 20),
        if (widget.failure case final failure?) ...[
          _Failure(message: failureMessage(l10n, failure), detail: failure),
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
          PracticeStage.ready || PracticeStage.scored => _RecordButton(
            key: const Key('practice-record'),
            label: state.stage == PracticeStage.scored
                ? l10n.practiceTryAgain
                : l10n.practiceRecord,
            icon: Icons.mic_none_outlined,
            onPressed: () => unawaited(controller.startRecording()),
          ),
          PracticeStage.recording => _RecordButton(
            key: const Key('practice-stop'),
            label: l10n.practiceStop,
            icon: Icons.stop_circle_outlined,
            onPressed: () => unawaited(controller.stopAndScore()),
          ),
          PracticeStage.scoring => _Busy(label: l10n.practiceScoring),
          PracticeStage.noMicrophone => _Failure(
            message: l10n.practiceNoMicrophone,
          ),
        },
        if (state.result case final result?) ...[
          const SizedBox(height: 20),
          RiseIn(
            delay: const Duration(milliseconds: 60),
            child: _Score(result: result, l10n: l10n),
          ),
        ],
        // Not localised and not shipped: this is here so the cost of the
        // model is a measured number instead of an argument.
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

    if (scored == null || scored.words.isEmpty) {
      return Text(text, style: style);
    }

    return Wrap(
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

class _RecordButton extends StatelessWidget {
  const _RecordButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    super.key,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => FilledButton.icon(
    onPressed: onPressed,
    icon: Icon(icon),
    label: Text(label),
    style: FilledButton.styleFrom(
      padding: const EdgeInsets.symmetric(vertical: 20),
    ),
  );
}

class _Busy extends StatelessWidget {
  const _Busy({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      const SizedBox(width: 12),
      Text(label),
    ],
  );
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
