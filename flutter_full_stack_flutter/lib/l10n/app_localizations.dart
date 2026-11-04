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

  /// Main heading on the greetings screen.
  ///
  /// In en, this message translates to:
  /// **'Say hello.'**
  String get headline;

  /// Sentence under the heading explaining what the screen does.
  ///
  /// In en, this message translates to:
  /// **'Your name travels to the Serverpod endpoint and comes back as a typed model.'**
  String get tagline;

  /// Label of the text field the user types a name into.
  ///
  /// In en, this message translates to:
  /// **'Your name'**
  String get nameFieldLabel;

  /// Tooltip on the button that sends the name to the server.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get sendTooltip;

  /// Caption above a successful response. Shown upper-cased.
  ///
  /// In en, this message translates to:
  /// **'From the server'**
  String get responseLabel;

  /// Caption above an error response. Shown upper-cased.
  ///
  /// In en, this message translates to:
  /// **'The call failed'**
  String get errorLabel;

  /// Shown while the request is in flight.
  ///
  /// In en, this message translates to:
  /// **'Calling the server'**
  String get callingServer;

  /// Tooltip on the theme switch button.
  ///
  /// In en, this message translates to:
  /// **'Theme: {mode}'**
  String themeTooltip(String mode);

  /// Theme is whatever the device asks for.
  ///
  /// In en, this message translates to:
  /// **'following the device'**
  String get themeModeSystem;

  /// Theme is pinned to light.
  ///
  /// In en, this message translates to:
  /// **'light'**
  String get themeModeLight;

  /// Theme is pinned to dark.
  ///
  /// In en, this message translates to:
  /// **'dark'**
  String get themeModeDark;

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

  /// Sentence under the chooser heading.
  ///
  /// In en, this message translates to:
  /// **'Each language has its own pack. Once it is on the device, practice works offline.'**
  String get pickLanguageTagline;

  /// Shown on a language whose pack is already downloaded.
  ///
  /// In en, this message translates to:
  /// **'On this device'**
  String get packReady;

  /// Shown on a language whose pack still has to be fetched.
  ///
  /// In en, this message translates to:
  /// **'{megabytes} MB to download'**
  String packMissing(int megabytes);

  /// On a language card while its pack downloads; a ring beside it shows how far.
  ///
  /// In en, this message translates to:
  /// **'Downloading the pack'**
  String get packDownloading;

  /// On a language card for the couple of seconds after its pack has downloaded, while it is checked against its SHA-256.
  ///
  /// In en, this message translates to:
  /// **'Checking the pack'**
  String get packChecking;

  /// On a language card whose download failed. What arrived is kept, so a tap resumes it.
  ///
  /// In en, this message translates to:
  /// **'Stopped partway. Tap to pick up where it left off.'**
  String get packInterrupted;

  /// On a language card whose downloaded pack did not match its SHA-256. It was deleted, so a tap downloads it from the start.
  ///
  /// In en, this message translates to:
  /// **'Arrived damaged. Tap to download it again.'**
  String get packDamaged;

  /// Which prompt of the deck is on screen.
  ///
  /// In en, this message translates to:
  /// **'{current} of {total}'**
  String practicePosition(int current, int total);

  /// Button that starts recording the learner reading the sentence.
  ///
  /// In en, this message translates to:
  /// **'Record'**
  String get practiceRecord;

  /// Button that ends the recording and scores it.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get practiceStop;

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
  /// **'That was too short. Tap Stop once you have finished reading.'**
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
