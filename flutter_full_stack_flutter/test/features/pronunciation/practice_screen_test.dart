import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_full_stack_flutter/core/app_settings.dart';
import 'package:flutter_full_stack_flutter/core/pronunciation/gop_scorer.dart';
import 'package:flutter_full_stack_flutter/core/pronunciation/lexicon.dart';
import 'package:flutter_full_stack_flutter/core/pronunciation/pronunciation_engine.dart';
import 'package:flutter_full_stack_flutter/features/pronunciation/presentation/practice_screen.dart';
import 'package:flutter_full_stack_flutter/features/pronunciation/providers/practice_controller.dart';
import 'package:flutter_full_stack_flutter/l10n/app_localizations.dart';
import 'package:flutter_full_stack_flutter/theme/app_theme.dart';
import 'package:flutter_full_stack_flutter/theme/app_tokens.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _StubPracticeController extends PracticeController {
  _StubPracticeController(this.value);

  final PracticeState value;

  @override
  FutureOr<PracticeState> build(String lang) => value;

  /// What the real controller does when an action fails: the error goes on
  /// top of the value it happened to, which Riverpod keeps.
  void fail(PracticeFailure failure) =>
      state = AsyncError(failure, StackTrace.empty);

  int rechecks = 0;

  @override
  Future<void> recheckMicrophone() async => rechecks++;
}

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

PhoneScore _phone(String symbol, double score, {String? heard}) => PhoneScore(
  symbol: symbol,
  start: 0,
  end: 0.2,
  logPosterior: -1,
  margin: 0.5,
  score: score,
  heardInstead: heard,
);

Widget _app(PracticeState state, {AppSettings? settings}) => ProviderScope(
  overrides: [
    appSettingsProvider.overrideWithValue(settings ?? _FakeAppSettings()),
    // A family override is handed the argument, so the stub stands in for
    // every language rather than only the one the test happens to open.
    practiceControllerProvider.overrideWith2(
      (_) => _StubPracticeController(state),
    ),
  ],
  child: MaterialApp(
    theme: AppTheme.light(),
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
          phones: [_phone('ð', 12, heard: 't')],
          // Set by the scorer in real use: the weakest phoneme is only
          // reported when the measurement can name what replaced it.
          weakest: _phone('ð', 12, heard: 't'),
        ),
        WordScore(
          word: 'weather',
          start: 0.2,
          end: 0.6,
          score: 88,
          phones: [_phone('w', 88)],
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
    // Fluency is reported, but never as part of the grade: a high rhythm
    // number next to a low score must not read as a better result.
    expect(find.textContaining('Fluency 92'), findsOneWidget);
    expect(find.textContaining('diagnostic only'), findsOneWidget);
    // The number alone is not feedback; naming the substitution is.
    expect(find.textContaining('sounded like /t/'), findsOneWidget);
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
    ) as _StubPracticeController).fail(
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
    expect(find.text('The weather is beautiful today'), findsOneWidget);
    expect(find.byKey(const Key('practice-record')), findsOneWidget);
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
    ) as _StubPracticeController;
    expect(controller.rechecks, 1);
    expect(binding.lifecycleState, AppLifecycleState.resumed);
  });

  testWidgets('the deck says which prompt of how many is up', (tester) async {
    await tester.pumpWidget(
      _app(
        const PracticeState(
          stage: PracticeStage.ready,
          kind: ExerciseKind.word,
          items: [_word, _exercise],
          index: 0,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('1 of 2'), findsOneWidget);
    expect(find.byKey(const Key('practice-kind')), findsOneWidget);
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
                phones: [_phone('θ', 72)],
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('72'), findsOneWidget);
    expect(find.textContaining('diagnostic only'), findsNothing);
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
          phones: [_phone('ð', 12)],
        ),
        WordScore(
          word: 'weather',
          start: 0.2,
          end: 0.6,
          score: 92,
          phones: [_phone('w', 92)],
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
}
