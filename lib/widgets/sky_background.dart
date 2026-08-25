import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/app_colors.dart';

/// The app's shared backdrop: the navy artwork, soft colour blooms over it, and
/// optionally a slow field of twinkling stars.
///
/// Drop it in as the first child of a screen's Stack:
/// `const Positioned.fill(child: SkyBackground())`.
///
/// The artwork and blooms sit in one RepaintBoundary so screen rebuilds (and the
/// twinkle animation above them) never drag the full-screen SVG into the repaint
/// path. Both are static, so that boundary is painted once.
class SkyBackground extends StatelessWidget {
  /// Whether to animate stars over the artwork. Off on the game table, where
  /// nothing should compete with the cards for attention.
  final bool twinkle;

  const SkyBackground({super.key, this.twinkle = true});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: RepaintBoundary(
            child: Stack(
              children: [
                Positioned.fill(
                  child: SvgPicture.asset(
                    'assets/Group 1.svg',
                    fit: BoxFit.cover,
                  ),
                ),
                const Positioned.fill(child: _Nebula()),
              ],
            ),
          ),
        ),
        if (twinkle) const Positioned.fill(child: _TwinkleStars()),
      ],
    );
  }
}

/// Wide, soft colour blooms over the artwork.
///
/// These exist to give the glass controls something to sit on. A translucent
/// pane over a flat field has no variation to pick up, so the buttons read as
/// grey boxes however carefully they're lit — the fix is behind them, not in
/// them.
///
/// Kept to the existing palette and to low alpha: the blooms are lighting, not
/// scenery, and nothing here may compete with the cards. They're also arranged
/// to light from the top-left, which is the same direction the buttons' rim and
/// fill gradients assume, so the whole screen agrees about where the light is.
class _Nebula extends StatelessWidget {
  const _Nebula();

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(
      child: Stack(
        children: [
          // The light itself, high on the left.
          _Bloom(
            center: Alignment(-0.7, -0.9),
            radius: 1.25,
            color: AppColors.mist,
            alpha: 0.20,
          ),
          // A cooler, dimmer bloom through the middle-right, so the field
          // doesn't fall straight from lit to unlit.
          _Bloom(
            center: Alignment(0.85, -0.1),
            radius: 0.95,
            color: AppColors.textFaint,
            alpha: 0.16,
          ),
          // Shade opposite the light, which deepens the bottom-right corner and
          // keeps the diagonal reading as a direction rather than a smear.
          _Bloom(
            center: Alignment(0.8, 1.0),
            radius: 1.3,
            color: AppColors.ink,
            alpha: 0.45,
          ),
        ],
      ),
    );
  }
}

/// One radial falloff from [color] at [alpha] to fully transparent.
class _Bloom extends StatelessWidget {
  final Alignment center;

  /// In units of the shorter screen edge. Above ~1.0 the bloom runs off screen,
  /// which is what keeps it reading as ambient light rather than as a circle.
  final double radius;

  final Color color;
  final double alpha;

  const _Bloom({
    required this.center,
    required this.radius,
    required this.color,
    required this.alpha,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: center,
            radius: radius,
            colors: [
              color.withValues(alpha: alpha),
              color.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }
}

/// A fixed set of stars fading in and out on independent cycles.
class _TwinkleStars extends StatefulWidget {
  const _TwinkleStars();

  @override
  State<_TwinkleStars> createState() => _TwinkleStarsState();
}

class _TwinkleStarsState extends State<_TwinkleStars>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_Star> _stars;

  @override
  void initState() {
    super.initState();
    // Seeded, so the layout is identical on every launch and screen.
    final rng = math.Random(7);
    _stars = List.generate(26, (_) {
      return _Star(
        dx: rng.nextDouble(),
        dy: rng.nextDouble(),
        radius: 0.6 + rng.nextDouble() * 1.8,
        phase: rng.nextDouble(),
        speed: 0.6 + rng.nextDouble() * 0.8,
      );
    });
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            painter: _TwinklePainter(_stars, _controller.value),
            size: Size.infinite,
          );
        },
      ),
    );
  }
}

class _Star {
  final double dx;
  final double dy;
  final double radius;
  final double phase;
  final double speed;

  const _Star({
    required this.dx,
    required this.dy,
    required this.radius,
    required this.phase,
    required this.speed,
  });
}

class _TwinklePainter extends CustomPainter {
  final List<_Star> stars;
  final double t;

  _TwinklePainter(this.stars, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white;
    for (final s in stars) {
      final cycle = (t * s.speed + s.phase) % 1.0;
      final glow = 0.4 - 0.3 * math.cos(cycle * 2 * math.pi);
      paint.color = Colors.white.withValues(alpha: glow.clamp(0.05, 0.7));
      canvas.drawCircle(
        Offset(s.dx * size.width, s.dy * size.height),
        s.radius,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_TwinklePainter old) => old.t != t;
}
