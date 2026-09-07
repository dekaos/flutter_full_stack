import 'package:flutter/material.dart';
import 'package:flutter_full_stack_flutter/features/greetings/presentation/greetings_screen.dart';
import 'package:flutter_full_stack_flutter/theme/app_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('GreetingsScreen renders input and empty state', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        // The theme is not optional here. Widgets read AppTokens through
        // `Theme.of(context).appTokens`, whose generated getter ends in `!`,
        // so a bare MaterialApp throws instead of falling back.
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const GreetingsScreen(),
        ),
      ),
    );

    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('No server response yet.'), findsOneWidget);
  });
}
