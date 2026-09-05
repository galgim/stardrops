import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../logic/ai_strategy.dart';
import '../models/take_player.dart';
import '../services/stats_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_metrics.dart';
import '../theme/app_text.dart';
import 'app_button.dart';
import 'difficulty_dialog.dart';
import 'star_count.dart';

/// End-of-game results: the outcome and actions on the left, a ranked
/// leaderboard of every player on the right.
///
/// There is deliberately no panel — no card, no gradient, no border. The
/// finished table stays visible through a darkened scrim and the results sit
/// directly on top of it, held together by type and alignment rather than by a
/// box. Anything that isn't information has been removed.
class GameOverOverlay extends StatelessWidget {
  final List<TakePlayer> players; // sorted best-first (fewest stars)
  final bool localWon; // true if this device's player holds or shares the lead
  final bool isTie; // true if more than one player shares the winning score
  final int localSeat; // which of the standings rows is you

  /// The lifetime record at the difficulty just played, already counting this
  /// game. Null in a networked game, where results aren't filed by difficulty.
  final ({AiLevel level, LevelRecord record})? record;

  final VoidCallback onPlayAgain;
  final VoidCallback onMenu;

  const GameOverOverlay({
    super.key,
    required this.players,
    required this.localWon,
    required this.isTie,
    required this.localSeat,
    required this.record,
    required this.onPlayAgain,
    required this.onMenu,
  });

  @override
  Widget build(BuildContext context) {
    final winner = players.first;

    // Opaque enough that white text clears the busiest table state, and it
    // absorbs taps so the board underneath can't be poked while it's up.
    return Container(
      color: Colors.black.withValues(alpha: 0.86),
      child: Center(
        // Scaled to fit rather than scrolled, so short landscape screens still
        // show everything — buttons included — in one view.
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: SizedBox(
              width: 620,
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      flex: 5,
                      child: _Outcome(
                        winner: winner,
                        localWon: localWon,
                        isTie: isTie,
                        record: record,
                        onPlayAgain: onPlayAgain,
                        onMenu: onMenu,
                      ),
                    ),
                    // Wider than a panel would need: with no edges to separate
                    // the columns, the gap is what keeps them apart.
                    const SizedBox(width: AppSpacing.xl * 2),
                    Expanded(
                      flex: 6,
                      child: _Leaderboard(
                        players: players,
                        localSeat: localSeat,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Left column: the headline and the two actions.
class _Outcome extends StatelessWidget {
  /// Empty space held below the buttons, which lifts this column without
  /// moving the standings beside it.
  ///
  /// The two columns are one block, centred as a unit, so nothing can raise
  /// the headline on its own. Growing this column at the bottom grows the
  /// block, and a centred block that grows by 50 rises by 25 — carrying the
  /// headline and buttons up with it while the standings, centred in that
  /// same block, stay exactly on the middle of the screen.
  static const _lift = 50.0;

  final TakePlayer winner;
  final bool localWon;
  final bool isTie;
  final ({AiLevel level, LevelRecord record})? record;
  final VoidCallback onPlayAgain;
  final VoidCallback onMenu;

  const _Outcome({
    required this.winner,
    required this.localWon,
    required this.isTie,
    required this.record,
    required this.onPlayAgain,
    required this.onMenu,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final headline = localWon
        ? (isTie ? l10n.resultsYouTie : l10n.resultsYouWin)
        : l10n.resultsWinner(winner.name);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Carries the composition now that no panel does, so it runs larger
        // than the standard display size.
        Text(
          headline,
          style: AppText.hero.copyWith(
            color: localWon ? AppColors.accent : AppColors.textPrimary,
          ),
        ),
        // Held equally off the headline above and the buttons below: the same
        // minimum gap either side, and an equal share of whatever room is
        // left. It sits in space the Spacer was already holding empty, so the
        // record costs the composition nothing.
        if (record != null) ...[
          const SizedBox(height: AppSpacing.md),
          const Spacer(),
          _RecordLine(
            level: record!.level,
            record: record!.record,
            won: localWon,
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        const Spacer(),
        AppButton.primary(label: l10n.resultsPlayAgain, onTap: onPlayAgain),
        const SizedBox(height: AppSpacing.md),
        AppButton.ghost(label: l10n.gameMenu, onTap: onMenu),
        const SizedBox(height: _lift),
      ],
    );
  }
}

/// Right column: every player ranked best-first.
class _Leaderboard extends StatelessWidget {
  final List<TakePlayer> players;
  final int localSeat;

  const _Leaderboard({required this.players, required this.localSeat});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      // Centred in the column rather than hanging from its top: the outcome
      // beside it is anchored at both ends by the headline and the buttons,
      // and a short list top-aligned against that reads as having slipped.
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(AppLocalizations.of(context)!.resultsStandings,
            style: AppText.label),
        const SizedBox(height: AppSpacing.md),
        for (final (i, p) in players.indexed) ...[
          // With no row fills to separate the entries, spacing does it.
          if (i > 0) const SizedBox(height: AppSpacing.md),
          _LeaderboardRow(
            rank: i + 1,
            player: p,
            isLocal: p.seat == localSeat,
          ),
        ],
      ],
    );
  }
}

/// One standings row: rank, name, and star total, with no container of its
/// own. The top three ranks are marked by medal colour and the winner also by
/// weight; your own name is always accent so you can find yourself at a
/// glance.
class _LeaderboardRow extends StatelessWidget {
  final int rank;
  final TakePlayer player;
  final bool isLocal;

  const _LeaderboardRow({
    required this.rank,
    required this.player,
    required this.isLocal,
  });

  /// Gold, silver, bronze. Anyone below third gets no medal and drops back to
  /// faint — a table of ten seats shouldn't be ten different colours.
  static const _medals = {
    1: AppColors.accent,
    2: AppColors.silver,
    3: AppColors.bronze,
  };

  @override
  Widget build(BuildContext context) {
    final isWinner = rank == 1;

    return Row(
      children: [
        SizedBox(
          width: 22,
          child: Text(
            '$rank',
            textAlign: TextAlign.right,
            style: AppText.statLarge.copyWith(
              color: _medals[rank] ?? AppColors.textFaint,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Text(
            player.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.title.copyWith(
              letterSpacing: 0,
              fontWeight: isWinner ? FontWeight.w700 : FontWeight.w500,
              color: isLocal ? AppColors.accent : AppColors.textPrimary,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        StarCount(
          count: player.totalStars,
          color: AppColors.textPrimary,
          iconColor: AppColors.accent,
          style: AppText.statLarge,
          iconSize: 13,
        ),
      ],
    );
  }
}

/// The lifetime record at the difficulty just played: the level, then wins and
/// losses. The number this game moved is drawn in accent and the other stays
/// faint, because a counter the player doesn't see change is no reason to
/// start another game.
class _RecordLine extends StatelessWidget {
  final AiLevel level;
  final LevelRecord record;
  final bool won;

  const _RecordLine({
    required this.level,
    required this.record,
    required this.won,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    // The words run long in translation — WON/LOST become GANADAS/PERDIDAS —
    // and this column can't grow, so the line shrinks rather than overflowing.
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            difficultyLabel(context, level),
            style: AppText.label.copyWith(color: AppColors.textFaint),
          ),
          const SizedBox(width: AppSpacing.lg),
          _count(record.wins, l10n.profileWon, won),
          const SizedBox(width: AppSpacing.lg),
          _count(record.losses, l10n.profileLost, !won),
        ],
      ),
    );
  }

  /// One count and its word, accent when this is the number that just moved.
  static Widget _count(int value, String label, bool changed) {
    final color = changed ? AppColors.accent : AppColors.textFaint;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text('$value', style: AppText.statLarge.copyWith(color: color)),
        const SizedBox(width: AppSpacing.xs),
        Text(label, style: AppText.caption.copyWith(color: color)),
      ],
    );
  }
}
