import 'package:flutter/material.dart';
import '../models/take_player.dart';
import '../theme/app_colors.dart';
import '../theme/app_metrics.dart';
import '../theme/app_text.dart';
import 'star_count.dart';
import 'take_card_widget.dart';

/// The scoreboard down the left edge: every player's name, star total, and
/// the card they played this round.
class PlayerSidebar extends StatelessWidget {
  final List<TakePlayer> players;
  final TakePlayer? currentPlayer;
  final bool showSelections;
  final List<GlobalKey> cardKeys;
  final TakePlayer? hiddenPlayer;

  /// The seat this device plays, shown in accent. Every other seat is a person
  /// too in a local game, so "not you" is the only distinction worth drawing.
  final int localSeat;

  const PlayerSidebar({
    super.key,
    required this.players,
    required this.currentPlayer,
    required this.showSelections,
    required this.cardKeys,
    required this.hiddenPlayer,
    required this.localSeat,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 132,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, p) in players.indexed)
            _PlayerSidebarRow(
              player: p,
              showCard: showSelections,
              isCurrent: p == currentPlayer,
              cardKey: cardKeys[i],
              hideCard: p == hiddenPlayer,
              isLocal: p.seat == localSeat,
            ),
        ],
      ),
    );
  }
}

class _PlayerSidebarRow extends StatelessWidget {
  final TakePlayer player;
  final bool showCard;
  final bool isCurrent;
  final GlobalKey cardKey;
  final bool hideCard;
  final bool isLocal;

  const _PlayerSidebarRow({
    required this.player,
    required this.showCard,
    required this.isCurrent,
    required this.cardKey,
    required this.hideCard,
    required this.isLocal,
  });

  @override
  Widget build(BuildContext context) {
    final selected = player.selectedCard;
    // Any accrued penalty shows red; only a clean 0 keeps the normal color.
    final scoreColor = player.totalStars > 0
        ? AppColors.penalty
        : (isLocal ? AppColors.accent : AppColors.mist);

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: isLocal
            ? AppColors.accent.withValues(alpha: 0.2)
            : Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.surface),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  player.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.chip.copyWith(
                    color: isLocal ? AppColors.accent : AppColors.mist,
                  ),
                ),
                const SizedBox(height: 2),
                StarCount(
                  count: player.totalStars,
                  color: scoreColor,
                  style: AppText.statSmall,
                  iconSize: 9,
                  animateColor: true,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          SizedBox(
            key: cardKey,
            width: 28,
            height: 39,
            child: (showCard && selected != null && !hideCard)
                ? TakeCardWidget(
                    card: selected,
                    width: 28,
                    height: 39,
                    highlighted: isCurrent,
                  )
                : null,
          ),
        ],
      ),
    );
  }
}
