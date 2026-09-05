import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_ko.dart';

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
    Locale('es'),
    Locale('ko'),
  ];

  /// This language's own name, shown in the language picker. Always written in the language itself, never translated into the current one — a Spanish speaker looks for 'Espanol', not 'Spanish'.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageName;

  /// No description provided for @menuTagline.
  ///
  /// In en, this message translates to:
  /// **'Fewest stars wins.'**
  String get menuTagline;

  /// No description provided for @menuPlay.
  ///
  /// In en, this message translates to:
  /// **'PLAY'**
  String get menuPlay;

  /// No description provided for @menuLocalGame.
  ///
  /// In en, this message translates to:
  /// **'LOCAL GAME'**
  String get menuLocalGame;

  /// No description provided for @menuHowToPlay.
  ///
  /// In en, this message translates to:
  /// **'HOW TO PLAY'**
  String get menuHowToPlay;

  /// No description provided for @menuSettings.
  ///
  /// In en, this message translates to:
  /// **'SETTINGS'**
  String get menuSettings;

  /// Screen-reader label for the round profile button. Never drawn on screen.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get menuProfileLabel;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'SETTINGS'**
  String get settingsTitle;

  /// No description provided for @settingsDone.
  ///
  /// In en, this message translates to:
  /// **'DONE'**
  String get settingsDone;

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'LANGUAGE'**
  String get settingsLanguage;

  /// No description provided for @soundOn.
  ///
  /// In en, this message translates to:
  /// **'SOUND ON'**
  String get soundOn;

  /// No description provided for @soundOff.
  ///
  /// In en, this message translates to:
  /// **'SOUND OFF'**
  String get soundOff;

  /// No description provided for @languageTitle.
  ///
  /// In en, this message translates to:
  /// **'LANGUAGE'**
  String get languageTitle;

  /// No description provided for @difficultyTitle.
  ///
  /// In en, this message translates to:
  /// **'DIFFICULTY'**
  String get difficultyTitle;

  /// No description provided for @difficultyEasy.
  ///
  /// In en, this message translates to:
  /// **'EASY'**
  String get difficultyEasy;

  /// No description provided for @difficultyNormal.
  ///
  /// In en, this message translates to:
  /// **'NORMAL'**
  String get difficultyNormal;

  /// No description provided for @difficultyHard.
  ///
  /// In en, this message translates to:
  /// **'HARD'**
  String get difficultyHard;

  /// No description provided for @profileTitle.
  ///
  /// In en, this message translates to:
  /// **'PROFILE'**
  String get profileTitle;

  /// No description provided for @profileYourName.
  ///
  /// In en, this message translates to:
  /// **'YOUR NAME'**
  String get profileYourName;

  /// Lifetime games played, above the per-difficulty table on the profile dialog.
  ///
  /// In en, this message translates to:
  /// **'{played} PLAYED'**
  String profileRecord(int played);

  /// Column heading over the win counts in the profile dialog's table.
  ///
  /// In en, this message translates to:
  /// **'WON'**
  String get profileWon;

  /// Column heading over the loss counts in the profile dialog's table.
  ///
  /// In en, this message translates to:
  /// **'LOST'**
  String get profileLost;

  /// No description provided for @gameMenu.
  ///
  /// In en, this message translates to:
  /// **'MENU'**
  String get gameMenu;

  /// Screen-reader label for the in-game menu button. Never drawn on screen.
  ///
  /// In en, this message translates to:
  /// **'Menu'**
  String get gameMenuLabel;

  /// No description provided for @gameAbandon.
  ///
  /// In en, this message translates to:
  /// **'ABANDON GAME'**
  String get gameAbandon;

  /// No description provided for @gameResume.
  ///
  /// In en, this message translates to:
  /// **'RESUME'**
  String get gameResume;

  /// No description provided for @gameConfirm.
  ///
  /// In en, this message translates to:
  /// **'CONFIRM'**
  String get gameConfirm;

  /// No description provided for @gameSelect.
  ///
  /// In en, this message translates to:
  /// **'SELECT'**
  String get gameSelect;

  /// No description provided for @gameOver.
  ///
  /// In en, this message translates to:
  /// **'GAME OVER'**
  String get gameOver;

  /// No description provided for @gameHostLeft.
  ///
  /// In en, this message translates to:
  /// **'The host left, so the game ended.'**
  String get gameHostLeft;

  /// Snackbar shown to the host when a player's phone drops out mid-game.
  ///
  /// In en, this message translates to:
  /// **'{name} left. The table plays on without them.'**
  String gamePlayerLeft(String name);

  /// Shown in place of the confirm button while the table is short of somebody.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Waiting for 1 player} other{Waiting for {count} players}}'**
  String gameWaitingForPlayers(int count);

  /// No description provided for @gameTakingRow.
  ///
  /// In en, this message translates to:
  /// **'{name} is taking a row'**
  String gameTakingRow(String name);

  /// Stands in for a player's name when the seat can't be identified.
  ///
  /// In en, this message translates to:
  /// **'Someone'**
  String get gameSomeone;

  /// Name given to each computer seat in a solo game.
  ///
  /// In en, this message translates to:
  /// **'AI {number}'**
  String gameAiName(int number);

  /// No description provided for @resultsYouWin.
  ///
  /// In en, this message translates to:
  /// **'YOU WIN!'**
  String get resultsYouWin;

  /// No description provided for @resultsYouTie.
  ///
  /// In en, this message translates to:
  /// **'YOU TIE\nFOR 1ST!'**
  String get resultsYouTie;

  /// Headline when somebody else won. The line break is deliberate.
  ///
  /// In en, this message translates to:
  /// **'{name}\nWINS!'**
  String resultsWinner(String name);

  /// No description provided for @resultsStandings.
  ///
  /// In en, this message translates to:
  /// **'FINAL STANDINGS'**
  String get resultsStandings;

  /// No description provided for @resultsPlayAgain.
  ///
  /// In en, this message translates to:
  /// **'PLAY AGAIN'**
  String get resultsPlayAgain;

  /// No description provided for @localGameTitle.
  ///
  /// In en, this message translates to:
  /// **'LOCAL GAME'**
  String get localGameTitle;

  /// No description provided for @localGameSameWifi.
  ///
  /// In en, this message translates to:
  /// **'Everyone needs to be on the same WiFi.'**
  String get localGameSameWifi;

  /// No description provided for @localGameHost.
  ///
  /// In en, this message translates to:
  /// **'HOST'**
  String get localGameHost;

  /// No description provided for @localGameJoin.
  ///
  /// In en, this message translates to:
  /// **'JOIN'**
  String get localGameJoin;

  /// No description provided for @joinGameTitle.
  ///
  /// In en, this message translates to:
  /// **'JOIN GAME'**
  String get joinGameTitle;

  /// No description provided for @joinEnterCode.
  ///
  /// In en, this message translates to:
  /// **'ENTER THE CODE'**
  String get joinEnterCode;

  /// No description provided for @joinBadCode.
  ///
  /// In en, this message translates to:
  /// **'That code doesn\'t look right.'**
  String get joinBadCode;

  /// No description provided for @purchaseTitle.
  ///
  /// In en, this message translates to:
  /// **'HOST A GAME'**
  String get purchaseTitle;

  /// No description provided for @purchaseBody.
  ///
  /// In en, this message translates to:
  /// **'Hosting is a one-time unlock. Joining a game someone else hosts is always free.'**
  String get purchaseBody;

  /// No description provided for @purchaseBuy.
  ///
  /// In en, this message translates to:
  /// **'UNLOCK'**
  String get purchaseBuy;

  /// Buy button with the store's own localised price, e.g. UNLOCK $1.99. Never build the price from a number — the store knows the player's currency.
  ///
  /// In en, this message translates to:
  /// **'UNLOCK {price}'**
  String purchaseBuyAt(String price);

  /// No description provided for @purchaseRestore.
  ///
  /// In en, this message translates to:
  /// **'RESTORE'**
  String get purchaseRestore;

  /// No description provided for @purchaseNotNow.
  ///
  /// In en, this message translates to:
  /// **'NOT NOW'**
  String get purchaseNotNow;

  /// No description provided for @purchaseStoreUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Can\'t reach the store right now.'**
  String get purchaseStoreUnavailable;

  /// No description provided for @purchaseUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This unlock isn\'t available right now.'**
  String get purchaseUnavailable;

  /// No description provided for @purchaseFailed.
  ///
  /// In en, this message translates to:
  /// **'That didn\'t go through. You haven\'t been charged.'**
  String get purchaseFailed;

  /// No description provided for @purchaseNothingToRestore.
  ///
  /// In en, this message translates to:
  /// **'Nothing to restore on this account.'**
  String get purchaseNothingToRestore;

  /// No description provided for @lobbyJoining.
  ///
  /// In en, this message translates to:
  /// **'JOINING'**
  String get lobbyJoining;

  /// No description provided for @lobbyOpening.
  ///
  /// In en, this message translates to:
  /// **'Opening the table…'**
  String get lobbyOpening;

  /// No description provided for @lobbyConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting…'**
  String get lobbyConnecting;

  /// No description provided for @lobbyShareCode.
  ///
  /// In en, this message translates to:
  /// **'Others join with this code, on the same WiFi.'**
  String get lobbyShareCode;

  /// No description provided for @lobbyTapToCopy.
  ///
  /// In en, this message translates to:
  /// **'TAP TO COPY'**
  String get lobbyTapToCopy;

  /// No description provided for @lobbyCodeCopied.
  ///
  /// In en, this message translates to:
  /// **'Code copied'**
  String get lobbyCodeCopied;

  /// No description provided for @lobbyWaitingForHost.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the host to start.'**
  String get lobbyWaitingForHost;

  /// No description provided for @lobbyStart.
  ///
  /// In en, this message translates to:
  /// **'START'**
  String get lobbyStart;

  /// No description provided for @lobbyLeave.
  ///
  /// In en, this message translates to:
  /// **'LEAVE'**
  String get lobbyLeave;

  /// No description provided for @lobbyPlayerCount.
  ///
  /// In en, this message translates to:
  /// **'PLAYERS  {count}/{max}'**
  String lobbyPlayerCount(int count, int max);

  /// No description provided for @lobbyNeedMore.
  ///
  /// In en, this message translates to:
  /// **'Need {count} to start'**
  String lobbyNeedMore(int count);

  /// No description provided for @netNoWifi.
  ///
  /// In en, this message translates to:
  /// **'No WiFi network. Connect to WiFi and try again.'**
  String get netNoWifi;

  /// No description provided for @netNoAddress.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t read this device\'s network address.'**
  String get netNoAddress;

  /// No description provided for @netDropped.
  ///
  /// In en, this message translates to:
  /// **'The connection dropped.'**
  String get netDropped;

  /// No description provided for @netCantHost.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open the game to other players.'**
  String get netCantHost;

  /// No description provided for @netNoGameFound.
  ///
  /// In en, this message translates to:
  /// **'No game found with that code. Check it and that both phones are on the same WiFi.'**
  String get netNoGameFound;

  /// No description provided for @netCantJoin.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t join that game.'**
  String get netCantJoin;

  /// No description provided for @netTableFull.
  ///
  /// In en, this message translates to:
  /// **'That game is full or already started.'**
  String get netTableFull;

  /// No description provided for @netHostLeft.
  ///
  /// In en, this message translates to:
  /// **'The host left the game.'**
  String get netHostLeft;

  /// No description provided for @introSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip  ›'**
  String get introSkip;

  /// No description provided for @introClose.
  ///
  /// In en, this message translates to:
  /// **'Close  ›'**
  String get introClose;

  /// No description provided for @introNext.
  ///
  /// In en, this message translates to:
  /// **'NEXT'**
  String get introNext;

  /// No description provided for @introDone.
  ///
  /// In en, this message translates to:
  /// **'DONE'**
  String get introDone;

  /// No description provided for @introCardsEyebrow.
  ///
  /// In en, this message translates to:
  /// **'THE CARDS'**
  String get introCardsEyebrow;

  /// No description provided for @introCardsTitle.
  ///
  /// In en, this message translates to:
  /// **'You get\n10 cards'**
  String get introCardsTitle;

  /// No description provided for @introCardsBody.
  ///
  /// In en, this message translates to:
  /// **'Every card has a number and some *stars*. Those stars are *penalty points* — collect as few as you can.'**
  String get introCardsBody;

  /// No description provided for @introCardsNumberRange.
  ///
  /// In en, this message translates to:
  /// **'NUMBER 1 – 104'**
  String get introCardsNumberRange;

  /// No description provided for @introCardsPenaltyStars.
  ///
  /// In en, this message translates to:
  /// **'PENALTY STARS'**
  String get introCardsPenaltyStars;

  /// No description provided for @introTableEyebrow.
  ///
  /// In en, this message translates to:
  /// **'THE TABLE'**
  String get introTableEyebrow;

  /// No description provided for @introTableTitle.
  ///
  /// In en, this message translates to:
  /// **'Five cards\nper row'**
  String get introTableTitle;

  /// No description provided for @introTableBody.
  ///
  /// In en, this message translates to:
  /// **'Four rows sit in the middle. Each one starts with a random card and holds 5 cards in total.'**
  String get introTableBody;

  /// No description provided for @introTableCaption.
  ///
  /// In en, this message translates to:
  /// **'STARTS WITH 1  ·  HOLDS 5'**
  String get introTableCaption;

  /// No description provided for @introRoundEyebrow.
  ///
  /// In en, this message translates to:
  /// **'EACH ROUND'**
  String get introRoundEyebrow;

  /// No description provided for @introRoundTitle.
  ///
  /// In en, this message translates to:
  /// **'Everyone plays\none card'**
  String get introRoundTitle;

  /// No description provided for @introRoundBody.
  ///
  /// In en, this message translates to:
  /// **'Each round, everyone picks one card and plays it at the same time. The lowest number lands first. A card joins the row that ends closest below it.'**
  String get introRoundBody;

  /// No description provided for @introRoundCaption.
  ///
  /// In en, this message translates to:
  /// **'PLAYED THIS ROUND'**
  String get introRoundCaption;

  /// No description provided for @introSixthEyebrow.
  ///
  /// In en, this message translates to:
  /// **'PENALTY 1 OF 2'**
  String get introSixthEyebrow;

  /// No description provided for @introSixthTitle.
  ///
  /// In en, this message translates to:
  /// **'Sixth card\ntakes the row'**
  String get introSixthTitle;

  /// No description provided for @introSixthBody.
  ///
  /// In en, this message translates to:
  /// **'A row stops at 5 cards. Play the 6th and you take all 5 — their *stars* become your *penalty points*.'**
  String get introSixthBody;

  /// On the two take-a-row slides: how many cards the row costs you. Wrap words in *asterisks* anywhere in an intro body to paint them the accent yellow.
  ///
  /// In en, this message translates to:
  /// **'You take all {count}'**
  String introTakeBadge(int count);

  /// No description provided for @introTooLowEyebrow.
  ///
  /// In en, this message translates to:
  /// **'PENALTY 2 OF 2'**
  String get introTooLowEyebrow;

  /// No description provided for @introTooLowTitle.
  ///
  /// In en, this message translates to:
  /// **'Lower than\nevery row'**
  String get introTooLowTitle;

  /// No description provided for @introTooLowBody.
  ///
  /// In en, this message translates to:
  /// **'A card lower than every row fits nowhere. Pick any row, take its *stars*, and your card starts that row again.'**
  String get introTooLowBody;

  /// No description provided for @introWinnerEyebrow.
  ///
  /// In en, this message translates to:
  /// **'AFTER 10 ROUNDS'**
  String get introWinnerEyebrow;

  /// No description provided for @introWinnerTitle.
  ///
  /// In en, this message translates to:
  /// **'Fewest stars\nwins'**
  String get introWinnerTitle;

  /// No description provided for @introWinnerBody.
  ///
  /// In en, this message translates to:
  /// **'After 10 rounds every hand is empty. Count the *stars*. Fewest wins.'**
  String get introWinnerBody;

  /// The player's own line on the example scoreboard in the last tutorial slide.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get introWinnerYou;
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
      <String>['en', 'es', 'ko'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'ko':
      return AppLocalizationsKo();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
