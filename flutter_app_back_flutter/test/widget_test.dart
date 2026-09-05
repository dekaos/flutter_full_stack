import 'package:flutter/material.dart';
import 'package:flutter_app_back_flutter/features/greetings/presentation/greetings_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('GreetingsScreen renders input and empty state', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: GreetingsScreen()),
      ),
    );

    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('No server response yet.'), findsOneWidget);
  });
}
