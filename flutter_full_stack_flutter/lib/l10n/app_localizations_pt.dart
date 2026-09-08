// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get headline => 'Diga olá.';

  @override
  String get tagline =>
      'Seu nome viaja até o endpoint do Serverpod e volta como um modelo tipado.';

  @override
  String get nameFieldLabel => 'Seu nome';

  @override
  String get sendTooltip => 'Enviar';

  @override
  String get responseLabel => 'Do servidor';

  @override
  String get errorLabel => 'A chamada falhou';

  @override
  String get callingServer => 'Chamando o servidor';

  @override
  String themeTooltip(String mode) {
    return 'Tema: $mode';
  }

  @override
  String get themeModeSystem => 'seguindo o aparelho';

  @override
  String get themeModeLight => 'claro';

  @override
  String get themeModeDark => 'escuro';

  @override
  String languageTooltip(String name) {
    return 'Idioma: $name';
  }

  @override
  String get languageSystem => 'seguindo o aparelho';

  @override
  String get languageEnglish => 'English';

  @override
  String get languagePortuguese => 'Português';
}
