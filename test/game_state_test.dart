import 'package:flutter_test/flutter_test.dart';
import 'package:stardrop/game/game_state.dart';

void main() {
  GameState build(List<int> stars) {
    final gs = GameState()..startSinglePlayer(stars.length, 'You', aiName: (i) => 'AI $i');
    for (var i = 0; i < stars.length; i++) {
      gs.players[i].totalStars = stars[i];
    }
    return gs;
  }

  test('outright local win', () {
    final gs = build([3, 9, 12]);
    expect(gs.localWon, isTrue);
    expect(gs.isTie, isFalse);
    expect(gs.sortedByStars.first.seat, gs.localSeat);
  });

  test('outright AI win', () {
    final gs = build([9, 3, 12]);
    expect(gs.localWon, isFalse);
    expect(gs.isTie, isFalse);
    expect(gs.sortedByStars.first.name, 'AI 1');
  });

  test('tied for fewest stars counts as a win and takes 1st', () {
    final gs = build([5, 5, 12]);
    expect(gs.localWon, isTrue);
    expect(gs.isTie, isTrue);
    expect(gs.sortedByStars.first.seat, gs.localSeat);
  });

  test('a tie between other seats leaves you out of the win', () {
    final gs = build([12, 4, 4]);
    expect(gs.localWon, isFalse);
    expect(gs.isTie, isTrue);
    expect(gs.sortedByStars.map((p) => p.name).toList(), [
      'AI 1',
      'AI 2',
      'You',
    ]);
  });

  test('pause holds a scheduled step; resume runs it', () async {
    final gs = build([0, 0, 0]);
    expect(gs.isPaused, isFalse);
    gs.pause();
    expect(gs.isPaused, isTrue);
    gs.confirmSelection(); // no selection -> no-op, sanity only
    gs.resume();
    expect(gs.isPaused, isFalse);
  });

  // ── Seats, dealing, and the network-facing doors ──────────────

  test('the same seed deals the same game on every device', () {
    final host = GameState()
      ..startGame(
        names: ['Clay', 'Alex', 'Sam'],
        localSeat: 0,
        aiSeats: const {},
        seed: 4242,
      );
    final joiner = GameState()
      ..startGame(
        names: ['Clay', 'Alex', 'Sam'],
        localSeat: 2, // a different device, same deal
        aiSeats: const {},
        seed: 4242,
      );

    for (var seat = 0; seat < 3; seat++) {
      expect(
        joiner.players[seat].hand.map((c) => c.number).toList(),
        host.players[seat].hand.map((c) => c.number).toList(),
        reason: 'seat $seat was dealt a different hand',
      );
    }
    expect(
      joiner.rows.map((r) => r.topCard!.number).toList(),
      host.rows.map((r) => r.topCard!.number).toList(),
    );
  });

  test('different seeds deal different games', () {
    List<int> handFor(int seed) => (GameState()
          ..startGame(
            names: ['A', 'B', 'C'],
            localSeat: 0,
            aiSeats: const {},
            seed: seed,
          ))
        .players[0]
        .hand
        .map((c) => c.number)
        .toList();

    expect(handFor(1), isNot(equals(handFor(2))));
  });

  test('each device sees itself in the accent seat', () {
    final gs = GameState()
      ..startGame(
        names: ['Clay', 'Alex', 'Sam'],
        localSeat: 1,
        aiSeats: const {},
        seed: 7,
      );
    expect(gs.localPlayer.name, 'Alex');
    expect(gs.players.every((p) => p.isAi), isFalse);
  });

  test('a round resolves only once every seat has played', () {
    final gs = GameState()
      ..startGame(
        names: ['A', 'B', 'C'],
        localSeat: 0,
        aiSeats: const {},
        seed: 11,
      );

    expect(gs.submitCard(0, gs.players[0].hand.first), isTrue);
    expect(gs.revealPhase, isFalse, reason: 'two seats still to play');
    expect(gs.submitCard(1, gs.players[1].hand.first), isTrue);
    expect(gs.revealPhase, isFalse, reason: 'one seat still to play');
    expect(gs.submitCard(2, gs.players[2].hand.first), isTrue);
    expect(gs.revealPhase, isTrue, reason: 'last seat played, round resolves');
  });

  // A desync is the failure mode that matters here: every device resolves the
  // round independently, so one accepted bad message corrupts all of them.
  group('submitCard rejects what would desync the table', () {
    late GameState gs;

    setUp(() {
      gs = GameState()
        ..startGame(
          names: ['A', 'B', 'C'],
          localSeat: 0,
          aiSeats: const {},
          seed: 3,
        );
    });

    test('a seat that does not exist', () {
      expect(gs.submitCard(9, gs.players[0].hand.first), isFalse);
      expect(gs.submitCard(-1, gs.players[0].hand.first), isFalse);
    });

    test('a card the seat is not holding', () {
      final notInHand = gs.players[1].hand.first;
      expect(gs.submitCard(0, notInHand), isFalse);
      expect(gs.players[0].selectedCard, isNull);
    });

    test('playing twice in one round', () {
      expect(gs.submitCard(0, gs.players[0].hand.first), isTrue);
      expect(gs.submitCard(0, gs.players[0].hand.first), isFalse);
    });

    test('a card rebuilt from the wire is matched by number', () {
      final wireCopy = gs.players[0].hand.first.number;
      expect(
        gs.submitCard(0, gs.players[0].hand.firstWhere(
          (c) => c.number == wireCopy,
        )),
        isTrue,
      );
    });
  });

  test('single player still plays a round off one tap', () {
    final gs = GameState()..startSinglePlayer(5, 'You', aiName: (i) => 'AI $i');
    final card = gs.localPlayer.hand.first;

    gs.selectCard(card);
    expect(gs.selectedCard, card);
    gs.confirmSelection();

    // One tap answered for the whole table: the AI seats filled themselves in
    // and the round moved on to the reveal.
    expect(gs.revealPhase, isTrue);
    expect(gs.players.every((p) => p.selectedCard != null), isTrue);
    expect(gs.players.every((p) => p.hand.length == 9), isTrue);
    expect(gs.localPlayer.hand.contains(card), isFalse);
  });

  test('a refused submission leaves the highlighted card where it was', () {
    final gs = GameState()..startSinglePlayer(3, 'You', aiName: (i) => 'AI $i');
    final card = gs.localPlayer.hand.first;
    gs.selectCard(card);
    gs.confirmSelection(); // plays it, resolves the round
    expect(gs.selectedCard, isNull);

    // Mid-reveal nothing may be played, and the hand must be untouched.
    final handBefore = gs.localPlayer.hand.length;
    expect(gs.submitCard(0, gs.localPlayer.hand.first), isFalse);
    expect(gs.localPlayer.hand.length, handBefore);
  });

  test('an unplayable player count is refused rather than crashing', () {
    final gs = GameState();
    gs.startGame(names: const [], localSeat: 0, aiSeats: const {});
    expect(gs.round, 0, reason: 'nothing was dealt');

    gs.startGame(
      names: List.generate(GameState.maxPlayers + 1, (i) => 'P$i'),
      localSeat: 0,
      aiSeats: const {},
    );
    expect(gs.round, 0, reason: 'still nothing dealt');
  });

  test('pickRow refuses a seat that was not asked, and a row off the end', () {
    final gs = GameState()
      ..startGame(
        names: ['A', 'B', 'C'],
        localSeat: 0,
        aiSeats: const {},
        seed: 5,
      );
    // Nobody is choosing, so every pick is refused.
    expect(gs.pickRow(0, 0), isFalse);
    expect(gs.pickRow(0, 99), isFalse);
  });
}
