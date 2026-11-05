// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get themeToDark => 'Switch to the dark theme';

  @override
  String get themeToLight => 'Switch to the light theme';

  @override
  String languageTooltip(String name) {
    return 'Language: $name';
  }

  @override
  String get languageSystem => 'following the device';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageKorean => '한국어';

  @override
  String get languagePortuguese => 'Português';

  @override
  String get languageSpanish => 'Español';

  @override
  String get pickLanguageHeadline => 'What are you practising?';

  @override
  String get packReady => 'On this device';

  @override
  String get packOnce => 'Downloaded once, then practice works offline.';

  @override
  String languageDownload(int megabytes) {
    return 'Download · $megabytes MB';
  }

  @override
  String get languageStart => 'Start practising';

  @override
  String get packDownloading => 'Downloading the pack';

  @override
  String packDownloadingPercent(int percent) {
    return 'Downloading · $percent%';
  }

  @override
  String packProgress(int received, int total) {
    return '$received of $total MB';
  }

  @override
  String get packChecking => 'Checking the pack';

  @override
  String get packInterrupted =>
      'Stopped partway. Tap to pick up where it left off.';

  @override
  String get packDamaged => 'Arrived damaged. Tap to download it again.';

  @override
  String practicePosition(int current, int total) {
    return '$current of $total';
  }

  @override
  String get practiceRecord => 'Hold to record';

  @override
  String get practiceHoldToTryAgain => 'Hold to try again';

  @override
  String practiceRecordingLeft(int seconds) {
    return 'Recording, $seconds s left. Let go to finish.';
  }

  @override
  String practiceHoldOffer(int seconds) {
    return 'Hold to speak · up to $seconds s';
  }

  @override
  String get practiceHoldLonger => 'Hold the button while you speak';

  @override
  String get practiceScoring => 'Scoring';

  @override
  String get practiceNoMicrophone =>
      'Practice needs the microphone. Turn it on in settings.';

  @override
  String get practiceAccuracy => 'Pronunciation';

  @override
  String get practiceFluency => 'Fluency';

  @override
  String get practiceFluencyDiagnostic => 'diagnostic only';

  @override
  String practiceRhythmDetail(String rate, int pauses) {
    String _temp0 = intl.Intl.pluralLogic(
      pauses,
      locale: localeName,
      other: '$pauses pauses',
      one: '1 pause',
      zero: 'no pauses',
    );
    return '$rate phonemes per second, $_temp0';
  }

  @override
  String practiceHeardInstead(String phoneme) {
    return 'sounded like $phoneme';
  }

  @override
  String get practiceNextSentence => 'Next sentence';

  @override
  String get practiceTryAgain => 'Try again';

  @override
  String get practiceUnavailable => 'Practice could not open.';

  @override
  String get practiceRecordFailed =>
      'The microphone could not start. Try again.';

  @override
  String get practiceScoreFailed =>
      'This attempt could not be scored. Record it again.';

  @override
  String get practiceTooShort =>
      'That was too short. Hold the button until you have finished reading.';

  @override
  String get practiceNotHeard =>
      'We could not hear you read it. Read the whole text, close to the microphone.';

  @override
  String get practiceOpenSettings => 'Open settings';

  @override
  String get licensesTooltip => 'Licenses';

  @override
  String get practiceListen => 'Listen';

  @override
  String get practiceListenStop => 'Stop reading';

  @override
  String get practiceSoundsOn => 'Sounds on';

  @override
  String get practiceSoundsOff => 'Sounds off';

  @override
  String practiceScoreDetails(int score) {
    return 'Pronunciation $score. See details';
  }

  @override
  String practiceHearWord(String word) {
    return 'Hear “$word”';
  }

  @override
  String get practiceReplay => 'Hear yourself';

  @override
  String get practiceReplayStop => 'Stop playback';

  @override
  String practiceHearWordYours(String word) {
    return 'Hear how you said “$word”';
  }
}
