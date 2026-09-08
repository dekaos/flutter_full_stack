import 'package:flutter/material.dart';
import 'package:flutter_full_stack_flutter/l10n/app_localizations.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'locale_controller.g.dart';

/// Whether the app follows the device's language or is pinned to one.
///
/// `null` means follow the device, which is also what `MaterialApp.locale`
/// treats as "resolve from the platform" — so following is the default and
/// costs nothing. This provider exists to let a user *override* it.
///
/// The choice is not persisted: that would need a storage dependency the app
/// does not have. Restarting returns to the device's language.
@Riverpod(keepAlive: true)
class LocaleController extends _$LocaleController {
  @override
  Locale? build() => null;

  /// Cycles through every supported language and back to following the
  /// device, starting with a language the device is *not* asking for.
  ///
  /// The order depends on [deviceLocale] for a reason. Stepping from "follow
  /// the device" to a fixed `supportedLocales.first` changes nothing on screen
  /// when the device is already English: the state moves, the copy does not,
  /// and the tap reads as one the app missed. Starting with a different
  /// language makes the first tap always visible.
  void cycle(Locale deviceLocale) {
    final ordered = _cycleOrder(deviceLocale);
    final current = state;
    if (current == null) {
      state = ordered.first;
      return;
    }
    final next = ordered.indexOf(current) + 1;
    state = next < ordered.length ? ordered[next] : null;
  }

  /// The supported languages with the device's own last, so that the step
  /// which renders the same copy as "follow the device" is the one right
  /// before returning to it.
  static List<Locale> _cycleOrder(Locale deviceLocale) => [
    ...AppLocalizations.supportedLocales.where((l) => l != deviceLocale),
    ...AppLocalizations.supportedLocales.where((l) => l == deviceLocale),
  ];
}

/// The language the device is asking for, narrowed to one the app has.
///
/// This is the resolution `MaterialApp` performs for itself when `locale` is
/// `null`, so while the user has overridden nothing it is exactly what is on
/// screen. [LocaleController.cycle] needs the *device's* language and not the
/// effective one — once a language is pinned, `Localizations.localeOf` returns
/// the pin and no longer says anything about the device.
Locale deviceLocaleOf(BuildContext context) => basicLocaleListResolution(
  View.of(context).platformDispatcher.locales,
  AppLocalizations.supportedLocales,
);
