import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_full_stack_client/flutter_full_stack_client.dart';
import 'package:flutter_full_stack_flutter/app/app.dart';
import 'package:flutter_full_stack_flutter/features/greetings/presentation/greetings_screen.dart';
import 'package:flutter_full_stack_flutter/features/greetings/providers/greeting_controller.dart';
import 'package:flutter_full_stack_flutter/theme/app_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

class _NoGreeting extends GreetingController {
  @override
  FutureOr<Greeting?> build() => null;
}

/// The real [App], because the defect being pinned here lives in the wiring
/// between the device, the controllers and `MaterialApp` — not in either
/// controller alone. Only the server call is stubbed out.
Widget _app() => ProviderScope(
  overrides: [greetingControllerProvider.overrideWith(_NoGreeting.new)],
  child: const App(),
);

Brightness _showing(WidgetTester tester) =>
    Theme.of(tester.element(find.byType(GreetingsScreen))).brightness;

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

void main() {
  // The fonts are bundled assets, and google_fonts registers them
  // asynchronously: the first frame lays text out in the fallback face and
  // paints it in Inter, which trips a framework assertion inside `paint`.
  // Loading them once up front is what the package documents for tests, and
  // it is why only the first test in a file ever hit this.
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    GoogleFonts.config.allowRuntimeFetching = false;
    AppTheme.light();
    await GoogleFonts.pendingFonts();
  });

  group('the theme button always changes what is on screen', () {
    for (final device in Brightness.values) {
      testWidgets('first tap, device ${device.name}', (tester) async {
        tester.platformDispatcher.platformBrightnessTestValue = device;
        addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

        await tester.pumpWidget(_app());
        await tester.pumpAndSettle();
        // Following the device: what is on screen is what the device asked for.
        expect(_showing(tester), device);

        await _tap(tester, 'greeting-theme');

        // The regression: cycling to a fixed ThemeMode.light moved the state
        // and left the pixels alone on a light device, so the tap looked lost
        // and the user pressed again.
        expect(_showing(tester), isNot(device));
      });
    }

    testWidgets('three taps show both brightnesses and return to following', (
      tester,
    ) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      await _tap(tester, 'greeting-theme');
      expect(_showing(tester), Brightness.dark);
      await _tap(tester, 'greeting-theme');
      expect(_showing(tester), Brightness.light);
      await _tap(tester, 'greeting-theme');

      // Back to following, which is the one step that looks the same as the
      // one before it. The icon is what reports it.
      expect(find.byIcon(Icons.brightness_auto_outlined), findsOneWidget);
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      await tester.pumpAndSettle();
      expect(_showing(tester), Brightness.dark);
    });
  });

  group('the language button always changes what is on screen', () {
    const cases = {'en': 'Say hello.', 'pt': 'Diga olá.'};

    cases.forEach((code, deviceCopy) {
      testWidgets('first tap, device $code', (tester) async {
        tester.platformDispatcher.localesTestValue = <Locale>[Locale(code)];
        addTearDown(tester.platformDispatcher.clearLocalesTestValue);

        await tester.pumpWidget(_app());
        await tester.pumpAndSettle();
        expect(find.text(deviceCopy), findsOneWidget);

        await _tap(tester, 'greeting-language');

        // The same regression: stepping to supportedLocales.first re-rendered
        // identical copy whenever the device was already English.
        expect(find.text(deviceCopy), findsNothing);
      });
    });

    testWidgets('the last step returns to following the device', (
      tester,
    ) async {
      tester.platformDispatcher.localesTestValue = const <Locale>[Locale('pt')];
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);

      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      // Two languages, so: device → the other one → the device's own → device.
      await _tap(tester, 'greeting-language');
      expect(find.text('Say hello.'), findsOneWidget);
      await _tap(tester, 'greeting-language');
      expect(find.text('Diga olá.'), findsOneWidget);
      await _tap(tester, 'greeting-language');

      expect(find.byIcon(Icons.language_outlined), findsOneWidget);
      tester.platformDispatcher.localesTestValue = const <Locale>[Locale('en')];
      await tester.pumpAndSettle();
      expect(find.text('Say hello.'), findsOneWidget);
    });
  });
}
