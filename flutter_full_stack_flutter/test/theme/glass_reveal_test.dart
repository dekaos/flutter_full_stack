import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_full_stack_flutter/theme/app_theme.dart';
import 'package:flutter_full_stack_flutter/theme/glass_surface.dart';
import 'package:flutter_full_stack_flutter/theme/reveal.dart';
import 'package:flutter_full_stack_flutter/theme/rise_in.dart';
import 'package:flutter_test/flutter_test.dart';

/// Sharp stripes behind the glass, so its blur can be measured: frosted,
/// they are smoothed away; seen through clear glass, they are not.
class _Stripes extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF223355),
    );
    final stripe = Paint()..color = const Color(0xFFFFCC33);
    for (var x = 0.0; x < size.width; x += 12) {
      canvas.drawRect(Rect.fromLTWH(x, 0, 5, size.height), stripe);
    }
  }

  @override
  bool shouldRepaint(_Stripes old) => false;
}

const _pane = Rect.fromLTWH(70, 40, 260, 80);

void main() {
  final frame = GlobalKey();

  Future<void> show(WidgetTester tester, Widget glass) async {
    tester.view
      ..physicalSize = const Size(400, 160)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      RepaintBoundary(
        key: frame,
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: Stack(
            fit: StackFit.expand,
            children: [
              CustomPaint(painter: _Stripes()),
              Positioned.fromRect(rect: _pane, child: glass),
            ],
          ),
        ),
      ),
    );
  }

  /// How plainly the stripes show through the middle of the pane: the
  /// spread of the red channel along a row, averaged over rows.
  Future<double> stripesSeen(WidgetTester tester) async {
    final bytes = (await tester.runAsync(() async {
      final boundary =
          frame.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage();
      final data = await image.toByteData();
      return (data!, image.width);
    }))!;
    final (data, width) = bytes;
    var spread = 0.0;
    var rows = 0;
    for (var y = _pane.top.toInt() + 20; y < _pane.bottom - 20; y++) {
      final reds = [
        for (var x = _pane.left.toInt() + 30; x < _pane.right - 30; x++)
          data.getUint8((y * width + x) * 4),
      ];
      final mean = reds.reduce((a, b) => a + b) / reds.length;
      final variance =
          reds.map((r) => (r - mean) * (r - mean)).reduce((a, b) => a + b) /
          reds.length;
      spread += variance;
      rows++;
    }
    return spread / rows;
  }

  /// [stripesSeen] on every frame until it settles.
  Future<List<double>> fadeIn(WidgetTester tester) async {
    final seen = <double>[];
    for (var i = 0; i < 40; i++) {
      seen.add(await stripesSeen(tester));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.pumpAndSettle();
    seen.add(await stripesSeen(tester));
    return seen;
  }

  /// That the pane frosted over as it faded in: steadily, and most of the
  /// way by [twoThirds] - the frame two thirds into the fade. Faded with an
  /// opacity layer, it stayed clear right to the last frame and then
  /// frosted all at once.
  void expectFrostedAsItCame(List<double> seen, {required int twoThirds}) {
    for (var i = 1; i < seen.length; i++) {
      expect(
        seen[i],
        lessThanOrEqualTo(seen[i - 1] * 1.01 + 1),
        reason: 'clearer again at frame $i: $seen',
      );
    }
    expect(
      seen[twoThirds],
      lessThan(seen.first * 0.1),
      reason: 'still clear two thirds of the way in: $seen',
    );
    expect(seen.last, lessThan(50), reason: 'not frosted at rest');
  }

  testWidgets('glass rising in frosts as it comes, rather than arriving '
      'clear and frosting with a jump at the end', (tester) async {
    await show(
      tester,
      const RiseIn(child: GlassSurface(dense: true, child: SizedBox.expand())),
    );
    // 520 ms: two thirds in is the 22nd frame.
    expectFrostedAsItCame(await fadeIn(tester), twoThirds: 22);
  });

  testWidgets('glass switching for other glass stays frosted throughout', (
    tester,
  ) async {
    Widget switcher(int which) => AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (child, animation) =>
          Reveal(opacity: animation, child: child),
      child: GlassSurface(
        key: ValueKey(which),
        dense: true,
        child: const SizedBox.expand(),
      ),
    );
    await show(tester, switcher(0));
    await tester.pumpAndSettle();
    await show(tester, switcher(1));
    // One pane going and the other coming, over the same place: the
    // stripes never show through. Faded with opacity layers, both panes
    // went clear for the length of the switch.
    final seen = await fadeIn(tester);
    expect(seen.reduce(math.max), lessThan(1000), reason: '$seen');
  });

  testWidgets('a reveal with no glass in it fades as any fade does', (
    tester,
  ) async {
    final opacity = AnimationController(vsync: tester, value: 0.5);
    addTearDown(opacity.dispose);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Reveal(opacity: opacity, child: const Text('hello')),
      ),
    );
    await tester.pump();
    final fade = tester.widget<FadeTransition>(find.byType(FadeTransition));
    expect(fade.opacity.value, 0.5);
  });

  testWidgets('reveals inside reveals fade the glass by both', (tester) async {
    final outer = AnimationController(vsync: tester, value: 0.5);
    final inner = AnimationController(vsync: tester, value: 0.4);
    addTearDown(outer.dispose);
    addTearDown(inner.dispose);
    late Animation<double> seen;
    await tester.pumpWidget(
      Reveal(
        opacity: outer,
        child: Reveal(
          opacity: inner,
          child: Builder(
            builder: (context) {
              seen = Reveal.of(context)!;
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    expect(seen.value, closeTo(0.2, 1e-9));
    // Claimed, neither fades its subtree any more: the glass does it.
    await tester.pump();
    for (final fade in tester.widgetList<FadeTransition>(
      find.byType(FadeTransition),
    )) {
      expect(fade.opacity.value, 1);
    }
  });
}
