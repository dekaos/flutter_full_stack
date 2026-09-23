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

  @override
  String get languageSpanish => 'Español';

  @override
  String get pickLanguageHeadline => 'What are you practising?';

  @override
  String get pickLanguageTagline =>
      'Each language has its own pack. Once it is on the device, practice works offline.';

  @override
  String get packReady => 'On this device';

  @override
  String packMissing(int megabytes) {
    return '$megabytes MB to download';
  }

  @override
  String get practiceWords => 'Words';

  @override
  String get practicePhrases => 'Phrases';

  @override
  String practicePosition(int current, int total) {
    return '$current of $total';
  }

  @override
  String get practiceHeadline => 'Read it out loud.';

  @override
  String get practiceTagline =>
      'Your pronunciation is scored on this device. Nothing is uploaded.';

  @override
  String get practiceDownloadPack => 'Download the language pack';

  @override
  String practiceDownloadExplainer(int megabytes) {
    return 'About $megabytes MB, once. After that, practice works with no connection.';
  }

  @override
  String get practiceDownloading => 'Downloading the language pack';

  @override
  String get practiceRecord => 'Record';

  @override
  String get practiceStop => 'Stop';

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
  String get practiceDownloadFailed =>
      'The language pack did not download. Check your connection and try again.';

  @override
  String get practiceRecordFailed =>
      'The microphone could not start. Try again.';

  @override
  String get practiceScoreFailed =>
      'This attempt could not be scored. Record it again.';

  @override
  String get practiceTooShort =>
      'That was too short. Tap Stop once you have finished reading.';

  @override
  String get practiceNotHeard =>
      'We could not hear you read it. Read the whole text, close to the microphone.';
}
