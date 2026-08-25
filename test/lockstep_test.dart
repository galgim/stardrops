import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stardrop/game/game_state.dart';
import 'package:stardrop/models/take_card.dart';

/// Lockstep: the whole design rests on every device reaching the same state
/// from the same moves, having been sent no state at all.
///
/// Two things could break that, and neither would show up as an error — the
/// tables would just quietly disagree about the score:
///
/// - a difference in the deal, which the seed rules out, and
/// - a difference in the *order* moves arrive in, which nothing rules out.
///   Cards are relayed one at a time over separate sockets, so no two devices
///   see them in the same order.
///
/// These run under `testWidgets` for its fake clock. The rules wait on real
/// delays between placements, and a full game of them would take minutes of
/// wall time; pumping advances that instantly.
void main() {
  const names = ['Clay', 'Alex', 'Sam'];

  /// Stands in for the game screen.
  ///
  /// The rules deliberately can't advance on their own — they stage a card
  /// flight and wait for the UI to say it landed. A headless test has to play
  /// that part, and does it on a microtask so it isn't re-entering the
  /// notification it was called from.
  void driveAnimations(GameState gs) {
    var scheduled = false;
    gs.addListener(() {
      if (scheduled) return;
      if (gs.rowTake == null && gs.flight == null) return;
      scheduled = true;
      scheduleMicrotask(() {
        scheduled = false;
        if (gs.rowTake != null) {
          gs.commitRowTake(gs.generation);
        } else if (gs.flight != null) {
          gs.commitFlight(gs.generation);
        }
      });
    });
  }

  GameState device(int seat, int seed) {
    final gs = GameState()
      ..startGame(
        names: names,
        localSeat: seat,
        aiSeats: const {},
        seed: seed,
      );
    driveAnimations(gs);
    return gs;
  }

  List<int> starsOf(GameState gs) => [for (final p in gs.players) p.totalStars];

  testWidgets(
    'two devices agree on the whole game, given the moves in opposite orders',
    (tester) async {
      await tester.pumpWidget(const SizedBox.shrink());

      const seed = 20260730;
      final forwards = device(0, seed);
      final backwards = device(2, seed);

      var guard = 0;
      while (!forwards.gameOver && guard++ < 40) {
        // Both devices are holding identical hands, so "the lowest card each
        // seat holds" names the same three cards on both.
        final chosen = [
          for (var seat = 0; seat < names.length; seat++)
            forwards.players[seat].hand.first.number,
        ];

        // The same three moves, arriving in reverse order on the second
        // device — which is exactly what separate sockets produce.
        for (var seat = 0; seat < names.length; seat++) {
          expect(
            forwards.submitCard(seat, TakeCard.fromNumber(chosen[seat])),
            isTrue,
          );
        }
        for (var seat = names.length - 1; seat >= 0; seat--) {
          expect(
            backwards.submitCard(seat, TakeCard.fromNumber(chosen[seat])),
            isTrue,
          );
        }

        await tester.pump(const Duration(seconds: 6));

        // Somebody may have to take a row. Both devices ask the same seat and
        // are told the same answer, because that answer is relayed too.
        var rowGuard = 0;
        while ((forwards.choosingRow || backwards.choosingRow) &&
            rowGuard++ < 10) {
          expect(
            forwards.rowChooserSeat ?? backwards.rowChooserSeat,
            backwards.rowChooserSeat ?? forwards.rowChooserSeat,
            reason: 'the devices disagree about who is choosing',
          );
          const takes = 0;
          if (forwards.choosingRow) {
            forwards.pickRow(forwards.rowChooserSeat!, takes);
          }
          if (backwards.choosingRow) {
            backwards.pickRow(backwards.rowChooserSeat!, takes);
          }
          await tester.pump(const Duration(seconds: 6));
        }

        // Every round both devices must still agree, not just at the end — a
        // divergence that cancels out later would still be a bug.
        expect(
          starsOf(backwards),
          starsOf(forwards),
          reason: 'scores diverged during round ${forwards.round}',
        );
        expect(
          [for (final r in backwards.rows) r.cards.map((c) => c.number).toList()],
          [for (final r in forwards.rows) r.cards.map((c) => c.number).toList()],
          reason: 'the tables diverged during round ${forwards.round}',
        );
      }

      expect(forwards.gameOver, isTrue, reason: 'the game never finished');
      expect(backwards.gameOver, isTrue, reason: 'one device is still playing');
      expect(starsOf(backwards), starsOf(forwards));

      // Ten cards each, one per round.
      expect(forwards.round, 10);
    },
  );

  testWidgets('a different seed produces a different game', (tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    final a = device(0, 1);
    final b = device(0, 2);
    expect(
      b.players[0].hand.map((c) => c.number).toList(),
      isNot(a.players[0].hand.map((c) => c.number).toList()),
    );
  });

  testWidgets('each device shows itself the right hand', (tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    const seed = 55;
    final clay = device(0, seed);
    final sam = device(2, seed);

    expect(clay.localPlayer.name, 'Clay');
    expect(sam.localPlayer.name, 'Sam');
    // Same table, different seat: the hand each device puts in front of its
    // own player is a different one, but both agree on what the other holds.
    expect(
      sam.localPlayer.hand.map((c) => c.number).toList(),
      clay.players[2].hand.map((c) => c.number).toList(),
    );
    expect(
      clay.localPlayer.hand.map((c) => c.number).toList(),
      sam.players[0].hand.map((c) => c.number).toList(),
    );
  });
}
