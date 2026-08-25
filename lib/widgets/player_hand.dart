import 'package:flutter/material.dart';
import '../models/take_card.dart';
import '../services/sfx.dart';
import 'take_card_widget.dart';

/// The player's fanned hand along the bottom of the screen.
class PlayerHand extends StatelessWidget {
  final List<TakeCard> hand;
  final TakeCard? selectedCard;
  final bool interactive;
  final void Function(TakeCard) onSelectCard;

  const PlayerHand({
    super.key,
    required this.hand,
    required this.selectedCard,
    required this.interactive,
    required this.onSelectCard,
  });

  @override
  Widget build(BuildContext context) {
    // `hand` is kept sorted by GameState.startGame, so no copy/sort here.
    const cardW = 70.0;
    const cardH = 98.0;
    const minStep = 19.0;
    const hPad = 8.0;

    final selectedIndex = selectedCard == null ? -1 : hand.indexOf(selectedCard!);
    final order = List<int>.generate(hand.length, (i) => i);
    if (selectedIndex != -1) {
      order
        ..remove(selectedIndex)
        ..add(selectedIndex);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableW = constraints.maxWidth - hPad * 2;
        final n = hand.length;

        double step;
        if (n <= 1) {
          step = cardW;
        } else {
          step = (availableW - cardW) / (n - 1);
          if (step > cardW) step = cardW;
          if (step < minStep) step = minStep;
        }

        final stackWidth = n == 0 ? 0.0 : (n - 1) * step + cardW;
        final leftOffset = hPad + ((availableW - stackWidth) / 2).clamp(0.0, double.infinity);

        return SizedBox(
          height: cardH + 10,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              for (final i in order)
                Positioned(
                  key: ValueKey(hand[i].number),
                  left: leftOffset + i * step,
                  top: 5,
                  child: GestureDetector(
                    // selectCard toggles, so tapping the raised card puts it
                    // back down — the two directions get different sounds.
                    onTap: interactive
                        ? () {
                            hand[i] == selectedCard
                                ? Sfx.cardDeselect()
                                : Sfx.cardSelect();
                            onSelectCard(hand[i]);
                          }
                        : null,
                    child: AnimatedSlide(
                      offset: hand[i] == selectedCard
                          ? const Offset(0, -0.3)
                          : Offset.zero,
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOut,
                      child: TakeCardWidget(
                        card: hand[i],
                        width: cardW,
                        height: cardH,
                        dimmed: !interactive,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
