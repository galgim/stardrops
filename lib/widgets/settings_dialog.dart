import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/app_metrics.dart';
import 'app_button.dart';
import 'app_dialog.dart';
import 'language_dialog.dart';
import 'sound_toggle.dart';

/// Opens the settings dialog. Shared by the menu screen and the in-game pause
/// menu, so both routes reach the same controls.
///
/// LANGUAGE is a button onto its own dialog rather than another inline toggle:
/// sound has two states and cycles in place, but the language list grows every
/// time a translation is added and wouldn't fit here.
Future<void> showSettingsDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (context) => AppDialog(
      title: AppLocalizations.of(context)!.settingsTitle,
      children: [
        const SoundToggle(),
        const SizedBox(height: AppSpacing.md),
        AppButton.dialog(
          label: AppLocalizations.of(context)!.settingsLanguage,
          filled: false,
          onTap: () => showLanguageDialog(context),
        ),
        const SizedBox(height: AppSpacing.md),
        AppButton.dialog(
          label: AppLocalizations.of(context)!.settingsDone,
          filled: false,
          onTap: () => Navigator.pop(context),
        ),
      ],
    ),
  );
}
