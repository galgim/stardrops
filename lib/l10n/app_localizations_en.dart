// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get languageName => 'English';

  @override
  String get menuTagline => 'Fewest stars wins.';

  @override
  String get menuPlay => 'PLAY';

  @override
  String get menuLocalGame => 'LOCAL GAME';

  @override
  String get menuHowToPlay => 'HOW TO PLAY';

  @override
  String get menuSettings => 'SETTINGS';

  @override
  String get menuProfileLabel => 'Profile';

  @override
  String get settingsTitle => 'SETTINGS';

  @override
  String get settingsDone => 'DONE';

  @override
  String get settingsLanguage => 'LANGUAGE';

  @override
  String get soundOn => 'SOUND ON';

  @override
  String get soundOff => 'SOUND OFF';

  @override
  String get languageTitle => 'LANGUAGE';

  @override
  String get difficultyTitle => 'DIFFICULTY';

  @override
  String get difficultyEasy => 'EASY';

  @override
  String get difficultyNormal => 'NORMAL';

  @override
  String get difficultyHard => 'HARD';

  @override
  String get profileTitle => 'PROFILE';

  @override
  String get profileYourName => 'YOUR NAME';

  @override
  String profileRecord(int played) {
    return '$played PLAYED';
  }

  @override
  String get profileWon => 'WON';

  @override
  String get profileLost => 'LOST';

  @override
  String get gameMenu => 'MENU';

  @override
  String get gameMenuLabel => 'Menu';

  @override
  String get gameAbandon => 'ABANDON GAME';

  @override
  String get gameResume => 'RESUME';

  @override
  String get gameConfirm => 'CONFIRM';

  @override
  String get gameSelect => 'SELECT';

  @override
  String get gameOver => 'GAME OVER';

  @override
  String get gameHostLeft => 'The host left, so the game ended.';

  @override
  String gamePlayerLeft(String name) {
    return '$name left. The table plays on without them.';
  }

  @override
  String gameWaitingForPlayers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Waiting for $count players',
      one: 'Waiting for 1 player',
    );
    return '$_temp0';
  }

  @override
  String gameTakingRow(String name) {
    return '$name is taking a row';
  }

  @override
  String get gameSomeone => 'Someone';

  @override
  String gameAiName(int number) {
    return 'AI $number';
  }

  @override
  String get resultsYouWin => 'YOU WIN!';

  @override
  String get resultsYouTie => 'YOU TIE\nFOR 1ST!';

  @override
  String resultsWinner(String name) {
    return '$name\nWINS!';
  }

  @override
  String get resultsStandings => 'FINAL STANDINGS';

  @override
  String get resultsPlayAgain => 'PLAY AGAIN';

  @override
  String get localGameTitle => 'LOCAL GAME';

  @override
  String get localGameSameWifi => 'Everyone needs to be on the same WiFi.';

  @override
  String get localGameHost => 'HOST';

  @override
  String get localGameJoin => 'JOIN';

  @override
  String get joinGameTitle => 'JOIN GAME';

  @override
  String get joinEnterCode => 'ENTER THE CODE';

  @override
  String get joinBadCode => 'That code doesn\'t look right.';

  @override
  String get purchaseTitle => 'HOST A GAME';

  @override
  String get purchaseBody =>
      'Hosting is a one-time unlock. Joining a game someone else hosts is always free.';

  @override
  String get purchaseBuy => 'UNLOCK';

  @override
  String purchaseBuyAt(String price) {
    return 'UNLOCK $price';
  }

  @override
  String get purchaseRestore => 'RESTORE';

  @override
  String get purchaseNotNow => 'NOT NOW';

  @override
  String get purchaseStoreUnavailable => 'Can\'t reach the store right now.';

  @override
  String get purchaseUnavailable => 'This unlock isn\'t available right now.';

  @override
  String get purchaseFailed =>
      'That didn\'t go through. You haven\'t been charged.';

  @override
  String get purchaseNothingToRestore => 'Nothing to restore on this account.';

  @override
  String get lobbyJoining => 'JOINING';

  @override
  String get lobbyOpening => 'Opening the table…';

  @override
  String get lobbyConnecting => 'Connecting…';

  @override
  String get lobbyShareCode => 'Others join with this code, on the same WiFi.';

  @override
  String get lobbyTapToCopy => 'TAP TO COPY';

  @override
  String get lobbyCodeCopied => 'Code copied';

  @override
  String get lobbyWaitingForHost => 'Waiting for the host to start.';

  @override
  String get lobbyStart => 'START';

  @override
  String get lobbyLeave => 'LEAVE';

  @override
  String lobbyPlayerCount(int count, int max) {
    return 'PLAYERS  $count/$max';
  }

  @override
  String lobbyNeedMore(int count) {
    return 'Need $count to start';
  }

  @override
  String get netNoWifi => 'No WiFi network. Connect to WiFi and try again.';

  @override
  String get netNoAddress => 'Couldn\'t read this device\'s network address.';

  @override
  String get netDropped => 'The connection dropped.';

  @override
  String get netCantHost => 'Couldn\'t open the game to other players.';

  @override
  String get netNoGameFound =>
      'No game found with that code. Check it and that both phones are on the same WiFi.';

  @override
  String get netCantJoin => 'Couldn\'t join that game.';

  @override
  String get netTableFull => 'That game is full or already started.';

  @override
  String get netHostLeft => 'The host left the game.';

  @override
  String get introSkip => 'Skip  ›';

  @override
  String get introClose => 'Close  ›';

  @override
  String get introNext => 'NEXT';

  @override
  String get introDone => 'DONE';

  @override
  String get introCardsEyebrow => 'THE CARDS';

  @override
  String get introCardsTitle => 'You get\n10 cards';

  @override
  String get introCardsBody =>
      'Every card has a number and some *stars*. Those stars are *penalty points* — collect as few as you can.';

  @override
  String get introCardsNumberRange => 'NUMBER 1 – 104';

  @override
  String get introCardsPenaltyStars => 'PENALTY STARS';

  @override
  String get introTableEyebrow => 'THE TABLE';

  @override
  String get introTableTitle => 'Five cards\nper row';

  @override
  String get introTableBody =>
      'Four rows sit in the middle. Each one starts with a random card and holds 5 cards in total.';

  @override
  String get introTableCaption => 'STARTS WITH 1  ·  HOLDS 5';

  @override
  String get introRoundEyebrow => 'EACH ROUND';

  @override
  String get introRoundTitle => 'Everyone plays\none card';

  @override
  String get introRoundBody =>
      'Each round, everyone picks one card and plays it at the same time. The lowest number lands first. A card joins the row that ends closest below it.';

  @override
  String get introRoundCaption => 'PLAYED THIS ROUND';

  @override
  String get introSixthEyebrow => 'PENALTY 1 OF 2';

  @override
  String get introSixthTitle => 'Sixth card\ntakes the row';

  @override
  String get introSixthBody =>
      'A row stops at 5 cards. Play the 6th and you take all 5 — their *stars* become your *penalty points*.';

  @override
  String introTakeBadge(int count) {
    return 'You take all $count';
  }

  @override
  String get introTooLowEyebrow => 'PENALTY 2 OF 2';

  @override
  String get introTooLowTitle => 'Lower than\nevery row';

  @override
  String get introTooLowBody =>
      'A card lower than every row fits nowhere. Pick any row, take its *stars*, and your card starts that row again.';

  @override
  String get introWinnerEyebrow => 'AFTER 10 ROUNDS';

  @override
  String get introWinnerTitle => 'Fewest stars\nwins';

  @override
  String get introWinnerBody =>
      'After 10 rounds every hand is empty. Count the *stars*. Fewest wins.';

  @override
  String get introWinnerYou => 'You';
}
