import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_metrics.dart';
import 'glass_pane.dart';

/// A round glass button with an icon in it — the in-game menu gear, the
/// profile button on the menu screen.
///
/// [GlassPane]'s default radius is a full pill, so square content comes out
/// circular. The size is fixed rather than offered as a parameter: 12pt of
/// padding around a 20pt icon is exactly the 44pt minimum tap target, and
/// there's no room under that. "Smaller" for a control this size means fewer
/// pixels of chrome, not a smaller target.
///
/// [semanticLabel] is required because there is no text to read. An icon-only
/// button with nothing behind it is silent to VoiceOver and TalkBack.
class AppIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final String semanticLabel;

  const AppIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    required this.semanticLabel,
  });

  /// 12 + 20 + 12. Named so the layouts that reserve room for one agree with it.
  static const size = AppSpacing.md * 2 + _iconSize;
  static const _iconSize = 20.0;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      button: true,
      enabled: onTap != null,
      child: GlassPane(
        onTap: onTap,
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Icon(icon, color: AppColors.textPrimary, size: _iconSize),
      ),
    );
  }
}
