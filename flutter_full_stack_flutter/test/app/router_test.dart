import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_full_stack_flutter/app/app.dart';
import 'package:flutter_full_stack_flutter/app/router.dart';
import 'package:flutter_full_stack_flutter/core/pronunciation/model_store.dart';
import 'package:flutter_full_stack_flutter/features/pronunciation/presentation/language_screen.dart';
import 'package:flutter_full_stack_flutter/features/pronunciation/presentation/practice_screen.dart';
import 'package:flutter_full_stack_flutter/features/pronunciation/providers/language_pack.dart';
import 'package:flutter_full_stack_flutter/features/pronunciation/providers/practice_controller.dart';
import 'package:flutter_full_stack_flutter/features/word_hunt/presentation/word_hunt_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/practice.dart';

/// Pumps the app and goes to the language chooser, before letting anything
/// settle: the app opens on the word hunt, whose space moves on every
/// frame, so `pumpAndSettle` would never return there. Covered by the
/// chooser, it stops.
Future<void> _toChooser(
  WidgetTester tester,
  ProviderContainer container,
) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const App()),
  );
  await tester.pump();
  container.read(routerProvider).goNamed('languages');
  await _settle(tester);
}

/// Pumps and lets the real asynchronous work finish: the chooser loads a
/// lexicon asset and stats the pack, and neither schedules a frame, so
/// `pumpAndSettle` alone returns while the cards are still empty.
Future<void> _settle(WidgetTester tester) async {
  await tester.runAsync(() async {
    await tester.pump();
    await Future<void>.delayed(const Duration(milliseconds: 50));
  });
  await tester.pumpAndSettle();
}

/// A container whose store holds the packs named in [packs] - English and
/// Spanish unless a test says otherwise. Practice only opens on a pack that
/// is on the device.
ProviderContainer _container({List<String> packs = const ['en', 'es']}) {
  final folder = Directory.systemTemp.createTempSync('router_test');
  addTearDown(() => folder.deleteSync(recursive: true));
  for (final lang in packs) {
    File('${folder.path}/phoneme_${lang}_r2.int8.onnx').writeAsStringSync('w');
  }
  return ProviderContainer(
    overrides: [
      practiceControllerProvider.overrideWith2(
        (_) => StubPracticeController(),
      ),
      modelStoreProvider.overrideWithValue(ModelStore(directory: folder)),
    ],
  );
}

/// Lets a navigation finish whose redirect reads the lexicon and the disk.
///
/// That is real I/O, which the test's clock does not wait for, interleaved
/// with steps that only the test's clock runs - so the two take turns until
/// the redirect has had its answer.
Future<void> _navigate(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the app opens on the word hunt', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          practiceControllerProvider.overrideWith2(
            (_) => StubPracticeController(),
          ),
          // Points the store at a real directory so checking for a pack does
          // not reach for the platform channel that gives the app's documents
          // folder, which does not exist in a widget test.
          modelStoreProvider.overrideWithValue(
            ModelStore(directory: Directory.systemTemp),
          ),
        ],
        child: const App(),
      ),
    );
    // Past the splash; not settled, as the word hunt's space never is.
    for (var i = 0; i < 150; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    expect(find.byType(WordHuntScreen), findsOneWidget);
    expect(find.byType(LanguageScreen), findsNothing);
  });

  testWidgets('practice can be left, to pick another language', (tester) async {
    final container = _container();
    addTearDown(container.dispose);

    await _toChooser(tester, container);

    // Its pack is on the device, so the button starts practice.
    await tester.tap(find.byKey(const Key('language-action-en')));
    await _navigate(tester);
    expect(find.byType(PracticeScreen), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byType(LanguageScreen), findsOneWidget);

    // And the chooser itself goes back to the word hunt, the app's home.
    expect(find.byType(BackButton), findsOneWidget);
  });

  testWidgets('a link straight into practice still has a way back', (
    tester,
  ) async {
    final container = _container();
    addTearDown(container.dispose);

    await _toChooser(tester, container);

    // Nothing was tapped: this is the deep-link case, and it is the one that
    // sibling routes plus `push` would have left stranded.
    container.read(routerProvider).go('/languages/practice/es');
    await _navigate(tester);

    expect(find.byType(PracticeScreen), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);
  });

  testWidgets('a link into practice for a pack not on the device lands on '
      'the chooser, where it is downloaded', (tester) async {
    final container = _container(packs: const []);
    addTearDown(container.dispose);

    await _toChooser(tester, container);

    container.read(routerProvider).go('/languages/practice/ko');
    await _navigate(tester);

    expect(find.byType(PracticeScreen), findsNothing);
    expect(find.byType(LanguageScreen), findsOneWidget);
  });
}
