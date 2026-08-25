import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../models/take_card.dart';
import '../theme/app_colors.dart';
import '../theme/app_metrics.dart';
import '../theme/app_text.dart';

/// A single playing card: the tier artwork with its number overlaid.
class TakeCardWidget extends StatelessWidget {
  final TakeCard card;
  final double width;
  final double height;
  final bool highlighted;
  final bool dimmed;

  const TakeCardWidget({
    super.key,
    required this.card,
    required this.width,
    required this.height,
    this.highlighted = false,
    this.dimmed = false,
  });

  @override
  Widget build(BuildContext context) {
    // The 5- and 7-star card faces are dark enough to need a light number.
    final textColor = card.stars >= 5 ? Colors.white : Colors.black87;

    // A card is an object resting on a surface, so it's separated from what's
    // under it by a shadow rather than by an outline. The accent border is
    // state — this is the card being played right now — and is the only border
    // a card ever has.
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: highlighted
            ? Border.all(color: AppColors.accent, width: 2)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: highlighted ? 0.38 : 0.22),
            blurRadius: highlighted ? 6 : 3,
            offset: Offset(0, highlighted ? 3 : 1),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.card),
              child: SvgPicture.asset(
                'assets/Card ${card.stars}.svg',
                fit: BoxFit.cover,
              ),
            ),
          ),
          Positioned(
            top: width * 0.08,
            left: width * 0.1,
            child: Text(
              '${card.number}',
              style: AppText.cardNumber(width * 0.28, textColor),
            ),
          ),
          // Last, so it dims the number along with the artwork.
          if (dimmed)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(AppRadius.card),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
