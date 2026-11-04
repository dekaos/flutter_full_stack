# Icon and splash

The app's mark is CNA's logo, white on CNA's red. It is the official vector,
taken from cna.com.br (`media.cna.com.br/cna_logo_3ff9a4f2fc.svg`) and kept,
outlines unchanged, in `lib/app/cna_logo.dart`. `lib/app/app_mark.dart` draws
it, and everything that shows it comes from that one drawing:

| What | Where it comes from |
|---|---|
| Launcher icons (iOS, Android, web) | drawn from the mark by `tool/render_branding.dart` |
| Native splash (iOS, Android, Android 12+) | the same tool, plus a few native files written by hand |
| Animated splash | `lib/app/splash.dart`, posing the mark frame by frame |

So the icon on the home screen, the splash the system shows and the splash the
app then plays cannot drift apart.

The logo is a wordmark, much wider than tall, and each place gives it as much
width as that place allows:

| Place | Logo width |
|---|---|
| iOS icon | about three quarters of the icon |
| Splash | 176 dp, the widest that still shows whole inside the 192 dp circle Android 12 shows a splash icon in |
| Android adaptive icon, web maskable icon | inside the circle the platform keeps whatever shape it crops to |

## The animated splash

It starts on the frame the native splash shows, CNA's red (`Splash.ground`)
with the logo in the middle, so the hand-over from the system's splash cannot
be seen. Then, in a little under two seconds:

1. **A speech bubble springs out of the logo's A.**
2. **It speaks.** Its five bars move like the voice message after an attempt.
3. **Three stars pop out over the logo**, one after another: the score.
4. **The logo swells and the red clears.** The app is underneath, rising in as
   it always does.

The app is only built as it is revealed, so its own entrance plays while the
splash clears instead of unseen behind it. A tap skips straight to the reveal.
Under reduced motion nothing moves: the logo just gives way to the app.

It is mounted once, over everything, through `MaterialApp.router`'s `builder`
in `app.dart`. The routes know nothing about it.

## Changing the mark

Edit `AppMark` (or, if CNA's logo changes, the outlines in `CnaLogo`: the `d`
of each `<path>` in the new SVG, in order, and its `viewBox`), then redraw:

```bash
melos run branding
```

That draws every image each platform wants, each at its own size from the
vector mark rather than shrunk from one big bitmap, and writes it in place:

| Platform | Images |
|---|---|
| iOS | `AppIcon.appiconset/*` (opaque, every size the set lists), `LaunchImage.imageset/*` (the logo, 200 pt box) |
| Android | `mipmap-*/ic_launcher.png` (legacy, shaped), `mipmap-*/ic_launcher_{background,foreground,monochrome}.png` (adaptive, the logo inside the 66 dp safe zone; the monochrome layer for Android 13 themed icons is the same white logo, since only its shape counts), `drawable-*/splash_mark.png` (200 dp box), `drawable-*/splash_mark_android12.png` (288 dp, the logo showing whole inside the system's 192 dp circle) |
| Web | `favicon.png`, `icons/Icon-{192,512}.png`, `icons/Icon-maskable-{192,512}.png` |

**Those images are generated. Never edit them.** The tool runs under
`flutter test` because drawing needs Flutter's engine.

The native files that place the images were written by hand, once:

- `android/app/src/main/res/values/colors.xml`: `splash_ground`.
- `drawable*/launch_background.xml`: the launch screen before Android 12.
- `values-v31/styles.xml` and `values-night-v31/styles.xml`: Android 12+.
- `mipmap-anydpi-v26/ic_launcher.xml`: the adaptive icon.
- `ios/Runner/Base.lproj/LaunchScreen.storyboard`: the background colour.
- `web/manifest.json`: `background_color` and `theme_color`.

Each uses the same red as `Splash.ground`. `test/app/splash_test.dart` reads
the Android colour, the storyboard and the manifest and fails if one drifts
from it.

**Why not `flutter_launcher_icons` or `flutter_native_splash`?**
`flutter_launcher_icons` pins `cli_util` below 0.5, and melos needs 0.5 or
later. The workspace has one lockfile, so the two cannot both be in it. Drawing
the icons ourselves also means each size is rendered sharp from the vector,
with no dependency to carry.
