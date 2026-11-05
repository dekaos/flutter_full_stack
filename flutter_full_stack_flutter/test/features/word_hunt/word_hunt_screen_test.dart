import 'package:flutter/material.dart';
import 'package:flutter_full_stack_flutter/app/router.dart';
import 'package:flutter_full_stack_flutter/features/pronunciation/presentation/language_screen.dart';
import 'package:flutter_full_stack_flutter/features/word_hunt/presentation/mission_screen.dart';
import 'package:flutter_full_stack_flutter/features/word_hunt/presentation/word_hunt_screen.dart';
import 'package:flutter_full_stack_flutter/features/word_hunt/providers/hunt_records.dart';
import 'package:flutter_full_stack_flutter/features/word_hunt/providers/word_bank.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_support.dart';

void main() {
  testWidgets('the app opens on the word hunt, with the best done on each '
      'theme', (tester) async {
    final semantics = tester.ensureSemantics();
    final app = HuntApp(
      records: {WordDeck.animals: const DeckRecord(score: 1840, stars: 3)},
    );
    await app.open(tester);

    expect(find.byType(WordHuntScreen), findsOneWidget);
    expect(find.text('Word Hunt'), findsOneWidget);
    expect(find.text('First steps'), findsOneWidget);
    expect(find.text('Animals'), findsOneWidget);
    // Each card is one button to a screen reader, its stars said with it.
    expect(find.bySemanticsLabel(RegExp('3 stars of 3')), findsOneWidget);
    expect(find.text('Best 1,840'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('No stars yet')), findsWidgets);

    // Every theme is there, further down.
    await tester.scrollUntilVisible(
      find.byKey(Key('hunt-deck-${WordDeck.values.last.name}')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await frames(tester, const Duration(seconds: 1));
    expect(find.text('Going further'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('a theme opens its mission, and leaving it comes home', (
    tester,
  ) async {
    final app = HuntApp();
    await app.open(tester);

    await tester.tap(find.byKey(const Key('hunt-deck-colors')));
    await frames(tester, const Duration(milliseconds: 600));
    final mission = tester.widget<MissionScreen>(find.byType(MissionScreen));
    expect(mission.deck, WordDeck.colors);

    await tester.tap(find.byKey(const Key('hunt-pause')));
    await frames(tester, const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const Key('hunt-quit')));
    await frames(tester, const Duration(milliseconds: 600));
    expect(find.byType(MissionScreen), findsNothing);
    expect(find.byType(WordHuntScreen), findsOneWidget);
  });

  testWidgets('pronunciation practice is a tap away, and Back comes home', (
    tester,
  ) async {
    final app = HuntApp();
    await app.open(tester);

    await tester.tap(find.byKey(const Key('hunt-pronunciation')));
    await tester.pumpAndSettle();
    expect(find.byType(LanguageScreen), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await frames(tester, const Duration(milliseconds: 600));
    expect(find.byType(LanguageScreen), findsNothing);
    expect(find.byType(WordHuntScreen), findsOneWidget);
  });

  testWidgets('the sound gets ready while the learner reads the themes', (
    tester,
  ) async {
    final app = HuntApp();
    await app.open(tester);
    // The splash shows the app under it only as it lifts; the lobby counts
    // from there.
    await frames(tester, WordHuntScreen.warmSoundAfter);
    expect(app.output.warmed, isTrue);
    expect(app.voice.warmed, contains('en'));
  });

  testWidgets('a link to a theme that does not exist goes home', (
    tester,
  ) async {
    final app = HuntApp();
    await app.open(tester);

    app.container.read(routerProvider).go('/mission/dinosaurs');
    await frames(tester, const Duration(milliseconds: 600));
    expect(find.byType(MissionScreen), findsNothing);
    expect(find.byType(WordHuntScreen), findsOneWidget);

    // And one to a theme that does opens straight into its mission.
    app.container.read(routerProvider).go('/mission/time');
    await frames(tester, const Duration(milliseconds: 600));
    expect(
      tester.widget<MissionScreen>(find.byType(MissionScreen)).deck,
      WordDeck.time,
    );
  });
}
