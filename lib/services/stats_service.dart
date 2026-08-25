import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../logic/ai_strategy.dart';

/// One difficulty's record. Losses aren't stored — they're whatever wasn't won.
/// A tie counts as a win (see `GameState.localWon`), so it isn't a loss either.
typedef LevelRecord = ({int played, int wins, int losses});

/// The player's lifetime record: a total, and a row per difficulty.
///
/// [gamesPlayed] counts every finished game, so it can exceed the rows added
/// up — a networked game has no AI level to file itself under.
typedef PlayerStats = ({int gamesPlayed, Map<AiLevel, LevelRecord> byLevel});

/// Persists lightweight player stats across sessions.
class StatsService {
  static const _kGames = 'games_played';

  static String _playedKey(AiLevel level) => 'games_played_${level.name}';
  static String _winsKey(AiLevel level) => 'player_wins_${level.name}';

  /// Reads the player's lifetime record, or null if it couldn't be read.
  /// Callers show nothing on null rather than a misleading zero.
  static Future<PlayerStats?> read() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return (
        gamesPlayed: prefs.getInt(_kGames) ?? 0,
        byLevel: {
          for (final level in AiLevel.values)
            level: _record(
              played: prefs.getInt(_playedKey(level)) ?? 0,
              wins: prefs.getInt(_winsKey(level)) ?? 0,
            ),
        },
      );
    } catch (e) {
      debugPrint('StatsService.read failed: $e');
      return null;
    }
  }

  /// Builds one row, clamping the derived loss count at zero so a hand-edited
  /// or half-written pair of counters can't render a negative.
  static LevelRecord _record({required int played, required int wins}) => (
    played: played,
    wins: wins,
    losses: played > wins ? played - wins : 0,
  );

  /// Records the outcome of a finished game. [level] is null over the network,
  /// where the seats are people and there is no difficulty to file the game under.
  ///
  /// Storage lives behind a platform channel, so it can fail (a full disk, a
  /// broken install). Stats are cosmetic — a failure is logged and swallowed
  /// rather than interrupting the game.
  static Future<void> recordResult({
    required bool playerWon,
    AiLevel? level,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_kGames, (prefs.getInt(_kGames) ?? 0) + 1);
      if (level == null) return;
      await prefs.setInt(
        _playedKey(level),
        (prefs.getInt(_playedKey(level)) ?? 0) + 1,
      );
      if (playerWon) {
        await prefs.setInt(
          _winsKey(level),
          (prefs.getInt(_winsKey(level)) ?? 0) + 1,
        );
      }
    } catch (e) {
      debugPrint('StatsService.recordResult failed: $e');
    }
  }
}
