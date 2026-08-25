import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:stardrop/logic/ai_strategy.dart';
import 'package:stardrop/models/game_row.dart';
import 'package:stardrop/models/take_card.dart';

void main() {
  GameRow row(List<int> numbers) =>
      GameRow([for (final n in numbers) TakeCard.fromNumber(n)]);

  test('empty row reports a null top card instead of throwing', () {
    expect(const GameRow([]).topCard, isNull);
    expect(row([6]).topCard!.number, 6);
  });

  test('card goes to the row whose top is nearest below it', () {
    final rows = [row([6]), row([24]), row([55]), row([80])];
    expect(AiStrategy.targetRowIndex(TakeCard.fromNumber(37), rows), 1);
    expect(AiStrategy.targetRowIndex(TakeCard.fromNumber(81), rows), 3);
    expect(AiStrategy.targetRowIndex(TakeCard.fromNumber(7), rows), 0);
  });

  test('card below every row top has no target', () {
    final rows = [row([6]), row([24]), row([55]), row([80])];
    expect(AiStrategy.targetRowIndex(TakeCard.fromNumber(3), rows), -1);
  });

  test('a momentarily empty row is skipped, not crashed on', () {
    final rows = [row([6]), const GameRow([]), row([55]), row([80])];
    expect(AiStrategy.targetRowIndex(TakeCard.fromNumber(37), rows), 0);
  });

  test('chooseBestRow picks the cheapest row', () {
    final rows = [row([11]), row([4, 7]), row([55]), row([10])];
    expect(AiStrategy.chooseBestRow(rows), 1); // 2 stars vs 5, 7, 3
  });

  test('a card that costs nothing beats one that picks up stars', () {
    final rows = [row([6]), row([24]), row([55]), row([80])];
    // 25 lands safely on the row topped by 24; 3 is under every top card and
    // would take a row.
    final hand = [TakeCard.fromNumber(3), TakeCard.fromNumber(25)];
    expect(AiStrategy.chooseCard(hand, rows).number, 25);
  });

  test('between safe cards it prefers the emptier row', () {
    final rows = [row([6, 7, 8]), row([24]), row([55]), row([80])];
    // Both are safe: 9 joins a row already holding three, 25 joins one holding
    // one. The emptier row is less likely to force a pickup later.
    final hand = [TakeCard.fromNumber(9), TakeCard.fromNumber(25)];
    expect(AiStrategy.chooseCard(hand, rows).number, 25);
  });

  test('when both cards cost stars it pays the smaller bill', () {
    // Row 0 is full and worth 27 stars; the rest are worth 3 each. Playing 56
    // is a sixth card into row 0 — 27 stars. Playing 2 goes under every top
    // card, taking the cheapest row instead — 3 stars.
    //
    // Regression: these two outcomes used to be scored in separate bands, so a
    // sixth card always won regardless of what either cost.
    final rows = [row([55, 11, 22, 33, 44]), row([60]), row([70]), row([80])];
    final hand = [TakeCard.fromNumber(56), TakeCard.fromNumber(2)];
    expect(AiStrategy.chooseCard(hand, rows).number, 2);
  });

  // ── Difficulty ────────────────────────────────────────────

  group('difficulty', () {
    // 25 is the best card here (safe, lands in the emptiest row), 9 the
    // runner-up (safe but joins a row already holding three), 2 the worst
    // (under every top card, so it takes a row).
    final rows = [row([6, 7, 8]), row([24]), row([55]), row([80])];
    final hand = [
      TakeCard.fromNumber(2),
      TakeCard.fromNumber(9),
      TakeCard.fromNumber(25),
    ];

    test('hard always takes the best card', () {
      for (final roll in [0.0, 0.34, 0.36, 0.99]) {
        expect(
          AiStrategy.chooseCard(
            hand,
            rows,
            level: AiLevel.hard,
            rng: _FixedRandom(roll),
          ).number,
          25,
        );
      }
    });

    test('normal takes the best card when it does not slip', () {
      expect(
        AiStrategy.chooseCard(
          hand,
          rows,
          level: AiLevel.normal,
          rng: _FixedRandom(0.99),
        ).number,
        25,
      );
    });

    test('normal slips to the runner-up, never to the worst card', () {
      expect(
        AiStrategy.chooseCard(
          hand,
          rows,
          level: AiLevel.normal,
          rng: _FixedRandom(0.0),
        ).number,
        9,
      );
    });

    test('normal cannot slip with only one card left', () {
      final last = [TakeCard.fromNumber(2)];
      expect(
        AiStrategy.chooseCard(
          last,
          rows,
          level: AiLevel.normal,
          rng: _FixedRandom(0.0),
        ).number,
        2,
      );
    });

    test('easy plays whatever the roll lands on, best card included', () {
      for (var i = 0; i < hand.length; i++) {
        expect(
          AiStrategy.chooseCard(
            hand,
            rows,
            level: AiLevel.easy,
            rng: _FixedRandom(0.0, nextInt: i),
          ).number,
          hand[i].number,
        );
      }
    });

    test('every level returns a card actually in the hand', () {
      // The real Random, run enough times to cover both sides of the slip.
      for (final level in AiLevel.values) {
        for (var i = 0; i < 200; i++) {
          expect(hand, contains(AiStrategy.chooseCard(hand, rows, level: level)));
        }
      }
    });
  });
}

/// A [Random] that always answers the same thing, so a test can sit on either
/// side of the slip chance instead of hunting for a seed that happens to.
class _FixedRandom implements Random {
  final double _double;
  final int _int;

  _FixedRandom(this._double, {int nextInt = 0}) : _int = nextInt;

  @override
  double nextDouble() => _double;

  @override
  int nextInt(int max) => _int;

  @override
  bool nextBool() => _double < 0.5;
}
