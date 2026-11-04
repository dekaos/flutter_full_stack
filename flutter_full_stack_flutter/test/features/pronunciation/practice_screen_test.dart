import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_full_stack_flutter/core/app_settings.dart';
import 'package:flutter_full_stack_flutter/core/audio/sound.dart';
import 'package:flutter_full_stack_flutter/core/audio/sound_board.dart';
import 'package:flutter_full_stack_flutter/core/pronunciation/gop_scorer.dart';
import 'package:flutter_full_stack_flutter/core/pronunciation/lexicon.dart';
import 'package:flutter_full_stack_flutter/core/pronunciation/model_store.dart';
import 'package:flutter_full_stack_flutter/core/pronunciation/pronunciation_engine.dart';
import 'package:flutter_full_stack_flutter/features/pronunciation/presentation/hiding_cat.dart';
import 'package:flutter_full_stack_flutter/features/pronunciation/presentation/practice_screen.dart';
import 'package:flutter_full_stack_flutter/features/pronunciation/presentation/prompt_scene.dart';
import 'package:flutter_full_stack_flutter/features/pronunciation/presentation/scenes/cat.dart';
import 'package:flutter_full_stack_flutter/features/pronunciation/providers/practice_audio.dart';
import 'package:flutter_full_stack_flutter/features/pronunciation/providers/practice_controller.dart';
import 'package:flutter_full_stack_flutter/l10n/app_localizations.dart';
import 'package:flutter_full_stack_flutter/theme/app_theme.dart';
import 'package:flutter_full_stack_flutter/theme/app_tokens.dart';
import 'package:flutter_full_stack_flutter/theme/glass_surface.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_audio.dart';
import '../../support/practice.dart';

class _FakeAppSettings implements AppSettings {
  int opened = 0;

  @override
  Future<void> open() async => opened++;
}

const _exercise = Exercise(
  id: 'en-001',
  text: 'The weather is beautiful today',
  words: [
    LexiconWord(word: 'The', phoneStart: 0, phoneEnd: 1),
    LexiconWord(word: 'weather', phoneStart: 1, phoneEnd: 2),
  ],
  phones: [
    LexiconPhone(symbol: 'ð', tokenIds: [10]),
    LexiconPhone(symbol: 'w', tokenIds: [11]),
  ],
);

Widget _app(
  PracticeState state, {
  AppSettings? settings,
  SoundBoard? board,
  ThemeMode theme = ThemeMode.light,
}) => ProviderScope(
  overrides: [
    appSettingsProvider.overrideWithValue(settings ?? _FakeAppSettings()),
    soundBoardProvider.overrideWithValue(board ?? fakeSoundBoard()),
    // A family override is handed the argument, so the stub stands in for
    // every language rather than only the one the test happens to open.
    practiceControllerProvider.overrideWith2(
      (_) => StubPracticeController(state),
    ),
  ],
  child: MaterialApp(
    theme: AppTheme.light(),
    darkTheme: AppTheme.dark(),
    themeMode: theme,
    locale: const Locale('en'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    home: const PracticeScreen(lang: 'en'),
  ),
);

const _word = Exercise(
  id: 'en-w01',
  kind: ExerciseKind.word,
  text: 'think',
  words: [LexiconWord(word: 'think', phoneStart: 0, phoneEnd: 1)],
  phones: [
    LexiconPhone(symbol: 'θ', tokenIds: [10]),
  ],
);

const _sunny = Exercise(
  id: 'en-p01',
  text: 'The weather is beautiful today',
  topic: PromptTopic.weather,
  words: [],
  phones: [],
);

const _coffee = Exercise(
  id: 'en-p03',
  text: 'I would like a cup of coffee please',
  topic: PromptTopic.coffee,
  words: [],
  phones: [],
);

void main() {
  testWidgets('offers the download before the pack is on the device', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const PracticeState(
          stage: PracticeStage.needsModel,
          kind: ExerciseKind.phrase,
          items: [_exercise],
          index: 0,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('practice-download')), findsOneWidget);
    // The size has to be on screen before the tap, not after it starts.
    expect(find.textContaining('355 MB'), findsOneWidget);
    expect(find.byKey(const Key('practice-record')), findsNothing);
  });

  // Once every byte is in, the pack is checked for a couple of seconds: the
  // bar must not sit full while nothing seems to happen.
  for (final (progress, says, bar) in [
    (const DownloadProgress(received: 50, total: 100), 'Downloading', 0.5),
    (
      const DownloadProgress(received: 100, total: 100, checking: true),
      'Checking',
      null,
    ),
  ]) {
    testWidgets('a download says "$says", with a bar at $bar', (tester) async {
      final l10n = lookupAppLocalizations(const Locale('en'));
      await tester.pumpWidget(
        _app(
          PracticeState(
            stage: PracticeStage.downloading,
            kind: ExerciseKind.phrase,
            items: const [_exercise],
            index: 0,
            download: progress,
          ),
        ),
      );
      // Not pumpAndSettle: an indeterminate bar never settles.
      await tester.pump(const Duration(seconds: 1));

      expect(
        find.text(
          progress.checking ? l10n.practiceChecking : l10n.practiceDownloading,
        ),
        findsOneWidget,
      );
      expect(
        tester
            .widget<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator),
            )
            .value,
        bar,
      );
    });
  }

  testWidgets('a bad phoneme says what it sounded like instead', (
    tester,
  ) async {
    final result = PronunciationResult(
      overall: 35,
      accuracy: 35,
      fluency: 92,
      speechRate: 11,
      pauses: 0,
      words: [
        WordScore(
          word: 'The',
          start: 0,
          end: 0.2,
          score: 12,
          phones: [phone('ð', 12, heard: 't')],
          // Set by the scorer in real use: the weakest phoneme is only
          // reported when the measurement can name what replaced it.
          weakest: phone('ð', 12, heard: 't'),
        ),
        WordScore(
          word: 'weather',
          start: 0.2,
          end: 0.6,
          score: 88,
          phones: [phone('w', 88)],
        ),
      ],
    );

    await tester.pumpWidget(
      _app(
        PracticeState(
          stage: PracticeStage.scored,
          kind: ExerciseKind.phrase,
          items: [_exercise],
          index: 0,
          result: result,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('practice-overall')), findsOneWidget);
    expect(find.text('35'), findsOneWidget);
    // The number alone is not feedback; naming the substitution is - and it
    // is on screen without asking, for the word that most needs it.
    expect(find.textContaining('sounded like /t/'), findsOneWidget);

    // The rest is one tap on the score away.
    await tester.tap(find.byKey(const Key('practice-overall')));
    await tester.pumpAndSettle();
    // Fluency is reported, but never as part of the grade: a high rhythm
    // number next to a low score must not read as a better result.
    expect(find.textContaining('Fluency 92'), findsOneWidget);
    expect(find.textContaining('diagnostic only'), findsOneWidget);
    expect(find.byKey(const Key('practice-details-overall')), findsOneWidget);
  });

  testWidgets('a failed attempt keeps the deck and says what to do', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const PracticeState(
          stage: PracticeStage.ready,
          kind: ExerciseKind.phrase,
          items: [_exercise],
          index: 0,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(PracticeScreen)),
    );
    (container.read(
      practiceControllerProvider('en').notifier,
    ) as StubPracticeController).fail(
      PracticeFailure(
        PracticeStep.score,
        ArgumentError('audio too short: 3 frames for 5 tokens'),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('This attempt could not be scored. Record it again.'),
      findsOneWidget,
    );
    // The prompt and the way to try again are both still there.
    expect(find.byKey(ValueKey(_exercise.id)), findsOneWidget);
    expect(find.bySemanticsLabel(_exercise.text), findsOneWidget);
    expect(find.byKey(const Key('practice-record')), findsOneWidget);
  });

  test('a damaged pack says it will download afresh; a dropped one, that it '
      'picks up where it stopped', () {
    final l10n = lookupAppLocalizations(const Locale('en'));

    expect(
      failureMessage(
        l10n,
        const PracticeFailure(
          PracticeStep.download,
          ModelIntegrityException('pack', expected: 'a', actual: 'b'),
        ),
      ),
      l10n.practiceDownloadDamaged,
    );
    expect(
      failureMessage(
        l10n,
        PracticeFailure(
          PracticeStep.download,
          ModelDownloadException(Uri.parse('http://host/pack'), 'closed'),
        ),
      ),
      l10n.practiceDownloadFailed,
    );
  });

  test('an attempt turned away says why, not that scoring broke', () {
    final l10n = lookupAppLocalizations(const Locale('en'));

    expect(
      failureMessage(
        l10n,
        const PracticeFailure(
          PracticeStep.score,
          AttemptRejected(RejectedBecause.notHeard),
        ),
      ),
      l10n.practiceNotHeard,
    );
    expect(
      failureMessage(
        l10n,
        const PracticeFailure(
          PracticeStep.score,
          AttemptRejected(RejectedBecause.tooShort),
        ),
      ),
      l10n.practiceTooShort,
    );
  });

  testWidgets('a refused microphone offers the way to settings', (
    tester,
  ) async {
    final settings = _FakeAppSettings();
    await tester.pumpWidget(
      _app(
        const PracticeState(
          stage: PracticeStage.noMicrophone,
          kind: ExerciseKind.phrase,
          items: [_exercise],
          index: 0,
        ),
        settings: settings,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open settings'));
    expect(settings.opened, 1);

    // Back from settings: the screen looks at the permission again.
    final binding = tester.binding
      ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
      ..handleAppLifecycleStateChanged(AppLifecycleState.hidden)
      ..handleAppLifecycleStateChanged(AppLifecycleState.paused)
      ..handleAppLifecycleStateChanged(AppLifecycleState.hidden)
      ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
      ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(PracticeScreen)),
    );
    final controller = container.read(
      practiceControllerProvider('en').notifier,
    ) as StubPracticeController;
    expect(controller.rechecks, 1);
    expect(binding.lifecycleState, AppLifecycleState.resumed);
  });

  testWidgets('the deck says which prompt of how many is up', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      _app(
        const PracticeState(
          stage: PracticeStage.ready,
          kind: ExerciseKind.phrase,
          items: [_sunny, _coffee],
          index: 0,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Dots on screen, words for a screen reader.
    expect(find.bySemanticsLabel('1 of 2'), findsOneWidget);
    // The screen is the sentence, the world and the button - no headline,
    // no deck switcher competing with them.
    expect(find.byType(SegmentedButton<ExerciseKind>), findsNothing);
    semantics.dispose();
  });

  testWidgets('while the learner speaks, the world steps back', (
    tester,
  ) async {
    double hush() => tester
        .widget<AnimatedOpacity>(find.byKey(const Key('practice-hush')))
        .opacity;

    await tester.pumpWidget(
      _app(
        const PracticeState(
          stage: PracticeStage.ready,
          kind: ExerciseKind.phrase,
          items: [_sunny],
          index: 0,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(hush(), 0);
    expect(find.byKey(const Key('practice-record')), findsOneWidget);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(PracticeScreen)),
    );
    (container.read(
      practiceControllerProvider('en').notifier,
    ) as StubPracticeController).show(
      const PracticeState(
        stage: PracticeStage.recording,
        kind: ExerciseKind.phrase,
        items: [_sunny],
        index: 0,
      ),
    );
    // The ripple around the stop button runs while the microphone is open,
    // so this cannot settle - which is the point of it.
    await tester.pump(const Duration(milliseconds: 500));
    expect(hush(), 1);
    expect(find.byKey(const Key('practice-stop')), findsOneWidget);
    expect(tester.hasRunningAnimations, isTrue);
  });

  testWidgets('scoring keeps the button, busy', (tester) async {
    await tester.pumpWidget(
      _app(
        const PracticeState(
          stage: PracticeStage.scoring,
          kind: ExerciseKind.phrase,
          items: [_sunny],
          index: 0,
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));

    final button = find.descendant(
      of: find.byKey(const Key('practice-scoring')),
      matching: find.byType(IconButton),
    );
    expect(tester.widget<IconButton>(button).onPressed, isNull);
    expect(find.byTooltip('Scoring'), findsOneWidget);
  });

  testWidgets('a word attempt shows no fluency block', (tester) async {
    await tester.pumpWidget(
      _app(
        PracticeState(
          stage: PracticeStage.scored,
          kind: ExerciseKind.word,
          items: const [_word],
          index: 0,
          result: PronunciationResult(
            overall: 72,
            accuracy: 72,
            fluency: null,
            speechRate: 0,
            pauses: 0,
            words: [
              WordScore(
                word: 'think',
                start: 0,
                end: 0.4,
                score: 72,
                phones: [phone('θ', 72)],
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('72'), findsOneWidget);
    await tester.tap(find.byKey(const Key('practice-overall')));
    await tester.pumpAndSettle();
    expect(find.textContaining('diagnostic only'), findsNothing);
  });

  testWidgets('a phrase is drawn behind, and swiping moves the picture on', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const PracticeState(
          stage: PracticeStage.ready,
          kind: ExerciseKind.phrase,
          items: [_sunny, _coffee],
          index: 0,
        ),
      ),
    );
    await tester.pumpAndSettle();

    PromptTopic? drawn() =>
        tester.widget<PromptScene>(find.byType(PromptScene)).topic;
    expect(drawn(), PromptTopic.weather);

    await tester.fling(
      find.byKey(ValueKey(_sunny.id)),
      const Offset(-600, 0),
      1000,
    );
    await tester.pumpAndSettle();

    expect(
      tester.widget<PromptScene>(find.byType(PromptScene)).topic,
      PromptTopic.coffee,
    );
    expect(drawn(), PromptTopic.coffee);
  });

  testWidgets('the cat hiding in the scene comes out when the learner '
      'pauses, and only where there is a scene', (tester) async {
    CatGesture? cat() =>
        tester.widget<PromptScene>(find.byType(PromptScene)).cat.value.gesture;

    await tester.pumpWidget(
      _app(
        const PracticeState(
          stage: PracticeStage.ready,
          kind: ExerciseKind.phrase,
          items: [_sunny],
          index: 0,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(cat(), isNull);
    await tester.pump(HidingCat.patience);
    await tester.pump();
    expect(cat(), CatGesture.lick);
    await tester.pumpAndSettle();

    // A word has no scene, and nowhere for a cat to be.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      _app(
        const PracticeState(
          stage: PracticeStage.ready,
          kind: ExerciseKind.word,
          items: [_word],
          index: 0,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.pump(HidingCat.patience);
    await tester.pump();
    expect(cat(), isNull);
  });

  testWidgets('a word has no scene', (tester) async {
    await tester.pumpWidget(
      _app(
        const PracticeState(
          stage: PracticeStage.ready,
          kind: ExerciseKind.word,
          items: [_word],
          index: 0,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.widget<PromptScene>(find.byType(PromptScene)).topic, isNull);
  });

  testWidgets('the prompt is coloured word by word', (tester) async {
    final result = PronunciationResult(
      overall: 50,
      accuracy: 50,
      fluency: 50,
      speechRate: 11,
      pauses: 0,
      words: [
        WordScore(
          word: 'The',
          start: 0,
          end: 0.2,
          score: 12,
          phones: [phone('ð', 12)],
        ),
        WordScore(
          word: 'weather',
          start: 0.2,
          end: 0.6,
          score: 92,
          phones: [phone('w', 92)],
        ),
      ],
    );

    await tester.pumpWidget(
      _app(
        PracticeState(
          stage: PracticeStage.scored,
          kind: ExerciseKind.phrase,
          items: [_exercise],
          index: 0,
          result: result,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final tokens = AppTheme.light().extension<AppTokens>()!;
    final weak = tester.widget<Text>(find.text('The'));
    final strong = tester.widget<Text>(find.text('weather'));
    expect(weak.style?.color, tokens.scoreWeak);
    expect(strong.style?.color, tokens.scoreStrong);
  });

  group('hearing yourself', () {
    // A second of recording: "The" over its first fifth, "weather" from
    // 0.2 s to 0.6 s.
    final attempt = Float32List(16000);
    PracticeState withAttempt() => PracticeState(
      stage: PracticeStage.scored,
      kind: ExerciseKind.phrase,
      items: const [_sunny],
      index: 0,
      attempt: attempt,
      result: scored(57, fluency: 100, words: theWeather()),
    );

    TextStyle? styleOf(WidgetTester tester, String word) =>
        tester.widget<Text>(find.text(word).first).style;

    testWidgets('the attempt is a voice message: tap it to hear yourself', (
      tester,
    ) async {
      final speakers = FakeSoundOutput();
      final board = SoundBoard(output: speakers, voice: FakeVoice());
      await tester.pumpWidget(_app(withAttempt(), board: board));
      await tester.pumpAndSettle();

      expect(find.byTooltip('Hear yourself'), findsOneWidget);
      await tester.tap(find.byKey(const Key('practice-replay')));
      await tester.pump();
      expect(speakers.clips, hasLength(1));
      expect(find.byTooltip('Stop playback'), findsOneWidget);

      speakers.finishClip();
      await tester.pumpAndSettle();
      expect(find.byTooltip('Hear yourself'), findsOneWidget);
    });

    testWidgets('played back, each word lights up as it is heard, and the '
        'ones to come wait faded', (tester) async {
      final speakers = FakeSoundOutput();
      final board = SoundBoard(output: speakers, voice: FakeVoice());
      await tester.pumpWidget(_app(withAttempt(), board: board));
      await tester.pumpAndSettle();
      final tokens = AppTheme.light().extension<AppTokens>()!;

      await tester.tap(find.byKey(const Key('practice-replay')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      // Saying "The": it is lit, "weather" is still to come.
      expect(styleOf(tester, 'The')?.decoration, TextDecoration.underline);
      expect(
        styleOf(tester, 'weather')?.color,
        tokens.scoreWeak.withValues(alpha: 0.4),
      );

      await tester.pump(const Duration(milliseconds: 300));
      // On to "weather"; "The" has been said.
      expect(styleOf(tester, 'weather')?.decorationThickness, 3);
      expect(styleOf(tester, 'weather')?.color, tokens.scoreWeak);
      expect(
        styleOf(tester, 'The')?.decoration,
        isNot(TextDecoration.underline),
      );

      speakers.finishClip();
      await tester.pumpAndSettle();
      expect(styleOf(tester, 'weather')?.decorationThickness, 2);
    });

    testWidgets('a word can be heard as it should sound, and as it was '
        'said', (tester) async {
      final speakers = FakeSoundOutput();
      final voice = FakeVoice();
      final board = SoundBoard(output: speakers, voice: voice);
      await tester.pumpWidget(_app(withAttempt(), board: board));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('practice-hear-word')));
      await tester.pump();
      expect(voice.said, ['weather']);

      await tester.tap(find.byKey(const Key('practice-hear-yours')));
      await tester.pumpAndSettle();
      // 0.2 to 0.6 s of the attempt, and a breath either side.
      final samples = (speakers.clips.single.lengthInBytes - 44) ~/ 2;
      expect(samples, closeTo(0.56 * 16000, 1));
      expect(voice.speaking.value, isFalse, reason: 'both at once');
    });
  });

  group('reading aloud', () {
    const ready = PracticeState(
      stage: PracticeStage.ready,
      kind: ExerciseKind.phrase,
      items: [_sunny],
      index: 0,
    );

    TextStyle? styleOf(WidgetTester tester, String word) =>
        tester.widget<Text>(find.text(word).first).style;

    testWidgets('the sentence lights up word by word as the voice reads it, '
        'before any attempt', (tester) async {
      final voice = FakeVoice();
      final board = SoundBoard(output: FakeSoundOutput(), voice: voice);
      await tester.pumpWidget(_app(ready, board: board));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('practice-listen')));
      await tester.pump();
      expect(voice.said, [_sunny.text]);

      // "The weather is beautiful today": the engine reaches "weather".
      voice.reach(4, 11);
      await tester.pump();
      expect(styleOf(tester, 'weather')?.decorationThickness, 3);
      expect(styleOf(tester, 'weather')?.decoration, TextDecoration.underline);
      expect(styleOf(tester, 'today')!.color!.a, lessThan(0.5));
      expect(styleOf(tester, 'The')!.color!.a, 1);

      voice.reach(25, 30);
      await tester.pump();
      expect(styleOf(tester, 'today')?.decorationThickness, 3);
      expect(styleOf(tester, 'today')!.color!.a, 1);

      voice.finish();
      await tester.pumpAndSettle();
      expect(
        styleOf(tester, 'today')?.decoration,
        isNot(TextDecoration.underline),
      );
    });

    testWidgets('after an attempt too, in its colours - but one word read '
        'alone lights nothing', (tester) async {
      final voice = FakeVoice();
      final board = SoundBoard(output: FakeSoundOutput(), voice: voice);
      final result = PronunciationResult(
        overall: 70,
        accuracy: 70,
        fluency: 80,
        speechRate: 12,
        pauses: 0,
        words: [
          WordScore(
            word: 'The',
            start: 0,
            end: 0.2,
            score: 90,
            phones: [phone('ð', 90)],
          ),
          WordScore(
            word: 'weather',
            start: 0.2,
            end: 0.6,
            score: 40,
            phones: [phone('ð', 40, heard: 'd')],
            weakest: phone('ð', 40, heard: 'd'),
          ),
        ],
      );
      await tester.pumpWidget(
        _app(
          ready.copyWith(stage: PracticeStage.scored, result: result),
          board: board,
        ),
      );
      await tester.pumpAndSettle();
      final tokens = AppTheme.light().extension<AppTokens>()!;

      await tester.tap(find.byKey(const Key('practice-listen')));
      await tester.pump();
      voice.reach(0, 3);
      await tester.pump();
      expect(styleOf(tester, 'The')?.decorationThickness, 3);
      expect(styleOf(tester, 'The')?.color, tokens.scoreStrong);
      expect(
        styleOf(tester, 'weather')?.color,
        tokens.scoreWeak.withValues(alpha: 0.4),
      );

      // The hint's speaker reads "weather" on its own.
      await tester.tap(find.byKey(const Key('practice-hear-word')));
      await tester.pumpAndSettle();
      voice.reach(0, 7);
      await tester.pump();
      expect(styleOf(tester, 'weather')?.decorationThickness, 2);
      expect(styleOf(tester, 'The')?.decorationThickness, 2);
    });
  });

  group('the deck', () {
    const two = PracticeState(
      stage: PracticeStage.ready,
      kind: ExerciseKind.phrase,
      items: [_sunny, _coffee],
      index: 0,
    );

    Finder card(Exercise prompt) => find.ancestor(
      of: find.byKey(ValueKey(prompt.id)),
      matching: find.byType(GlassSurface),
    );

    Widget still(Widget app) => MediaQuery(
      data: const MediaQueryData(disableAnimations: true),
      child: app,
    );

    testWidgets('cards pass a gutter apart as they are swiped, instead of '
        'touching', (tester) async {
      await tester.pumpWidget(still(_app(two)));
      await tester.pumpAndSettle();
      final resting = tester.getRect(card(_sunny));

      final swipe = await tester.startGesture(resting.center);
      await swipe.moveBy(Offset(-resting.width / 2, 0));
      await tester.pump();
      final going = tester.getRect(card(_sunny));
      final coming = tester.getRect(card(_coffee));
      expect(coming.left - going.right, closeTo(2 * 20, 0.5));
      await swipe.up();
      await tester.pumpAndSettle();
    });

    testWidgets('changing the theme leaves the card where it is, not tipped '
        'as if half swiped', (tester) async {
      await tester.pumpWidget(_app(two));
      await tester.pumpAndSettle();
      await tester.fling(
        find.byKey(ValueKey(_sunny.id)),
        const Offset(-600, 0),
        1000,
      );
      await tester.pumpAndSettle();
      final resting = tester.getRect(card(_coffee));

      await tester.pumpWidget(_app(two, theme: ThemeMode.dark));
      await tester.pumpAndSettle();
      expect(tester.getRect(card(_coffee)), resting);
    });

    testWidgets('cards fan as they are swiped, and settle back exactly in '
        'place', (tester) async {
      await tester.pumpWidget(_app(two));
      await tester.pumpAndSettle();
      final resting = tester.getRect(card(_sunny));
      expect(resting.left, 20, reason: 'not on the gutter at rest');

      final swipe = await tester.startGesture(resting.center);
      await swipe.moveBy(Offset(-resting.width / 3, 0));
      await tester.pump();
      final going = tester.getRect(card(_sunny));
      // Tipped and shrunk, not only slid along.
      expect(going.size, isNot(resting.size));
      // Let go short of the next card, it springs back - all the way.
      await swipe.up();
      await tester.pumpAndSettle();
      expect(tester.getRect(card(_sunny)), resting);
    });
  });

  group('the result', () {
    PronunciationResult missedTwo() =>
        scored(57, fluency: 100, words: theWeather());

    PracticeState showing(PronunciationResult result) => PracticeState(
      stage: PracticeStage.scored,
      kind: ExerciseKind.phrase,
      items: const [_sunny],
      index: 0,
      result: result,
    );

    testWidgets('leaves the scene in view: a medal beside the record '
        'button, and one line under the sentence', (tester) async {
      await tester.pumpWidget(_app(showing(missedTwo())));
      await tester.pumpAndSettle();

      final record = tester.getRect(find.byKey(const Key('practice-record')));
      final medal = tester.getRect(find.byKey(const Key('practice-overall')));
      // In the footer, across the record button from the reading.
      expect(medal.center.dx, greaterThan(record.right));
      expect(medal.center.dy, closeTo(record.center.dy, 30));

      final hint = tester.getRect(
        find.ancestor(
          of: find.byKey(const Key('practice-hear-word')),
          matching: find.byType(GlassSurface),
        ),
      );
      expect(hint.height, lessThan(64), reason: 'a line, not a card');
      // No card of numbers over the island until it is asked for.
      expect(find.byKey(const Key('practice-details-overall')), findsNothing);
      expect(find.textContaining('Fluency'), findsNothing);
    });

    testWidgets('starts on the word that most needs fixing; tapping another '
        'says what went wrong there, and reads it aloud', (tester) async {
      final voice = FakeVoice();
      final board = SoundBoard(output: FakeSoundOutput(), voice: voice);
      await tester.pumpWidget(_app(showing(missedTwo()), board: board));
      await tester.pumpAndSettle();
      expect(find.textContaining('sounded like /t/'), findsOneWidget);
      expect(find.textContaining('sounded like /w/'), findsNothing);

      await tester.tap(find.text('The'));
      await tester.pumpAndSettle();
      expect(find.textContaining('sounded like /w/'), findsOneWidget);
      expect(voice.said, ['The']);

      await tester.tap(find.byKey(const Key('practice-hear-word')));
      await tester.pump();
      expect(voice.said, ['The', 'The']);
    });

    testWidgets('the medal shows its band in stars - one, even for a weak '
        'attempt', (tester) async {
      for (final (overall, stars) in [(35.0, 1), (70.0, 2), (92.0, 3)]) {
        await tester.pumpWidget(
          _app(showing(scored(overall))),
        );
        await tester.pumpAndSettle();
        expect(
          find.byIcon(Icons.star_rounded),
          findsNWidgets(stars),
          reason: 'scored $overall',
        );
        expect(find.text('${overall.round()}'), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
      }
    });
  });

  group('sound', () {
    const ready = PracticeState(
      stage: PracticeStage.ready,
      kind: ExerciseKind.phrase,
      items: [_sunny],
      index: 0,
    );

    testWidgets('an attempt is answered with a chime in its band, once', (
      tester,
    ) async {
      final speakers = FakeSoundOutput();
      final board = SoundBoard(output: speakers, voice: FakeVoice());
      await tester.pumpWidget(_app(ready, board: board));
      await tester.pumpAndSettle();
      speakers.played.clear();

      final controller =
          ProviderScope.containerOf(
                tester.element(find.byType(PracticeScreen)),
              ).read(practiceControllerProvider('en').notifier)
              as StubPracticeController;
      for (final (score, chime) in [
        (92.0, Sound.scoreStrong),
        (70.0, Sound.scoreFair),
        (35.0, Sound.scoreWeak),
      ]) {
        controller.show(
          ready.copyWith(stage: PracticeStage.scored, result: scored(score)),
        );
        await tester.pump();
        expect(speakers.sounds.where(chimes.contains), [chime]);
        // Rebuilt with the same score, it is not answered again.
        controller.show(ready.copyWith(stage: PracticeStage.scored));
        await tester.pump();
        expect(speakers.sounds.where(chimes.contains), [chime]);
        speakers.played.clear();
      }
      await tester.pumpAndSettle();
    });

    testWidgets('coming straight here, it is only got ready once the first '
        'scene has arrived - never while it arrives', (tester) async {
      final speakers = FakeSoundOutput();
      final board = SoundBoard(output: speakers, voice: FakeVoice());
      await tester.pumpWidget(_app(ready, board: board));
      await tester.pump(
        PromptScene.arrival - const Duration(milliseconds: 100),
      );
      expect(speakers.warmed, isFalse);
      await tester.pump(const Duration(milliseconds: 200));
      expect(speakers.warmed, isTrue);
    });

    testWidgets('can be turned off from the app bar, and on again', (
      tester,
    ) async {
      await tester.pumpWidget(_app(ready));
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(PracticeScreen)),
      );
      expect(container.read(soundEffectsProvider), isTrue);
      expect(find.byTooltip('Sounds on'), findsOneWidget);

      await tester.tap(find.byKey(const Key('app-sounds')));
      await tester.pump();
      expect(container.read(soundEffectsProvider), isFalse);
      expect(find.byTooltip('Sounds off'), findsOneWidget);

      await tester.tap(find.byKey(const Key('app-sounds')));
      await tester.pump();
      expect(container.read(soundEffectsProvider), isTrue);
    });

    testWidgets('the sentence can be listened to, and the reading stopped', (
      tester,
    ) async {
      final voice = FakeVoice();
      final board = SoundBoard(output: FakeSoundOutput(), voice: voice);
      await tester.pumpWidget(_app(ready, board: board));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('practice-listen')));
      await tester.pump();
      expect(voice.said, [_sunny.text]);
      expect(find.byTooltip('Stop reading'), findsOneWidget);

      await tester.tap(find.byKey(const Key('practice-listen')));
      await tester.pumpAndSettle();
      expect(voice.speaking.value, isFalse);
      expect(find.byTooltip('Listen'), findsOneWidget);
    });

    testWidgets('there is nothing to listen to without a voice in the '
        "sentence's accent", (tester) async {
      final board = SoundBoard(
        output: FakeSoundOutput(),
        voice: FakeVoice(available: false),
      );
      await tester.pumpWidget(_app(ready, board: board));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('practice-listen')), findsNothing);
      expect(find.byKey(const Key('practice-record')), findsOneWidget);
    });

    testWidgets('while the microphone is open, listening steps aside', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(ready.copyWith(stage: PracticeStage.recording)),
      );
      // Not settled: the record button ripples for as long as it records.
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(
        find.byKey(const Key('practice-listen')),
        warnIfMissed: false,
      );
      await tester.pump();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(PracticeScreen)),
      );
      final voice = container.read(soundBoardProvider).voice as FakeVoice;
      expect(voice.said, isEmpty);
    });
  });
}

const Set<Sound> chimes = {Sound.scoreStrong, Sound.scoreFair, Sound.scoreWeak};
