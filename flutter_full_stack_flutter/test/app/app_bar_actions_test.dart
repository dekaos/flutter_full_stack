import 'package:flutter/material.dart';
import 'package:flutter_full_stack_flutter/app/app_bar_actions.dart';
import 'package:flutter_full_stack_flutter/app/locale_controller.dart';
import 'package:flutter_full_stack_flutter/features/pronunciation/providers/practice_audio.dart';
import 'package:flutter_full_stack_flutter/l10n/app_localizations.dart';
import 'package:flutter_full_stack_flutter/theme/theme_mode_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _bar(AppBarActions actions) => ProviderScope(
  child: MaterialApp(
    locale: const Locale('en'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    home: Scaffold(appBar: AppBar(actions: [actions])),
  ),
);

const _all = ['app-sounds', 'app-language', 'app-theme', 'app-licenses'];

void main() {
  testWidgets('offers sounds, theme and licences, and not the language, '
      'unless told otherwise', (tester) async {
    await tester.pumpWidget(_bar(const AppBarActions()));
    expect(find.byKey(const Key('app-sounds')), findsOneWidget);
    expect(find.byKey(const Key('app-language')), findsNothing);
    expect(find.byKey(const Key('app-theme')), findsOneWidget);
    expect(find.byKey(const Key('app-licenses')), findsOneWidget);
  });

  testWidgets('each control is shown or hidden by its own flag', (
    tester,
  ) async {
    for (final shown in _all) {
      await tester.pumpWidget(
        _bar(
          AppBarActions(
            sounds: shown == 'app-sounds',
            language: shown == 'app-language',
            theme: shown == 'app-theme',
            licenses: shown == 'app-licenses',
          ),
        ),
      );
      for (final key in _all) {
        expect(
          find.byKey(Key(key)),
          key == shown ? findsOneWidget : findsNothing,
          reason: 'only $shown asked for',
        );
      }
    }
  });

  testWidgets('each control does what it says', (tester) async {
    await tester.pumpWidget(
      _bar(const AppBarActions(language: true)),
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(AppBarActions)),
    );

    await tester.tap(find.byKey(const Key('app-sounds')));
    await tester.pump();
    expect(container.read(soundEffectsProvider), isFalse);
    expect(find.byTooltip('Sounds off'), findsOneWidget);

    await tester.tap(find.byKey(const Key('app-language')));
    await tester.pump();
    expect(container.read(localeControllerProvider), isNotNull);

    await tester.tap(find.byKey(const Key('app-theme')));
    await tester.pump();
    expect(
      container.read(themeModeControllerProvider),
      isNot(ThemeMode.system),
    );
  });
}
