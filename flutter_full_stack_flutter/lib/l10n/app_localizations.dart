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

  /// Tab for the single-word prompts.
  ///
  /// In en, this message translates to:
  /// **'Words'**
  String get practiceWords;

  /// Tab for the full-sentence prompts.
  ///
  /// In en, this message translates to:
  /// **'Phrases'**
  String get practicePhrases;

  /// Which prompt of the deck is on screen.
  ///
  /// In en, this message translates to:
  /// **'{current} of {total}'**
  String practicePosition(int current, int total);

  /// Main heading on the pronunciation practice screen.
  ///
  /// In en, this message translates to:
  /// **'Read it out loud.'**
  String get practiceHeadline;

  /// Sentence under the heading, explaining that scoring is local.
  ///
  /// In en, this message translates to:
  /// **'Your pronunciation is scored on this device. Nothing is uploaded.'**
  String get practiceTagline;

  /// Button that fetches the acoustic model for a language.
  ///
  /// In en, this message translates to:
  /// **'Download the language pack'**
  String get practiceDownloadPack;

  /// Explains the size and the one-off nature of the download.
  ///
  /// In en, this message translates to:
  /// **'About {megabytes} MB, once. After that, practice works with no connection.'**
  String practiceDownloadExplainer(int megabytes);

  /// Shown while the model is being fetched.
  ///
  /// In en, this message translates to:
  /// **'Downloading the language pack'**
  String get practiceDownloading;

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

  /// Shown when fetching the acoustic model failed.
  ///
  /// In en, this message translates to:
  /// **'The language pack did not download. Check your connection and try again.'**
  String get practiceDownloadFailed;

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
