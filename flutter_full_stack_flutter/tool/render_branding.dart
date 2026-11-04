// Draws every launcher icon and native splash image the app ships, for every
// platform and size, from the one drawing of the mark in
// lib/app/app_mark.dart:
//
//     dart run melos:melos run branding
//
// Each size is drawn from the vector mark at that size, not shrunk from one
// large bitmap, so even the 16 px favicon is as sharp as it can be. It runs
// under `flutter test` because drawing needs Flutter's engine.
//
// Every PNG it writes is generated: change the mark, then run this - never
// edit the images. The few native files that place them - the Android launch
// drawables and styles, the adaptive icon XML, the iOS launch storyboard's
// colour - are written by hand once, and are documented in docs/branding.md.
//
// Why not flutter_launcher_icons: it pins cli_util below 0.5, melos needs 0.5
// or later, and the workspace has one lockfile.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_full_stack_flutter/app/app_mark.dart';
import 'package:flutter_full_stack_flutter/app/splash.dart';
import 'package:flutter_full_stack_flutter/theme/app_theme.dart';
import 'package:flutter_test/flutter_test.dart';

/// Android's density buckets and their scale.
const _densities = {
  'mdpi': 1.0,
  'hdpi': 1.5,
  'xhdpi': 2.0,
  'xxhdpi': 3.0,
  'xxxhdpi': 4.0,
};

/// CNA's red, a step lighter at the top left and deeper at the bottom
/// right, with a soft light where the eye lands: the icon's ground.
void _ground(Canvas canvas, Size size) {
  final rect = Offset.zero & size;
  canvas
    ..drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF2324F), Brand.red, Color(0xFFC40F31)],
          stops: [0, 0.5, 1],
        ).createShader(rect),
    )
    ..drawRect(
      rect,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.4, -0.5),
          radius: 0.9,
          colors: [Color(0x26FFFFFF), Color(0x00FFFFFF)],
        ).createShader(rect),
    );
}

/// Writes a [size]-pixel square PNG at [path], drawn by [draw].
Future<void> _png(
  String path,
  int size,
  void Function(Canvas canvas, Size size) draw,
) async {
  final recorder = ui.PictureRecorder();
  draw(Canvas(recorder), Size.square(size.toDouble()));
  final image = await recorder.endRecording().toImage(size, size);
  final png = await image.toByteData(format: ui.ImageByteFormat.png);
  File(path)
    ..createSync(recursive: true)
    ..writeAsBytesSync(png!.buffer.asUint8List());
}

/// The mark in a box [share] of the canvas wide, centred, over the ground
/// if [ground] - and with the corners rounded off by [round], as a share of
/// the size, for a legacy icon nothing else will shape.
void Function(Canvas, Size) _icon({
  double share = 1,
  bool ground = true,
  bool mark = true,
  double round = 0,
}) => (canvas, size) {
  if (round > 0) {
    canvas.clipRRect(
      RRect.fromRectAndRadius(
        Offset.zero & size,
        Radius.circular(size.width * round),
      ),
    );
  }
  if (ground) _ground(canvas, size);
  if (!mark) return;
  final box = size.width * share;
  final inset = (size.width - box) / 2;
  canvas
    ..save()
    ..translate(inset, inset);
  const AppMark().paint(canvas, Size.square(box));
  canvas.restore();
};

Future<void> _ios() async {
  // The sizes Xcode's AppIcon set asks for, by file name: points and scale.
  const icons = 'ios/Runner/Assets.xcassets/AppIcon.appiconset';
  for (final file in Directory(icons).listSync().whereType<File>()) {
    final name = file.uri.pathSegments.last;
    final match = RegExp(
      r'Icon-App-([\d.]+)x[\d.]+@(\d)x\.png',
    ).firstMatch(name);
    if (match == null) continue;
    final pixels = (double.parse(match[1]!) * int.parse(match[2]!)).round();
    // Opaque and square: iOS rounds it, and rejects an icon with alpha.
    await _png('$icons/$name', pixels, _icon(share: 0.86));
  }
  // The launch image: the logo alone, over the storyboard's red.
  const launch = 'ios/Runner/Assets.xcassets/LaunchImage.imageset';
  for (final (suffix, scale) in [('', 1), ('@2x', 2), ('@3x', 3)]) {
    await _png(
      '$launch/LaunchImage$suffix.png',
      (Splash.markSize * scale).round(),
      _icon(ground: false),
    );
  }
}

Future<void> _android() async {
  const res = 'android/app/src/main/res';
  for (final MapEntry(key: bucket, value: scale) in _densities.entries) {
    int px(double dp) => (dp * scale).round();
    // Before Android 8, a launcher shows the PNG as it is: shape it here.
    await _png(
      '$res/mipmap-$bucket/ic_launcher.png',
      px(48),
      _icon(share: 0.84, round: 0.22),
    );
    // Android 8 and later: the ground and the logo on layers of their own,
    // 108 dp each, the logo inside the middle 66 dp the launcher keeps
    // whatever shape it crops to. The monochrome layer, which Android 13
    // tints for themed icons, is the same white logo: only its shape counts.
    await _png(
      '$res/mipmap-$bucket/ic_launcher_background.png',
      px(108),
      _icon(mark: false),
    );
    for (final layer in ['foreground', 'monochrome']) {
      await _png(
        '$res/mipmap-$bucket/ic_launcher_$layer.png',
        px(108),
        _icon(share: 0.66, ground: false),
      );
    }
    // The launch screen: the logo, as the animated splash starts.
    await _png(
      '$res/drawable-$bucket/splash_mark.png',
      px(Splash.markSize),
      _icon(ground: false),
    );
    // Android 12's splash icon: 288 dp, of which the system shows a circle
    // 192 dp across - so the logo in the middle, 176 dp wide, shows whole,
    // and at the same size as everywhere else.
    await _png(
      '$res/drawable-$bucket/splash_mark_android12.png',
      px(288),
      _icon(share: Splash.markSize / 288, ground: false),
    );
  }
}

Future<void> _web() async {
  await _png('web/favicon.png', 32, _icon(share: 0.96, round: 0.22));
  for (final size in [192, 512]) {
    await _png(
      'web/icons/Icon-$size.png',
      size,
      _icon(share: 0.86, round: 0.22),
    );
    // Maskable: the platform crops to any shape, keeping a circle 80% of
    // the side across - the logo sits inside it.
    await _png(
      'web/icons/Icon-maskable-$size.png',
      size,
      _icon(share: 0.84),
    );
  }
}

void main() {
  testWidgets('draw the branding', (tester) async {
    await tester.runAsync(() async {
      await _ios();
      await _android();
      await _web();
    });
  });
}
