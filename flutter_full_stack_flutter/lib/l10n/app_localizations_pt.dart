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
  String get languageKorean => '한국어';

  @override
  String get languagePortuguese => 'Português';

  @override
  String get languageSpanish => 'Español';

  @override
  String get pickLanguageHeadline => 'O que você vai praticar?';

  @override
  String get packReady => 'Neste aparelho';

  @override
  String get packOnce => 'Baixado uma vez, a prática funciona sem internet.';

  @override
  String languageDownload(int megabytes) {
    return 'Baixar · $megabytes MB';
  }

  @override
  String get languageStart => 'Começar a praticar';

  @override
  String get packDownloading => 'Baixando o pacote';

  @override
  String packDownloadingPercent(int percent) {
    return 'Baixando · $percent%';
  }

  @override
  String packProgress(int received, int total) {
    return '$received de $total MB';
  }

  @override
  String get packChecking => 'Conferindo o pacote';

  @override
  String get packInterrupted =>
      'Parou no meio. Toque para continuar de onde parou.';

  @override
  String get packDamaged => 'Chegou com defeito. Toque para baixar de novo.';

  @override
  String practicePosition(int current, int total) {
    return '$current de $total';
  }

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
  String get practiceRecordFailed =>
      'Não deu para começar a gravar. Tente de novo.';

  @override
  String get practiceScoreFailed =>
      'Não deu para avaliar essa tentativa. Grave de novo.';

  @override
  String get practiceTooShort =>
      'Ficou curto demais. Toque em Parar depois de terminar de ler.';

  @override
  String get practiceNotHeard =>
      'Não deu para ouvir você lendo. Leia o texto inteiro, perto do microfone.';

  @override
  String get practiceOpenSettings => 'Abrir configurações';

  @override
  String get licensesTooltip => 'Licenças';

  @override
  String get practiceListen => 'Ouvir';

  @override
  String get practiceListenStop => 'Parar a leitura';

  @override
  String get practiceSoundsOn => 'Sons ligados';

  @override
  String get practiceSoundsOff => 'Sons desligados';

  @override
  String practiceScoreDetails(int score) {
    return 'Pronúncia $score. Ver detalhes';
  }

  @override
  String practiceHearWord(String word) {
    return 'Ouvir “$word”';
  }

  @override
  String get practiceReplay => 'Ouvir sua voz';

  @override
  String get practiceReplayStop => 'Parar a reprodução';

  @override
  String practiceHearWordYours(String word) {
    return 'Ouvir como você disse “$word”';
  }
}
