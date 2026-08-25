// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String get languageName => '한국어';

  @override
  String get menuTagline => '별이 가장 적으면 승리.';

  @override
  String get menuPlay => '게임 시작';

  @override
  String get menuLocalGame => '같이 하기';

  @override
  String get menuHowToPlay => '게임 방법';

  @override
  String get menuSettings => '설정';

  @override
  String get menuProfileLabel => '프로필';

  @override
  String get settingsTitle => '설정';

  @override
  String get settingsDone => '완료';

  @override
  String get settingsLanguage => '언어';

  @override
  String get soundOn => '소리 켜짐';

  @override
  String get soundOff => '소리 꺼짐';

  @override
  String get languageTitle => '언어';

  @override
  String get difficultyTitle => '난이도';

  @override
  String get difficultyEasy => '쉬움';

  @override
  String get difficultyNormal => '보통';

  @override
  String get difficultyHard => '어려움';

  @override
  String get profileTitle => '프로필';

  @override
  String get profileYourName => '내 이름';

  @override
  String profileRecord(int played) {
    return '$played판';
  }

  @override
  String get profileWon => '승';

  @override
  String get profileLost => '패';

  @override
  String get gameMenu => '메뉴';

  @override
  String get gameMenuLabel => '메뉴';

  @override
  String get gameAbandon => '게임 포기';

  @override
  String get gameResume => '계속하기';

  @override
  String get gameConfirm => '확인';

  @override
  String get gameSelect => '선택';

  @override
  String get gameOver => '게임 종료';

  @override
  String get gameHostLeft => '방장이 나가서 게임이 끝났습니다.';

  @override
  String gamePlayerLeft(String name) {
    return '$name님이 나갔습니다. 게임은 계속됩니다.';
  }

  @override
  String gameWaitingForPlayers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count명 기다리는 중',
    );
    return '$_temp0';
  }

  @override
  String gameTakingRow(String name) {
    return '$name님이 줄을 가져가는 중';
  }

  @override
  String get gameSomeone => '누군가';

  @override
  String gameAiName(int number) {
    return 'AI $number';
  }

  @override
  String get resultsYouWin => '승리!';

  @override
  String get resultsYouTie => '공동\n1위!';

  @override
  String resultsWinner(String name) {
    return '$name\n승리!';
  }

  @override
  String get resultsStandings => '최종 순위';

  @override
  String get resultsPlayAgain => '다시 하기';

  @override
  String get localGameTitle => '같이 하기';

  @override
  String get localGameSameWifi => '모두 같은 WiFi에 연결되어 있어야 합니다.';

  @override
  String get localGameHost => '방 만들기';

  @override
  String get localGameJoin => '참가하기';

  @override
  String get joinGameTitle => '참가하기';

  @override
  String get joinEnterCode => '코드를 입력하세요';

  @override
  String get joinBadCode => '코드가 올바르지 않습니다.';

  @override
  String get lobbyJoining => '참가 중';

  @override
  String get lobbyOpening => '방을 여는 중…';

  @override
  String get lobbyConnecting => '연결 중…';

  @override
  String get lobbyShareCode => '같은 WiFi에서 이 코드로 참가할 수 있습니다.';

  @override
  String get lobbyTapToCopy => '눌러서 복사';

  @override
  String get lobbyCodeCopied => '코드를 복사했습니다';

  @override
  String get lobbyWaitingForHost => '방장이 시작하기를 기다리는 중입니다.';

  @override
  String get lobbyStart => '시작';

  @override
  String get lobbyLeave => '나가기';

  @override
  String lobbyPlayerCount(int count, int max) {
    return '인원  $count/$max';
  }

  @override
  String lobbyNeedMore(int count) {
    return '$count명부터 시작할 수 있습니다';
  }

  @override
  String get netNoWifi => 'WiFi에 연결되어 있지 않습니다. 연결한 뒤 다시 시도하세요.';

  @override
  String get netNoAddress => '이 기기의 네트워크 주소를 읽을 수 없습니다.';

  @override
  String get netDropped => '연결이 끊겼습니다.';

  @override
  String get netCantHost => '다른 플레이어에게 방을 열 수 없습니다.';

  @override
  String get netNoGameFound =>
      '해당 코드의 게임을 찾을 수 없습니다. 코드가 맞는지, 두 기기가 같은 WiFi에 있는지 확인하세요.';

  @override
  String get netCantJoin => '그 게임에 참가할 수 없습니다.';

  @override
  String get netTableFull => '그 게임은 인원이 가득 찼거나 이미 시작되었습니다.';

  @override
  String get netHostLeft => '방장이 게임을 나갔습니다.';

  @override
  String get introSkip => '건너뛰기  ›';

  @override
  String get introClose => '닫기  ›';

  @override
  String get introNext => '다음';

  @override
  String get introDone => '완료';

  @override
  String get introCardsEyebrow => '카드';

  @override
  String get introCardsTitle => '카드 10장을\n받습니다';

  @override
  String get introCardsBody => '카드마다 숫자와 *별*이 있습니다. 이 별이 *벌점*이니 최대한 적게 모으세요.';

  @override
  String get introCardsNumberRange => '숫자 1 – 104';

  @override
  String get introCardsPenaltyStars => '벌점 별';

  @override
  String get introTableEyebrow => '테이블';

  @override
  String get introTableTitle => '한 줄에\n다섯 장';

  @override
  String get introTableBody =>
      '가운데에 네 줄이 있습니다. 각 줄은 무작위 카드 한 장으로 시작하고, 최대 다섯 장까지 들어갑니다.';

  @override
  String get introTableCaption => '한 장으로 시작  ·  최대 다섯 장';

  @override
  String get introRoundEyebrow => '매 라운드';

  @override
  String get introRoundTitle => '모두 한 장씩\n냅니다';

  @override
  String get introRoundBody =>
      '매 라운드 모두 카드 한 장을 골라 동시에 냅니다. 숫자가 낮은 카드부터 놓이고, 바로 아래에서 끝나는 줄에 붙습니다.';

  @override
  String get introRoundCaption => '이번 라운드에 낸 카드';

  @override
  String get introSixthEyebrow => '벌점 1 / 2';

  @override
  String get introSixthTitle => '여섯 번째 카드는\n줄을 가져갑니다';

  @override
  String get introSixthBody =>
      '한 줄은 다섯 장까지입니다. 여섯 번째를 내면 다섯 장을 모두 가져가고, 그 *별*이 *벌점*이 됩니다.';

  @override
  String introTakeBadge(int count) {
    return '$count장 모두 가져갑니다';
  }

  @override
  String get introTooLowEyebrow => '벌점 2 / 2';

  @override
  String get introTooLowTitle => '모든 줄보다\n낮을 때';

  @override
  String get introTooLowBody =>
      '모든 줄보다 낮은 카드는 어디에도 놓을 수 없습니다. 줄을 하나 골라 그 *별*을 가져가고, 낸 카드가 그 줄을 새로 시작합니다.';

  @override
  String get introWinnerEyebrow => '10 라운드 후';

  @override
  String get introWinnerTitle => '별이 가장 적으면\n승리';

  @override
  String get introWinnerBody =>
      '10 라운드가 끝나면 손패가 모두 빕니다. *별*을 세어 합계가 가장 낮은 사람이 이깁니다.';

  @override
  String get introWinnerYou => '나';
}
