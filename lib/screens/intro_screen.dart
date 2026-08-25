import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/take_card.dart';
import '../services/onboarding_service.dart';
import '../services/profile_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_metrics.dart';
import '../theme/app_text.dart';
import '../widgets/app_button.dart';
import '../widgets/card_flight.dart';
import '../widgets/sky_background.dart';
import '../widgets/star_count.dart';
import '../widgets/take_card_widget.dart';
import 'game_screen.dart';

/// The how-to-play slideshow. Six diagram-driven slides — the cards, the
/// table, how a round resolves, the two ways to take a row, and who wins.
///
/// Shown automatically on a fresh install ([isFirstRun] true, ending in PLAY),
/// and on demand from the menu's HOW TO PLAY ([isFirstRun] false, ending in
/// DONE).
class IntroScreen extends StatefulWidget {
  /// True only for the automatic first-launch showing. Dismissing then starts
  /// a game; otherwise it returns to the menu.
  final bool isFirstRun;

  const IntroScreen({super.key, this.isFirstRun = false});

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {
  final PageController _controller = PageController();
  int _page = 0;

  static const _slideCount = 6;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Leaves the tutorial — into a game on first launch, back to the menu
  /// otherwise. Either way the tutorial counts as seen, so skipping it doesn't
  /// bring it back next launch.
  ///
  /// The write isn't awaited: it's fire-and-forget bookkeeping that logs its
  /// own failures, and making the player wait on storage to leave a screen
  /// would be worse than showing the slides again.
  Future<void> _dismiss() async {
    OnboardingService.markIntroSeen();

    if (!widget.isFirstRun) {
      Navigator.pop(context);
      return;
    }

    // First run hands straight into a game without passing the menu, so the
    // name has to be read here too. It'll be the default unless the player
    // somehow set one already, but reading beats hardcoding it a second time.
    final name = await ProfileService.read();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => GameScreen(playerCount: 5, playerName: name),
      ),
    );
  }

  void _next() {
    if (_page >= _slideCount - 1) {
      _dismiss();
    } else {
      _controller.nextPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _page == _slideCount - 1;
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppColors.backdrop,
      body: Stack(
        children: [
          const Positioned.fill(child: SkyBackground()),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(40, AppSpacing.sm, 40, AppSpacing.md),
              child: Column(
                children: [
                  // Top bar: skip out early. Hidden on the last slide, where
                  // the primary button already says how to leave.
                  SizedBox(
                    height: 32,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: AnimatedOpacity(
                        opacity: isLast ? 0 : 1,
                        duration: const Duration(milliseconds: 200),
                        child: TextButton(
                          onPressed: isLast ? null : _dismiss,
                          child: Text(
                            widget.isFirstRun ? l10n.introSkip : l10n.introClose,
                            style: AppText.caption,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Slides.
                  Expanded(
                    child: PageView(
                      controller: _controller,
                      onPageChanged: (i) => setState(() => _page = i),
                      children: const [
                        _ObjectiveSlide(),
                        _TableSlide(),
                        _GameplaySlide(),
                        _CatchSlide(),
                        _TooLowSlide(),
                        _WinnerSlide(),
                      ],
                    ),
                  ),
                  // Bottom bar: dots + primary button.
                  SizedBox(
                    height: 56,
                    child: Stack(
                      children: [
                        Align(
                          alignment: Alignment.center,
                          child: _Dots(count: _slideCount, active: _page),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: SizedBox(
                            width: isLast ? 200 : 130,
                            child: AppButton.primary(
                              label: isLast
                                  ? (widget.isFirstRun
                                      ? l10n.menuPlay
                                      : l10n.introDone)
                                  : l10n.introNext,
                              onTap: _next,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════
// SLIDE SCAFFOLD
// ═══════════════════════════════════════════

/// Common layout for a slide: text block on the left, diagram on the right.
class _SlideLayout extends StatelessWidget {
  final String? eyebrow;
  final String title;
  final String body;
  final Widget diagram;

  const _SlideLayout({
    this.eyebrow,
    required this.title,
    required this.body,
    required this.diagram,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // The text is laid out at a fixed design width, then scaled down to fit
        // like the diagram beside it. Short landscape phones (iPhone SE, ~375
        // tall) don't have room for the block at full size, and a fixed flex
        // ratio only papers over one screen height — scale-to-fit covers them
        // all without a magic number per device.
        Expanded(
          flex: 5,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: SizedBox(
              width: 340,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (eyebrow != null) ...[
                    Text(
                      eyebrow!,
                      style: AppText.label,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                  Text(
                    title,
                    style: AppText.display,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text.rich(_highlight(body, AppText.body)),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.xl),
        Expanded(
          flex: 5,
          child: Center(
            child: FittedBox(fit: BoxFit.scaleDown, child: diagram),
          ),
        ),
      ],
    );
  }
}

/// Paints the `*marked*` runs of a translated line in the accent yellow, so the
/// words for stars and penalty points match the yellow stars in the diagram
/// beside them. An unclosed marker just leaves the rest of the line unpainted.
TextSpan _highlight(String text, TextStyle style) {
  return TextSpan(
    style: style,
    children: [
      for (final (i, part) in text.split('*').indexed)
        TextSpan(
          text: part,
          style: i.isOdd ? const TextStyle(color: AppColors.accent) : null,
        ),
    ],
  );
}

// ═══════════════════════════════════════════
// SLIDE 1 — THE CARDS / HOW THEY SCORE
// ═══════════════════════════════════════════

class _ObjectiveSlide extends StatelessWidget {
  const _ObjectiveSlide();

  // Representative card for each star tier, so the range of penalties is
  // visible at a glance rather than described in the copy.
  static const _examples = [3, 5, 10, 11, 55];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return _SlideLayout(
      eyebrow: l10n.introCardsEyebrow,
      title: l10n.introCardsTitle,
      body: l10n.introCardsBody,
      diagram: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _DiagramCaption(l10n.introCardsNumberRange),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final n in _examples)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                  child: _CardWithStars(TakeCard.fromNumber(n)),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          _DiagramCaption(l10n.introCardsPenaltyStars),
        ],
      ),
    );
  }
}

/// A game card with its star value shown beneath it.
class _CardWithStars extends StatelessWidget {
  final TakeCard card;

  const _CardWithStars(this.card);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TakeCardWidget(card: card, width: 50, height: 74),
        const SizedBox(height: AppSpacing.sm),
        _StarBadge(card.stars),
      ],
    );
  }
}

// ═══════════════════════════════════════════
// SLIDE 2 — THE TABLE
// ═══════════════════════════════════════════

/// Explains the board before any rule about playing onto it: one row, seeded
/// with a random card, four empty spaces waiting behind it.
///
/// Only one row is drawn — all four are identical at this point, and the copy
/// already says there are four. The gameplay slide shows the full board.
class _TableSlide extends StatelessWidget {
  const _TableSlide();

  // The first of the gameplay slide's four starters, so the board stays
  // recognisable from one slide to the next.
  static const _starter = 6;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return _SlideLayout(
      eyebrow: l10n.introTableEyebrow,
      title: l10n.introTableTitle,
      body: l10n.introTableBody,
      diagram: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _DiagramRow(
            tops: [_starter],
            emptySlots: 4,
            cardWidth: _DiagramRow.loneWidth,
            cardHeight: _DiagramRow.loneHeight,
          ),
          const SizedBox(height: AppSpacing.md),
          _DiagramCaption(l10n.introTableCaption),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════
// SLIDE 3 — PLAYING A ROUND
// ═══════════════════════════════════════════

/// Plays a round on a loop: three cards revealed together, then placed one at a
/// time from lowest to highest. Watching the order happen explains it better
/// than a sentence about it does.
///
/// All three land in the same row, drawn at the table slide's size. Spreading
/// them across four rows showed the same ordering rule at a quarter the size,
/// and this leaves the row one short of full for the slide that follows.
class _GameplaySlide extends StatelessWidget {
  const _GameplaySlide();

  static const _rowStart = 6;
  static const _revealed = [12, 37, 62]; // already in resolve order

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return _SlideLayout(
      eyebrow: l10n.introRoundEyebrow,
      title: l10n.introRoundTitle,
      body: l10n.introRoundBody,
      diagram: _Steps(
        // One step to reveal, one per card, one to hold the finished board.
        count: _revealed.length + 2,
        builder: (step) {
          final placed = step.clamp(0, _revealed.length);
          final active = (step >= 1 && step <= _revealed.length) ? step - 1 : null;
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // The row always draws its full five slots, so it doesn't resize
              // as cards arrive — the empties shrink instead.
              _DiagramRow(
                tops: [_rowStart, ..._revealed.take(placed)],
                emptySlots: _revealed.length + 1 - placed,
                highlight: active != null,
                cardWidth: _DiagramRow.loneWidth,
                cardHeight: _DiagramRow.loneHeight,
              ),
              const SizedBox(height: AppSpacing.md),
              _DiagramCaption(l10n.introRoundCaption),
              const SizedBox(height: AppSpacing.sm),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (int i = 0; i < _revealed.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.sm),
                      child: TakeCardWidget(
                        card: TakeCard.fromNumber(_revealed[i]),
                        width: 34,
                        height: 50,
                        highlighted: i == active,
                        dimmed: i < placed,
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

/// One row of the board: its cards, plus any empty spaces left in it.
class _DiagramRow extends StatelessWidget {
  final List<int> tops;
  final bool highlight;
  final bool danger;
  final int emptySlots;

  /// Card size. Defaults to the size a stack of four rows can afford; a slide
  /// showing one row on its own passes [loneWidth]/[loneHeight] instead, since
  /// a FittedBox only ever scales down.
  final double cardWidth;
  final double cardHeight;

  /// Card size for a slide that draws a single row.
  static const loneWidth = 52.0;
  static const loneHeight = 76.0;

  static const _gap = 3.0;
  static const _border = 1.2;
  static const _insetX = AppSpacing.sm + _border;
  static const _insetY = AppSpacing.xs + _border;

  /// Where slot [i] sits relative to the row's own top-left corner, and how big
  /// a row of [slots] ends up. The take animation flies cards out of a row this
  /// widget drew, so the two have to agree on where the slots are.
  static Rect slotRect(int i, double w, double h) =>
      Rect.fromLTWH(_insetX + i * (w + _gap), _insetY, w, h);

  static Size sizeFor(int slots, double w, double h) =>
      Size(2 * _insetX + slots * (w + _gap), 2 * _insetY + h);

  const _DiagramRow({
    required this.tops,
    this.highlight = false,
    this.danger = false,
    this.emptySlots = 0,
    this.cardWidth = 34,
    this.cardHeight = 50,
  });

  @override
  Widget build(BuildContext context) {
    // danger wins over highlight: a row being taken reads as a cost, not as the
    // one the player wants.
    final tint = danger
        ? AppColors.danger
        : highlight
            ? AppColors.accent
            : null;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: tint?.withValues(alpha: 0.2) ?? Colors.black.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(AppRadius.surface),
        border: Border.all(
          color: tint ?? AppColors.mist.withValues(alpha: 0.3),
          width: _border,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final n in tops)
            Padding(
              padding: const EdgeInsets.only(right: _gap),
              child: TakeCardWidget(card: TakeCard.fromNumber(n), width: cardWidth, height: cardHeight),
            ),
          for (int i = 0; i < emptySlots; i++)
            Padding(
              padding: const EdgeInsets.only(right: _gap),
              child: Container(
                width: cardWidth,
                height: cardHeight,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  border: Border.all(
                    color: AppColors.mist.withValues(alpha: 0.25),
                    width: 1,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════
// SLIDES 4 & 5 — THE TWO WAYS TO TAKE A ROW
// ═══════════════════════════════════════════

/// The two "you take a row" slides. Both run the same loop on a single row,
/// driven by the game's own [TakePile]: the row's cards sweep into a stack at
/// slot 0, fly to the taker fading out, and [incoming] is left starting the row
/// over — the beats a real take plays.
///
/// Only the cards and the copy differ between them, so they share this rather
/// than keeping two copies of the animation.
class _TakeSlide extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String body;
  final String Function(int count) badge;

  /// The row being taken, and the card whose arrival takes it.
  final List<int> rowCards;
  final int incoming;

  const _TakeSlide({
    required this.eyebrow,
    required this.title,
    required this.body,
    required this.badge,
    required this.rowCards,
    required this.incoming,
  });

  static const _w = _DiagramRow.loneWidth;
  static const _h = _DiagramRow.loneHeight;

  /// A row's capacity. Both slides draw all five slots, full or not, so the two
  /// diagrams are the same size.
  static const _slots = 5;

  static final _rowSize = _DiagramRow.sizeFor(_slots, _w, _h);
  static final _lowerTop = _rowSize.height + AppSpacing.xl;

  /// Where the pile lands. Card-shaped rather than pill-shaped so the cards
  /// shrink into the badge instead of squashing, and inset from the right edge
  /// so it stays inside the badge whatever the translated label measures.
  static final _target =
      Rect.fromLTWH(_rowSize.width - 90, _lowerTop + 12, 30, 44);

  @override
  Widget build(BuildContext context) {
    final stars = rowCards
        .map((n) => TakeCard.fromNumber(n).stars)
        .reduce((a, b) => a + b);

    return _SlideLayout(
      eyebrow: eyebrow,
      title: title,
      body: body,
      diagram: _Steps(
        count: 4,
        builder: (step) {
          // 0 holds the row with the card that can't go anywhere else, 1 flies
          // the pile out, 2–3 hold the restarted row and the stars it cost.
          final taking = step == 1;
          final restarted = step >= 2;
          final tops = restarted
              ? [incoming]
              : (taking ? const <int>[] : rowCards);
          return SizedBox(
            width: _rowSize.width,
            height: _lowerTop + _h,
            child: Stack(
              children: [
                Positioned(
                  left: 0,
                  top: 0,
                  child: _DiagramRow(
                    // Emptied while the pile is in flight, exactly as the real
                    // table hides the row it's taking.
                    tops: tops,
                    emptySlots: _slots - tops.length,
                    danger: step == 0,
                    highlight: restarted,
                    cardWidth: _w,
                    cardHeight: _h,
                  ),
                ),
                if (taking)
                  Positioned.fill(
                    child: TakePile(
                      cards: [for (final n in rowCards) TakeCard.fromNumber(n)],
                      fromRects: [
                        for (var i = 0; i < rowCards.length; i++)
                          _DiagramRow.slotRect(i, _w, _h),
                      ],
                      pileRect: _DiagramRow.slotRect(0, _w, _h),
                      sidebarRect: _target,
                      duration: _Steps.interval,
                    ),
                  ),
                // The incoming card, waiting below until it lands in the row.
                Positioned(
                  left: 0,
                  top: _lowerTop,
                  child: AnimatedOpacity(
                    opacity: restarted ? 0 : 1,
                    duration: const Duration(milliseconds: 250),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _CardOutline(
                          color: AppColors.danger,
                          child: TakeCardWidget(
                            card: TakeCard.fromNumber(incoming),
                            width: _w,
                            height: _h,
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.only(left: AppSpacing.sm),
                          child: Icon(Icons.close_rounded,
                              color: AppColors.danger, size: 20),
                        ),
                      ],
                    ),
                  ),
                ),
                // The taker: dim until the stars actually arrive.
                Positioned(
                  right: 0,
                  top: _lowerTop + AppSpacing.md,
                  child: AnimatedOpacity(
                    opacity: restarted ? 1 : 0.35,
                    duration: const Duration(milliseconds: 250),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.sm,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.danger.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        border: Border.all(color: AppColors.danger, width: 1.2),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(badge(rowCards.length),
                              style: AppText.buttonSmall),
                          const SizedBox(width: AppSpacing.sm),
                          _StarBadge(stars),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Penalty 1 of 2: a full row, and the sixth card that takes it.
class _CatchSlide extends StatelessWidget {
  const _CatchSlide();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return _TakeSlide(
      eyebrow: l10n.introSixthEyebrow,
      title: l10n.introSixthTitle,
      body: l10n.introSixthBody,
      badge: l10n.introTakeBadge,
      rowCards: const [4, 17, 23, 38, 46], // five 1-star cards, row is full
      incoming: 51,
    );
  }
}

/// Penalty 2 of 2: a card lower than the row's last card, which has nowhere to
/// go. The row it takes is the player's pick — shown here already made.
class _TooLowSlide extends StatelessWidget {
  const _TooLowSlide();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return _TakeSlide(
      eyebrow: l10n.introTooLowEyebrow,
      title: l10n.introTooLowTitle,
      body: l10n.introTooLowBody,
      badge: l10n.introTakeBadge,
      rowCards: const [6, 9, 14], // three 1-star cards, room to spare
      incoming: 3,
    );
  }
}

// ═══════════════════════════════════════════
// SLIDE 6 — WHO WINS
// ═══════════════════════════════════════════

/// Ends on the scoreboard, so the last thing a new player sees is what they're
/// actually playing for.
class _WinnerSlide extends StatelessWidget {
  const _WinnerSlide();

  // Sorted low to high — the winning line is the first one, as on the real
  // scoreboard.
  static const _scores = [14, 22, 31, 47];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // Built here rather than held as a constant: every name on this scoreboard
    // is translated, including the AI seats.
    final lines = [
      (l10n.introWinnerYou, _scores[0]),
      for (var i = 1; i < _scores.length; i++) (l10n.gameAiName(i), _scores[i]),
    ];
    return _SlideLayout(
      eyebrow: l10n.introWinnerEyebrow,
      title: l10n.introWinnerTitle,
      body: l10n.introWinnerBody,
      diagram: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (i, (name, stars)) in lines.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _ScoreLine(name: name, stars: stars, winner: i == 0),
            ),
        ],
      ),
    );
  }
}

/// One line of the example scoreboard: a name, its star total, and a crown on
/// the winning line.
class _ScoreLine extends StatelessWidget {
  final String name;
  final int stars;
  final bool winner;

  const _ScoreLine({
    required this.name,
    required this.stars,
    required this.winner,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 210,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: winner
            ? AppColors.accent.withValues(alpha: 0.2)
            : Colors.black.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(AppRadius.surface),
        border: Border.all(
          color: winner ? AppColors.accent : AppColors.mist.withValues(alpha: 0.3),
          width: 1.2,
        ),
      ),
      child: Row(
        children: [
          if (winner) ...[
            const Icon(Icons.emoji_events_rounded,
                color: AppColors.accent, size: 18),
            const SizedBox(width: AppSpacing.sm),
          ],
          Expanded(child: Text(name, style: AppText.buttonSmall)),
          _StarBadge(stars),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════
// SHARED PIECES
// ═══════════════════════════════════════════

/// Loops a slide through a short numbered sequence, one step per tick, so the
/// animated slides don't each need their own clock.
class _Steps extends StatefulWidget {
  final int count;
  final Widget Function(int step) builder;

  static const interval = Duration(milliseconds: 1400);

  const _Steps({required this.count, required this.builder});

  @override
  State<_Steps> createState() => _StepsState();
}

class _StepsState extends State<_Steps> {
  Timer? _timer;
  int _step = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(_Steps.interval, (_) {
      if (!mounted) return;
      setState(() => _step = (_step + 1) % widget.count);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(_step);
}

/// A small uppercase label naming part of a diagram.
class _DiagramCaption extends StatelessWidget {
  final String text;

  const _DiagramCaption(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text, style: AppText.label);
  }
}

/// A pill showing a star count, e.g. "3 ★".
class _StarBadge extends StatelessWidget {
  final int count;

  const _StarBadge(this.count);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.4), width: 1),
      ),
      child: StarCount(
        count: count,
        color: Colors.white,
        iconColor: AppColors.accent,
        gap: 4,
      ),
    );
  }
}

/// A hairline outline framing an incoming/highlighted card.
class _CardOutline extends StatelessWidget {
  final Widget child;
  final Color color;

  const _CardOutline({required this.child, this.color = AppColors.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.card + 3),
        border: Border.all(color: color, width: 1.4),
      ),
      child: child,
    );
  }
}

class _Dots extends StatelessWidget {
  final int count;
  final int active;

  const _Dots({required this.count, required this.active});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            width: i == active ? 22 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: i == active ? AppColors.accent : AppColors.textSecondary.withValues(alpha: 0.33),
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
          ),
      ],
    );
  }
}
