import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../logic/ai_strategy.dart';
import '../theme/app_metrics.dart';
import 'app_button.dart';
import 'app_dialog.dart';

/// Asks how hard the computer players should be. Returns null if dismissed,
/// which leaves the menu where it was rather than starting a game nobody
/// picked a difficulty for.
Future<AiLevel?> showDifficultyDialog(BuildContext context) {
  return showDialog<AiLevel>(
    context: context,
    builder: (context) => AppDialog(
      title: AppLocalizations.of(context)!.difficultyTitle,
      children: [
        for (final (i, level) in AiLevel.values.indexed) ...[
          if (i > 0) const SizedBox(height: AppSpacing.md),
          AppButton.dialog(
            label: difficultyLabel(context, level),
            filled: false,
            onTap: () => Navigator.pop(context, level),
          ),
        ],
      ],
    ),
  );
}

/// Shown to the player. Kept here rather than on [AiLevel] itself, so the rules
/// don't carry around strings only the UI uses. Shared with the profile
/// dialog's per-difficulty win counts.
String difficultyLabel(BuildContext context, AiLevel level) {
  final l10n = AppLocalizations.of(context)!;
  return switch (level) {
    AiLevel.easy => l10n.difficultyEasy,
    AiLevel.normal => l10n.difficultyNormal,
    AiLevel.hard => l10n.difficultyHard,
  };
}
