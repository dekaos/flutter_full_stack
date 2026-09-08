// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get headline => 'Say hello.';

  @override
  String get tagline =>
      'Your name travels to the Serverpod endpoint and comes back as a typed model.';

  @override
  String get nameFieldLabel => 'Your name';

  @override
  String get sendTooltip => 'Send';

  @override
  String get responseLabel => 'From the server';

  @override
  String get errorLabel => 'The call failed';

  @override
  String get callingServer => 'Calling the server';

  @override
  String themeTooltip(String mode) {
    return 'Theme: $mode';
  }

  @override
  String get themeModeSystem => 'following the device';

  @override
  String get themeModeLight => 'light';

  @override
  String get themeModeDark => 'dark';

  @override
  String languageTooltip(String name) {
    return 'Language: $name';
  }

  @override
  String get languageSystem => 'following the device';

  @override
  String get languageEnglish => 'English';

  @override
  String get languagePortuguese => 'Português';
}
