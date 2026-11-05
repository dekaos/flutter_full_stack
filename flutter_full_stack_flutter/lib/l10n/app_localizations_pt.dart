// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get themeToDark => 'Mudar para o tema escuro';

  @override
  String get themeToLight => 'Mudar para o tema claro';

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
  String get practiceRecord => 'Segure para gravar';

  @override
  String get practiceHoldToTryAgain => 'Segure para tentar de novo';

  @override
  String practiceRecordingLeft(int seconds) {
    return 'Gravando, faltam $seconds s. Solte para terminar.';
  }

  @override
  String practiceHoldOffer(int seconds) {
    return 'Segure para falar · até $seconds s';
  }

  @override
  String get practiceHoldLonger => 'Segure o botão enquanto fala';

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
      'Ficou curto demais. Segure o botão até terminar de ler.';

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

  @override
  String get huntTitle => 'Caça-Palavras';

  @override
  String get huntTagline =>
      'A gente pede uma palavra. Ache ela em inglês e acerte a nave.';

  @override
  String get huntPronunciation => 'Praticar pronúncia';

  @override
  String get huntLevelFirst => 'Primeiros passos';

  @override
  String get huntLevelEveryday => 'No dia a dia';

  @override
  String get huntLevelFurther => 'Indo além';

  @override
  String huntDeckWords(int count) {
    return '$count palavras';
  }

  @override
  String huntDeckBest(int score) {
    final intl.NumberFormat scoreNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String scoreString = scoreNumberFormat.format(score);

    return 'Recorde $scoreString';
  }

  @override
  String huntDeckStars(int stars) {
    String _temp0 = intl.Intl.pluralLogic(
      stars,
      locale: localeName,
      other: '$stars estrelas de 3',
      one: '1 estrela de 3',
      zero: 'Nenhuma estrela ainda',
    );
    return '$_temp0';
  }

  @override
  String get huntDeckGreetings => 'Frases do dia a dia';

  @override
  String get huntDeckColors => 'Cores';

  @override
  String get huntDeckNumbers => 'Números';

  @override
  String get huntDeckAnimals => 'Animais';

  @override
  String get huntDeckFamily => 'Família e pessoas';

  @override
  String get huntDeckFood => 'Comida e bebida';

  @override
  String get huntDeckHome => 'Em casa';

  @override
  String get huntDeckBody => 'O corpo';

  @override
  String get huntDeckClothes => 'Roupas';

  @override
  String get huntDeckTime => 'Dias e horas';

  @override
  String get huntDeckCity => 'Pela cidade';

  @override
  String get huntDeckNature => 'Natureza e clima';

  @override
  String get huntDeckSchool => 'Escola e trabalho';

  @override
  String get huntDeckActions => 'Ações';

  @override
  String get huntDeckFeelings => 'Como é, como está';

  @override
  String get huntFind => 'Ache em inglês';

  @override
  String get huntAnswerWas => 'A resposta era';

  @override
  String huntWordOf(int current, int total) {
    return 'Palavra $current de $total';
  }

  @override
  String get huntScore => 'Pontos';

  @override
  String huntCombo(double multiplier) {
    final intl.NumberFormat multiplierNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String multiplierString = multiplierNumberFormat.format(multiplier);

    return 'Combo ×$multiplierString';
  }

  @override
  String huntShields(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Restam $count escudos',
      one: 'Resta 1 escudo',
      zero: 'Sem escudos',
    );
    return '$_temp0';
  }

  @override
  String get huntHint => 'Dica';

  @override
  String huntHintsLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Restam $count dicas',
      one: 'Resta 1 dica',
      zero: 'Sem dicas',
    );
    return '$_temp0';
  }

  @override
  String get huntPause => 'Pausar';

  @override
  String get huntPaused => 'Pausado';

  @override
  String get huntResume => 'Continuar';

  @override
  String get huntQuit => 'Sair da missão';

  @override
  String get huntReady => 'Prepare-se!';

  @override
  String get huntGo => 'Já!';

  @override
  String get huntShipsLabel => 'Naves';

  @override
  String huntShoot(String word) {
    return 'Atirar em “$word”';
  }

  @override
  String get huntResultsDone => 'Missão cumprida!';

  @override
  String get huntResultsAlmost => 'Quase lá!';

  @override
  String get huntResultsWrecked => 'Os escudos acabaram!';

  @override
  String get huntNewBest => 'Novo recorde!';

  @override
  String huntFoundOf(int found, int total) {
    return '$found de $total palavras encontradas';
  }

  @override
  String huntBestStreak(int count) {
    return 'Maior sequência: $count';
  }

  @override
  String get huntMissionWords => 'As palavras da missão';

  @override
  String huntHear(String word) {
    return 'Ouvir “$word”';
  }

  @override
  String get huntPlayAgain => 'Jogar de novo';

  @override
  String get huntOtherThemes => 'Outros temas';

  @override
  String huntStars(int stars) {
    String _temp0 = intl.Intl.pluralLogic(
      stars,
      locale: localeName,
      other: '$stars estrelas',
      one: '1 estrela',
      zero: 'Nenhuma estrela',
    );
    return '$_temp0';
  }
}
