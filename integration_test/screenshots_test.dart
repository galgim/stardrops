import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stardrop/l10n/app_localizations.dart';
import 'package:stardrop/logic/ai_strategy.dart';
import 'package:stardrop/screens/game_screen.dart';
import 'package:stardrop/screens/intro_screen.dart';
import 'package:stardrop/screens/lobby_screen.dart';
import 'package:stardrop/screens/menu_screen.dart';
import 'package:stardrop/widgets/player_hand.dart';
import 'package:stardrop/widgets/take_card_widget.dart';

// Store screenshots, captured on whatever simulator you point it at, so the
// set can be regenerated for every release instead of shot by hand.
//
//   SHOT_DIR=screenshots/iphone-6.5 flutter drive \
//     --driver test_driver/integration_test.dart \
//     --target integration_test/screenshots_test.dart -d <simulator id>
//   python3 tool/store_shots.py
//
// The game is landscape-locked. main.dart does that lock, and these tests pump
// screens directly without going through it, so pump() below applies the same
// lock — otherwise the simulator stays portrait and every capture is a
// letterboxed phone-shaped game in the middle of a tall image.
//
// These come out at the simulator's own resolution, which App Store Connect
// will not necessarily accept — a modern iPhone gives 2796x1290 and the upload
// is rejected with only 'the dimensions of one or more screenshots are wrong'.
// So the device type matters more than the iOS version. An iPhone 11 Pro Max
// or XS Max is natively 2688x1242 in landscape, which is a size the 6.5" slot
// takes as-is:
//
//   xcrun simctl create "Stardrops Shots" \
//     com.apple.CoreSimulator.SimDeviceType.iPhone-11-Pro-Max \
//     com.apple.CoreSimulator.SimRuntime.iOS-26-5
//
// Substitute whatever runtime is installed — `xcrun simctl list runtimes`.
// The name is only a label; `flutter drive -d` takes it or the UDID the create
// command prints. Delete it again with `xcrun simctl delete "Stardrops Shots"`.
//
// If you capture on a different device anyway, resize before framing —
// tool/store_shots.py checks the width and refuses a capture it does not
// expect, rather than framing a slice of the wrong picture:
//
//   cd screenshots/iphone-6.5 && for f in *.png; do sips -z 1242 2688 "$f"; done
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  /// Wraps a screen the way main.dart does, so AppLocalizations.of() resolves.
  /// Same harness as test/render_smoke_test.dart — without the delegates every
  /// localised string throws on its null check.
  Future<void> pump(WidgetTester tester, Widget home) async {
    // The same lock main.dart sets. These tests never call main(), so without
    // this the device stays portrait.
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: home,
      ),
    );
    // Never pumpAndSettle in here: the star background animates forever, so it
    // would time out rather than return. Every wait below is an explicit pump.
    // Rotation is a real animation on the device, not an instant resize.
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pump(const Duration(milliseconds: 600));
  }

  setUp(() {
    // A player who has been at it a while, so the record is not all zeroes.
    // 'You' rather than a real name: a listing is read by whoever is browsing,
    // and the seat is theirs.
    SharedPreferences.setMockInitialValues({
      'player_name': 'You',
      'seen_intro': true,
      'sfx_on': true,
      'games_played': 22,
      'games_played_easy': 9,
      'player_wins_easy': 7,
      'games_played_normal': 8,
      'player_wins_normal': 4,
      'games_played_hard': 5,
      'player_wins_hard': 2,
    });
  });

  // The board, one round in. A freshly dealt table is four rows holding one
  // card each, which shows the layout but not the game — the rows have to have
  // something in them before "fill a row and you take it" means anything.
  testWidgets('01 game', (tester) async {
    await binding.convertFlutterSurfaceToImage();
    await pump(tester, const GameScreen(
      playerCount: 5,
      playerName: 'You',
      aiLevel: AiLevel.hard,
    ));

    // Highest card in hand: it lands on a row rather than forcing the
    // take-a-row prompt, so the capture shows the table and not a dialog.
    final hand = find.descendant(
      of: find.byType(PlayerHand),
      matching: find.byType(TakeCardWidget),
    );
    await tester.tap(hand.last);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('CONFIRM'));

    // Five cards fly one after another, each with its own animation, and
    // pumpAndSettle can't be used to wait them out. Pump past the whole
    // sequence by hand.
    for (var i = 0; i < 24; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
    await binding.takeScreenshot('01-game');
  });

  // The host lobby, because the join code is the whole idea: one person reads
  // out a code and everyone else is in.
  testWidgets('02 local play', (tester) async {
    await binding.convertFlutterSurfaceToImage();
    await pump(tester, const LobbyScreen(playerName: 'You'));
    // The code only appears once the socket has bound, which is a real bind on
    // a real device and takes a moment.
    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pump(const Duration(milliseconds: 600));
    await binding.takeScreenshot('02-local-play');
  });

  testWidgets('03 difficulty', (tester) async {
    await binding.convertFlutterSurfaceToImage();
    await pump(tester, const MenuScreen());
    await tester.tap(find.text('PLAY'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    // The live binding paints a crosshair wherever the test touched, and it
    // fades over the following frames. Pump past the fade or the marker sits
    // on the button in the capture.
    await tester.pump(const Duration(milliseconds: 900));
    await binding.takeScreenshot('03-difficulty');
  });

  testWidgets('04 how to play', (tester) async {
    await binding.convertFlutterSurfaceToImage();
    await pump(tester, const IntroScreen());
    // Slide 2 is the first one that shows the rule rather than the title.
    await tester.tap(find.text('NEXT'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 900));
    await binding.takeScreenshot('04-how-to-play');
  });

  // The record lives in the profile dialog, not on the menu — it moved there
  // when it was broken down by difficulty. A capture of the menu shows the
  // wordmark and four buttons and nothing about a record at all.
  testWidgets('05 profile', (tester) async {
    await binding.convertFlutterSurfaceToImage();
    await pump(tester, const MenuScreen());
    await tester.tap(find.byIcon(Icons.person_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    // Same pointer-crosshair fade as in '03 difficulty'.
    await tester.pump(const Duration(milliseconds: 900));
    await binding.takeScreenshot('05-profile');
  });

  testWidgets('06 menu', (tester) async {
    await binding.convertFlutterSurfaceToImage();
    await pump(tester, const MenuScreen());
    await tester.pump(const Duration(milliseconds: 600));
    await binding.takeScreenshot('06-menu');
  });

  // Not a store listing shot. App Store Connect requires a screenshot of the
  // in-app purchase for review, and this is it — reviewer-only, never shown to
  // players, so it needs no framing.
  //
  // The UNLOCK button carries a price only when a real store answers: on a bare
  // simulator there is none, and the button falls back to its plain label. Run
  // this against a StoreKit configuration or a sandbox account if the price
  // needs to be in the picture.
  testWidgets('07 host unlock', (tester) async {
    await binding.convertFlutterSurfaceToImage();
    await pump(tester, const MenuScreen());
    await tester.tap(find.text('LOCAL GAME'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('HOST'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    // Same pointer-crosshair fade as in '03 difficulty'.
    await tester.pump(const Duration(milliseconds: 900));
    await binding.takeScreenshot('07-host-unlock');
  });
}
