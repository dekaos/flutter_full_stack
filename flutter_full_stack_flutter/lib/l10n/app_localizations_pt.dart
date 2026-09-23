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

  @override
  String get languageSpanish => 'Español';

  @override
  String get pickLanguageHeadline => 'O que você vai praticar?';

  @override
  String get pickLanguageTagline =>
      'Cada idioma tem seu pacote. Depois que ele está no aparelho, a prática funciona sem conexão.';

  @override
  String get packReady => 'Neste aparelho';

  @override
  String packMissing(int megabytes) {
    return '$megabytes MB para baixar';
  }

  @override
  String get practiceWords => 'Palavras';

  @override
  String get practicePhrases => 'Frases';

  @override
  String practicePosition(int current, int total) {
    return '$current de $total';
  }

  @override
  String get practiceHeadline => 'Leia em voz alta.';

  @override
  String get practiceTagline =>
      'Sua pronúncia é avaliada neste aparelho. Nada é enviado.';

  @override
  String get practiceDownloadPack => 'Baixar o pacote do idioma';

  @override
  String practiceDownloadExplainer(int megabytes) {
    return 'Cerca de $megabytes MB, uma vez só. Depois disso, a prática funciona sem conexão.';
  }

  @override
  String get practiceDownloading => 'Baixando o pacote do idioma';

  @override
  String get practiceRecord => 'Gravar';

  @override
  String get practiceStop => 'Parar';

  @override
  String get practiceScoring => 'Avaliando';

  @override
  String get practiceNoMicrophone =>
      'A prática precisa do microfone. Libere nas configurações.';

  @override
  String get practiceAccuracy => 'Pronúncia';

  @override
  String get practiceFluency => 'Fluência';

  @override
  String get practiceFluencyDiagnostic => 'só diagnóstico';

  @override
  String practiceRhythmDetail(String rate, int pauses) {
    String _temp0 = intl.Intl.pluralLogic(
      pauses,
      locale: localeName,
      other: '$pauses pausas',
      one: '1 pausa',
      zero: 'sem pausas',
    );
    return '$rate fonemas por segundo, $_temp0';
  }

  @override
  String practiceHeardInstead(String phoneme) {
    return 'soou como $phoneme';
  }

  @override
  String get practiceNextSentence => 'Próxima frase';

  @override
  String get practiceTryAgain => 'Tentar de novo';

  @override
  String get practiceUnavailable => 'A prática não abriu.';

  @override
  String get practiceDownloadFailed =>
      'O pacote do idioma não foi baixado. Confira a conexão e tente de novo.';

  @override
  String get practiceRecordFailed =>
      'Não deu para começar a gravar. Tente de novo.';

  @override
  String get practiceScoreFailed =>
      'Não deu para avaliar essa tentativa. Grave de novo.';
}
