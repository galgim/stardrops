import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_localizations.dart';

/// Remembers which language the player chose, and tells the whole app when it
/// changes.
///
/// This is the one place `setState` doesn't reach. Changing the language has to
/// rebuild every screen at once, and the switch is thrown from a dialog several
/// widgets deep — a `setState` there only rebuilds that dialog. So the current
/// locale lives in a [ValueNotifier] that the app's root listens to: the dialog
/// writes to it, the root rebuilds everything below it. That's the smallest
/// thing that works, and it's built into Flutter, so no state-management
/// package is involved.
class LocaleService {
  const LocaleService._();

  static const _kLanguage = 'language_code';

  /// The language in use. The root of the app rebuilds when this changes.
  ///
  /// Seeded with English so the first frame has something to draw; [load]
  /// replaces it before `runApp` if the player has chosen something else.
  static final current = ValueNotifier<Locale>(const Locale('en'));

  /// Every language the app is translated into, newest translation last. Comes
  /// straight from the generated delegate, so adding an .arb file adds a row to
  /// the picker without touching this file.
  static List<Locale> get supported => AppLocalizations.supportedLocales;

  /// Reads the saved language into [current]. Call once before `runApp`.
  ///
  /// A saved language the app no longer ships is ignored rather than trusted —
  /// a downgrade could leave a code behind that has no translation, and
  /// `Locale('xx')` with no delegate renders every string blank.
  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final code = prefs.getString(_kLanguage);
      if (code == null) return;
      final match = supported.where((l) => l.languageCode == code);
      if (match.isEmpty) {
        debugPrint('LocaleService: dropping unsupported saved language "$code"');
        return;
      }
      current.value = match.first;
    } catch (e) {
      // Storage sits behind a platform channel and can fail. English is a
      // working app, so this logs and carries on rather than blocking startup.
      debugPrint('LocaleService.load failed: $e');
    }
  }

  /// Switches the app to [locale] and remembers it for next launch. The switch
  /// itself is immediate; only the persisting can fail, and a language that
  /// doesn't survive a restart beats one that doesn't apply at all.
  static Future<void> set(Locale locale) async {
    current.value = locale;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kLanguage, locale.languageCode);
    } catch (e) {
      debugPrint('LocaleService.set failed: $e');
    }
  }
}
