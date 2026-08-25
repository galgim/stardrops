import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/sfx.dart';
import '../theme/app_colors.dart';
import '../theme/app_metrics.dart';

/// A pane of glass. The app's one surface material, and the only thing that
/// draws a background.
///
/// The glass is built from three things, in the order that matters:
///
/// 1. A **rim light** — a hairline that's bright at the top-left and fades to
///    almost nothing at the bottom-right. This is what makes a translucent
///    rectangle read as a pane of glass rather than a grey box, and it's the
///    detail the reference style hangs on.
/// 2. A **frosted fill** — enough to genuinely lift what's behind it.
/// 3. A **wide soft shadow**, which sets the pane off the backdrop.
///
/// Light comes from the top-left throughout, so the rim and the fill gradient
/// agree with each other.
///
/// This is the look on its own, with no interaction — the dialogs use it, and
/// they are surfaces rather than controls. [GlassPane] wraps it for things you
/// press. The two were one class until dialogs needed the look without the
/// press response, and a null onTap draws the *disabled* look instead.
class GlassSurface extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  /// The base colour. The fill gradient derives its highlight and shading from
  /// this, so translucent tints and opaque fills both light correctly.
  final Color fill;

  /// Whether [fill] is a tint applied at glass alpha, or painted as given.
  ///
  /// Opaque panes get no rim. A rim on a solid fill reads as an outline, not as
  /// an edge catching the light — the reference's solid CTA has none either.
  final bool translucent;

  /// How strong the frost is, overriding [restAlpha].
  ///
  /// The default was tuned on buttons — pills a couple of centimetres across,
  /// where 22% reads as material rather than as a tint. A dialog needs far
  /// more than that: it lands on top of a table full of cards, and at button
  /// strength the board reads straight through the text.
  final double? fillAlpha;

  /// Tint of the outer shadow — gold under the yellow primary so it reads as a
  /// glow, black under glass so the pane lifts off the backdrop.
  final Color shadowColor;

  /// Full pill by default, which rounds anything in this app completely.
  final double radius;

  /// Pressed and disabled looks. Driven by [GlassPane]; a plain surface is
  /// neither.
  final bool pressed;
  final bool enabled;

  /// Frost strength at rest and under the thumb.
  static const restAlpha = 0.22;
  static const pressedAlpha = 0.32;

  /// Rim thickness. Any thicker and it stops being a catch of light and starts
  /// being a border.
  static const rimWidth = 1.2;

  /// Short enough to feel like a consequence of the touch rather than an
  /// animation playing afterwards.
  static const duration = Duration(milliseconds: 90);

  const GlassSurface({
    super.key,
    required this.child,
    required this.padding,
    this.fill = AppColors.textPrimary,
    this.translucent = true,
    this.fillAlpha,
    this.shadowColor = Colors.black,
    this.radius = AppRadius.pill,
    this.pressed = false,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final corners = BorderRadius.circular(radius);

    // Disabled stays inside the glass family rather than turning grey — a
    // greyed-out slab on a navy screen reads as a rendering bug more than as an
    // unavailable control.
    final Color base;
    if (!enabled) {
      base = AppColors.textPrimary.withValues(alpha: 0.06);
    } else if (translucent) {
      base = fill.withValues(
        alpha: pressed ? pressedAlpha : (fillAlpha ?? restAlpha),
      );
    } else {
      base = fill;
    }

    // The frost. Diagonal rather than vertical, so it agrees with the rim about
    // where the light is coming from. The shadow is wide and soft at rest, tight
    // and close on press, as though the pane were pushed toward the backdrop.
    Widget pane = AnimatedContainer(
      duration: duration,
      curve: Curves.easeOut,
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: corners,
        boxShadow: enabled
            ? [
                BoxShadow(
                  color: shadowColor.withValues(alpha: pressed ? 0.20 : 0.30),
                  blurRadius: pressed ? 10 : 24,
                  offset: Offset(0, pressed ? 2 : 8),
                  spreadRadius: -4,
                ),
              ]
            : null,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(base, Colors.white, 0.12)!,
            base,
            Color.lerp(base, Colors.black, 0.08)!,
          ],
          stops: const [0.0, 0.55, 1.0],
        ),
      ),
      child: child,
    );

    // The rim goes over the frost, stroked rather than layered behind it: the
    // frost is translucent, so a rim painted underneath would bleed through the
    // whole pane as a diagonal wash instead of reading as an edge.
    if (enabled && translucent) {
      pane = CustomPaint(
        foregroundPainter: _RimPainter(radius: corners, width: rimWidth),
        child: pane,
      );
    }

    return pane;
  }
}

/// A [GlassSurface] you can press, and the app's one press response.
///
/// The press response is load-bearing rather than decoration — the tap sound is
/// tactile, and a control that makes a physical noise while staying perfectly
/// still reads as broken. On press the pane shrinks, the frost brightens, and
/// the shadow pulls in tight, as though it were pushed toward the backdrop.
///
/// Everything tappable that isn't a playing card should go through here, so the
/// whole app answers touch the same way.
class GlassPane extends StatefulWidget {
  final Widget child;

  /// Null disables the pane: it dims, drops its rim and shadow, and ignores
  /// touch.
  final VoidCallback? onTap;

  final Color fill;
  final bool translucent;
  final double? fillAlpha;
  final Color shadowColor;
  final EdgeInsetsGeometry padding;

  const GlassPane({
    super.key,
    required this.child,
    required this.padding,
    this.onTap,
    this.fill = AppColors.textPrimary,
    this.translucent = true,
    this.fillAlpha,
    this.shadowColor = Colors.black,
  });

  @override
  State<GlassPane> createState() => _GlassPaneState();
}

class _GlassPaneState extends State<GlassPane> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  /// Sound, then the haptic tick, then the callback.
  void _handleTap() {
    Sfx.tap();
    // Haptics go through a platform channel and are missing on some devices and
    // on the simulator. A failure there must not swallow the actual tap.
    HapticFeedback.lightImpact().catchError(
      (Object e) => debugPrint('GlassPane: haptic failed — $e'),
    );
    widget.onTap!();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;

    return GestureDetector(
      // Stays null when disabled, so a disabled pane doesn't swallow taps aimed
      // past it or feel tappable.
      onTap: enabled ? _handleTap : null,
      onTapDown: enabled ? (_) => _setPressed(true) : null,
      onTapUp: enabled ? (_) => _setPressed(false) : null,
      onTapCancel: enabled ? () => _setPressed(false) : null,
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: GlassSurface.duration,
        curve: Curves.easeOut,
        child: GlassSurface(
          padding: widget.padding,
          fill: widget.fill,
          translucent: widget.translucent,
          fillAlpha: widget.fillAlpha,
          shadowColor: widget.shadowColor,
          pressed: _pressed,
          enabled: enabled,
          child: widget.child,
        ),
      ),
    );
  }
}

/// Strokes a pane's outline with a gradient that runs bright at the top-left and
/// fades to almost nothing at the bottom-right — the edge catching the light.
///
/// This exists because a `BoxDecoration` border can only be one flat colour, and
/// a flat outline reads as a border rather than as glass.
class _RimPainter extends CustomPainter {
  final BorderRadius radius;
  final double width;

  const _RimPainter({required this.radius, required this.width});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return; // nothing laid out yet; deflate would go negative

    final rect = Offset.zero & size;

    // Inset by half the stroke, so the rim lands fully inside the pane instead
    // of straddling its edge and looking twice as thick as it is.
    canvas.drawRRect(
      radius.toRRect(rect).deflate(width / 2),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0x8CFFFFFF), // ~55% — the lit edge
            Color(0x24FFFFFF), // ~14%
            Color(0x0DFFFFFF), // ~5% — effectively gone
          ],
          stops: [0.0, 0.45, 1.0],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_RimPainter old) =>
      old.radius != radius || old.width != width;
}
