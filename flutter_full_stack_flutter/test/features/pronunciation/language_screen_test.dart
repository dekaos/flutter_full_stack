import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_full_stack_flutter/core/audio/sound.dart';
import 'package:flutter_full_stack_flutter/core/audio/sound_board.dart';
import 'package:flutter_full_stack_flutter/core/pronunciation/lexicon.dart';
import 'package:flutter_full_stack_flutter/core/pronunciation/model_store.dart';
import 'package:flutter_full_stack_flutter/features/pronunciation/presentation/country_scene.dart';
import 'package:flutter_full_stack_flutter/features/pronunciation/presentation/language_screen.dart';
import 'package:flutter_full_stack_flutter/features/pronunciation/presentation/prompt_scene.dart';
import 'package:flutter_full_stack_flutter/features/pronunciation/providers/language_pack.dart';
import 'package:flutter_full_stack_flutter/features/pronunciation/providers/practice_audio.dart';
import 'package:flutter_full_stack_flutter/l10n/app_localizations.dart';
import 'package:flutter_full_stack_flutter/theme/app_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../support/fake_audio.dart';

Widget _app(Directory packs, {SoundBoard? board, ThemeData? theme}) =>
    ProviderScope(
      overrides: [
        // A real directory instead of the support directory, which needs a
        // platform channel a widget test does not have.
        modelStoreProvider.overrideWithValue(ModelStore(directory: packs)),
        soundBoardProvider.overrideWithValue(board ?? fakeSoundBoard()),
      ],
      child: MaterialApp(
        theme: theme ?? AppTheme.light(),
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

/// Builds [app] on the test's clock, so the places' timers are kept by it,
/// and lets the real I/O behind the panels - the lexicons, the disk - take
/// its turns in between.
Future<void> _open(WidgetTester tester, Widget app) async {
  await tester.pumpWidget(app);
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
  }
}

/// Lets the real I/O behind a page that has just come into view - its
/// lexicon, its pack on disk - take its turns with the test's clock.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Brings [lang]'s page into view through its tab, the way a learner who
/// does not swipe would.
Future<void> _go(WidgetTester tester, String lang) async {
  await tester.tap(find.byKey(Key('language-tab-$lang')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
  await _settle(tester);
}

/// Lets [time] go by a frame at a time, as it does on a device - so an
/// animation is seen passing the moments its sounds are on.
Future<void> _play(WidgetTester tester, Duration time) async {
  const frame = Duration(milliseconds: 16);
  for (var t = Duration.zero; t < time; t += frame) {
    await tester.pump(frame);
  }
}

Finder _action(String lang) => find.byKey(Key('language-action-$lang'));

/// The places' own sounds, in the order they were heard.
List<Sound> _places(FakeSoundOutput speakers) => [
  for (final sound in speakers.sounds)
    if (const [
      Sound.fanfare,
      Sound.guitarStrum,
      Sound.templeBell,
    ].contains(sound))
      sound,
];

void main() {
  late Directory packs;

  setUp(() async {
    packs = await Directory.systemTemp.createTemp('language_screen_test');
  });

  tearDown(() {
    if (packs.existsSync()) packs.deleteSync(recursive: true);
  });

  testWidgets('names every language in itself, in the tabs', (tester) async {
    await _pump(tester, _app(packs));

    // Not "Spanish": someone choosing a language has to recognise it without
    // already reading the one the app happens to be in.
    for (final (lang, name) in const [
      ('en', 'English'),
      ('es', 'Español'),
      ('ko', '한국어'),
    ]) {
      expect(
        find.descendant(
          of: find.byKey(Key('language-tab-$lang')),
          matching: find.text(name),
        ),
        findsOneWidget,
      );
    }
  });

  testWidgets('opens on the first language, and what it costs', (
    tester,
  ) async {
    await _pump(tester, _app(packs));

    expect(_action('en'), findsOneWidget);
    // Whether the pack is there decides whether the button starts practice
    // or a 355 MB download, so it is said on the button, before the tap.
    expect(
      find.descendant(
        of: _action('en'),
        matching: find.text('Download · 355 MB'),
      ),
      findsOneWidget,
    );
    expect(
      find.text('Downloaded once, then practice works offline.'),
      findsOneWidget,
    );
  });

  testWidgets('a tab brings its language into view', (tester) async {
    await _pump(tester, _app(packs));

    await _go(tester, 'ko');

    // Its page, panel and all, in place of the first one's.
    expect(_action('ko'), findsOneWidget);
    expect(_action('en'), findsNothing);
  });

  testWidgets('a downloaded pack reads as ready, and its button starts '
      'practice', (tester) async {
    File('${packs.path}/phoneme_es_r2.int8.onnx').writeAsStringSync('w');
    await _pump(tester, _app(packs));

    await _go(tester, 'es');

    expect(find.text('On this device'), findsOneWidget);
    expect(
      find.descendant(
        of: _action('es'),
        matching: find.text('Start practising'),
      ),
      findsOneWidget,
    );
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
    testWidgets('is downloaded right on its panel, the button filling, and '
        'practice opens once it has landed', (tester) async {
      final store = _Store(packs);
      final speakers = FakeSoundOutput();
      final board = SoundBoard(output: speakers, voice: FakeVoice());
      await _pump(tester, _routed(store, board: board));

      await tester.tap(_action('en'));
      await tester.pump();

      expect(store.asked, 1);
      // Said on the button - in the colour of the track, and of the fill.
      expect(
        find.descendant(
          of: _action('en'),
          matching: find.text('Downloading the pack'),
        ),
        findsWidgets,
      );
      // Still the chooser: nothing opens before the pack is here.
      expect(_action('en'), findsOneWidget);

      store.report(_english, const DownloadProgress(received: 42, total: 100));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        find.descendant(
          of: _action('en'),
          matching: find.text('Downloading · 42%'),
        ),
        findsWidgets,
      );

      store.report(
        _english,
        const DownloadProgress(received: 100, total: 100, checking: true),
      );
      await tester.pump();
      expect(
        find.descendant(
          of: _action('en'),
          matching: find.text('Checking the pack'),
        ),
        findsWidgets,
      );

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

    testWidgets('that stopped partway says so, and its button picks it up', (
      tester,
    ) async {
      final store = _Store(packs);
      await _pump(tester, _routed(store));
      await tester.tap(_action('en'));
      await tester.pump();

      store.fail(
        _english,
        ModelDownloadException(Uri.parse('http://host/$_english'), 'closed'),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.text('Stopped partway. Tap to pick up where it left off.'),
        findsOneWidget,
      );
      expect(
        find.descendant(of: _action('en'), matching: find.text('Try again')),
        findsOneWidget,
      );

      await tester.tap(_action('en'));
      await tester.pump();
      expect(store.asked, 2);
      expect(
        find.descendant(
          of: _action('en'),
          matching: find.text('Downloading the pack'),
        ),
        findsWidgets,
      );
    });

    testWidgets('that arrived damaged says so', (tester) async {
      final store = _Store(packs);
      await _pump(tester, _routed(store));
      await tester.tap(_action('en'));
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

      await tester.tap(_action('en'));
      await tester.pump();
      // Changed their mind, to a language that is already here.
      await _go(tester, 'es');
      await tester.tap(_action('es'));
      await tester.pumpAndSettle();
      expect(find.text('practising es'), findsOneWidget);

      store.land(_english);
      await tester.pump(LanguageScreen.landing);
      await tester.pumpAndSettle();

      expect(find.text('practising es'), findsOneWidget);
      expect(find.text('practising en'), findsNothing);
    });
  });

  group('the places', () {
    testWidgets('the first arrives as the screen opens, and is heard', (
      tester,
    ) async {
      final speakers = FakeSoundOutput();
      final board = SoundBoard(output: speakers, voice: FakeVoice());
      await _open(tester, _app(packs, board: board));
      expect(find.byType(CountryScene), findsOneWidget);

      // Not before the page has risen in.
      await _play(tester, LanguageScreen.firstArrival);
      expect(_places(speakers), isEmpty);

      await _play(tester, PromptScene.arrival);
      expect(_places(speakers), [Sound.fanfare]);
    });

    testWidgets('swiping to the next has it arrive and be heard; swiping '
        'back has the first tell its story again', (tester) async {
      final speakers = FakeSoundOutput();
      final board = SoundBoard(output: speakers, voice: FakeVoice());
      await _open(tester, _app(packs, board: board));
      await _play(tester, LanguageScreen.firstArrival + PromptScene.arrival);
      speakers.played.clear();

      await tester.fling(find.byType(PageView), const Offset(-300, 0), 1000);
      await _play(tester, PromptScene.arrival);
      expect(_action('es'), findsOneWidget);
      expect(_places(speakers), [Sound.guitarStrum]);

      await tester.fling(find.byType(PageView), const Offset(300, 0), 1000);
      await _play(tester, PromptScene.arrival);
      expect(_action('en'), findsOneWidget);
      expect(_places(speakers), [Sound.guitarStrum, Sound.fanfare]);
    });

    testWidgets('are not there under high contrast', (tester) async {
      await _pump(tester, _app(packs, theme: AppTheme.highContrastLight()));

      expect(find.byType(CountryScene), findsNothing);
      // The choice is all still there.
      expect(find.byKey(const Key('language-tab-es')), findsOneWidget);
      expect(_action('en'), findsOneWidget);
    });
  });

  group('fits the screen', () {
    for (final (name, size) in const [
      ('a small phone', Size(320, 480)),
      ('a phone', Size(411, 891)),
      ('a tablet', Size(768, 1024)),
      ('a tablet on its side', Size(1280, 800)),
      ('a phone on its side', Size(891, 411)),
    ]) {
      testWidgets('on $name: nothing overflows, nothing overlaps', (
        tester,
      ) async {
        tester.view
          ..physicalSize = size
          ..devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        await _pump(tester, _app(packs));

        // An overflow is reported as an error, and fails here.
        expect(tester.takeException(), isNull);
        final tabs = tester
            .getRect(find.byKey(const Key('language-tab-en')))
            .expandToInclude(
              tester.getRect(find.byKey(const Key('language-tab-ko'))),
            );
        final action = tester.getRect(_action('en'));
        // The panel never over the tabs - under them on a tall screen, at
        // the side on a wide one.
        expect(action.overlaps(tabs), isFalse);
        expect(action.top, greaterThan(tabs.top));
        if (size.width > size.height) {
          expect(action.center.dx, greaterThan(size.width / 2));
        }
        // No wider than a page of type, however wide the screen.
        expect(action.width, lessThanOrEqualTo(560));
        expect(action.bottom, lessThanOrEqualTo(size.height));
      });
    }
  });
}
