import 'package:flutter/services.dart';

/// Opens the app's own page in the system settings.
///
/// It is the only way back from a refused permission: once the microphone is
/// denied, iOS never asks again, and neither does Android after the second
/// refusal. A few lines of platform code in `MainActivity.kt` and
/// `AppDelegate.swift` rather than a plugin, because this is the one thing
/// needed from one - `permission_handler`, the usual choice, also wants a
/// macro per permission in the Podfile.
class AppSettings {
  const AppSettings();

  static const _channel = MethodChannel(
    'br.com.stuhler.flutter_full_stack/app_settings',
  );

  Future<void> open() => _channel.invokeMethod<void>('open');
}
