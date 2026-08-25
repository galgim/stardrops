import 'dart:math';

import 'package:flutter/foundation.dart';

import '../game/game_state.dart';
import '../logic/ai_strategy.dart';
import '../models/take_card.dart';
import 'lan_session.dart';

/// Keeps one device's [GameState] in step with the rest of the table.
///
/// Nothing about the game is sent over the wire — no hands, no rows, no
/// scores. Every device dealt the same cards from the same seed, so the only
/// thing anyone needs to know is which seat played which card, and it works
/// the consequences out locally. That's why this class is small: it forwards
/// two kinds of move and applies the ones that come back.
///
/// The host is a relay. A joiner sends its move to the host, the host applies
/// it and passes it on to everyone else. The host's own moves go straight out.
class NetGame {
  NetGame({
    required this.gs,
    this.host,
    this.client,
    this.onRestart,
    this.onPlayerLeft,
    this.onHostLost,
  }) : assert(
         (host == null) != (client == null),
         'a device is either hosting or joining, never both or neither',
       ) {
    host?.onMessage = _onFromPlayer;
    host?.onPlayerLeft = _onPlayerGone;
    client?.onMessage = (msg) => _onFromHost(msg);
    client?.addListener(_checkHost);
  }

  final GameState gs;
  final LanHost? host;
  final LanClient? client;

  /// Called when a fresh game has been dealt, so the screen can clear the
  /// per-game state it holds outside [GameState].
  final VoidCallback? onRestart;

  /// Called on the host when a player's phone goes away mid-game, so the
  /// screen can say so.
  final void Function(String name)? onPlayerLeft;

  /// Called on a joiner when the host goes away. Nothing can be relayed after
  /// that, so the game is over whether it finished or not.
  final VoidCallback? onHostLost;

  bool get isHost => host != null;

  /// Moves that arrived before this device was ready for them.
  ///
  /// Devices run the same rules but not the same clock: animations take
  /// seconds, and a phone that finished the last round first can play its next
  /// card while another is still watching cards fly. A move that can't be
  /// applied yet isn't wrong, it's early — so it waits here and is retried
  /// every time the game state moves on.
  final List<Map<String, dynamic>> _early = [];

  /// About two rounds' worth. Anything still unapplied after that isn't early,
  /// it's a move this device can never make sense of, and holding it forever
  /// would just leak.
  static const _maxEarly = 25;

  /// Seats whose phone has gone. Host only — it's the one that can tell.
  final Set<int> _gone = {};

  // ── Sending ───────────────────────────────────────────────

  /// Tells the table this device played [card]. Call after [GameState] has
  /// accepted it locally.
  void sendPlay(TakeCard card) =>
      _relay({'t': Msg.play, 'seat': gs.localSeat, 'card': card.number});

  /// Tells the table this device took [row].
  void sendPick(int row) =>
      _relay({'t': Msg.pick, 'seat': gs.localSeat, 'row': row});

  /// Asks for another game. Only the host can actually deal one — it picks the
  /// seed, because every device has to shuffle the same way.
  void requestRestart() {
    if (isHost) {
      _dealAgain(Random().nextInt(1 << 31));
    } else {
      client?.send({'t': Msg.restart});
    }
  }

  /// Sends a move out. The host is already everyone's relay, so it broadcasts;
  /// a joiner has only one connection, and the host forwards from there.
  void _relay(Map<String, dynamic> msg) {
    if (isHost) {
      host!.broadcast(msg);
    } else {
      client!.send(msg);
    }
  }

  // ── Receiving ─────────────────────────────────────────────

  /// A move from a joiner, arriving at the host. The host both applies it and
  /// passes it on, since nobody else can hear that joiner directly.
  ///
  /// [seat] comes from the connection it arrived on, not from the message, so
  /// a device can't claim to be somebody else.
  void _onFromPlayer(int seat, Map<String, dynamic> msg) {
    if (msg['t'] == Msg.restart) {
      _dealAgain(Random().nextInt(1 << 31));
      return;
    }

    final move = _sanitise(msg, seat);
    if (move == null) return;
    _applyOrHold(move);
    host!.broadcast(move);
  }

  /// A message from the host, arriving at a joiner.
  void _onFromHost(Map<String, dynamic> msg) {
    if (msg['t'] == Msg.restart) {
      final seed = msg['seed'];
      if (seed is int) _redeal(seed);
      return;
    }

    final seat = msg['seat'];
    if (seat is! int) return;
    final move = _sanitise(msg, seat);
    if (move == null) return;
    _applyOrHold(move);
  }

  /// Rebuilds a move from untrusted input, or null if it isn't one.
  ///
  /// The rules themselves re-check everything — [GameState.submitCard] and
  /// [GameState.pickRow] refuse anything that would desync the table — so this
  /// only has to guarantee the shape. Rebuilding rather than forwarding the
  /// original also drops any extra keys a sender put in.
  Map<String, dynamic>? _sanitise(Map<String, dynamic> msg, int seat) {
    switch (msg['t']) {
      case Msg.play:
        final card = msg['card'];
        // Range-checked here so a nonsense number never reaches the early
        // queue, where it would be retried until it aged out.
        if (card is! int || card < 1 || card > GameState.deckSize) return null;
        return {'t': Msg.play, 'seat': seat, 'card': card};
      case Msg.pick:
        final row = msg['row'];
        if (row is! int) return null;
        return {'t': Msg.pick, 'seat': seat, 'row': row};
      default:
        return null;
    }
  }

  /// Applies [move], or holds it if this device hasn't caught up yet.
  void _applyOrHold(Map<String, dynamic> move) {
    if (_apply(move)) return;
    if (_early.length >= _maxEarly) {
      debugPrint('NetGame: dropping a move that never became playable');
      _early.removeAt(0);
    }
    _early.add(move);
  }

  /// Guards against re-entering. Applying a move notifies the game state's
  /// listeners, and the screen's listener calls straight back in here — which
  /// would otherwise mutate [_early] from inside its own `removeWhere`, and
  /// let the host answer twice for the same absent seat.
  bool _catchingUp = false;

  /// Called whenever the game state moves on — the only thing that can make an
  /// early move playable, or leave the table waiting on a seat that has gone.
  void catchUp() {
    if (_catchingUp) return;
    _catchingUp = true;
    try {
      if (_early.isNotEmpty) _early.removeWhere(_apply);
      _coverForAbsent();
    } finally {
      _catchingUp = false;
    }
  }

  // ── Players who have gone ─────────────────────────────────

  /// Host only: a player's connection dropped mid-game.
  void _onPlayerGone(int seat, String name) {
    if (seat < 0 || seat >= gs.players.length) return;
    if (!_gone.add(seat)) return;
    onPlayerLeft?.call(name);
    catchUp();
  }

  /// Host only: answers for seats whose phone has gone, so the table isn't
  /// left waiting on somebody who isn't there.
  ///
  /// The choice is relayed exactly like a real player's, which is the whole
  /// reason this is cheap: the other devices apply a card number they were
  /// sent rather than working one out, so the AI standing in doesn't have to
  /// behave identically everywhere — only the host ever runs it.
  ///
  /// Ending the game instead would have been fewer lines, but a locked screen
  /// or a walk out of WiFi range is ordinary, and losing everyone's game to
  /// one of them isn't acceptable.
  void _coverForAbsent() {
    if (!isHost || _gone.isEmpty || gs.gameOver) return;

    if (gs.choosingRow) {
      final seat = gs.rowChooserSeat;
      if (seat != null && _gone.contains(seat)) {
        final row = AiStrategy.chooseBestRow(gs.rows);
        if (gs.pickRow(seat, row)) {
          host!.broadcast({'t': Msg.pick, 'seat': seat, 'row': row});
        }
      }
      return; // nothing else can move until the row is settled
    }

    if (gs.revealPhase) return;

    for (final seat in _gone) {
      final player = gs.players[seat];
      if (player.selectedCard != null || player.hand.isEmpty) continue;
      // At full strength, whatever the table's difficulty is: this seat is a
      // person who lost their connection, not an opponent anyone chose.
      final card = AiStrategy.chooseCard(player.hand, gs.rows);
      if (gs.submitCard(seat, card)) {
        host!.broadcast({'t': Msg.play, 'seat': seat, 'card': card.number});
      }
    }
  }

  /// Joiner only: the host's socket closed. Without the relay there is no
  /// game left to play, so the screen is told to bow out.
  void _checkHost() {
    if (client?.hostLost ?? false) onHostLost?.call();
  }

  /// Applies one move to the local rules. False means "not yet".
  bool _apply(Map<String, dynamic> move) {
    final seat = move['seat'] as int;

    // This device's own moves come back to it: a joiner's move is relayed to
    // everyone including the sender. It's already applied, so drop it rather
    // than let it sit in the early queue being retried forever.
    if (seat == gs.localSeat) return true;

    switch (move['t']) {
      case Msg.play:
        return gs.submitCard(seat, TakeCard.fromNumber(move['card'] as int));
      case Msg.pick:
        return gs.pickRow(seat, move['row'] as int);
      default:
        return true; // unknown, and never going to become known
    }
  }

  // ── Restarting ────────────────────────────────────────────

  /// Host only: deal another game and tell everyone which one.
  void _dealAgain(int seed) {
    host?.broadcast({'t': Msg.restart, 'seed': seed});
    _redeal(seed);
  }

  void _redeal(int seed) {
    _early.clear(); // moves from the finished game must not leak into the new one
    gs.reset(seed: seed);
    onRestart?.call();
    // Whoever left is still gone, so the host keeps covering their seat in the
    // new game too — _gone deliberately survives a redeal.
    catchUp();
  }

  void dispose() {
    host?.onMessage = null;
    host?.onPlayerLeft = null;
    client?.onMessage = null;
    client?.removeListener(_checkHost);
  }
}
