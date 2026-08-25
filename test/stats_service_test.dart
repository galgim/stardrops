import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stardrop/logic/ai_strategy.dart';
import 'package:stardrop/services/stats_service.dart';

/// The counters are the only logic here: losses are derived rather than stored,
/// and a game only lands in a difficulty row when there was an AI to play.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('a difficulty row counts its own played, won and lost', () async {
    await StatsService.recordResult(playerWon: true, level: AiLevel.hard);
    await StatsService.recordResult(playerWon: false, level: AiLevel.hard);
    await StatsService.recordResult(playerWon: false, level: AiLevel.hard);

    final hard = (await StatsService.read())!.byLevel[AiLevel.hard]!;
    expect(hard.played, 3);
    expect(hard.wins, 1);
    expect(hard.losses, 2);
  });

  test('a game lands in one difficulty row and no other', () async {
    await StatsService.recordResult(playerWon: true, level: AiLevel.easy);

    final stats = await StatsService.read();
    expect(stats!.byLevel[AiLevel.easy]!.wins, 1);
    expect(stats.byLevel[AiLevel.normal]!.played, 0);
    expect(stats.byLevel[AiLevel.hard]!.played, 0);
  });

  test('a networked game counts as played but joins no row', () async {
    await StatsService.recordResult(playerWon: true);

    final stats = await StatsService.read();
    expect(stats!.gamesPlayed, 1);
    expect(stats.byLevel.values.map((r) => r.played), everyElement(0));
  });

  test('a fresh install reads zeros, not nulls', () async {
    final stats = await StatsService.read();
    expect(stats!.gamesPlayed, 0);
    expect(stats.byLevel.length, AiLevel.values.length);
    expect(stats.byLevel.values.map((r) => r.losses), everyElement(0));
  });

  test('more wins than games can never show a negative loss count', () async {
    SharedPreferences.setMockInitialValues({
      'games_played_easy': 1,
      'player_wins_easy': 4,
    });

    final easy = (await StatsService.read())!.byLevel[AiLevel.easy]!;
    expect(easy.losses, 0);
  });
}
