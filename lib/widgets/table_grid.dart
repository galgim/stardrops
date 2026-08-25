import 'package:flutter/material.dart';
import '../models/game_row.dart';
import '../theme/app_colors.dart';
import '../theme/app_metrics.dart';
import '../theme/app_text.dart';
import 'star_count.dart';
import 'take_card_widget.dart';

/// The four table rows, laid out 2x2.
class TableGrid extends StatelessWidget {
  final List<GameRow> rows;
  final int? lastAffectedRow;
  final bool lastWasTake;
  final bool choosingRow;
  final void Function(int) onPickRow;
  final List<List<GlobalKey>> slotKeys;
  final int? hiddenRow;

  const TableGrid({
    super.key,
    required this.rows,
    required this.lastAffectedRow,
    required this.lastWasTake,
    required this.choosingRow,
    required this.onPickRow,
    required this.slotKeys,
    required this.hiddenRow,
  });

  Widget _cell(int i, Alignment alignment) {
    final isAffected = lastAffectedRow == i;
    return GestureDetector(
      onTap: choosingRow ? () => onPickRow(i) : null,
      child: LayoutBuilder(
        builder: (context, constraints) {
          const starsW = 30.0;
          const hPad = 8.0;
          const cardGap = 1.5;
          const vPad = 6.0;
          const aspect = 50.0 / 70.0;
          const safetyMargin = 6.0;
          const maxCardW = 50.0;

          final overhead = starsW + hPad + cardGap * 4 + safetyMargin;
          final maxCardWByWidth = (constraints.maxWidth - overhead) / 5;
          final maxCardHByHeight = constraints.maxHeight - vPad;
          final maxCardWByHeight = maxCardHByHeight * aspect;
          var cardW = maxCardWByWidth < maxCardWByHeight ? maxCardWByWidth : maxCardWByHeight;
          if (cardW > maxCardW) cardW = maxCardW;
          final cardH = cardW / aspect;

          return Align(
            alignment: alignment,
            child: _GameRowWidget(
              row: rows[i],
              isAffected: isAffected,
              wasTake: isAffected && lastWasTake,
              choosingRow: choosingRow,
              cardW: cardW < 0 ? 0 : cardW,
              cardH: cardH < 0 ? 0 : cardH,
              slotKeys: slotKeys[i],
              hideCards: hiddenRow == i,
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _cell(0, Alignment.bottomCenter)),
              const SizedBox(width: 3),
              Expanded(child: _cell(1, Alignment.bottomCenter)),
            ],
          ),
        ),
        const SizedBox(height: 3),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _cell(2, Alignment.topCenter)),
              const SizedBox(width: 3),
              Expanded(child: _cell(3, Alignment.topCenter)),
            ],
          ),
        ),
      ],
    );
  }
}

class _GameRowWidget extends StatelessWidget {
  final GameRow row;
  final bool isAffected;
  final bool wasTake;
  final bool choosingRow;
  final double cardW;
  final double cardH;
  final List<GlobalKey> slotKeys;
  final bool hideCards; // cards flying to the taker are drawn in the overlay

  const _GameRowWidget({
    required this.row,
    required this.isAffected,
    required this.wasTake,
    required this.choosingRow,
    required this.cardW,
    required this.cardH,
    required this.slotKeys,
    required this.hideCards,
  });

  @override
  Widget build(BuildContext context) {
    Color borderColor;
    Color bgColor;
    if (choosingRow) {
      borderColor = AppColors.accent;
      bgColor = AppColors.accent.withValues(alpha: 0.15);
    } else if (wasTake) {
      borderColor = AppColors.penalty;
      bgColor = AppColors.penalty.withValues(alpha: 0.15);
    } else if (isAffected) {
      borderColor = AppColors.mist;
      bgColor = Colors.white.withValues(alpha: 0.08);
    } else {
      borderColor = Colors.white.withValues(alpha: 0.15);
      bgColor = Colors.white.withValues(alpha: 0.05);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppRadius.surface),
        border: Border.all(color: borderColor, width: choosingRow || isAffected ? 2 : 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(5, (slot) {
              final padRight = slot < 4 ? 1.5 : 0.0;
              if (slot < row.cards.length && !hideCards) {
                return Padding(
                  padding: EdgeInsets.only(right: padRight),
                  child: TakeCardWidget(
                    key: slotKeys[slot],
                    card: row.cards[slot],
                    width: cardW,
                    height: cardH,
                  ),
                );
              } else {
                return Padding(
                  padding: EdgeInsets.only(right: padRight),
                  child: Container(
                    key: slotKeys[slot],
                    width: cardW,
                    height: cardH,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadius.card),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1),
                        width: 1,
                      ),
                    ),
                  ),
                );
              }
            }),
          ),
          const SizedBox(width: 2),
          SizedBox(
            width: 30,
            child: Align(
              alignment: Alignment.centerRight,
              child: StarCount(
                count: row.totalStars,
                color: row.isFull
                    ? AppColors.penalty
                    : Colors.white.withValues(alpha: 0.55),
                style: AppText.statSmall,
                iconSize: 8,
                gap: 2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
