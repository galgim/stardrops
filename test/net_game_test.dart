import 'package:flutter_test/flutter_test.dart';
import 'package:stardrop/game/game_state.dart';
import 'package:stardrop/net/join_code.dart';
import 'package:stardrop/net/lan_session.dart';
import 'package:stardrop/net/net_game.dart';

/// The relay, end to end over real sockets: a joiner plays a card, and both
/// the host and the *other* joiner end up knowing about it.
///
/// Deliberately never lets a round complete. Resolving one starts the real
/// animation timers, and none of what's being checked here needs them.
void main() {
  const names = ['Clay', 'Alex', 'Sam'];
  const seed = 31415;
  final loopback = JoinCode.encode('127.0.0.1')!;

  Future<void> waitFor(
    String what,
    bool Function() condition, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (!condition()) {
      if (DateTime.now().isAfter(deadline)) fail('timed out waiting for $what');
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
  }

  GameState dealt(int seat) => GameState()
    ..startGame(names: names, localSeat: seat, aiSeats: const {}, seed: seed);

  /// A host and two joiners, seated and dealt, with the relay running on all
  /// three — the state the game screen starts in.
  Future<
    ({
      LanHost host,
      List<LanClient> clients,
      List<GameState> states,
      List<NetGame> nets,
    })?
  >
  seatedTable() async {
    final host = LanHost(hostName: names[0]);
    if (!await host.start()) {
      markTestSkipped('no local network available: ${host.error}');
      await host.dispose();
      return null;
    }

    final clients = [LanClient(), LanClient()];
    for (var i = 0; i < clients.length; i++) {
      await clients[i].connect(loopback, names[i + 1]);
    }
    await waitFor('all three seated', () => host.names.length == 3);
    host.started = true;

    final states = [for (var seat = 0; seat < 3; seat++) dealt(seat)];
    final nets = [
      NetGame(gs: states[0], host: host),
      NetGame(gs: states[1], client: clients[0]),
      NetGame(gs: states[2], client: clients[1]),
    ];
    return (host: host, clients: clients, states: states, nets: nets);
  }

  test('a card played by a joiner reaches every other device', () async {
    final table = await seatedTable();
    if (table == null) return;
    addTearDown(() async {
      for (final n in table.nets) {
        n.dispose();
      }
      for (final c in table.clients) {
        await c.dispose();
      }
      await table.host.dispose();
    });

    final host = table.states[0];
    final alex = table.states[1];
    final sam = table.states[2];

    // Alex, in seat 1, plays — the same thing the game screen does: apply
    // locally first, then announce it.
    final alexCard = alex.localPlayer.hand.first;
    expect(alex.submitCard(1, alexCard), isTrue);
    table.nets[1].sendPlay(alexCard);

    await waitFor(
      'the host to see it',
      () => host.players[1].selectedCard != null,
    );
    await waitFor(
      'the other joiner to see it',
      () => sam.players[1].selectedCard != null,
    );

    // Not just "something arrived" — the same card, off the same hand.
    for (final gs in [host, alex, sam]) {
      expect(gs.players[1].selectedCard?.number, alexCard.number);
      expect(gs.players[1].hand.length, 9);
      expect(gs.players[0].selectedCard, isNull, reason: 'seat 0 has not played');
    }
  });

  test('two joiners playing both land everywhere', () async {
    final table = await seatedTable();
    if (table == null) return;
    addTearDown(() async {
      for (final n in table.nets) {
        n.dispose();
      }
      for (final c in table.clients) {
        await c.dispose();
      }
      await table.host.dispose();
    });

    final states = table.states;
    for (var seat = 1; seat <= 2; seat++) {
      final card = states[seat].localPlayer.hand.first;
      expect(states[seat].submitCard(seat, card), isTrue);
      table.nets[seat].sendPlay(card);
    }

    await waitFor(
      'both cards to reach the host',
      () =>
          states[0].players[1].selectedCard != null &&
          states[0].players[2].selectedCard != null,
    );
    // Seat 0 still hasn't played, so nobody may have resolved the round.
    for (final gs in states) {
      expect(gs.revealPhase, isFalse);
    }
  });

  test('a device cannot play on behalf of another seat', () async {
    final table = await seatedTable();
    if (table == null) return;
    addTearDown(() async {
      for (final n in table.nets) {
        n.dispose();
      }
      for (final c in table.clients) {
        await c.dispose();
      }
      await table.host.dispose();
    });

    final host = table.states[0];
    // Alex's socket, claiming to be the host's seat and playing a card out of
    // the host's hand. The seat is taken from the connection, not the message,
    // so this is read as Alex playing a card Alex doesn't hold — and refused.
    final notMine = host.players[0].hand.first.number;
    table.clients[0].send({'t': Msg.play, 'seat': 0, 'card': notMine});

    // Nothing to wait for, so give the message time to be wrong.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(host.players[0].selectedCard, isNull, reason: 'seat 0 was spoofed');
    expect(host.players[1].selectedCard, isNull, reason: 'the card was not seat 1\'s');
  });

  test('a malformed move is dropped, not applied', () async {
    final table = await seatedTable();
    if (table == null) return;
    addTearDown(() async {
      for (final n in table.nets) {
        n.dispose();
      }
      for (final c in table.clients) {
        await c.dispose();
      }
      await table.host.dispose();
    });

    final host = table.states[0];
    for (final junk in <Map<String, dynamic>>[
      {'t': Msg.play}, // no card
      {'t': Msg.play, 'card': 'seven'}, // not a number
      {'t': Msg.play, 'card': 9999}, // not in the deck
      {'t': Msg.pick, 'row': 99}, // not a row
      {'t': 'nonsense'},
    ]) {
      table.clients[0].send(junk);
    }

    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(host.players.every((p) => p.selectedCard == null), isTrue);
    expect(host.gameOver, isFalse);
  });

  // ── When a phone goes away ────────────────────────────────

  test('a mid-game departure does not renumber the seats left behind', () async {
    final table = await seatedTable();
    if (table == null) return;
    addTearDown(() async {
      for (final n in table.nets) {
        n.dispose();
      }
      await table.clients[1].dispose();
      await table.host.dispose();
    });

    expect(table.clients[1].seat, 2, reason: 'Sam started in seat 2');

    // Alex, in seat 1, drops. In the lobby that would move Sam up to seat 1 —
    // mid-game it must not, or Sam would inherit Alex's hand.
    await table.clients[0].dispose();
    await waitFor('the host to notice', () => table.host.names.length == 2);

    expect(table.clients[1].seat, 2, reason: 'Sam was moved out of their seat');
    expect(table.states[2].localSeat, 2);
    expect(table.states[0].players[2].name, 'Sam');
  });

  test('the host plays for a seat whose phone has gone', () async {
    final table = await seatedTable();
    if (table == null) return;

    final left = <String>[];
    // Rebuilt with the callback the game screen supplies, so the host actually
    // covers rather than just noticing.
    table.nets[0].dispose();
    final hostNet = NetGame(
      gs: table.states[0],
      host: table.host,
      onPlayerLeft: left.add,
    );
    addTearDown(() async {
      hostNet.dispose();
      table.nets[1].dispose();
      table.nets[2].dispose();
      await table.clients[0].dispose();
      await table.host.dispose();
    });

    final host = table.states[0];
    final alex = table.states[1];

    // Sam's phone goes away without playing.
    await table.clients[1].dispose();

    await waitFor(
      'the host to answer for Sam',
      () => host.players[2].selectedCard != null,
    );
    // And the remaining player hears about it like any ordinary move, so the
    // table stays in step without having to work out Sam's card themselves.
    await waitFor(
      'Alex to be told what Sam played',
      () => alex.players[2].selectedCard != null,
    );

    expect(left, ['Sam']);
    expect(
      alex.players[2].selectedCard?.number,
      host.players[2].selectedCard?.number,
    );
    // Sam's absence must not have answered for anybody else.
    expect(host.players[0].selectedCard, isNull);
    expect(host.players[1].selectedCard, isNull);
  });

  test('a joiner is told when the host disappears mid-game', () async {
    final table = await seatedTable();
    if (table == null) return;

    var lost = 0;
    table.nets[1].dispose();
    final alexNet = NetGame(
      gs: table.states[1],
      client: table.clients[0],
      onHostLost: () => lost++,
    );
    addTearDown(() async {
      alexNet.dispose();
      table.nets[0].dispose();
      table.nets[2].dispose();
      for (final c in table.clients) {
        await c.dispose();
      }
    });

    await table.host.dispose();
    await waitFor('the joiner to notice', () => lost > 0);
    expect(lost, 1, reason: 'the game should only end once');
  });

  test('the host deals everyone the same new game on a restart', () async {
    final table = await seatedTable();
    if (table == null) return;
    addTearDown(() async {
      for (final n in table.nets) {
        n.dispose();
      }
      for (final c in table.clients) {
        await c.dispose();
      }
      await table.host.dispose();
    });

    final states = table.states;
    final before = states[0].players[0].hand.map((c) => c.number).toList();

    // A joiner asks; only the host can pick the deal, so it comes back around.
    table.nets[2].requestRestart();

    await waitFor(
      'a new deal to reach every device',
      () => states.every(
        (gs) => !_sameHand(gs.players[0].hand.map((c) => c.number).toList(), before),
      ),
    );

    final hands = [
      for (final gs in states) gs.players[0].hand.map((c) => c.number).toList(),
    ];
    expect(hands[1], hands[0], reason: 'the joiners must deal what the host did');
    expect(hands[2], hands[0]);
  });

  /// The lobby is still the registered handler for a moment after START, while
  /// the game screen is being built. A move landing in that window has to
  /// survive the handover — one that doesn't leaves the whole table waiting on
  /// a seat that already played.
  test('a move relayed during the lobby handover is replayed, not dropped',
      () async {
    final host = LanHost(hostName: names[0]);
    if (!await host.start()) {
      markTestSkipped('no local network available: ${host.error}');
      await host.dispose();
      return;
    }
    final client = LanClient();
    addTearDown(() async {
      await client.dispose();
      await host.dispose();
    });

    await client.connect(loopback, names[1]);
    await waitFor('the joiner to be seated', () => host.names.length == 2);

    // Standing in for the lobby: it understands START and nothing else, and
    // hands anything else back for whoever takes over next.
    var seenByLobby = 0;
    client.onMessage = (msg) {
      if (msg['t'] == Msg.start) return;
      seenByLobby++;
      client.hold(msg);
    };

    host.broadcast({'t': Msg.play, 'seat': 0, 'card': 42});
    await waitFor('the lobby to see the move', () => seenByLobby == 1);

    // The game screen takes over, and is handed the move it never saw arrive.
    final seenByGame = <Map<String, dynamic>>[];
    client.onMessage = seenByGame.add;
    expect(seenByGame.single['card'], 42);
  });
}

bool _sameHand(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
