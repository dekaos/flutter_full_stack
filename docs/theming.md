# Theming

Two knobs produce the whole look: a seed colour and a font call. Everything
else — light, dark, both high-contrast variants, and the glass — is derived
from them.

![Two knobs, four themes](theming-flow.svg)

## Where it lives

| File | Role |
|---|---|
| `lib/theme/app_theme.dart` | the two knobs, and the four `ThemeData` |
| `lib/theme/app_tokens.dart` | the tokens Material has no slot for |
| `lib/theme/app_tokens.tailor.dart` | generated — `copyWith`, `lerp`, equality |
| `lib/theme/glass_surface.dart` | the translucent pane |
| `lib/theme/app_backdrop.dart` | the gradient a screen sits on |
| `lib/theme/theme_mode_controller.dart` | lets a user override the device |

## Changing the look

**Colours.** One line in `app_theme.dart`:

```dart
static const seed = Color(0xFF6C5CE7);
```

Every Material colour comes from `ColorScheme.fromSeed` on that seed, and every
token in `AppTokens.of` is derived from the resulting scheme — so the glass tint
and the backdrop gradient move with it too. There is no second place to update.

**Font.** One line, same file:

```dart
static TextTheme _font(TextTheme base) => GoogleFonts.interTextTheme(base);
```

Any `GoogleFonts.*TextTheme` works.

**A new token.** Add the field, run the generator:

```dart
@override
final double gutter;
```

`melos run generate` writes the `copyWith`, `lerp` and equality for it. Two
things the compiler will remind you of: the field needs `@override`, because the
generated mixin declares it abstract, and it has to be set in both branches of
`AppTokens.of`.

## The four themes, and who picks

A device asks for more than light or dark: it can also ask for increased
contrast. `MaterialApp` has a slot for each combination, all four built from the
same seed by the same function, so they cannot drift apart.

`themeMode` defaults to `ThemeMode.system`, which means following the device
costs nothing — no provider, no listener. `ThemeModeController` exists only so a
user can *override* it, and the choice is deliberately not persisted; that would
need a storage dependency the app does not have yet.

These are real screenshots of the app, taken by flipping the simulator's own
appearance and "Increase Contrast" settings:

![The three variants side by side](theming-variants.png)

Look at the third one. The glass is gone: the pane is opaque, the border is
hard, the gradient is flat. That is not a special case in the screen's code —
`AppTokens.of` returns `glassBlur: 0` and an opaque fill when the device asks
for contrast, and `GlassSurface` skips the `BackdropFilter` entirely when the
blur is zero. **A translucent surface cannot honour a contrast request, so it
stops being translucent.** No widget branches on it.

## Reading tokens

```dart
final tokens = Theme.of(context).appTokens;
```

One getter, generated. A widget never asks whether it is light or dark — it
reads a token and gets the value for whichever theme is live.

That is the reason the tokens are a `ThemeExtension` rather than global
constants behind an `if (isDark)`. When the device flips at sunset, Flutter
animates between the two `ThemeData`, and the generated `lerp` carries the glass
tint and blur along with the colours. Constants would snap mid-transition.

## Using the glass

```dart
Scaffold(
  extendBodyBehindAppBar: true,   // so the backdrop runs under the bar
  appBar: AppBar(title: const Text('...')),
  body: AppBackdrop(
    child: GlassSurface(child: ...),
  ),
)
```

`AppBackdrop` is not decoration. `GlassSurface` blurs what is behind it, so over
a flat background it reads as flat translucent paint rather than glass. The
backdrop is what gives it something to refract, which is why it is part of the
design system.

`GlassSurface` takes an `onTap`. Without it there is no gesture handling and no
animation controller at all — the pane has no idle animation on purpose, because
one that pulses forever costs a repaint every frame for the life of the screen,
multiplied by the number of panes on it. With `onTap` it gets an ink ripple and
a small press scale, and that scale is skipped when the device asks for reduced
motion.

## Three things that will bite

**A widget test must supply a theme.** The generated getter ends in `!`, so a
bare `MaterialApp` throws rather than falling back:

```dart
MaterialApp(theme: AppTheme.light(), home: const GreetingsScreen())
```

`test/widget_test.dart` shows it. This is the failure you get if you forget:
`_TypeError` while building `AppBackdrop`.

**`google_fonts` fetches the family at runtime** on first use and caches it,
which means a first run needs network and shows a fallback face until it lands.
To avoid that, bundle the `.ttf` files as assets and set
`GoogleFonts.config.allowRuntimeFetching = false`. That decision is still open
here.

**The generator writes `*.tailor.dart`, not `*.g.dart`.** It is a second
generated suffix, and the analyzer excludes in
`flutter_full_stack_flutter/analysis_options.yaml` list both. Anything that
reasons about generated files by name has to know about both.
