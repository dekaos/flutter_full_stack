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

  /// Cycles device → English → Portuguese → device, which is enough for one
  /// button while there are two languages.
  void cycle() {
    const supported = AppLocalizations.supportedLocales;
    final current = state;
    if (current == null) {
      state = supported.first;
      return;
    }
    final next = supported.indexOf(current) + 1;
    state = next < supported.length ? supported[next] : null;
  }
}
