import 'package:flutter/material.dart';
import '../models/take_card.dart';
import 'take_card_widget.dart';

/// Overlay animations for cards moving around the table. Both are inserted
/// into the Overlay by GameScreen and removed when their run finishes.
class FlyingCard extends StatefulWidget {
  final TakeCard card;
  final Rect from;
  final Rect to;
  final Duration duration;

  const FlyingCard({
    super.key,
    required this.card,
    required this.from,
    required this.to,
    required this.duration,
  });

  @override
  State<FlyingCard> createState() => _FlyingCardState();
}

class _FlyingCardState extends State<FlyingCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: widget.duration)..forward();
  late final Animation<Rect?> _rect = RectTween(
    begin: widget.from,
    end: widget.to,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _rect,
      builder: (context, _) {
        // Tweening the whole rect scales the card as it travels; the number
        // font tracks width inside TakeCardWidget, so it scales for free.
        final r = _rect.value!;
        return Positioned.fromRect(
          rect: r,
          child: TakeCardWidget(
            card: widget.card,
            width: r.width,
            height: r.height,
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════
// TAKE PILE (row cards → consolidate → fly to taker, in an Overlay)
// ═══════════════════════════════════════════

class TakePile extends StatefulWidget {
  /// Fraction of the run spent gathering the cards into a stack before the
  /// whole pile flies to the taker. Kept small so most of the run is the
  /// flight to the sidebar, where the penalty is registering.
  ///
  /// Public because the riffle sound has to land over the gather, not the
  /// flight — [Sfx.rowGather] spreads its five hits across this same window.
  static const gatherFraction = 0.35;

  final List<TakeCard> cards;
  final List<Rect> fromRects; // each card's current row-slot rect
  final Rect pileRect; // where the cards stack up (slot 0)
  final Rect sidebarRect; // the taker's sidebar card slot
  final Duration duration;

  const TakePile({
    super.key,
    required this.cards,
    required this.fromRects,
    required this.pileRect,
    required this.sidebarRect,
    required this.duration,
  });

  @override
  State<TakePile> createState() => _TakePileState();
}

class _TakePileState extends State<TakePile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: widget.duration)..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // Small per-card offset so the gathered cards read as a stack, not one card.
  Offset _stackOffset(int i) => Offset(i * 1.5, -i * 1.5);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        return Stack(
          children: [
            for (var i = 0; i < widget.cards.length; i++) _card(i, t),
          ],
        );
      },
    );
  }

  Widget _card(int i, double t) {
    final stacked = widget.pileRect.shift(_stackOffset(i));
    Rect rect;
    double opacity = 1;
    if (t <= TakePile.gatherFraction) {
      final p = Curves.easeOut.transform(t / TakePile.gatherFraction);
      rect = Rect.lerp(widget.fromRects[i], stacked, p)!;
    } else {
      final p = Curves.easeIn.transform((t - TakePile.gatherFraction) / (1 - TakePile.gatherFraction));
      rect = Rect.lerp(stacked, widget.sidebarRect, p)!;
      opacity = 1 - p; // fade out as it reaches the taker
    }
    return Positioned.fromRect(
      rect: rect,
      child: Opacity(
        opacity: opacity.clamp(0.0, 1.0),
        child: TakeCardWidget(
          card: widget.cards[i],
          width: rect.width,
          height: rect.height,
        ),
      ),
    );
  }
}
