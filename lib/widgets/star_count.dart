import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme/app_text.dart';

/// A star count: the number followed by the star icon, e.g. "3 ★".
///
/// Used for player scores, row totals, and the intro's card values, so the
/// number and icon always sit the same distance apart at every size.
class StarCount extends StatelessWidget {
  final int count;
  final Color color;

  /// Icon colour, when it differs from the number's. Defaults to [color].
  final Color? iconColor;

  /// Which of the data styles the number is set in. A style rather than a size,
  /// so call sites can't quietly reintroduce a font size of their own.
  final TextStyle style;

  /// The star glyph's size. A drawing dimension rather than type, so it stays a
  /// number — matched by eye to [style] at each call site.
  final double iconSize;
  final double gap;

  /// Cross-fades the number's colour when it changes — used by the scoreboard,
  /// where a player's score turns red the moment they pick up stars.
  final bool animateColor;

  const StarCount({
    super.key,
    required this.count,
    required this.color,
    this.iconColor,
    this.style = AppText.stat,
    this.iconSize = 11,
    this.gap = 3,
    this.animateColor = false,
  });

  @override
  Widget build(BuildContext context) {
    final textStyle = style.copyWith(color: color);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (animateColor)
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 250),
            style: textStyle,
            child: Text('$count'),
          )
        else
          Text('$count', style: textStyle),
        SizedBox(width: gap),
        SvgPicture.asset(
          'assets/Star.svg',
          width: iconSize,
          height: iconSize,
          colorFilter: ColorFilter.mode(iconColor ?? color, BlendMode.srcIn),
        ),
      ],
    );
  }
}
