import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_full_stack_flutter/app/app.dart';
import 'package:flutter_full_stack_flutter/core/pronunciation/lexicon.dart';
import 'package:flutter_full_stack_flutter/core/pronunciation/model_store.dart';
import 'package:flutter_full_stack_flutter/features/pronunciation/presentation/language_screen.dart';
import 'package:flutter_full_stack_flutter/features/pronunciation/presentation/practice_screen.dart';
import 'package:flutter_full_stack_flutter/features/pronunciation/providers/language_pack.dart';
import 'package:flutter_full_stack_flutter/features/pronunciation/providers/practice_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/on_device.dart';

/// Where the packs are downloaded from: the server's web server, at
/// `/models`. Set by `melos run test:e2e` from `E2E_MODEL_BASE_URL`.
const _modelBaseUrl = String.fromEnvironment('MODEL_BASE_URL');

/// End-to-end: the real app on a real device, downloading a language pack
/// from a running Serverpod server and practising with it.
///
/// The download is the one thing the app asks of the server, and it is the
/// path no widget test can see: a real HTTP request to the web server's
/// static route, the bytes streamed to a `.part` file on the device's disk,
/// the progress on the button, the rename once every byte is in, and the
/// router's guard letting practice open only then. Practice itself then runs
/// on the device - the bundled lexicon, the aligner, the scorer and its
/// calibration - exactly as shipped.
///
/// Two things are stood in for, because a device in CI cannot provide them:
/// the voice reading into the microphone (`ScriptedRecorder`), and the
/// 355 MB acoustic model, which the server serves as stand-in bytes
/// (`tool/e2e_packs.dart`) and the app replaces with one that hears the
/// prompt perfectly (`ParrotModel`). So what a stand-in pack cannot pass,
/// its SHA-256, the store here is told to accept.
///
/// It needs a server serving those stand-ins:
///
///     dart run tool/e2e_packs.dart
///     MODELS_DIR=$PWD/build/e2e_packs melos run server:start   # one terminal
///     melos run test:e2e                                       # another
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a language pack downloaded from the server opens practice, '
      'and an attempt in it is scored on the device', (tester) async {
    final english = await Lexicon.load('en');

    // A folder of its own, so every run starts with the pack missing - and
    // nothing is left behind in the app's real one.
    final packs = Directory.systemTemp.createTempSync('e2e_packs');
    addTearDown(() => packs.deleteSync(recursive: true));
    final store = ModelStore(
      directory: packs,
      // The bytes are a stand-in, so they cannot match the real pack's
      // digest. Everything before and after the check is real.
      fingerprint: (_) async => english.modelSha256,
    );
    final recorder = ScriptedRecorder();
    late final ProviderContainer container;
    container = ProviderContainer(
      overrides: [
        modelStoreProvider.overrideWithValue(store),
        attemptRecorderProvider.overrideWithValue(recorder),
        phonemeModelLoaderProvider.overrideWithValue(
          (_) async => ParrotModel(
            lexicon: english,
            prompt: () => container
                .read(practiceControllerProvider('en'))
                .requireValue
                .exercise,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const App()),
    );

    // The chooser opens on English, its pack not on the device yet: the
    // button offers the download.
    final action = find.byKey(const Key('language-action-en'));
    await pumpUntilFound(
      tester,
      find.descendant(
        of: action,
        matching: find.byIcon(Icons.download_rounded),
      ),
      failure: 'The chooser never offered to download the English pack.',
    );

    await tester.tap(action);
    await pumpUntil(
      tester,
      () =>
          find.byType(PracticeScreen).evaluate().isNotEmpty ||
          container.read(languagePackControllerProvider('en')).value
              is PackMissing,
      timeout: const Duration(minutes: 2),
      failure: 'The pack neither landed nor failed in two minutes.',
    );
    final pack = container.read(languagePackControllerProvider('en')).value;
    if (pack case PackMissing(:final failure)) {
      final host = _modelBaseUrl.isEmpty
          ? 'the modelBaseUrl in assets/config.json'
          : _modelBaseUrl;
      fail(
        'The download failed: $failure\n'
        'Is a server at $host serving the stand-in packs? '
        'See `tool/e2e_packs.dart`.',
      );
    }
    expect(
      await store.isDownloaded(english.model),
      isTrue,
      reason: 'practice must only open once the pack is on the disk',
    );
    expect(
      File('${packs.path}/${english.model}.part').existsSync(),
      isFalse,
      reason: 'a pack that landed is renamed, not left as a partial download',
    );
    await tester.pumpAndSettle();

    // Practice opens on the phrases, on the first of them.
    final opened = container.read(practiceControllerProvider('en')).value!;
    final first = english.byKind(ExerciseKind.phrase).first;
    expect(opened.kind, ExerciseKind.phrase);
    expect(opened.exercise.id, first.id);
    expect(find.byKey(const Key('practice-overall')), findsNothing);

    await holdToRecord(tester);
    await pumpUntilFound(
      tester,
      find.byKey(const Key('practice-overall')),
      failure: 'The attempt was never scored.',
    );
    await tester.pumpAndSettle();

    final scored = container.read(practiceControllerProvider('en')).value!;
    expect(recorder.recorded, 1);
    expect(scored.stage, PracticeStage.scored);
    expect(scored.attempt, isNotNull, reason: 'kept to be played back');
    // A perfect reading, through the shipped calibration, must score as one.
    expect(scored.result!.overall, greaterThanOrEqualTo(80));
    expect(find.text('${scored.result!.overall.round()}'), findsOneWidget);

    // The next prompt is a swipe away, and the score stays with the prompt
    // that earned it.
    final deck = find.descendant(
      of: find.byType(PracticeScreen),
      matching: find.byType(PageView),
    );
    await tester.drag(deck, const Offset(-300, 0));
    await tester.pumpAndSettle();
    final next = container.read(practiceControllerProvider('en')).value!;
    expect(next.index, 1);
    expect(next.result, isNull);
    expect(find.byKey(const Key('practice-overall')), findsNothing);

    // Back on the chooser, the pack now shows as on the device.
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byType(LanguageScreen), findsOneWidget);
    expect(
      find.descendant(
        of: action,
        matching: find.byIcon(Icons.arrow_forward_rounded),
      ),
      findsOneWidget,
    );
  });
}
