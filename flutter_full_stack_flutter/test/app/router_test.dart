import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_full_stack_flutter/app/app.dart';
import 'package:flutter_full_stack_flutter/app/router.dart';
import 'package:flutter_full_stack_flutter/core/pronunciation/lexicon.dart';
import 'package:flutter_full_stack_flutter/core/pronunciation/model_store.dart';
import 'package:flutter_full_stack_flutter/features/greetings/presentation/greetings_screen.dart';
import 'package:flutter_full_stack_flutter/features/pronunciation/presentation/language_screen.dart';
import 'package:flutter_full_stack_flutter/features/pronunciation/presentation/practice_screen.dart';
import 'package:flutter_full_stack_flutter/features/pronunciation/providers/practice_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Stands in for the real controller, which would reach for the documents
/// directory to see whether the language pack is on disk — a platform channel
/// that does not exist in a widget test.
class _StubPracticeController extends PracticeController {
  @override
  FutureOr<PracticeState> build(String lang) => const PracticeState(
    stage: PracticeStage.needsModel,
    kind: ExerciseKind.phrase,
    items: [Exercise(id: 'x', text: 'hello', words: [], phones: [])],
    index: 0,
  );
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

ProviderContainer _container() => ProviderContainer(
  overrides: [
    practiceControllerProvider.overrideWith2((_) => _StubPracticeController()),
    modelStoreProvider.overrideWithValue(
      ModelStore(directory: Directory.systemTemp),
    ),
  ],
);

void main() {
  testWidgets('the app opens on the language chooser', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          practiceControllerProvider.overrideWith2(
            (_) => _StubPracticeController(),
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
    await tester.pumpAndSettle();

    expect(find.byType(LanguageScreen), findsOneWidget);
    // The Serverpod demo is still reachable at /greetings, but it is not what
    // the app is for any more.
    expect(find.byType(GreetingsScreen), findsNothing);
  });

  testWidgets('practice can be left, to pick another language', (tester) async {
    final container = _container();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const App()),
    );
    await _settle(tester);

    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    expect(find.byType(PracticeScreen), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byType(LanguageScreen), findsOneWidget);
  });

  testWidgets('a link straight into practice still has a way back', (
    tester,
  ) async {
    final container = _container();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const App()),
    );
    await _settle(tester);

    // Nothing was tapped: this is the deep-link case, and it is the one that
    // sibling routes plus `push` would have left stranded.
    container.read(routerProvider).go('/practice/es');
    await tester.pumpAndSettle();

    expect(find.byType(PracticeScreen), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);
  });
}
