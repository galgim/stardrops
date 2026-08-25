import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_metrics.dart';
import '../theme/app_text.dart';
import 'glass_pane.dart';

/// The app's labelled button — a [GlassPane] with text in it.
///
/// [AppButton.primary] is the only opaque control in the app: solid yellow with
/// a gold glow, so "act here" still carries across the table. [AppButton.ghost]
/// and [AppButton.dialog] are glass. The press response, the tap sound, and the
/// haptic all come from [GlassPane], so buttons and the in-game gear answer
/// touch identically.
class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  final Color fill;
  final Color textColor;
  final Color shadowColor;
  final bool translucent;

  final double horizontalPadding;

  /// Uses [AppText.buttonSmall] instead of [AppText.button] — for the in-game
  /// confirm beside the hand, and for dialog actions. No call site names a
  /// size; there are two, and this picks between them.
  final bool compact;

  /// Accent-filled: PLAY, CONFIRM, NEXT, PLAY AGAIN.
  const AppButton.primary({
    super.key,
    required this.label,
    this.onTap,
    this.horizontalPadding = AppSpacing.xl,
    this.compact = false,
  }) : fill = AppColors.accent,
       textColor = AppColors.ink,
       shadowColor = AppColors.accentEdge,
       translucent = false;

  /// The quieter action next to a [AppButton.primary]. Plain glass.
  const AppButton.ghost({
    super.key,
    required this.label,
    this.onTap,
    this.horizontalPadding = AppSpacing.xl,
    this.compact = false,
  }) : fill = AppColors.textPrimary,
       textColor = AppColors.textPrimary,
       shadowColor = Colors.black,
       translucent = true;

  /// For the dialogs — the pause menu and settings. [filled] marks the
  /// committing choice, which gets red glass and red text; the way back out gets
  /// plain glass and white text.
  ///
  /// The red text is doing most of the work. A tint at glass alpha is far too
  /// faint on its own to read as "this one is destructive".
  const AppButton.dialog({
    super.key,
    required this.label,
    this.onTap,
    required bool filled,
    this.horizontalPadding = AppSpacing.xl,
  }) : fill = filled ? AppColors.penalty : AppColors.textPrimary,
       textColor = filled ? AppColors.penalty : AppColors.textPrimary,
       shadowColor = Colors.black,
       translucent = true,
       compact = true;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;

    return GlassPane(
      onTap: onTap,
      fill: fill,
      translucent: translucent,
      shadowColor: shadowColor,
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: AppSpacing.md,
      ),
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            maxLines: 1,
            style: (compact ? AppText.buttonSmall : AppText.button).copyWith(
              color: enabled
                  ? textColor
                  : AppColors.textPrimary.withValues(alpha: 0.28),
            ),
          ),
        ),
      ),
    );
  }
}
