import 'dart:math';

import '../models/take_card.dart';
import '../models/game_row.dart';

/// How well an AI seat plays.
///
/// There is only one strategy in this file — [hard] is it, evaluated in full.
/// The easier levels are that same strategy made to slip, rather than separate
/// (and separately wrong) heuristics of their own.
enum AiLevel {
  /// Plays a card at random. Loses badly and obviously.
  easy,

  /// Plays the best card most of the time and the runner-up the rest, so it
  /// gives ground steadily without ever making a move it didn't evaluate.
  normal,

  /// Always plays the cheapest card it can find.
  hard,
}

class AiStrategy {
  // Returns the row index where [card] should be placed, or -1 if none qualify.
  static int targetRowIndex(TakeCard card, List<GameRow> rows) {
    int best = -1;
    int bestTop = -1;
    for (int i = 0; i < rows.length; i++) {
      final top = rows[i].topCard;
      // A row is only ever momentarily empty, and no card resolves during that
      // window — skip it rather than crash if the sequencing ever changes.
      if (top == null) continue;
      if (top.number < card.number && top.number > bestTop) {
        bestTop = top.number;
        best = i;
      }
    }
    return best;
  }

  /// Everything that costs stars scores at or above this; every safe placement
  /// scores below it. Within the paying band the score is the actual number of
  /// stars the card would cost, so the two ways of picking up — being under
  /// every row, and playing a sixth card — are compared on the same scale.
  ///
  /// They used to sit in bands of their own (1000+ and 500+), which meant a
  /// sixth card always beat choosing a row no matter what each cost. The AI
  /// would swallow a 27-star row rather than take a 3-star one.
  static const _payBand = 1000;

  /// How often [AiLevel.normal] plays the runner-up instead of the best card.
  ///
  /// It slips often enough to lose ground over ten rounds, but every slip is
  /// still a card it scored — the second-cheapest, not a random one. That's
  /// what keeps it feeling like a weaker player rather than a broken one.
  static const _normalSlipChance = 0.35;

  /// Only ever consulted on one device.
  ///
  /// The AI runs in two places, and neither needs to agree with another phone:
  /// a solo game has no other phone, and the host covering an absent seat
  /// broadcasts the card number it settled on rather than letting the others
  /// work it out. So this is free to be random.
  static final _rng = Random();

  /// Picks the card to play this round: the cheapest in stars, and among cards
  /// that cost nothing, the one landing in the emptiest row.
  ///
  /// [level] weakens that choice rather than replacing it — see [AiLevel].
  /// [rng] is for tests; production leaves it null and takes [_rng].
  ///
  /// Throws on an empty hand, like it always has. Both callers check first,
  /// because a seat with no cards left isn't a choice to make.
  static TakeCard chooseCard(
    List<TakeCard> hand,
    List<GameRow> rows, {
    AiLevel level = AiLevel.hard,
    Random? rng,
  }) {
    final random = rng ?? _rng;
    if (level == AiLevel.easy) return hand[random.nextInt(hand.length)];

    // Best and runner-up in one pass. Strictly-less-than throughout, so the
    // earlier card wins a tie and a given hand always yields the same pair.
    TakeCard? best;
    TakeCard? runnerUp;
    int bestScore = _payBand * 2;
    int runnerUpScore = _payBand * 2;

    for (final card in hand) {
      final score = _scoreCard(card, rows);
      if (score < bestScore) {
        runnerUp = best;
        runnerUpScore = bestScore;
        best = card;
        bestScore = score;
      } else if (score < runnerUpScore) {
        runnerUp = card;
        runnerUpScore = score;
      }
    }

    // A one-card hand has no runner-up to slip to, and plays the same at every
    // level — there is nothing to choose between.
    if (level == AiLevel.normal &&
        runnerUp != null &&
        random.nextDouble() < _normalSlipChance) {
      return runnerUp;
    }
    return best ?? hand.first;
  }

  /// What playing [card] would cost, lower being better.
  static int _scoreCard(TakeCard card, List<GameRow> rows) {
    final idx = targetRowIndex(card, rows);

    // Below every row's top card: the player takes a row of their choice, and
    // chooseBestRow will pick the cheapest — so that's the price. The two must
    // agree, or the AI would be costing a move it doesn't go on to make.
    if (idx == -1) return _payBand + rows[chooseBestRow(rows)].totalStars;

    final row = rows[idx];

    // Sixth card into a full row: the player takes the five already there.
    if (row.isFull) return _payBand + row.totalStars;

    // Costs nothing now. Prefer the emptiest row, since a row with room is
    // less likely to force a pickup later; the card's own stars only break
    // ties between equally empty rows.
    return row.size * 10 + card.stars;
  }

  static int chooseBestRow(List<GameRow> rows) {
    int bestIdx = 0;
    int minStars = rows[0].totalStars;
    for (int i = 1; i < rows.length; i++) {
      if (rows[i].totalStars < minStars) {
        minStars = rows[i].totalStars;
        bestIdx = i;
      }
    }
    return bestIdx;
  }
}
