import 'take_card.dart';

class GameRow {
  final List<TakeCard> cards;

  const GameRow(this.cards);

  /// The card a new card must beat, or null while the row is empty — which it
  /// briefly is between a row being taken and the replacement card landing.
  TakeCard? get topCard => cards.isEmpty ? null : cards.last;
  int get size => cards.length;
  int get totalStars => cards.fold(0, (s, c) => s + c.stars);
  bool get isFull => cards.length >= 5;

  GameRow withCard(TakeCard c) => GameRow([...cards, c]);
}
