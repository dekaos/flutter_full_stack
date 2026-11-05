import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_pt.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('pt'),
  ];

  /// Tooltip on the theme button while the app is light.
  ///
  /// In en, this message translates to:
  /// **'Switch to the dark theme'**
  String get themeToDark;

  /// Tooltip on the theme button while the app is dark.
  ///
  /// In en, this message translates to:
  /// **'Switch to the light theme'**
  String get themeToLight;

  /// Tooltip on the language switch button.
  ///
  /// In en, this message translates to:
  /// **'Language: {name}'**
  String languageTooltip(String name);

  /// Language is whatever the device asks for.
  ///
  /// In en, this message translates to:
  /// **'following the device'**
  String get languageSystem;

  /// Name of the English locale.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// Name of the Korean language, in that language.
  ///
  /// In en, this message translates to:
  /// **'한국어'**
  String get languageKorean;

  /// Name of the Portuguese locale, in that language.
  ///
  /// In en, this message translates to:
  /// **'Português'**
  String get languagePortuguese;

  /// Name of the Spanish language, in that language.
  ///
  /// In en, this message translates to:
  /// **'Español'**
  String get languageSpanish;

  /// Main heading on the language chooser.
  ///
  /// In en, this message translates to:
  /// **'What are you practising?'**
  String get pickLanguageHeadline;

  /// Shown on a language whose pack is already downloaded.
  ///
  /// In en, this message translates to:
  /// **'On this device'**
  String get packReady;

  /// Under a language whose pack is not on the device yet, before the download button.
  ///
  /// In en, this message translates to:
  /// **'Downloaded once, then practice works offline.'**
  String get packOnce;

  /// The button that downloads a language's pack, with its size.
  ///
  /// In en, this message translates to:
  /// **'Download · {megabytes} MB'**
  String languageDownload(int megabytes);

  /// The button that opens practice in a language whose pack is on the device.
  ///
  /// In en, this message translates to:
  /// **'Start practising'**
  String get languageStart;

  /// On the download button before the server has said how big the pack is.
  ///
  /// In en, this message translates to:
  /// **'Downloading the pack'**
  String get packDownloading;

  /// On the download button as it fills: how much of the pack has come down.
  ///
  /// In en, this message translates to:
  /// **'Downloading · {percent}%'**
  String packDownloadingPercent(int percent);

  /// Under a language whose pack is downloading: how much has come down, in megabytes.
  ///
  /// In en, this message translates to:
  /// **'{received} of {total} MB'**
  String packProgress(int received, int total);

  /// On the download button, full, for the couple of seconds after the pack has come down, while it is checked against its SHA-256.
  ///
  /// In en, this message translates to:
  /// **'Checking the pack'**
  String get packChecking;

  /// Under a language whose download failed. What arrived is kept, so trying again resumes it.
  ///
  /// In en, this message translates to:
  /// **'Stopped partway. Tap to pick up where it left off.'**
  String get packInterrupted;

  /// Under a language whose downloaded pack did not match its SHA-256. It was deleted, so trying again downloads it from the start.
  ///
  /// In en, this message translates to:
  /// **'Arrived damaged. Tap to download it again.'**
  String get packDamaged;

  /// Which prompt of the deck is on screen.
  ///
  /// In en, this message translates to:
  /// **'{current} of {total}'**
  String practicePosition(int current, int total);

  /// The record button, for a screen reader: it is held while the learner reads the sentence.
  ///
  /// In en, this message translates to:
  /// **'Hold to record'**
  String get practiceRecord;

  /// The record button once an attempt has been scored, for a screen reader.
  ///
  /// In en, this message translates to:
  /// **'Hold to try again'**
  String get practiceHoldToTryAgain;

  /// The record button while it records, for a screen reader.
  ///
  /// In en, this message translates to:
  /// **'Recording, {seconds} s left. Let go to finish.'**
  String practiceRecordingLeft(int seconds);

  /// Bubble over the record button until the learner first records: how to use it, and how long an attempt may be.
  ///
  /// In en, this message translates to:
  /// **'Hold to speak · up to {seconds} s'**
  String practiceHoldOffer(int seconds);

  /// Bubble over the record button after it was tapped rather than held.
  ///
  /// In en, this message translates to:
  /// **'Hold the button while you speak'**
  String get practiceHoldLonger;

  /// Shown while the recording is being scored.
  ///
  /// In en, this message translates to:
  /// **'Scoring'**
  String get practiceScoring;

  /// Shown when microphone permission was refused.
  ///
  /// In en, this message translates to:
  /// **'Practice needs the microphone. Turn it on in settings.'**
  String get practiceNoMicrophone;

  /// Caption for the phoneme accuracy part of the score.
  ///
  /// In en, this message translates to:
  /// **'Pronunciation'**
  String get practiceAccuracy;

  /// Caption for the rhythm and pausing measure, reported beside the score.
  ///
  /// In en, this message translates to:
  /// **'Fluency'**
  String get practiceFluency;

  /// Says the fluency number does not count towards the score.
  ///
  /// In en, this message translates to:
  /// **'diagnostic only'**
  String get practiceFluencyDiagnostic;

  /// The raw rhythm measurements behind the fluency number.
  ///
  /// In en, this message translates to:
  /// **'{rate} phonemes per second, {pauses, plural, =0{no pauses} =1{1 pause} other{{pauses} pauses}}'**
  String practiceRhythmDetail(String rate, int pauses);

  /// Names the phoneme the model heard in place of the right one.
  ///
  /// In en, this message translates to:
  /// **'sounded like {phoneme}'**
  String practiceHeardInstead(String phoneme);

  /// Moves practice on to the next prompt.
  ///
  /// In en, this message translates to:
  /// **'Next sentence'**
  String get practiceNextSentence;

  /// Records another attempt at the same sentence.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get practiceTryAgain;

  /// Shown when the practice screen could not load at all.
  ///
  /// In en, this message translates to:
  /// **'Practice could not open.'**
  String get practiceUnavailable;

  /// Shown when recording could not begin.
  ///
  /// In en, this message translates to:
  /// **'The microphone could not start. Try again.'**
  String get practiceRecordFailed;

  /// Shown when a recording was made but could not be scored.
  ///
  /// In en, this message translates to:
  /// **'This attempt could not be scored. Record it again.'**
  String get practiceScoreFailed;

  /// Shown when a recording holds too little audio to score.
  ///
  /// In en, this message translates to:
  /// **'That was too short. Hold the button until you have finished reading.'**
  String get practiceTooShort;

  /// Shown when a recording holds no speech, or only a fragment of the prompt.
  ///
  /// In en, this message translates to:
  /// **'We could not hear you read it. Read the whole text, close to the microphone.'**
  String get practiceNotHeard;

  /// Button that opens the app's page in the system settings, where the microphone can be allowed.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get practiceOpenSettings;

  /// Tooltip of the app bar button that opens the licences page, including the pronunciation models'.
  ///
  /// In en, this message translates to:
  /// **'Licenses'**
  String get licensesTooltip;

  /// Button that reads the sentence aloud, in the accent it is scored against, for the learner to copy.
  ///
  /// In en, this message translates to:
  /// **'Listen'**
  String get practiceListen;

  /// The listen button while the sentence is being read aloud: stops the reading.
  ///
  /// In en, this message translates to:
  /// **'Stop reading'**
  String get practiceListenStop;

  /// Tooltip of the button that turns off the scenes', the cat's and the score's sounds, while they are on. The sentence can still be listened to.
  ///
  /// In en, this message translates to:
  /// **'Sounds on'**
  String get practiceSoundsOn;

  /// Tooltip of the same button while those sounds are off.
  ///
  /// In en, this message translates to:
  /// **'Sounds off'**
  String get practiceSoundsOff;

  /// Label of the round score badge beside the record button. Tapping it opens the full result: fluency, rhythm and every phoneme that went wrong.
  ///
  /// In en, this message translates to:
  /// **'Pronunciation {score}. See details'**
  String practiceScoreDetails(int score);

  /// Tooltip of the speaker button that reads one word of the sentence aloud.
  ///
  /// In en, this message translates to:
  /// **'Hear “{word}”'**
  String practiceHearWord(String word);

  /// Button on the learner's own recording, drawn as a voice message: plays their last attempt back to them while the sentence lights up word by word.
  ///
  /// In en, this message translates to:
  /// **'Hear yourself'**
  String get practiceReplay;

  /// The same button while the learner's recording is playing: stops it.
  ///
  /// In en, this message translates to:
  /// **'Stop playback'**
  String get practiceReplayStop;

  /// Tooltip of the button that plays back just one word, cut from the learner's own recording, to compare with how it should sound.
  ///
  /// In en, this message translates to:
  /// **'Hear how you said “{word}”'**
  String practiceHearWordYours(String word);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'pt'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'pt':
      return AppLocalizationsPt();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
