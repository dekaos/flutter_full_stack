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

  /// Name of the word hunt game, the headline of its lobby.
  ///
  /// In en, this message translates to:
  /// **'Word Hunt'**
  String get huntTitle;

  /// Under the word hunt's headline: how the game is played, in one line.
  ///
  /// In en, this message translates to:
  /// **'We ask for a word. Find it in English and hit its ship.'**
  String get huntTagline;

  /// Tooltip of the lobby button that opens pronunciation practice.
  ///
  /// In en, this message translates to:
  /// **'Practise pronunciation'**
  String get huntPronunciation;

  /// Heading over the word hunt's beginner themes.
  ///
  /// In en, this message translates to:
  /// **'First steps'**
  String get huntLevelFirst;

  /// Heading over the word hunt's everyday themes.
  ///
  /// In en, this message translates to:
  /// **'Everyday life'**
  String get huntLevelEveryday;

  /// Heading over the word hunt's harder themes.
  ///
  /// In en, this message translates to:
  /// **'Going further'**
  String get huntLevelFurther;

  /// On a theme's card: how many words it has.
  ///
  /// In en, this message translates to:
  /// **'{count} words'**
  String huntDeckWords(int count);

  /// On a theme's card: the highest score made on it.
  ///
  /// In en, this message translates to:
  /// **'Best {score}'**
  String huntDeckBest(int score);

  /// Read by a screen reader for a theme's best stars.
  ///
  /// In en, this message translates to:
  /// **'{stars, plural, =0{No stars yet} =1{1 star of 3} other{{stars} stars of 3}}'**
  String huntDeckStars(int stars);

  /// Word hunt theme: greetings and polite phrases.
  ///
  /// In en, this message translates to:
  /// **'Everyday phrases'**
  String get huntDeckGreetings;

  /// Word hunt theme: colours.
  ///
  /// In en, this message translates to:
  /// **'Colours'**
  String get huntDeckColors;

  /// Word hunt theme: numbers.
  ///
  /// In en, this message translates to:
  /// **'Numbers'**
  String get huntDeckNumbers;

  /// Word hunt theme: animals.
  ///
  /// In en, this message translates to:
  /// **'Animals'**
  String get huntDeckAnimals;

  /// Word hunt theme: family members and people.
  ///
  /// In en, this message translates to:
  /// **'Family and people'**
  String get huntDeckFamily;

  /// Word hunt theme: food and drink.
  ///
  /// In en, this message translates to:
  /// **'Food and drink'**
  String get huntDeckFood;

  /// Word hunt theme: rooms and things in a house.
  ///
  /// In en, this message translates to:
  /// **'At home'**
  String get huntDeckHome;

  /// Word hunt theme: parts of the body.
  ///
  /// In en, this message translates to:
  /// **'The body'**
  String get huntDeckBody;

  /// Word hunt theme: clothes and accessories.
  ///
  /// In en, this message translates to:
  /// **'Clothes'**
  String get huntDeckClothes;

  /// Word hunt theme: days of the week and words for time.
  ///
  /// In en, this message translates to:
  /// **'Days and time'**
  String get huntDeckTime;

  /// Word hunt theme: places in a city and transport.
  ///
  /// In en, this message translates to:
  /// **'Around town'**
  String get huntDeckCity;

  /// Word hunt theme: nature and weather.
  ///
  /// In en, this message translates to:
  /// **'Nature and weather'**
  String get huntDeckNature;

  /// Word hunt theme: school and work.
  ///
  /// In en, this message translates to:
  /// **'School and work'**
  String get huntDeckSchool;

  /// Word hunt theme: everyday verbs.
  ///
  /// In en, this message translates to:
  /// **'Actions'**
  String get huntDeckActions;

  /// Word hunt theme: adjectives for feelings and opposites.
  ///
  /// In en, this message translates to:
  /// **'How it is, how you feel'**
  String get huntDeckFeelings;

  /// Over the word the learner is asked to find, in the word hunt.
  ///
  /// In en, this message translates to:
  /// **'Find in English'**
  String get huntFind;

  /// In the word hunt, over the answer once time has run out on a word.
  ///
  /// In en, this message translates to:
  /// **'The answer was'**
  String get huntAnswerWas;

  /// Read by a screen reader for the word hunt's progress.
  ///
  /// In en, this message translates to:
  /// **'Word {current} of {total}'**
  String huntWordOf(int current, int total);

  /// Label of the word hunt's score.
  ///
  /// In en, this message translates to:
  /// **'Score'**
  String get huntScore;

  /// Chip shown while words are found in a row: what the next one scores at.
  ///
  /// In en, this message translates to:
  /// **'Combo ×{multiplier}'**
  String huntCombo(double multiplier);

  /// Read by a screen reader for the rocket's shields: each wrong shot takes one.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No shields left} =1{1 shield left} other{{count} shields left}}'**
  String huntShields(int count);

  /// Button that lights up the right ship, for half its points.
  ///
  /// In en, this message translates to:
  /// **'Hint'**
  String get huntHint;

  /// Tooltip of the hint button.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No hints left} =1{1 hint left} other{{count} hints left}}'**
  String huntHintsLeft(int count);

  /// Tooltip of the word hunt's pause button.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get huntPause;

  /// Heading of the word hunt's pause panel.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get huntPaused;

  /// Button that ends the pause.
  ///
  /// In en, this message translates to:
  /// **'Keep playing'**
  String get huntResume;

  /// Button on the pause panel that goes back to the themes.
  ///
  /// In en, this message translates to:
  /// **'Leave the mission'**
  String get huntQuit;

  /// Over the countdown before a mission's first word.
  ///
  /// In en, this message translates to:
  /// **'Get ready!'**
  String get huntReady;

  /// The end of the countdown, as the first ships fly in.
  ///
  /// In en, this message translates to:
  /// **'Go!'**
  String get huntGo;

  /// Heading of the row of buttons that stands in for the ships when a screen reader is on.
  ///
  /// In en, this message translates to:
  /// **'Ships'**
  String get huntShipsLabel;

  /// Read by a screen reader for a ship: firing at it.
  ///
  /// In en, this message translates to:
  /// **'Shoot “{word}”'**
  String huntShoot(String word);

  /// Results heading when the mission earned at least one star.
  ///
  /// In en, this message translates to:
  /// **'Mission complete!'**
  String get huntResultsDone;

  /// Results heading when the mission earned no stars. Encouraging, never a verdict.
  ///
  /// In en, this message translates to:
  /// **'Almost there!'**
  String get huntResultsAlmost;

  /// Results heading when wrong shots used up every shield.
  ///
  /// In en, this message translates to:
  /// **'Out of shields!'**
  String get huntResultsWrecked;

  /// Badge on the results when this score beats the theme's best.
  ///
  /// In en, this message translates to:
  /// **'New record!'**
  String get huntNewBest;

  /// On the results: how many of the mission's words were found.
  ///
  /// In en, this message translates to:
  /// **'{found} of {total} words found'**
  String huntFoundOf(int found, int total);

  /// On the results: most words found in a row.
  ///
  /// In en, this message translates to:
  /// **'Best streak: {count}'**
  String huntBestStreak(int count);

  /// Heading over the list of words on the results.
  ///
  /// In en, this message translates to:
  /// **'This mission\'s words'**
  String get huntMissionWords;

  /// Tooltip of the speaker button beside a word on the results.
  ///
  /// In en, this message translates to:
  /// **'Hear “{word}”'**
  String huntHear(String word);

  /// Results button: a new mission on the same theme.
  ///
  /// In en, this message translates to:
  /// **'Play again'**
  String get huntPlayAgain;

  /// Results button: back to the list of themes.
  ///
  /// In en, this message translates to:
  /// **'Other themes'**
  String get huntOtherThemes;

  /// Read by a screen reader for the stars a mission earned.
  ///
  /// In en, this message translates to:
  /// **'{stars, plural, =0{No stars} =1{1 star} other{{stars} stars}}'**
  String huntStars(int stars);
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
