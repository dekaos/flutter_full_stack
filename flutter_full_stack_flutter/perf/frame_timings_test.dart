import 'package:flutter/foundation.dart';
import 'package:flutter_full_stack_flutter/app/app.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// Measures what the app costs to render, so that growth shows up as a number
/// instead of as a complaint.
///
/// This is deliberately a separate suite from `greeting_flow_test.dart`. That
/// one proves behaviour and needs a server, a database and a migration; this
/// one touches no network at all, which is what makes it cheap enough to run
/// on every change. The expensive parts of this app are not the HTTP call -
/// they are seven `BackdropFilter`s, a `CustomPaint` drawing three radial
/// gradients, and four `ThemeData` rebuilt from one seed.
///
/// Run it through the driver so the numbers reach a file:
///
///     melos run perf
///
/// **Profile mode matters more than anything else here.** A debug build keeps
/// assertions on and skips ahead-of-time compilation, which inflates raster
/// time by an order of magnitude. Debug numbers are only comparable to other
/// debug numbers, which is why the build mode is written into the report and
/// the budget tool keys its baselines by it.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the greeting screen, from launch through interaction', (
    tester,
  ) async {
    await binding.watchPerformance(() async {
      // Launch, including the entrance animations: the aurora drifting into
      // place and the staggered rise-in are the first thing a user ever sees,
      // and the most expensive frames the app draws.
      await tester.pumpWidget(const ProviderScope(child: App()));
      await tester.pumpAndSettle();

      // Each theme tap rebuilds four ThemeData from the seed and repaints
      // every glass surface. Twice, so both brightnesses are measured.
      for (var i = 0; i < 2; i++) {
        await tester.tap(find.byKey(const Key('greeting-theme')));
        await tester.pumpAndSettle();
      }

      // Each language tap re-resolves every string on screen.
      for (var i = 0; i < 2; i++) {
        await tester.tap(find.byKey(const Key('greeting-language')));
        await tester.pumpAndSettle();
      }

      // Typing repaints the translucent well on every keystroke, and runs the
      // dead-key formatter over the value each time.
      await tester.enterText(
        find.byKey(const Key('greeting-name-field')),
        'Anderson Stuhler',
      );
      await tester.pumpAndSettle();
    }, reportKey: 'greeting_screen');

    // Self-describing, so a report can never be compared against a baseline
    // taken in a different build mode.
    (binding.reportData ??= <String, dynamic>{})['build_mode'] = kProfileMode
        ? 'profile'
        : kReleaseMode
        ? 'release'
        : 'debug';
  });
}
