import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_full_stack_flutter/app/app_mark.dart';
import 'package:flutter_full_stack_flutter/app/splash.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host({bool reduceMotion = false}) => MaterialApp(
  home: Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
      child: const Splash(child: Text('the app')),
    ),
  ),
);

/// The mark as the splash is painting it now, or `null` once it is gone.
MarkPose? _pose(WidgetTester tester) {
  final paints = tester.widgetList<CustomPaint>(find.byType(CustomPaint));
  for (final paint in paints) {
    if (paint.painter case final AppMark mark) return mark.pose;
  }
  return null;
}

Future<void> _at(WidgetTester tester, int ms) async {
  // From the first frame, in steps, as the clock runs.
  for (var t = 0; t < ms; t += 20) {
    await tester.pump(const Duration(milliseconds: 20));
  }
}

void main() {
  testWidgets('starts on the native splash: CNA red, the logo at rest - '
      'and the app not built yet', (tester) async {
    await tester.pumpWidget(_host());

    expect(_pose(tester), const MarkPose());
    final mark = find.byWidgetPredicate(
      (w) => w is CustomPaint && w.painter is AppMark,
    );
    expect(tester.getSize(mark), const Size.square(Splash.markSize));
    expect(
      find.byWidgetPredicate(
        (w) => w is ColoredBox && w.color == Splash.ground,
      ),
      findsOneWidget,
    );
    expect(find.text('the app'), findsNothing);
  });

  testWidgets('a bubble springs out of the logo and speaks, then what it '
      'said turns into a tick, and it pops', (tester) async {
    await tester.pumpWidget(_host());

    // 0.5 s: the bubble is out, and speaking.
    await _at(tester, 500);
    expect(_pose(tester)!.bubble, greaterThan(0.9));
    expect(_pose(tester)!.levels, isNot(MarkPose.rest), reason: 'silent');
    expect(_pose(tester)!.tick, 0);
    expect(_pose(tester)!.burst, 0);

    // 1.15 s: done speaking, the voice gathering into the tick.
    await _at(tester, 650);
    expect(_pose(tester)!.levels, MarkPose.rest, reason: 'still talking');
    expect(_pose(tester)!.tick, inExclusiveRange(0, 1));

    // 1.55 s: the tick drawn, the bubble back from its hop, its "pop!"
    // flying out.
    await _at(tester, 400);
    expect(_pose(tester)!.tick, 1);
    expect(_pose(tester)!.burst, inExclusiveRange(0, 1));
    expect(_pose(tester)!.bubble, closeTo(1, 0.01));
  });

  testWidgets('reveals the app underneath, then gets out of the way', (
    tester,
  ) async {
    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();

    expect(find.text('the app'), findsOneWidget);
    expect(_pose(tester), isNull);
  });

  testWidgets('a tap goes straight to the reveal', (tester) async {
    await tester.pumpWidget(_host());
    await _at(tester, 200);
    expect(find.text('the app'), findsNothing);

    await tester.tap(find.byType(Splash));
    await tester.pump();
    expect(find.text('the app'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(_pose(tester), isNull);
  });

  testWidgets('under reduced motion nothing moves: the logo gives way', (
    tester,
  ) async {
    await tester.pumpWidget(_host(reduceMotion: true));
    for (var t = 0; t < 400; t += 50) {
      expect(_pose(tester), anyOf(isNull, const MarkPose()));
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pump(Splash.still);
    await tester.pump();
    expect(find.text('the app'), findsOneWidget);
    expect(_pose(tester), isNull);
  });

  // The animated splash takes over from the system's on its first frame,
  // and the hand-over is only invisible if both start on the same red.
  // The native ones are written in the platforms' own files, which nothing
  // else keeps in step.
  test('every native splash is on the red the animated one starts on', () {
    const ground = Splash.ground;
    String hex(Color c) =>
        (c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0');

    final android = File(
      'android/app/src/main/res/values/colors.xml',
    ).readAsStringSync();
    expect(
      RegExp('name="splash_ground">#([0-9A-Fa-f]{6})<')
          .firstMatch(android)![1]!
          .toLowerCase(),
      hex(ground),
    );

    final storyboard = File(
      'ios/Runner/Base.lproj/LaunchScreen.storyboard',
    ).readAsStringSync();
    final colour = RegExp(
      r'key="backgroundColor" red="([\d.]+)" green="([\d.]+)" '
      r'blue="([\d.]+)"',
    ).firstMatch(storyboard)!;
    for (final (i, channel) in [ground.r, ground.g, ground.b].indexed) {
      expect(double.parse(colour[i + 1]!), closeTo(channel, 1 / 255));
    }

    final web = File('web/manifest.json').readAsStringSync();
    expect(
      web,
      contains('"background_color": "#${hex(ground).toUpperCase()}"'),
    );
  });
}
