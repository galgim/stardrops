import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_metrics.dart';
import '../theme/app_text.dart';
import 'glass_pane.dart';

/// The shell every dialog in the app sits in: a pane of glass, generous
/// padding, a centred caps title, then the caller's controls stacked
/// full-width.
///
/// Material's `Dialog` is still here for the barrier, the centring and the
/// route behaviour, but its own surface is turned off — it was the last stock
/// white-ish Material panel in the app, and it sat on a navy screen looking
/// like something from a different program. The glass underneath is the same
/// material as every button on it.
///
/// The width cap is load-bearing. [CrossAxisAlignment.stretch] below makes the
/// Column take every pixel it's offered, and on a landscape phone that is most
/// of the screen — without the cap a dialog stops looking like a dialog.
///
/// The content scrolls, which matters only when a keyboard is up. `Dialog`
/// adds the keyboard's inset to its own padding, and on a landscape phone a
/// keyboard takes over half the screen — roughly 127pt of an iPhone SE's 375
/// is left for a dialog whose natural height is about 180. Without a scroll
/// view the Column simply overflowed, which is what the striped bar at the
/// bottom of the profile dialog was. Nothing scrolls when the keyboard is
/// down; the dialog is its natural size and behaves exactly as before.
///
/// Not a `show...` function, because the pause menu has to wrap it in a
/// [PopScope] to intercept Android's back gesture.
class AppDialog extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const AppDialog({super.key, required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      // Material's default is 24pt top and bottom. That's fine with no
      // keyboard and pure waste with one, since the keyboard's inset is added
      // on top of it — this buys back 24pt of the little that's left.
      insetPadding: const EdgeInsets.symmetric(
        horizontal: 40,
        vertical: AppSpacing.md,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 260),
        child: GlassSurface(
          radius: AppRadius.panel,
          // Deep navy rather than white: a panel this large in white glass is
          // fog over the screen rather than a surface lifted off it.
          fill: AppColors.ink,
          // Nearly opaque, unlike every other surface in the app. A dialog is
          // the one place where legibility beats the material — it lands on top
          // of a table full of cards, and at glass strength the board reads
          // straight through the text. Still translucent enough to keep the
          // rim, which is what stops it looking like a flat box.
          fillAlpha: 0.88,
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: SingleChildScrollView(
            // Sizes to its content and only scrolls once there isn't room, so
            // this is invisible until a keyboard makes it necessary.
            //
            // Anchored to the bottom, because a dialog is ordered least
            // important first: the title, then any explanation, then the thing
            // you came to touch. If something has to be off-screen it should be
            // the title, not the field — and with the top anchored it was
            // exactly the other way round.
            reverse: true,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(title, style: AppText.title, textAlign: TextAlign.center),
                const SizedBox(height: AppSpacing.lg),
                ...children,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
