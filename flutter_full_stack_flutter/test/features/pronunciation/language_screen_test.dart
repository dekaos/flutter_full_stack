import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_full_stack_flutter/core/audio/sound.dart';
import 'package:flutter_full_stack_flutter/core/audio/sound_board.dart';
import 'package:flutter_full_stack_flutter/core/pronunciation/lexicon.dart';
import 'package:flutter_full_stack_flutter/core/pronunciation/model_store.dart';
import 'package:flutter_full_stack_flutter/features/pronunciation/presentation/language_screen.dart';
import 'package:flutter_full_stack_flutter/features/pronunciation/providers/language_pack.dart';
import 'package:flutter_full_stack_flutter/features/pronunciation/providers/practice_audio.dart';
import 'package:flutter_full_stack_flutter/l10n/app_localizations.dart';
import 'package:flutter_full_stack_flutter/theme/app_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../support/fake_audio.dart';

Widget _app(Directory packs, {SoundBoard? board}) => ProviderScope(
  overrides: [
    // A real directory instead of the support directory, which needs a
    // platform channel a widget test does not have.
    modelStoreProvider.overrideWithValue(ModelStore(directory: packs)),
    soundBoardProvider.overrideWithValue(board ?? fakeSoundBoard()),
  ],
  child: MaterialApp(
    theme: AppTheme.light(),
    locale: const Locale('en'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    home: const LanguageScreen(),
  ),
);

/// A store whose downloads land - or fail - when the test says, with no
/// network: a real download is real I/O, which a widget test's clock does
/// not wait for.
class _Store extends ModelStore {
  _Store(Directory packs) : super(directory: packs);

  final _running = <String, Completer<File>>{};
  final _reports = <String, void Function(DownloadProgress)?>{};

  /// How many downloads were asked for, joined ones included.
  int asked = 0;

  @override
  bool isDownloading(String name) => _running.containsKey(name);

  @override
  Future<File> ensure(
    String name, {
    required String sha256,
    void Function(DownloadProgress)? onProgress,
  }) {
    asked++;
    _reports[name] = onProgress;
    return (_running[name] ??= Completer<File>()).future;
  }

  void report(String name, DownloadProgress progress) =>
      _reports[name]?.call(progress);

  /// The pack arrives, whole and checked.
  void land(String name) {
    final pack = File('${directory!.path}/$name')..writeAsStringSync('w');
    _running.remove(name)!.complete(pack);
  }

  void fail(String name, Object error) =>
      _running.remove(name)!.completeError(error);
}

const _english = 'phoneme_en_r2.int8.onnx';

/// The chooser under a router, with practice as a placeholder that says
/// which language it opened on.
Widget _routed(ModelStore store, {SoundBoard? board}) => ProviderScope(
  overrides: [
    modelStoreProvider.overrideWithValue(store),
    soundBoardProvider.overrideWithValue(board ?? fakeSoundBoard()),
  ],
  child: MaterialApp.router(
    theme: AppTheme.light(),
    locale: const Locale('en'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    routerConfig: GoRouter(
      routes: [
        GoRoute(
          path: '/',
          name: 'languages',
          builder: (_, _) => const LanguageScreen(),
          routes: [
            GoRoute(
              path: 'practice/:lang',
              name: 'practice',
              builder: (_, state) =>
                  Text('practising ${state.pathParameters['lang']}'),
            ),
          ],
        ),
      ],
    ),
  ),
);

/// Pumps and lets the real asynchronous work finish.
///
/// `pumpAndSettle` alone is not enough here: loading the lexicon asset and
/// stat-ing the pack are real I/O, and neither schedules a frame, so the
/// settle returns while the provider is still loading and the card renders
/// its empty state. Under a router the screen is only built a frame or two
/// after the app, so the frames that build it are pumped inside too.
Future<void> _pump(WidgetTester tester, Widget app) async {
  await tester.runAsync(() async {
    await tester.pumpWidget(app);
    for (var i = 0; i < 3; i++) {
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 30));
    }
  });
  await tester.pumpAndSettle();
}

void main() {
  late Directory packs;

  setUp(() async {
    packs = await Directory.systemTemp.createTemp('language_screen_test');
  });

  tearDown(() {
    if (packs.existsSync()) packs.deleteSync(recursive: true);
  });

  testWidgets('offers both languages, named in themselves', (tester) async {
    await _pump(tester, _app(packs));

    expect(find.text('English'), findsOneWidget);
    // Not "Spanish": someone choosing a language has to recognise it without
    // already reading the one the app happens to be in.
    expect(find.text('Español'), findsOneWidget);
    expect(find.text('한국어'), findsOneWidget);
  });

  testWidgets('says which packs still have to be downloaded', (tester) async {
    await _pump(tester, _app(packs));

    // Whether the pack is there decides whether a tap starts practice or a
    // 355 MB download, so it belongs on the card, not behind the tap.
    expect(find.textContaining('355 MB'), findsNWidgets(3));
    expect(find.text('On this device'), findsNothing);
  });

  testWidgets('a downloaded pack reads as ready', (tester) async {
    File('${packs.path}/phoneme_en_r2.int8.onnx').writeAsStringSync('weights');

    await _pump(tester, _app(packs));

    expect(find.text('On this device'), findsOneWidget);
    expect(find.textContaining('355 MB'), findsNWidgets(2));
  });

  testWidgets('gets practice sound ready while the learner chooses, once '
      'the screen has risen in', (tester) async {
    final packs = Directory.systemTemp.createTempSync('language_warm');
    addTearDown(() => packs.deleteSync(recursive: true));
    final speakers = FakeSoundOutput();
    final voice = FakeVoice();
    final board = SoundBoard(output: speakers, voice: voice);

    await tester.pumpWidget(_app(packs, board: board));
    await tester.pump(
      LanguageScreen.settle - const Duration(milliseconds: 100),
    );
    expect(speakers.warmed, isFalse, reason: 'competing with its entrance');

    await tester.pump(const Duration(milliseconds: 200));
    expect(speakers.warmed, isTrue);
    expect(voice.warmed, practiceLanguages);
  });

  group('a pack not on the device', () {
    testWidgets('is downloaded right on its card, and practice opens once it '
        'has landed', (tester) async {
      final store = _Store(packs);
      final speakers = FakeSoundOutput();
      final board = SoundBoard(output: speakers, voice: FakeVoice());
      await _pump(tester, _routed(store, board: board));

      await tester.tap(find.text('English'));
      await tester.pump();

      expect(store.asked, 1);
      expect(find.text('Downloading the pack'), findsOneWidget);
      // Still the chooser: nothing opens before the pack is here.
      expect(find.text('English'), findsOneWidget);

      store.report(_english, const DownloadProgress(received: 42, total: 100));
      await tester.pump();
      expect(find.text('42'), findsOneWidget);

      store.report(
        _english,
        const DownloadProgress(received: 100, total: 100, checking: true),
      );
      await tester.pump();
      expect(find.text('Checking the pack'), findsOneWidget);

      store.land(_english);
      await tester.pump();
      // A beat to see it arrive, with a chime, before practice opens.
      expect(find.text('On this device'), findsOneWidget);
      expect(speakers.sounds, contains(Sound.sparkle));
      expect(find.text('practising en'), findsNothing);

      await tester.pump(LanguageScreen.landing);
      await tester.pumpAndSettle();
      expect(find.text('practising en'), findsOneWidget);
    });

    testWidgets('that stopped partway says so, and a tap picks it up', (
      tester,
    ) async {
      final store = _Store(packs);
      await _pump(tester, _routed(store));
      await tester.tap(find.text('English'));
      await tester.pump();

      store.fail(
        _english,
        ModelDownloadException(Uri.parse('http://host/$_english'), 'closed'),
      );
      await tester.pump();

      expect(
        find.text('Stopped partway. Tap to pick up where it left off.'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);

      await tester.tap(find.text('English'));
      await tester.pump();
      expect(store.asked, 2);
      expect(find.text('Downloading the pack'), findsOneWidget);
    });

    testWidgets('that arrived damaged says so', (tester) async {
      final store = _Store(packs);
      await _pump(tester, _routed(store));
      await tester.tap(find.text('English'));
      await tester.pump();

      store.fail(
        _english,
        const ModelIntegrityException(_english, expected: 'a', actual: 'b'),
      );
      await tester.pump();

      expect(
        find.text('Arrived damaged. Tap to download it again.'),
        findsOneWidget,
      );
    });

    testWidgets('that lands after the learner went to practise another '
        'language does not pull them out of it', (tester) async {
      final store = _Store(packs);
      File('${packs.path}/phoneme_es_r2.int8.onnx').writeAsStringSync('w');
      await _pump(tester, _routed(store));

      await tester.tap(find.text('English'));
      await tester.pump();
      // Changed their mind, to a language that is already here.
      await tester.tap(find.text('Español'));
      await tester.pumpAndSettle();
      expect(find.text('practising es'), findsOneWidget);

      store.land(_english);
      await tester.pump(LanguageScreen.landing);
      await tester.pumpAndSettle();

      expect(find.text('practising es'), findsOneWidget);
      expect(find.text('practising en'), findsNothing);
    });
  });
}
