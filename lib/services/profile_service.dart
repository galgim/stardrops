import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Stores the name the player goes by. No account, no password — it's a label
/// for the sidebar and, later, for the other phones in a local game.
class ProfileService {
  static const _kName = 'player_name';

  /// Used until the player sets something, and whenever storage fails.
  static const defaultName = 'You';

  /// The longest name the sidebar chip can show before ellipsing. Enforced on
  /// the way in so a name can't arrive too long from anywhere.
  static const maxLength = 12;

  /// Reads the saved name, falling back to [defaultName].
  ///
  /// Storage sits behind a platform channel and can fail. A name is cosmetic,
  /// so a failure logs and yields the default rather than blocking the menu.
  static Future<String> read() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return clean(prefs.getString(_kName));
    } catch (e) {
      debugPrint('ProfileService.read failed: $e');
      return defaultName;
    }
  }

  /// Saves [name], trimmed and capped. Returns the value actually stored so the
  /// caller can show the same string it persisted.
  static Future<String> save(String name) async {
    final value = clean(name);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kName, value);
    } catch (e) {
      debugPrint('ProfileService.save failed: $e');
    }
    return value;
  }

  /// Trims, caps to [maxLength], and substitutes [defaultName] for anything
  /// blank. Shared by the reader, the writer, and — once there's a network —
  /// names arriving from another device, which can't be trusted to be sane.
  static String clean(String? name) {
    final trimmed = (name ?? '').trim();
    if (trimmed.isEmpty) return defaultName;
    return trimmed.length <= maxLength
        ? trimmed
        : trimmed.substring(0, maxLength);
  }
}
