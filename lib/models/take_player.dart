import 'take_card.dart';

class TakePlayer {
  /// Position at the table, and this player's identity everywhere else — it's
  /// what a choice arriving from another device names, and what breaks ties in
  /// the final standings. Always matches the index in `GameState.players`.
  final int seat;

  final String name;

  /// Whether this seat plays itself. The opposite of [isAi] is not "you": in a
  /// local multiplayer game every seat is a person and only one of them is
  /// you. "Is this me" is `seat == GameState.localSeat` — a fact about the
  /// device, not about the player.
  final bool isAi;

  List<TakeCard> hand;
  int totalStars;
  TakeCard? selectedCard;

  TakePlayer({
    required this.seat,
    required this.name,
    required this.isAi,
    List<TakeCard>? hand,
    this.totalStars = 0,
    this.selectedCard,
  }) : hand = hand ?? [];
}
