import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_full_stack_client/flutter_full_stack_client.dart';
import 'package:flutter_full_stack_flutter/features/greetings/presentation/greetings_screen.dart';
import 'package:flutter_full_stack_flutter/features/greetings/providers/greeting_controller.dart';
import 'package:flutter_full_stack_flutter/l10n/app_localizations.dart';
import 'package:flutter_full_stack_flutter/theme/app_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _StubGreetingController extends GreetingController {
  _StubGreetingController(this.greeting);

  final Greeting? greeting;

  @override
  FutureOr<Greeting?> build() => greeting;
}

/// The theme is not optional: widgets read tokens through
/// `Theme.of(context).appTokens`, whose generated getter ends in `!`, so a
/// bare MaterialApp throws while building.
Widget _app({
  Greeting? greeting,
  Locale locale = const Locale('en'),
}) => ProviderScope(
  overrides: [
    greetingControllerProvider.overrideWith(
      () => _StubGreetingController(greeting),
    ),
  ],
  child: MaterialApp(
    theme: AppTheme.light(),
    // Pinned, not left to the platform: these tests assert English copy, and
    // the harness locale is not something they should depend on.
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    home: const GreetingsScreen(),
  ),
);

void main() {
  testWidgets('shows the prompt and no response card until there is one', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text('Say hello.'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    // The empty state is the absence of a card, not a card saying it is empty.
    expect(find.text('FROM THE SERVER'), findsNothing);
  });

  testWidgets('renders Portuguese when the locale says so', (tester) async {
    // This is the override path: MaterialApp.locale set explicitly is exactly
    // what LocaleController does, so proving it here proves the button works
    // without having to tap one.
    await tester.pumpWidget(_app(locale: const Locale('pt')));
    await tester.pumpAndSettle();

    expect(find.text('Diga olá.'), findsOneWidget);
    expect(find.text('Say hello.'), findsNothing);
  });

  testWidgets('reveals the greeting once the controller has one', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        greeting: Greeting(
          message: 'Hello Bob',
          author: 'Serverpod',
          timestamp: DateTime.utc(2026),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('FROM THE SERVER'), findsOneWidget);
    expect(find.textContaining('Hello Bob'), findsOneWidget);
  });
}
