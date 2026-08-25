import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/locale_service.dart';
import '../theme/app_metrics.dart';
import 'app_button.dart';
import 'app_dialog.dart';

/// Lists the languages the app is translated into and switches to the one
/// tapped. Closes itself on a choice; dismissing changes nothing.
///
/// The switch takes effect before this returns — [LocaleService] rebuilds the
/// app from the root — so the settings dialog underneath is already in the new
/// language by the time the player sees it again.
Future<void> showLanguageDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (context) => AppDialog(
      title: AppLocalizations.of(context)!.languageTitle,
      children: [
        for (final (i, locale) in LocaleService.supported.indexed) ...[
          if (i > 0) const SizedBox(height: AppSpacing.md),
          AppButton.dialog(
            // Each language names itself, so someone who has landed in a
            // language they can't read still recognises their own on the list.
            label: _endonyms[locale.languageCode] ?? locale.languageCode,
            filled: false,
            onTap: () {
              LocaleService.set(locale);
              Navigator.pop(context);
            },
          ),
        ],
      ],
    ),
  );
}

/// Each language's name in itself. Read from the translations rather than
/// hardcoded, so a new .arb file supplies its own row.
final _endonyms = {
  for (final locale in LocaleService.supported)
    locale.languageCode: lookupAppLocalizations(locale).languageName,
};
