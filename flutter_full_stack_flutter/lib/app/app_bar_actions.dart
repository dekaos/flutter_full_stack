import 'package:flutter/material.dart';
import 'package:flutter_full_stack_flutter/app/locale_controller.dart';
import 'package:flutter_full_stack_flutter/features/pronunciation/providers/practice_audio.dart';
import 'package:flutter_full_stack_flutter/l10n/app_localizations.dart';
import 'package:flutter_full_stack_flutter/theme/theme_mode_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The app bar's controls - sounds, language, theme and licences - on every
/// screen that has an app bar, each shown or not by its own flag.
///
/// They are app-level controls, not a feature's: whichever screen a user is
/// on is where they need them, not the one they would have to navigate to
/// first. The defaults are what the app offers today, so a screen just uses
/// `const AppBarActions()`; change a default here, or pass a flag where one
/// screen should differ.
class AppBarActions extends ConsumerWidget {
  const AppBarActions({
    this.sounds = true,
    this.language = false,
    this.theme = true,
    this.licenses = true,
    super.key,
  });

  /// The switch for practice's sounds - the scenes', the cat's and the
  /// score's. The voice reading a prompt is not one of them, and stays.
  final bool sounds;

  /// The language switch. Off for now: the app follows the device's
  /// language, and the cycle stays in place for when it is offered again.
  final bool language;

  /// The theme switch: light to dark, or dark to light, in one tap.
  final bool theme;

  /// The way to the licences page - which is where the attribution the
  /// models' Apache-2.0 licence requires is shown, so it is on by default:
  /// registered is not enough, it has to be reachable.
  final bool licenses;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final device = MediaQuery.platformBrightnessOf(context);
    final shown = shownIn(
      ref.watch(themeModeControllerProvider),
      device: device,
    );
    final locale = ref.watch(localeControllerProvider);
    final soundsOn = ref.watch(soundEffectsProvider);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (sounds)
          IconButton(
            key: const Key('app-sounds'),
            onPressed: ref.read(soundEffectsProvider.notifier).toggle,
            icon: Icon(
              soundsOn ? Icons.volume_up_outlined : Icons.volume_off_outlined,
            ),
            tooltip: soundsOn ? l10n.practiceSoundsOn : l10n.practiceSoundsOff,
          ),
        if (language)
          IconButton(
            key: const Key('app-language'),
            onPressed: () => ref
                .read(localeControllerProvider.notifier)
                .cycle(deviceLocaleOf(context)),
            icon: Icon(_localeIconFor(locale)),
            tooltip: l10n.languageTooltip(_languageName(l10n, locale)),
          ),
        if (theme)
          IconButton(
            key: const Key('app-theme'),
            onPressed: () =>
                ref.read(themeModeControllerProvider.notifier).toggle(device),
            // What a tap does: the moon in the light, the sun in the dark.
            icon: Icon(switch (shown) {
              Brightness.light => Icons.dark_mode_outlined,
              Brightness.dark => Icons.light_mode_outlined,
            }),
            tooltip: switch (shown) {
              Brightness.light => l10n.themeToDark,
              Brightness.dark => l10n.themeToLight,
            },
          ),
        if (licenses)
          IconButton(
            key: const Key('app-licenses'),
            onPressed: () => showLicensePage(context: context),
            icon: const Icon(Icons.info_outline),
            tooltip: l10n.licensesTooltip,
          ),
      ],
    );
  }

  /// A globe for "whatever the device speaks", a translate mark for a language
  /// the user picked. Pinning the language the device already speaks renders
  /// identical copy, so the icon is the only thing that can report the change.
  IconData _localeIconFor(Locale? locale) =>
      locale == null ? Icons.language_outlined : Icons.translate_outlined;

  /// A locale's own name, never translated: a language picker that renders
  /// every option in the language you are already reading is useless to
  /// someone who cannot read it.
  String _languageName(AppLocalizations l10n, Locale? locale) {
    if (locale == null) return l10n.languageSystem;

    return switch (locale.languageCode) {
      'en' => l10n.languageEnglish,
      'pt' => l10n.languagePortuguese,
      // A supported locale with no name here is an unfinished change, not a
      // state to handle: dropping an .arb file into lib/l10n puts the locale
      // into the cycle on its own, and this switch has to keep up. Showing
      // the raw code makes that visible instead of mislabelling the new
      // language as "following the device".
      _ => locale.languageCode.toUpperCase(),
    };
  }
}
