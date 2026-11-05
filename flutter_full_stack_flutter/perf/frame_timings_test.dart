import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_full_stack_flutter/app/app.dart';
import 'package:flutter_full_stack_flutter/core/pronunciation/lexicon.dart';
import 'package:flutter_full_stack_flutter/core/pronunciation/model_store.dart';
import 'package:flutter_full_stack_flutter/features/pronunciation/presentation/practice_screen.dart';
import 'package:flutter_full_stack_flutter/features/pronunciation/providers/language_pack.dart';
import 'package:flutter_full_stack_flutter/features/pronunciation/providers/practice_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../integration_test/support/on_device.dart';

/// Measures what the app costs to render, so that growth shows up as a number
/// instead of as a complaint.
///
/// Two screens, each its own summary in the report, so a regression says
/// which one it is in:
///
/// - `language_screen`: the chooser, opened from the word hunt the app
///   now launches into - the aurora drifting in, the headline and panel
///   rising - then each place arriving as its page
///   comes into view, the parallax of a swipe, a tab tap animating across
///   two pages, and the theme flipped both ways (four `ThemeData` rebuilt,
///   every glass surface repainted over a full-screen scene).
/// - `practice_screen`: opening practice, its scene arriving behind the
///   glass deck, the deck swiped to the next prompt and its scene changing,
///   an attempt held - the hush over the scene, the halo rippling, the
///   countdown - and its score revealed: the medal, the voice message, the
///   hint, the cat answering.
///
/// This is deliberately a separate suite from `integration_test/`. That one
/// proves behaviour and needs a server; this one touches no network at all,
/// which is what makes it cheap enough to run on every change. The English
/// pack is planted on the disk instead of downloaded, the microphone is
/// `ScriptedRecorder` and the model `ParrotModel` - what they replace is not
/// what this measures.
///
/// Run it through the driver so the numbers reach a file:
///
///     melos run perf
///
/// **Profile mode matters more than anything else here.** A debug build keeps
/// assertions on and skips ahead-of-time compilation, which inflates raster
/// time by an order of magnitude. Debug numbers are only comparable to other
/// debug numbers, which is why the build mode is written into the report and
/// the budget tool keys its baselines by it.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the language chooser, then practice', (tester) async {
    final english = await Lexicon.load('en');
    final packs = Directory.systemTemp.createTempSync('perf_packs');
    addTearDown(() => packs.deleteSync(recursive: true));
    // English is on the device, so practice opens on it; the other two show
    // their download, as they would for a learner who has picked one.
    File('${packs.path}/${english.model}').writeAsStringSync('stand-in');

    late final ProviderContainer container;
    container = ProviderContainer(
      overrides: [
        modelStoreProvider.overrideWithValue(ModelStore(directory: packs)),
        attemptRecorderProvider.overrideWithValue(ScriptedRecorder()),
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

    // Launch, outside the measurement: the app opens on the word hunt now,
    // which has no baseline yet, and what is measured here is the chooser
    // it leads to - its entrance included, as it rises in over the word
    // hunt.
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const App()),
    );
    await openPronunciation(tester);

    await binding.watchPerformance(() async {
      await pumpUntilFound(
        tester,
        find.descendant(
          of: find.byKey(const Key('language-action-en')),
          matching: find.byIcon(Icons.arrow_forward_rounded),
        ),
        failure: 'The chooser never showed the English pack as ready.',
      );
      await tester.pumpAndSettle();

      // A swipe, as a learner moves on: the place lags its page, and the
      // next one arrives as it comes into view.
      await tester.fling(
        find.byType(PageView),
        const Offset(-300, 0),
        1000,
      );
      await tester.pumpAndSettle();

      // A tab tap, animating on to the last place.
      await tester.tap(find.byKey(const Key('language-tab-ko')));
      await tester.pumpAndSettle();

      // And back across all of them to the first.
      await tester.tap(find.byKey(const Key('language-tab-en')));
      await tester.pumpAndSettle();

      // Each theme tap rebuilds four ThemeData from the seed and repaints
      // every glass surface over the scene. Twice, so both brightnesses are
      // measured.
      for (var i = 0; i < 2; i++) {
        await tester.tap(find.byKey(const Key('app-theme')));
        await tester.pumpAndSettle();
      }
    }, reportKey: 'language_screen');

    await binding.watchPerformance(() async {
      await tester.tap(find.byKey(const Key('language-action-en')));
      await pumpUntilFound(
        tester,
        find.byType(PracticeScreen),
        failure: 'Practice never opened on the English pack.',
      );
      await tester.pumpAndSettle();

      // The deck swiped twice: each prompt brings its own scene in.
      final deck = find.descendant(
        of: find.byType(PracticeScreen),
        matching: find.byType(PageView),
      );
      for (var i = 0; i < 2; i++) {
        await tester.fling(deck, const Offset(-300, 0), 1000);
        await tester.pumpAndSettle();
      }

      // An attempt, held and let go, and its score revealed.
      await holdToRecord(tester);
      await pumpUntilFound(
        tester,
        find.byKey(const Key('practice-overall')),
        failure: 'The attempt was never scored.',
      );
      await tester.pumpAndSettle();
    }, reportKey: 'practice_screen');

    // Self-describing, so a report can never be compared against a baseline
    // taken in a different build mode.
    (binding.reportData ??= <String, dynamic>{})['build_mode'] = kProfileMode
        ? 'profile'
        : kReleaseMode
        ? 'release'
        : 'debug';
  });
}
