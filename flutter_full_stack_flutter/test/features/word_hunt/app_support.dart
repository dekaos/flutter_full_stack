import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_full_stack_flutter/app/app.dart';
import 'package:flutter_full_stack_flutter/core/audio/sound_board.dart';
import 'package:flutter_full_stack_flutter/core/pronunciation/model_store.dart';
import 'package:flutter_full_stack_flutter/features/pronunciation/providers/language_pack.dart';
import 'package:flutter_full_stack_flutter/features/pronunciation/providers/practice_audio.dart';
import 'package:flutter_full_stack_flutter/features/pronunciation/providers/practice_controller.dart';
import 'package:flutter_full_stack_flutter/features/word_hunt/providers/hunt_records.dart';
import 'package:flutter_full_stack_flutter/features/word_hunt/providers/mission_controller.dart';
import 'package:flutter_full_stack_flutter/features/word_hunt/providers/word_bank.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_audio.dart';
import '../../support/practice.dart';
import 'support.dart';

/// The real app, with everything a widget test cannot have stood in for:
/// speakers and a voice that write down what they were asked to do, the
/// records in memory, a seeded mission, and an empty pack store.
class HuntApp {
  HuntApp({Map<WordDeck, DeckRecord> records = const {}})
    : records = MemoryRecords(records) {
    final folder = Directory.systemTemp.createTempSync('hunt_app');
    addTearDown(() => folder.deleteSync(recursive: true));
    _overrides = [
      soundBoardProvider.overrideWithValue(
        SoundBoard(output: output, voice: voice),
      ),
      missionRandomProvider.overrideWithValue(math.Random(5)),
      huntRecordsProvider.overrideWith(() => this.records),
      modelStoreProvider.overrideWithValue(ModelStore(directory: folder)),
      practiceControllerProvider.overrideWith2(
        (_) => StubPracticeController(),
      ),
    ];
  }

  final FakeSoundOutput output = FakeSoundOutput();
  final FakeVoice voice = FakeVoice();
  final MemoryRecords records;
  late final List<Override> _overrides;

  /// The app's providers. A [ProviderScope] rather than a container of the
  /// test's own, so that they - and every clock a mission is running - go
  /// with the widget tree when the test ends.
  late ProviderContainer container;

  /// Pumps the app and lets its splash play out.
  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(overrides: _overrides, child: const App()),
    );
    container = ProviderScope.containerOf(tester.element(find.byType(App)));
    await frames(tester, const Duration(milliseconds: 2200));
  }

  MissionState mission(WordDeck deck) =>
      container.read(missionControllerProvider(deck));
}

/// Plays [length] of frames, one at a time. The word hunt's space moves on
/// every frame, so `pumpAndSettle` would wait for ever while it is on
/// screen.
Future<void> frames(WidgetTester tester, Duration length) async {
  const frame = Duration(milliseconds: 16);
  for (var t = Duration.zero; t < length; t += frame) {
    await tester.pump(frame);
  }
}
