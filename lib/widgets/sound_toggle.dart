import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/sfx.dart';
import '../theme/app_colors.dart';
import '../theme/app_metrics.dart';
import '../theme/app_text.dart';
import 'glass_pane.dart';

/// The sound on/off switch, shared by the menu's settings dialog and the in-game
/// pause dialog so the two can't drift apart.
///
/// Built on [GlassPane] rather than a Material `Switch`: it's the same glass as
/// every other control, and it gets the press response for free. State reads
/// from both the icon and the text, not from colour alone.
class SoundToggle extends StatefulWidget {
  const SoundToggle({super.key});

  @override
  State<SoundToggle> createState() => _SoundToggleState();
}

class _SoundToggleState extends State<SoundToggle> {
  // Starts wherever the saved setting left it.
  bool _on = Sfx.soundOn;

  /// Flips the switch, then confirms it audibly when turning sound back on.
  ///
  /// [GlassPane] plays its tap clip before this runs, so switching off ends on a
  /// click and then silence, which is right. Switching on would otherwise be
  /// silent — that click was swallowed while sound was still off — so it gets
  /// one here, after the flip.
  void _toggle() {
    final next = !_on;
    setState(() => _on = next);
    Sfx.setSoundOn(next);
    if (next) Sfx.tap();
  }

  @override
  Widget build(BuildContext context) {
    final color = _on ? AppColors.textPrimary : AppColors.textSecondary;

    return GlassPane(
      onTap: _toggle,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.md,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _on ? Icons.volume_up_rounded : Icons.volume_off_rounded,
            color: color,
            size: 18,
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            _on
                ? AppLocalizations.of(context)!.soundOn
                : AppLocalizations.of(context)!.soundOff,
            style: AppText.buttonSmall.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}
