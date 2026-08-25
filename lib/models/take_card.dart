class TakeCard {
  final int number;
  final int stars;

  const TakeCard({required this.number, required this.stars});

  factory TakeCard.fromNumber(int n) => TakeCard(number: n, stars: _starsFor(n));

  static int _starsFor(int n) {
    if (n == 55) return 7;
    if (n % 11 == 0) return 5;
    if (n % 10 == 0) return 3;
    if (n % 5 == 0) return 2;
    return 1;
  }
}
