// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get languageName => 'Español';

  @override
  String get menuTagline => 'Gana quien tenga menos estrellas.';

  @override
  String get menuPlay => 'JUGAR';

  @override
  String get menuLocalGame => 'PARTIDA LOCAL';

  @override
  String get menuHowToPlay => 'CÓMO JUGAR';

  @override
  String get menuSettings => 'AJUSTES';

  @override
  String get menuProfileLabel => 'Perfil';

  @override
  String get settingsTitle => 'AJUSTES';

  @override
  String get settingsDone => 'LISTO';

  @override
  String get settingsLanguage => 'IDIOMA';

  @override
  String get soundOn => 'SONIDO SÍ';

  @override
  String get soundOff => 'SONIDO NO';

  @override
  String get languageTitle => 'IDIOMA';

  @override
  String get difficultyTitle => 'DIFICULTAD';

  @override
  String get difficultyEasy => 'FÁCIL';

  @override
  String get difficultyNormal => 'NORMAL';

  @override
  String get difficultyHard => 'DIFÍCIL';

  @override
  String get profileTitle => 'PERFIL';

  @override
  String get profileYourName => 'TU NOMBRE';

  @override
  String profileRecord(int played) {
    return '$played JUGADAS';
  }

  @override
  String get profileWon => 'GANADAS';

  @override
  String get profileLost => 'PERDIDAS';

  @override
  String get gameMenu => 'MENÚ';

  @override
  String get gameMenuLabel => 'Menú';

  @override
  String get gameAbandon => 'ABANDONAR';

  @override
  String get gameResume => 'SEGUIR';

  @override
  String get gameConfirm => 'CONFIRMAR';

  @override
  String get gameSelect => 'ELIGE';

  @override
  String get gameOver => 'FIN DE LA PARTIDA';

  @override
  String get gameHostLeft => 'El anfitrión se fue, así que la partida terminó.';

  @override
  String gamePlayerLeft(String name) {
    return '$name se fue. La mesa sigue sin esa persona.';
  }

  @override
  String gameWaitingForPlayers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Esperando a $count jugadores',
      one: 'Esperando a 1 jugador',
    );
    return '$_temp0';
  }

  @override
  String gameTakingRow(String name) {
    return '$name está tomando una fila';
  }

  @override
  String get gameSomeone => 'Alguien';

  @override
  String gameAiName(int number) {
    return 'IA $number';
  }

  @override
  String get resultsYouWin => '¡GANASTE!';

  @override
  String get resultsYouTie => '¡EMPATAS\nEN 1.º!';

  @override
  String resultsWinner(String name) {
    return '¡$name\nGANA!';
  }

  @override
  String get resultsStandings => 'CLASIFICACIÓN FINAL';

  @override
  String get resultsPlayAgain => 'OTRA PARTIDA';

  @override
  String get localGameTitle => 'PARTIDA LOCAL';

  @override
  String get localGameSameWifi => 'Todos tienen que estar en el mismo WiFi.';

  @override
  String get localGameHost => 'CREAR';

  @override
  String get localGameJoin => 'UNIRSE';

  @override
  String get joinGameTitle => 'UNIRSE';

  @override
  String get joinEnterCode => 'ESCRIBE EL CÓDIGO';

  @override
  String get joinBadCode => 'Ese código no parece correcto.';

  @override
  String get purchaseTitle => 'CREAR PARTIDA';

  @override
  String get purchaseBody =>
      'Crear partidas se desbloquea una sola vez. Unirse a la partida de otra persona siempre es gratis.';

  @override
  String get purchaseBuy => 'DESBLOQUEAR';

  @override
  String purchaseBuyAt(String price) {
    return 'DESBLOQUEAR $price';
  }

  @override
  String get purchaseRestore => 'RESTAURAR';

  @override
  String get purchaseNotNow => 'AHORA NO';

  @override
  String get purchaseStoreUnavailable =>
      'No se puede conectar con la tienda ahora mismo.';

  @override
  String get purchaseUnavailable =>
      'Esta compra no está disponible ahora mismo.';

  @override
  String get purchaseFailed => 'No se completó. No se te ha cobrado nada.';

  @override
  String get purchaseNothingToRestore =>
      'No hay nada que restaurar en esta cuenta.';

  @override
  String get lobbyJoining => 'UNIÉNDOSE';

  @override
  String get lobbyOpening => 'Abriendo la mesa…';

  @override
  String get lobbyConnecting => 'Conectando…';

  @override
  String get lobbyShareCode =>
      'Los demás se unen con este código, en el mismo WiFi.';

  @override
  String get lobbyTapToCopy => 'TOCA PARA COPIAR';

  @override
  String get lobbyCodeCopied => 'Código copiado';

  @override
  String get lobbyWaitingForHost => 'Esperando a que el anfitrión empiece.';

  @override
  String get lobbyStart => 'EMPEZAR';

  @override
  String get lobbyLeave => 'SALIR';

  @override
  String lobbyPlayerCount(int count, int max) {
    return 'JUGADORES  $count/$max';
  }

  @override
  String lobbyNeedMore(int count) {
    return 'Hacen falta $count para empezar';
  }

  @override
  String get netNoWifi =>
      'Sin red WiFi. Conéctate al WiFi e inténtalo de nuevo.';

  @override
  String get netNoAddress =>
      'No se pudo leer la dirección de red de este dispositivo.';

  @override
  String get netDropped => 'Se perdió la conexión.';

  @override
  String get netCantHost => 'No se pudo abrir la partida a otros jugadores.';

  @override
  String get netNoGameFound =>
      'No hay ninguna partida con ese código. Compruébalo y asegúrate de que ambos teléfonos estén en el mismo WiFi.';

  @override
  String get netCantJoin => 'No se pudo entrar en esa partida.';

  @override
  String get netTableFull => 'Esa partida está llena o ya empezó.';

  @override
  String get netHostLeft => 'El anfitrión salió de la partida.';

  @override
  String get introSkip => 'Saltar  ›';

  @override
  String get introClose => 'Cerrar  ›';

  @override
  String get introNext => 'SIGUIENTE';

  @override
  String get introDone => 'LISTO';

  @override
  String get introCardsEyebrow => 'LAS CARTAS';

  @override
  String get introCardsTitle => 'Recibes\n10 cartas';

  @override
  String get introCardsBody =>
      'Cada carta tiene un número y unas *estrellas*. Esas estrellas son *puntos de penalización*: junta las menos posibles.';

  @override
  String get introCardsNumberRange => 'NÚMERO 1 – 104';

  @override
  String get introCardsPenaltyStars => 'ESTRELLAS DE PENALIZACIÓN';

  @override
  String get introTableEyebrow => 'LA MESA';

  @override
  String get introTableTitle => 'Cinco cartas\npor fila';

  @override
  String get introTableBody =>
      'Cuatro filas ocupan el centro. Cada una empieza con una carta al azar y cabe un máximo de 5.';

  @override
  String get introTableCaption => 'EMPIEZA CON 1  ·  CABEN 5';

  @override
  String get introRoundEyebrow => 'CADA RONDA';

  @override
  String get introRoundTitle => 'Todos juegan\nuna carta';

  @override
  String get introRoundBody =>
      'Cada ronda todos eligen una carta y la juegan a la vez. El número más bajo se coloca primero. Cada carta va a la fila que termina justo por debajo.';

  @override
  String get introRoundCaption => 'JUGADAS ESTA RONDA';

  @override
  String get introSixthEyebrow => 'PENALIZACIÓN 1 DE 2';

  @override
  String get introSixthTitle => 'La sexta carta\nse lleva la fila';

  @override
  String get introSixthBody =>
      'Una fila se queda en 5 cartas. Juega la sexta y te llevas las 5: sus *estrellas* pasan a ser tus *puntos de penalización*.';

  @override
  String introTakeBadge(int count) {
    return 'Te llevas las $count';
  }

  @override
  String get introTooLowEyebrow => 'PENALIZACIÓN 2 DE 2';

  @override
  String get introTooLowTitle => 'Más baja que\ntodas las filas';

  @override
  String get introTooLowBody =>
      'Una carta más baja que todas las filas no cabe en ninguna. Eliges una fila, te llevas sus *estrellas* y tu carta la empieza de nuevo.';

  @override
  String get introWinnerEyebrow => 'TRAS 10 RONDAS';

  @override
  String get introWinnerTitle => 'Gana quien tenga\nmenos estrellas';

  @override
  String get introWinnerBody =>
      'Tras 10 rondas todas las manos están vacías. Se cuentan las *estrellas*. Gana el total más bajo.';

  @override
  String get introWinnerYou => 'Tú';
}
