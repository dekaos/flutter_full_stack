import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_full_stack_flutter/core/pronunciation/model_store.dart';
import 'package:flutter_full_stack_flutter/features/pronunciation/presentation/language_screen.dart';
import 'package:flutter_full_stack_flutter/features/pronunciation/providers/practice_controller.dart';
import 'package:flutter_full_stack_flutter/l10n/app_localizations.dart';
import 'package:flutter_full_stack_flutter/theme/app_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Directory packs) => ProviderScope(
  overrides: [
    // A real directory instead of the support directory, which needs a
    // platform channel a widget test does not have.
    modelStoreProvider.overrideWithValue(ModelStore(directory: packs)),
  ],
  child: MaterialApp(
    theme: AppTheme.light(),
    locale: const Locale('en'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    home: const LanguageScreen(),
  ),
);

/// Pumps and lets the real asynchronous work finish.
///
/// `pumpAndSettle` alone is not enough here: loading the lexicon asset and
/// stat-ing the pack are real I/O, and neither schedules a frame, so the
/// settle returns while the provider is still loading and the card renders
/// its empty state.
Future<void> _pump(WidgetTester tester, Widget app) async {
  await tester.runAsync(() async {
    await tester.pumpWidget(app);
    await tester.pump();
    await Future<void>.delayed(const Duration(milliseconds: 50));
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
  });

  testWidgets('says which packs still have to be downloaded', (tester) async {
    await _pump(tester, _app(packs));

    // Whether the pack is there decides whether a tap starts practice or a
    // 355 MB download, so it belongs on the card, not behind the tap.
    expect(find.textContaining('355 MB'), findsNWidgets(2));
    expect(find.text('On this device'), findsNothing);
  });

  testWidgets('a downloaded pack reads as ready', (tester) async {
    File('${packs.path}/phoneme_en_r2.int8.onnx').writeAsStringSync('weights');

    await _pump(tester, _app(packs));

    expect(find.text('On this device'), findsOneWidget);
    expect(find.textContaining('355 MB'), findsOneWidget);
  });
}
