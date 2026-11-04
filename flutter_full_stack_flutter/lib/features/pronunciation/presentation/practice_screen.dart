import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show ValueListenable, kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_full_stack_flutter/app/app_bar_actions.dart';
import 'package:flutter_full_stack_flutter/core/audio/sound.dart';
import 'package:flutter_full_stack_flutter/core/audio/synth.dart';
import 'package:flutter_full_stack_flutter/core/pronunciation/attempt_recorder.dart';
import 'package:flutter_full_stack_flutter/core/pronunciation/gop_scorer.dart';
import 'package:flutter_full_stack_flutter/core/pronunciation/lexicon.dart';
import 'package:flutter_full_stack_flutter/core/pronunciation/pronunciation_engine.dart';
import 'package:flutter_full_stack_flutter/features/pronunciation/presentation/hiding_cat.dart';
import 'package:flutter_full_stack_flutter/features/pronunciation/presentation/prompt_scene.dart';
import 'package:flutter_full_stack_flutter/features/pronunciation/presentation/score_band.dart';
import 'package:flutter_full_stack_flutter/features/pronunciation/providers/practice_audio.dart';
import 'package:flutter_full_stack_flutter/features/pronunciation/providers/practice_controller.dart';
import 'package:flutter_full_stack_flutter/l10n/app_localizations.dart';
import 'package:flutter_full_stack_flutter/theme/app_tokens.dart';
import 'package:flutter_full_stack_flutter/theme/aurora_backdrop.dart';
import 'package:flutter_full_stack_flutter/theme/glass_surface.dart';
import 'package:flutter_full_stack_flutter/theme/motion.dart';
import 'package:flutter_full_stack_flutter/theme/reveal.dart';
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
///
/// It is heard the way it is seen: the scene and the cat make a few soft
/// sounds as they move, an attempt's score is answered with a chime in its
/// band, and the sentence can be listened to before it is said. All of it
/// stops the moment the microphone opens (`SoundBoard`), and everything but
/// the reading can be turned off from the app bar ([AppBarActions.sounds]).
class PracticeScreen extends ConsumerWidget {
  const PracticeScreen({required this.lang, super.key});

  final String lang;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final tokens = Theme.of(context).appTokens;
    final state = ref.watch(practiceControllerProvider(lang));
    final value = state.value;
    final board = ref.watch(soundBoardProvider);
    final topic = value?.topic;
    // An attempt's score is answered once, as it arrives, in its band.
    ref.listen(practiceControllerProvider(lang), (previous, next) {
      final result = next.value?.result;
      if (result != null && !identical(result, previous?.value?.result)) {
        board.play(chimeFor(result));
      }
    });
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
            return Stack(
              fit: StackFit.expand,
              children: [
                // On the page, not in the card: fixed while the deck swipes
                // over it, and blurred by the glass like the rest of the
                // backdrop. Told what the deck and the footer cover, so its
                // island stands whole in the open space between them.
                // The black cat hiding in the scene, and when it comes out.
                HidingCat(
                  prompt: topic == null ? null : value?.exercise.id,
                  stage: value?.stage,
                  result: value?.result,
                  walks: topic != null && PromptScene.scriptOf(topic).catWalks,
                  onSound: board.play,
                  builder: (context, cat) => PromptScene(
                    topic: topic,
                    cat: cat,
                    onSound: board.play,
                    clear: EdgeInsets.only(
                      top: padding.top + _Layout.deckBottom,
                      bottom: padding.bottom + _Layout.footer,
                    ),
                  ),
                ),
                IgnorePointer(
                  child: AnimatedOpacity(
                    key: const Key('practice-hush'),
                    opacity: hushed ? 1 : 0,
                    duration: context.motion(
                      const Duration(milliseconds: 280),
                    ),
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

class _PracticeState extends ConsumerState<_Practice>
    with SingleTickerProviderStateMixin {
  late final PageController _pages = PageController(
    initialPage: widget.state.index,
  );

  /// Coming back to the app is how a learner returns from granting the
  /// microphone in settings, so that is when to look again.
  late final AppLifecycleListener _lifecycle;

  /// The word of the last attempt the learner tapped, by its place in the
  /// result; until they tap one, the one that most needs fixing.
  int? _picked;

  Timer? _warm;

  /// Runs across what of the attempt is being played back, for the
  /// playhead on its voice message and the words lighting up as they are
  /// heard ([PracticeState.replaying]).
  late final AnimationController _replay = AnimationController(vsync: this);

  /// The outline of the attempt's recording, worked out once per attempt.
  ({Float32List of, List<double> bars})? _outline;

  /// Where the playback of the attempt is, while there is one.
  _Heard? _heard(PracticeState state) => switch (state.replaying) {
    final span? => _Heard(_replay, span),
    null => null,
  };

  List<double> _barsFor(Float32List attempt) {
    final outline = _outline;
    if (outline != null && identical(outline.of, attempt)) return outline.bars;
    final bars = envelope(attempt, bars: _VoiceMessage.count);
    _outline = (of: attempt, bars: bars);
    return bars;
  }

  @override
  void initState() {
    super.initState();
    // Normally ready already, from the language screen. Coming straight
    // here, it waits for the first scene to have arrived rather than
    // competing with it - that scene is simply not heard.
    _warm = warmPracticeSoundAfter(ref, PromptScene.arrival);
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
    // A new attempt starts on its own worst word.
    if (!identical(old.state.result, widget.state.result)) _picked = null;
    // Kept in step with the playback: started as it starts, from the top of
    // the stretch being played, and put away when it ends.
    final span = widget.state.replaying;
    if (span != old.state.replaying) {
      if (span == null) {
        _replay
          ..stop()
          ..value = 0;
      } else {
        _replay
          ..duration = Duration(
            microseconds: ((span.to - span.from) * 1e6).round(),
          )
          ..forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _warm?.cancel();
    _replay.dispose();
    _lifecycle.dispose();
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = widget.state;
    final controller = ref.read(
      practiceControllerProvider(widget.lang).notifier,
    );
    final words = state.kind == ExerciseKind.word;
    final result = state.result;
    final shown = result == null ? null : _picked ?? worstWord(result);
    final attempt = state.attempt;

    return Padding(
      padding: const EdgeInsets.only(top: _Layout.top),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // A deck, not a list: one prompt at a time is what a learner reads
          // aloud, and swiping is how they move on. Edge to edge, with each
          // card's gutter inside its own page, so cards pass a gutter apart
          // instead of sliding by touching.
          RiseIn(
            child: SizedBox(
              height: words ? _Layout.wordDeck : _Layout.phraseDeck,
              child: PageView.builder(
                controller: _pages,
                itemCount: state.items.length,
                onPageChanged: controller.goTo,
                itemBuilder: (context, index) => _DeckCard(
                  pages: _pages,
                  index: index,
                  current: state.index,
                  child: GlassSurface(
                    dense: true,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    child: Center(
                      child: _Prompt(
                        key: ValueKey(state.items[index].id),
                        text: state.items[index].text,
                        large: words,
                        // The score belongs to the attempt that produced it,
                        // so it is only painted on the prompt it came from.
                        result: index == state.index ? state.result : null,
                        picked: shown,
                        // Only on the prompt the attempt belongs to.
                        heard: index == state.index ? _heard(state) : null,
                        // The prompt being read aloud lights up with it.
                        reading: index == state.index && state.speaking
                            ? ref.read(soundBoardProvider).voice.spoken
                            : null,
                        onWord: (picked) {
                          setState(() => _picked = picked);
                          final word = state.result!.words[picked].word;
                          unawaited(controller.hear(word));
                        },
                      ),
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
            label: l10n.practicePosition(
              state.index + 1,
              state.items.length,
            ),
          ),
          const SizedBox(height: _Layout.gap),
          // Whatever there is to read besides the sentence, and only while
          // there is. Empty, it leaves the world in view.
          Expanded(
            child: SingleChildScrollView(
              // The gutter here and not round the deck, whose cards carry
              // their own.
              padding: const EdgeInsets.symmetric(horizontal: _Layout.gutter),
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
                    // A refusal is final as far as the system dialog goes, so
                    // the only way forward is the settings page - and it has
                    // to be one tap away.
                    PracticeStage.noMicrophone => _Failure(
                      message: l10n.practiceNoMicrophone,
                      actionLabel: l10n.practiceOpenSettings,
                      onAction: () => unawaited(
                        ref.read(appSettingsProvider).open(),
                      ),
                    ),
                    _ => const SizedBox.shrink(),
                  },
                  // The attempt itself, as a voice message to play back.
                  if ((result, attempt) case (final result?, final attempt?))
                    RiseIn(
                      delay: const Duration(milliseconds: 30),
                      child: Center(
                        child: _VoiceMessage(
                          bars: _barsFor(attempt),
                          result: result,
                          length: attempt.length / AttemptRecorder.sampleRate,
                          heard: _heard(state),
                          l10n: l10n,
                          onPlay: () => unawaited(controller.replay()),
                        ),
                      ),
                    ),
                  if (result != null && attempt != null && shown != null)
                    const SizedBox(height: 8),
                  // One line, under the sentence it is about, so the island
                  // - and the cat answering the attempt - stays in view.
                  if (result != null && shown != null)
                    RiseIn(
                      delay: const Duration(milliseconds: 60),
                      child: Center(
                        child: AnimatedSwitcher(
                          duration: context.motion(
                            const Duration(milliseconds: 200),
                          ),
                          // A reveal, not a fade: the hint is glass.
                          transitionBuilder: Reveal.transition,
                          child: _WordHint(
                            key: ValueKey(shown),
                            word: result.words[shown],
                            errorThreshold: result.errorThreshold,
                            l10n: l10n,
                            onHear: () => unawaited(
                              controller.hear(result.words[shown].word),
                            ),
                            onHearYours: state.attempt == null
                                ? null
                                : () => unawaited(
                                    controller.replay(word: shown),
                                  ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          SizedBox(
            height: _Layout.footer,
            child: Row(
              children: [
                // Hear it, then say it: the reading stands just before the
                // button that records, on the side a sentence starts.
                Expanded(
                  child: Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: RiseIn(
                      delay: const Duration(milliseconds: 160),
                      child: _ListenControl(
                        lang: widget.lang,
                        state: state,
                        l10n: l10n,
                        onListen: () => unawaited(controller.listen()),
                      ),
                    ),
                  ),
                ),
                // A slot of its own size, so the reading beside it stays
                // put while the record button comes and goes.
                SizedBox.square(
                  dimension: _RoundButton.size + 40,
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
                // The score, on the other side of the button from the
                // reading: as small as a button, and a button for the rest.
                Expanded(
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: result == null
                        ? const SizedBox.shrink()
                        : _ScoreMedal(
                            key: ValueKey(result),
                            result: result,
                            l10n: l10n,
                            onTap: () => unawaited(
                              _showDetails(
                                context,
                                result,
                                state.scoringTime,
                              ),
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One card of the deck, flipped through as a hand of cards is fanned:
/// the card going tips away about the foot of the deck and shrinks a
/// little, the one coming straightens and grows into place. At rest it is
/// exactly where it would be without any of this.
///
/// Only while the learner swipes, so it costs nothing at rest; under
/// reduced motion the cards simply slide.
class _DeckCard extends StatelessWidget {
  const _DeckCard({
    required this.pages,
    required this.index,
    required this.current,
    required this.child,
  });

  /// How far the fan opens: the tilt, in radians, and how much smaller and
  /// lower a card is a whole page away.
  static const tilt = 0.09;
  static const shrink = 0.1;
  static const drop = 16.0;

  final PageController pages;
  final int index;

  /// The prompt the deck is on: where it stands whenever the controller
  /// cannot say. A theme change rebuilds the scroll position under the
  /// deck, and for that one frame it has no size yet - read as the
  /// controller's first page, the card on screen was drawn a whole page
  /// out, tipped and shrunk, and stayed that way, as nothing moved after.
  final int current;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final card = Padding(
      padding: const EdgeInsets.symmetric(horizontal: _Layout.gutter),
      child: child,
    );
    if (context.still) return card;
    return AnimatedBuilder(
      animation: pages,
      child: card,
      builder: (context, card) {
        final page = pages.hasClients && pages.position.haveDimensions
            ? pages.page ?? current.toDouble()
            : current.toDouble();
        // Where this card is from the middle, in pages: below zero going
        // off to the left, above it coming in from the right.
        final from = (index - page).clamp(-1.0, 1.0);
        final away = from.abs();
        return Transform.translate(
          offset: Offset(0, drop * away),
          child: Transform.rotate(
            angle: tilt * from,
            alignment: Alignment.bottomCenter,
            child: Transform.scale(scale: 1 - shrink * away, child: card),
          ),
        );
      },
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
                  duration: context.motion(const Duration(milliseconds: 220)),
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
  const _Prompt({
    required this.text,
    this.large = false,
    this.result,
    this.picked,
    this.onWord,
    this.heard,
    this.reading,
    super.key,
  });

  final String text;

  /// A single word gets room to be a single word. Setting one word in the
  /// size meant for a sentence reads as a sentence that lost its rest.
  final bool large;
  final PronunciationResult? result;

  /// Which word of [result] its hint is about, underlined to tie the two
  /// together.
  final int? picked;

  /// Called with a word's place in [result] when it is tapped: each one
  /// can be heard on its own, and says what went wrong in it.
  final ValueChanged<int>? onWord;

  /// The attempt playing back, if it is: the words light up as they are
  /// heard, karaoke-fashion - the one being said pops, those still to come
  /// wait faded - so the learner sees which word each sound was.
  final _Heard? heard;

  /// The voice reading a prompt aloud, while it is: the same karaoke,
  /// following the engine's own word-by-word progress through [text].
  final ValueListenable<({String text, TextRange range})?>? reading;

  /// The words as drawn - each where it stands in [text], for following a
  /// reading through it, and with its score once there is one.
  List<_Token> _tokens() {
    final scored = result;
    if (scored == null || scored.words.isEmpty) {
      return [
        for (final match in RegExp(r'\S+').allMatches(text))
          _Token(match[0]!, match.start, match.end),
      ];
    }
    // The scored words, found in the prompt in order. One that cannot be
    // found there simply never lights up during a reading.
    final lower = text.toLowerCase();
    var from = 0;
    return [
      for (final word in scored.words)
        () {
          final at = lower.indexOf(word.word.toLowerCase(), from);
          if (at < 0) return _Token(word.word, -1, -1, word);
          from = at + word.word.length;
          return _Token(word.word, at, from, word);
        }(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = large
        ? theme.textTheme.displaySmall
        : theme.textTheme.headlineSmall;
    final still = context.still;
    final tokens = _tokens();
    final scored = result != null && result!.words.isNotEmpty;

    // Word by word whether or not there is a score yet, so the sentence
    // keeps its place when one arrives and any of it can light up. Centred:
    // in a compact card the sentence is the whole of it, and reads as a
    // line to say rather than a paragraph to scan.
    Widget sentence({int? now, bool Function(_Token)? ahead}) {
      final words = Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 4,
        children: [
          for (final (i, token) in tokens.indexed)
            _word(
              theme,
              style,
              i,
              token,
              now: i == now,
              ahead: ahead?.call(token) ?? false,
              still: still,
            ),
        ],
      );
      // Before a score there is nothing to tap: one sentence to a screen
      // reader, not a list of words.
      return scored
          ? words
          : Semantics(
              label: text,
              child: ExcludeSemantics(child: words),
            );
    }

    final heard = this.heard;
    if (heard != null && scored) {
      return AnimatedBuilder(
        animation: heard.clock,
        builder: (context, _) {
          final at = heard.seconds;
          final only = heard.span.word;
          // Played back whole, every word takes its turn; played back
          // alone, only that one does. Scored, the words are the result's,
          // in its order.
          final now = result!.wordAt(at);
          return sentence(
            now: only != null && only != now ? null : now,
            ahead: only != null
                ? null
                : (t) => t.score != null && at < t.score!.start,
          );
        },
      );
    }

    final reading = this.reading;
    if (reading != null) {
      return ValueListenableBuilder(
        valueListenable: reading,
        builder: (context, spoken, _) {
          // Only a reading of this very prompt - not of one word of it.
          if (spoken == null || spoken.text != text) return sentence();
          final at = spoken.range.start;
          final now = tokens.indexWhere((t) => t.start <= at && at < t.end);
          return sentence(
            now: now < 0 ? null : now,
            ahead: (t) => t.start > at,
          );
        },
      );
    }
    return sentence();
  }

  Widget _word(
    ThemeData theme,
    TextStyle? style,
    int i,
    _Token token, {
    required bool now,
    required bool ahead,
    required bool still,
  }) {
    final hop = still ? Duration.zero : const Duration(milliseconds: 160);
    final score = token.score;
    final colour = score == null
        ? (style?.color ?? theme.colorScheme.onSurface)
        : scoreColour(theme, score.score, result!.errorThreshold);
    // The word being heard hops up and grows a touch, as a karaoke ball
    // does - drawn bigger, never laid out bigger, so the sentence does not
    // shuffle about under it.
    final word = AnimatedSlide(
      offset: Offset(0, now && !still ? -0.14 : 0),
      duration: hop,
      curve: Curves.easeOutBack,
      child: AnimatedScale(
        scale: now && !still ? 1.06 : 1,
        duration: hop,
        curve: Curves.easeOutBack,
        child: Text(
          token.text,
          style: style?.copyWith(
            color: ahead ? colour.withValues(alpha: 0.4) : colour,
            decoration: (score != null && i == picked) || now
                ? TextDecoration.underline
                : null,
            decorationColor: colour,
            decorationThickness: now ? 3 : 2,
          ),
        ),
      ),
    );
    if (score == null) return word;
    return Semantics(
      button: true,
      selected: i == picked,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onWord == null ? null : () => onWord!(i),
        child: word,
      ),
    );
  }
}

/// A word of a prompt as drawn: its [text], where it stands in the prompt
/// as character offsets ([start] to [end], `-1` if it could not be found),
/// and its [score] once the prompt has been attempted.
class _Token {
  const _Token(this.text, this.start, this.end, [this.score]);

  final String text;
  final int start;
  final int end;
  final WordScore? score;
}

/// Where a playback of the attempt is: [span] of the recording, run across
/// by [clock] from `0` to `1`.
class _Heard {
  const _Heard(this.clock, this.span);

  final Animation<double> clock;
  final ({double from, double to, int? word}) span;

  /// How far into the recording, in seconds.
  double get seconds => span.from + clock.value * (span.to - span.from);
}

/// The learner's attempt as a voice message: a play button and the outline
/// of their own recording, each bar in the colour of the word it falls in,
/// so where it went wrong can be seen before it is heard. Played back, a
/// playhead runs along it while the words above light up as they are said.
class _VoiceMessage extends StatelessWidget {
  const _VoiceMessage({
    required this.bars,
    required this.result,
    required this.length,
    required this.l10n,
    required this.onPlay,
    this.heard,
  });

  /// How many bars the outline is drawn with.
  static const count = 36;

  final List<double> bars;
  final PronunciationResult result;

  /// How long the recording is, in seconds.
  final double length;
  final _Heard? heard;
  final AppLocalizations l10n;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final quiet = theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.45);
    // Each bar takes the colour of the word being said at its middle, and
    // the gaps between words stay quiet.
    final colours = [
      for (var i = 0; i < bars.length; i++)
        switch (result.wordAt((i + 0.5) / bars.length * length)) {
          final word? => scoreColour(
            theme,
            result.words[word].score,
            result.errorThreshold,
          ),
          null => quiet,
        },
    ];
    final playing = heard != null && heard!.span.word == null;

    return GlassSurface(
      dense: true,
      padding: const EdgeInsetsDirectional.fromSTEB(4, 4, 18, 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            key: const Key('practice-replay'),
            onPressed: onPlay,
            tooltip: playing ? l10n.practiceReplayStop : l10n.practiceReplay,
            icon: Icon(
              playing ? Icons.stop_rounded : Icons.play_arrow_rounded,
            ),
          ),
          SizedBox(
            width: 168,
            height: 30,
            child: CustomPaint(
              painter: _OutlinePainter(
                bars: bars,
                colours: colours,
                length: length,
                heard: heard,
                playhead: theme.colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OutlinePainter extends CustomPainter {
  _OutlinePainter({
    required this.bars,
    required this.colours,
    required this.length,
    required this.heard,
    required this.playhead,
  }) : super(repaint: heard?.clock);

  final List<double> bars;
  final List<Color> colours;
  final double length;
  final _Heard? heard;
  final Color playhead;

  @override
  void paint(Canvas canvas, Size size) {
    final step = size.width / bars.length;
    final at = heard == null ? null : heard!.seconds / length;
    final paint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = step * 0.55;
    for (var i = 0; i < bars.length; i++) {
      final x = step * (i + 0.5);
      final h = math.max(3, bars[i] * (size.height - 4));
      final middle = (i + 0.5) / bars.length;
      // Still to come while it plays: faded, filling in as it is heard.
      final colour = at != null && middle > at
          ? colours[i].withValues(alpha: colours[i].a * 0.4)
          : colours[i];
      canvas.drawLine(
        Offset(x, size.height / 2 - h / 2),
        Offset(x, size.height / 2 + h / 2),
        paint..color = colour,
      );
    }
    if (at != null) {
      final x = at.clamp(0.0, 1.0) * size.width;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        Paint()
          ..color = playhead
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_OutlinePainter old) =>
      old.bars != bars ||
      old.colours != colours ||
      old.length != length ||
      old.heard?.span != heard?.span ||
      old.playhead != playhead;
}

/// Maps a 0-100 score onto the three score tokens, by its [ScoreBand].
Color scoreColour(ThemeData theme, double score, double errorThreshold) {
  final tokens = theme.appTokens;
  return switch (ScoreBand.of(score, errorThreshold)) {
    ScoreBand.strong => tokens.scoreStrong,
    ScoreBand.fair => tokens.scoreFair,
    ScoreBand.weak => tokens.scoreWeak,
  };
}

/// The chime an attempt is answered with: in its [ScoreBand], as its score
/// is coloured. Brighter the better, and never a buzzer - a weak attempt
/// gets one soft, plain note, not a verdict.
Sound chimeFor(PronunciationResult result) =>
    switch (ScoreBand.of(result.overall, result.errorThreshold)) {
      ScoreBand.strong => Sound.scoreStrong,
      ScoreBand.fair => Sound.scoreFair,
      ScoreBand.weak => Sound.scoreWeak,
    };

/// The one thing to do on this screen, as one round button: record, stop,
/// or wait while the attempt is scored.
///
/// Absent while there is nothing to record with - the pane above then
/// carries the way forward, the settings page - so the footer never offers
/// a button that cannot work.
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
    PracticeStage.noMicrophone => const SizedBox.shrink(),
  };
}

/// The sentence read aloud, for the learner to copy - and, while it is
/// being read, the way to stop it.
///
/// Only where the device has a voice in the accent the sentence is scored
/// against: a reading in another accent would teach what the score marks
/// wrong. It steps aside while the microphone is open and the attempt is
/// scored, as the rest of the world does.
class _ListenControl extends ConsumerWidget {
  const _ListenControl({
    required this.lang,
    required this.state,
    required this.l10n,
    required this.onListen,
  });

  static const size = 52.0;

  final String lang;
  final PracticeState state;
  final AppLocalizations l10n;
  final VoidCallback onListen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final voiced = ref.watch(phraseVoiceAvailableProvider(lang)).value;
    if (voiced != true) return const SizedBox.shrink();
    final away = switch (state.stage) {
      PracticeStage.recording || PracticeStage.scoring => true,
      _ => false,
    };
    return AnimatedOpacity(
      opacity: away ? 0 : 1,
      duration: context.motion(const Duration(milliseconds: 200)),
      child: IgnorePointer(
        ignoring: away,
        child: ExcludeSemantics(
          excluding: away,
          child: IconButton.filledTonal(
            key: const Key('practice-listen'),
            onPressed: onListen,
            tooltip: state.speaking
                ? l10n.practiceListenStop
                : l10n.practiceListen,
            iconSize: 26,
            style: IconButton.styleFrom(
              fixedSize: const Size.square(size),
            ),
            icon: Icon(
              state.speaking ? Icons.stop_rounded : Icons.volume_up_rounded,
            ),
          ),
        ),
      ),
    );
  }
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
    final ripple = widget.live && !context.still;
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
    // Live, it turns from the call to action to the calm colour: the red is
    // already what it is at rest, and a change the eye can catch is the
    // point.
    final fill = widget.live ? scheme.secondary : scheme.primary;
    final ink = widget.live ? scheme.onSecondary : scheme.onPrimary;
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
  const _Score({required this.result, required this.l10n, this.scoringTime});

  final PronunciationResult result;
  final AppLocalizations l10n;

  /// How long it took to score - debug builds only, see below.
  final Duration? scoringTime;

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
                key: const Key('practice-details-overall'),
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
          // Not localised and not shipped: this is here so the cost of the
          // model is a measured number instead of an argument.
          if (kDebugMode && scoringTime != null) ...[
            const SizedBox(height: 8),
            Text(
              'scored in ${scoringTime!.inMilliseconds} ms',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The whole of an attempt's result - the numbers, the fluency beside them
/// and every phoneme that went wrong - in a sheet over the scene, for the
/// learner who wants more than the medal and the hint.
Future<void> _showDetails(
  BuildContext context,
  PronunciationResult result,
  Duration? scoringTime,
) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  backgroundColor: Colors.transparent,
  elevation: 0,
  builder: (context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.all(_Layout.gutter),
      child: SingleChildScrollView(
        child: _Score(
          result: result,
          l10n: AppLocalizations.of(context)!,
          scoringTime: scoringTime,
        ),
      ),
    ),
  ),
);

/// The word of an attempt that most needs fixing: the weakest one whose
/// wrong phoneme can be named - which is the one a hint can say something
/// about - or `null` when there is none.
int? worstWord(PronunciationResult result) {
  int? worst;
  for (final (i, word) in result.words.indexed) {
    if (word.weakest?.heardInstead == null) continue;
    if (worst == null || word.score < result.words[worst].score) worst = i;
  }
  return worst;
}

/// One word of the attempt and what went wrong in it, in a single line
/// under the sentence: "weather /ð/ sounded like /t/", and a speaker to
/// hear it said right.
///
/// A line rather than a card, so the scene stays in view - the cat comes
/// out to answer the attempt, and a card over the island hid it.
class _WordHint extends StatelessWidget {
  const _WordHint({
    required this.word,
    required this.errorThreshold,
    required this.l10n,
    required this.onHear,
    this.onHearYours,
    super.key,
  });

  final WordScore word;
  final double errorThreshold;
  final AppLocalizations l10n;
  final VoidCallback onHear;

  /// Plays the word back as the learner said it, cut from their attempt:
  /// the two buttons side by side are how it should sound, and how it did.
  final VoidCallback? onHearYours;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colour = scoreColour(theme, word.score, errorThreshold);
    final phone = word.weakest;
    final heard = phone?.heardInstead;
    return GlassSurface(
      dense: true,
      padding: const EdgeInsetsDirectional.fromSTEB(18, 4, 4, 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: word.word,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: colour,
                    ),
                  ),
                  if (phone != null && heard != null) ...[
                    TextSpan(
                      text: '  /${phone.symbol}/  ',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.appTokens.scoreWeak,
                      ),
                    ),
                    TextSpan(
                      text: l10n.practiceHeardInstead('/$heard/'),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ] else
                    TextSpan(
                      text: '  ${word.score.round()}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          ),
          IconButton(
            key: const Key('practice-hear-word'),
            onPressed: onHear,
            tooltip: l10n.practiceHearWord(word.word),
            icon: const Icon(Icons.volume_up_rounded),
          ),
          if (onHearYours case final hearYours?)
            IconButton(
              key: const Key('practice-hear-yours'),
              onPressed: hearYours,
              tooltip: l10n.practiceHearWordYours(word.word),
              icon: const Icon(Icons.record_voice_over_rounded),
            ),
        ],
      ),
    );
  }
}

/// The attempt's score as a medal beside the record button: the number
/// counting up inside a ring that fills to it, in its band's colour, and
/// one to three stars along its foot - one even for a weak attempt, which
/// still earned a try. It pops in as the score arrives; tapping it opens
/// the whole result ([_showDetails]).
class _ScoreMedal extends StatefulWidget {
  const _ScoreMedal({
    required this.result,
    required this.l10n,
    required this.onTap,
    super.key,
  });

  static const size = 64.0;

  final PronunciationResult result;
  final AppLocalizations l10n;
  final VoidCallback onTap;

  @override
  State<_ScoreMedal> createState() => _ScoreMedalState();
}

class _ScoreMedalState extends State<_ScoreMedal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _arrival = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    context.playOnce(_arrival);
  }

  @override
  void dispose() {
    _arrival.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final result = widget.result;
    final score = result.overall.round();
    final colour = scoreColour(theme, result.overall, result.errorThreshold);
    final stars = ScoreBand.of(result.overall, result.errorThreshold).index + 1;
    const size = _ScoreMedal.size;

    double span(double begin, double end, Curve curve) => curve.transform(
      ((_arrival.value - begin) / (end - begin)).clamp(0.0, 1.0),
    );

    return Semantics(
      button: true,
      label: widget.l10n.practiceScoreDetails(score),
      excludeSemantics: true,
      child: Tooltip(
        message: widget.l10n.practiceScoreDetails(score),
        child: AnimatedBuilder(
          animation: _arrival,
          builder: (context, _) {
            final fill = span(0.05, 0.6, Curves.easeOutCubic);
            return Transform.scale(
              scale: span(0, 0.45, Curves.elasticOut),
              child: SizedBox(
                width: size,
                height: size + 14,
                child: Stack(
                  alignment: Alignment.topCenter,
                  children: [
                    Material(
                      color: theme.colorScheme.surface.withValues(alpha: 0.9),
                      shape: CircleBorder(
                        side: BorderSide(
                          color: colour.withValues(alpha: 0.35),
                        ),
                      ),
                      elevation: 3,
                      shadowColor: colour,
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: widget.onTap,
                        child: SizedBox.square(
                          dimension: size,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              SizedBox.square(
                                dimension: size - 10,
                                child: CircularProgressIndicator(
                                  value: result.overall / 100 * fill,
                                  strokeWidth: 4,
                                  strokeCap: StrokeCap.round,
                                  color: colour,
                                  backgroundColor: colour.withValues(
                                    alpha: 0.18,
                                  ),
                                ),
                              ),
                              Text(
                                '${(score * fill).round()}',
                                key: const Key('practice-overall'),
                                style: theme.textTheme.titleLarge?.copyWith(
                                  color: colour,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // The stars along its foot, like a rosette's ribbon,
                    // popping in one after another.
                    Positioned(
                      bottom: 0,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (var i = 0; i < 3; i++)
                            Transform.scale(
                              scale: span(
                                0.4 + 0.12 * i,
                                0.75 + 0.12 * i,
                                Curves.elasticOut,
                              ),
                              child: Icon(
                                i < stars
                                    ? Icons.star_rounded
                                    : Icons.star_outline_rounded,
                                size: 18,
                                color: i < stars
                                    ? colour
                                    : theme.colorScheme.onSurfaceVariant
                                          .withValues(alpha: 0.5),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
