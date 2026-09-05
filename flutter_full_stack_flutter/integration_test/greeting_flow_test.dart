import 'package:flutter/material.dart';
import 'package:flutter_full_stack_flutter/app/app.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// The backend this test drives. Empty means the app resolves the URL itself,
/// through `assets/config.json` and then localhost — see `getServerUrl()`.
const _serverUrl = String.fromEnvironment('SERVER_URL');

/// End-to-end test: the real app, the real generated client, a real HTTP call
/// to a running Serverpod server, and a real Postgres behind it.
///
/// Nothing is faked, so this is the test that catches a stale generated client,
/// a missing migration or a serialization change — the failures that unit and
/// widget tests cannot see.
///
/// It needs the stack running. Use the Melos script, which starts the
/// containers and the server first:
///
///     melos run test:e2e
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('sending a name renders the greeting built by the server', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: App()));

    // serverpodClientProvider resolves the server URL and initializes auth
    // before the first usable frame.
    await tester.pumpAndSettle();

    expect(
      find.text('No server response yet.'),
      findsOneWidget,
      reason: 'the app should open in its empty state',
    );

    await tester.enterText(find.byType(TextField), 'Bob');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.send));

    await _pumpUntilFound(
      tester,
      find.textContaining('Hello Bob'),
      describeFailure:
          'The server never answered with a greeting. Is it '
          'running at ${_serverUrl.isEmpty ? 'localhost:8080' : _serverUrl}? '
          'Start the stack with `melos run server:start`.',
    );

    // The screen renders Greeting.toString(), which is the encoded JSON, so
    // this also asserts the model round-tripped through serialization.
    expect(find.textContaining('"author":"Serverpod"'), findsOneWidget);
  });
}

/// Pumps frames until [finder] matches something, then returns.
///
/// `pumpAndSettle` is not enough for a network round trip: it returns as soon
/// as no frame is scheduled, which is true while the HTTP request is still in
/// flight. Fails with [describeFailure] if nothing matches within [timeout].
Future<void> _pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  required String describeFailure,
  Duration timeout = const Duration(seconds: 30),
}) async {
  final deadline = DateTime.now().add(timeout);

  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty) return;
  }

  fail(describeFailure);
}
