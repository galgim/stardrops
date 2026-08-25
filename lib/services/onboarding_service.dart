import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Remembers whether the player has already been shown the how-to-play
/// tutorial, so it only appears automatically on a fresh install.
class OnboardingService {
  static const _kSeenIntro = 'seen_intro';

  /// True once the tutorial has been shown at least once.
  ///
  /// Storage lives behind a platform channel and can fail. On failure this
  /// reports false — a new player still gets taught the game, at the cost of a
  /// returning player seeing a screen they can skip in one tap. That's the
  /// cheaper of the two failure modes.
  static Future<bool> hasSeenIntro() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_kSeenIntro) ?? false;
    } catch (e) {
      debugPrint('OnboardingService.hasSeenIntro failed: $e');
      return false;
    }
  }

  /// Records that the tutorial has been shown. Called when the player leaves
  /// it, whether they read it through or skipped.
  static Future<void> markIntroSeen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kSeenIntro, true);
    } catch (e) {
      debugPrint('OnboardingService.markIntroSeen failed: $e');
    }
  }
}
