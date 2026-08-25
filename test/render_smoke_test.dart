import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stardrop/l10n/app_localizations.dart';
import 'package:stardrop/services/profile_service.dart';
import 'package:stardrop/screens/game_screen.dart';
import 'package:stardrop/screens/intro_screen.dart';
import 'package:stardrop/screens/menu_screen.dart';

/// Wraps a screen the way main.dart does, so AppLocalizations.of() resolves.
/// Without the delegates every localised string throws on the null check, and
/// these tests would be failing on their harness rather than on layout.
Widget app(Widget home, {Locale locale = const Locale('en')}) => MaterialApp(
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: home,
    );

void main() {
  // Shortest landscape phone the game targets (iPhone 12/13/14 class)...
  const size = Size(844, 390);
  // ...and the smallest, iPhone SE in landscape, which is tighter vertically.
  const seSize = Size(667, 375);

  for (final (label, s) in [('iPhone 14', size), ('iPhone SE', seSize)]) {
    testWidgets('every intro slide lays out without overflow — $label', (
      tester,
    ) async {
      tester.view.physicalSize = s;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        app(const IntroScreen(isFirstRun: true)),
      );
      await tester.pump();
      expect(tester.takeException(), isNull, reason: 'slide 1');

      // The star background animates forever, so pumpAndSettle would time out —
      // pump past the page transition by hand instead.
      for (final slide in [2, 3, 4, 5, 6]) {
        await tester.tap(find.text('NEXT'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(tester.takeException(), isNull, reason: 'slide $slide');

        // Two of the slides loop through an animated sequence, and a later
        // step lays out more cards than the first one does. Pump through a
        // full loop so every step gets measured, not just the opening frame.
        for (var step = 0; step < 6; step++) {
          await tester.pump(const Duration(milliseconds: 1500));
          expect(
            tester.takeException(),
            isNull,
            reason: 'slide $slide step $step',
          );
        }
      }

      // Last slide swaps NEXT for PLAY on first launch.
      expect(find.text('PLAY'), findsOneWidget);
    });

    testWidgets('menu lays out without overflow — $label', (tester) async {
      tester.view.physicalSize = s;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(app(const MenuScreen()));
      await tester.pump();
      expect(tester.takeException(), isNull);

      expect(find.text('STARDROPS'), findsOneWidget);
      expect(find.text('PLAY'), findsOneWidget);
      expect(find.text('HOW TO PLAY'), findsOneWidget);

      // The profile moved out of the button column into the corner, so it's
      // an icon now and there is no PROFILE label to find.
      expect(find.byIcon(Icons.person_rounded), findsOneWidget);
      expect(find.text('PROFILE'), findsNothing);
    });

    testWidgets('game screen lays out without overflow — $label', (
      tester,
    ) async {
      tester.view.physicalSize = s;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        app(const GameScreen(playerCount: 5, playerName: 'You')),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);

      // Scoreboard, opponents, and the confirm button are all on screen.
      expect(find.text('You'), findsWidgets);
      expect(find.text('AI 4'), findsOneWidget);
      expect(find.text('SELECT'), findsOneWidget);
    });

    // The dialog is the tallest thing that ever lands on the game screen, and
    // the pause one carries the most: a toggle and two buttons.
    testWidgets('the pause dialog fits over the game — $label', (tester) async {
      tester.view.physicalSize = s;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        app(const GameScreen(playerCount: 5, playerName: 'You')),
      );
      await tester.pump();

      await tester.tap(find.byIcon(Icons.menu));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(tester.takeException(), isNull);
      expect(find.text('ABANDON GAME'), findsOneWidget);
      expect(find.text('RESUME'), findsOneWidget);
    });
  }

  // Opens the profile from the menu, then taps the name to reach the editor.
  // Three tests need that pair of taps, and the second one is easy to forget
  // now that the field lives a dialog deeper than the profile.
  Future<void> openProfile(WidgetTester tester) async {
    await tester.pumpWidget(app(const MenuScreen()));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.person_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> openNameEditor(WidgetTester tester) async {
    await tester.tap(find.text(ProfileService.defaultName));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  // The corner button is the only way to reach the name editor now, so it had
  // better still open it — and the profile itself must not be a text field,
  // which is the whole point of the extra step.
  testWidgets('the corner profile button opens the name editor', (
    tester,
  ) async {
    tester.view.physicalSize = seSize;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await openProfile(tester);

    expect(find.text('PROFILE'), findsOneWidget); // now the dialog's title
    expect(find.text('YOUR NAME'), findsOneWidget);
    expect(find.byType(TextField), findsNothing); // the name is a button here

    await openNameEditor(tester);
    expect(find.byType(TextField), findsOneWidget);
  });

  // A keyboard over a landscape phone takes more than half the screen, and
  // both of the dialogs with a text field are opened from the menu. Two things
  // used to overflow at once here: the dialog's own content, and — less
  // obviously — the menu's button column behind it, because Scaffold shrinks
  // its body by the keyboard inset whether or not anything on it is typed
  // into. The range of heights is deliberate; a keyboard with a suggestion
  // strip or a different language is taller than the plain one.
  for (final (label, s) in [('iPhone 14', size), ('iPhone SE', seSize)]) {
    for (final keyboard in [160.0, 200.0, 260.0]) {
      testWidgets(
        'profile dialog survives a ${keyboard.toInt()}pt keyboard — $label',
        (tester) async {
          tester.view.physicalSize = s;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);

          await openProfile(tester);
          await openNameEditor(tester);
          expect(tester.takeException(), isNull, reason: 'before the keyboard');

          tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));
          expect(
            tester.takeException(),
            isNull,
            reason: 'with the keyboard up',
          );

          // Still usable, not just un-crashed. There is no button to press — the
          // keyboard's own key commits — so the field is the whole dialog, and
          // it has to be entirely on screen.
          expect(find.text('SAVE'), findsNothing);
          final field = tester.getRect(find.byType(TextField));
          // The profile dialog is still mounted underneath with a scroll view of
          // its own, so this has to be the editor's, not whichever comes first.
          final viewport = tester.getRect(
            find.ancestor(
              of: find.byType(TextField),
              matching: find.byType(SingleChildScrollView),
            ),
          );
          expect(
            field.top >= viewport.top - 0.5 &&
                field.bottom <= viewport.bottom + 0.5,
            isTrue,
            reason: 'the name field was pushed out of the dialog',
          );
        },
      );
    }
  }

  testWidgets('join-code dialog survives the keyboard', (tester) async {
    tester.view.physicalSize = seSize;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(app(const MenuScreen()));
    await tester.pump();
    await tester.tap(find.text('LOCAL GAME'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('JOIN'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(TextField), findsOneWidget);

    tester.view.viewInsets = const FakeViewPadding(bottom: 220);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);

    final field = tester.getRect(find.byType(TextField));
    final viewport = tester.getRect(find.byType(SingleChildScrollView));
    expect(
      field.top >= viewport.top - 0.5 && field.bottom <= viewport.bottom + 0.5,
      isTrue,
      reason: 'the code field was pushed out of the dialog',
    );
  });

  // The button is gone, so the typing itself has to be what saves — otherwise
  // tapping outside the dialog would quietly throw the name away.
  testWidgets('the name is saved as it is typed, with no button', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = seSize;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await openProfile(tester);
    await openNameEditor(tester);

    expect(find.text('SAVE'), findsNothing);

    await tester.enterText(find.byType(TextField), 'Clay');
    await tester.pump();
    expect(await ProfileService.read(), 'Clay');

    // Dismissed by tapping the barrier rather than by any button — the name
    // still has to survive that.
    await tester.tapAt(const Offset(8, 8));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(await ProfileService.read(), 'Clay');

    // And the profile behind it picks the new name up, rather than still
    // showing the one it opened with.
    await tester.pump();
    expect(find.text('Clay'), findsOneWidget);
  });

  // The record table is three columns of numbers on the narrowest screen the
  // app supports, with three-digit counts and the longest level names a
  // translation gives it. Nothing here is allowed to overflow or clip.
  testWidgets('the record table fits the profile on a small screen', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'games_played': 512,
      'games_played_easy': 128,
      'player_wins_easy': 120,
      'games_played_normal': 256,
      'player_wins_normal': 64,
      'games_played_hard': 111,
      'player_wins_hard': 5,
    });
    tester.view.physicalSize = seSize;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await openProfile(tester);
    await tester.pump(); // the stats land a frame after the dialog opens

    expect(tester.takeException(), isNull);
    expect(find.text('512 PLAYED'), findsOneWidget);
    // 120 won of 128 played on easy, so 8 lost — the losses are derived, and
    // this is the one place that arithmetic reaches the screen.
    expect(find.text('120'), findsOneWidget);
    expect(find.text('8'), findsOneWidget);
    expect(find.text('106'), findsOneWidget); // 111 played, 5 won on hard
  });

  // Opened from the menu the same slides end in DONE, not PLAY — that button
  // returns to the menu instead of starting a game.
  testWidgets('tutorial opened from the menu ends in DONE', (tester) async {
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(app(const IntroScreen()));
    for (var i = 0; i < 5; i++) {
      await tester.tap(find.text('NEXT'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }

    expect(find.text('DONE'), findsOneWidget);
    expect(find.text('PLAY'), findsNothing);
  });

  // Back used to pop the route and throw the game away without asking.
  testWidgets('back opens the pause menu instead of abandoning the game', (
    tester,
  ) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      app(const GameScreen(playerCount: 5, playerName: 'You')),
    );
    await tester.pump();

    // What Android's back button and iOS's edge-swipe both come through as.
    tester.state<NavigatorState>(find.byType(Navigator)).maybePop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('ABANDON GAME'), findsOneWidget); // pause dialog is up
    expect(find.byType(GameScreen), findsOneWidget); // and the game survived
  });

  // The back guard blocks the *system* pop only. Deliberate exits call
  // Navigator.pop directly and must still work, or a game becomes a dead end.
  testWidgets('ABANDON GAME still returns to the menu', (tester) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(app(const MenuScreen()));
    await tester.pump();

    // The star field animates forever, so pumpAndSettle would time out —
    // pump past each route transition by hand.
    await tester.tap(find.text('PLAY'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // PLAY asks how hard the AI should be before it deals.
    expect(find.text('DIFFICULTY'), findsOneWidget);
    await tester.tap(find.text('NORMAL'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(GameScreen), findsOneWidget);

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Dismissing the dialog and popping the route run back to back, so this
    // needs longer than a single transition to clear.
    await tester.tap(find.text('ABANDON GAME'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(GameScreen), findsNothing);
    expect(find.byType(MenuScreen), findsOneWidget);
  });

  // Spanish runs roughly 20% longer than English, and this app is landscape
  // with fixed-width columns. AppButton scales its label down to fit, so the
  // risk isn't the buttons — it's the blocks around them. Run the same layouts
  // on the tightest phone in the longer language.
  group('Spanish layout', () {
    const es = Locale('es');

    testWidgets('menu, tutorial, and game lay out — iPhone SE', (tester) async {
      tester.view.physicalSize = seSize;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(app(const MenuScreen(), locale: es));
      await tester.pump();
      expect(tester.takeException(), isNull, reason: 'menu');
      expect(find.text('JUGAR'), findsOneWidget);

      await tester.pumpWidget(
        app(const GameScreen(playerCount: 5, playerName: 'You'), locale: es),
      );
      await tester.pump();
      expect(tester.takeException(), isNull, reason: 'game');
      // The AI seats are named from the translations too.
      expect(find.text('IA 4'), findsOneWidget);

      await tester.pumpWidget(
        app(const IntroScreen(isFirstRun: true), locale: es),
      );
      await tester.pump();
      expect(tester.takeException(), isNull, reason: 'slide 1');

      for (final slide in [2, 3, 4, 5, 6]) {
        await tester.tap(find.text('SIGUIENTE'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(tester.takeException(), isNull, reason: 'slide $slide');

        // Two slides animate through steps that lay out more cards than the
        // opening frame does, so pump a full loop rather than one frame.
        for (var step = 0; step < 6; step++) {
          await tester.pump(const Duration(milliseconds: 1500));
          expect(
            tester.takeException(),
            isNull,
            reason: 'slide $slide step $step',
          );
        }
      }
    });

    // The one genuinely tight spot: a fixed 100pt slot holding either CONFIRM
    // or the waiting message, both of which are longer in Spanish.
    testWidgets('the pause dialog fits over the game — iPhone SE',
        (tester) async {
      tester.view.physicalSize = seSize;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        app(const GameScreen(playerCount: 5, playerName: 'You'), locale: es),
      );
      await tester.pump();

      await tester.tap(find.byIcon(Icons.menu));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(tester.takeException(), isNull);
      expect(find.text('ABANDONAR'), findsOneWidget);
      expect(find.text('SEGUIR'), findsOneWidget);
    });
  });

  // Korean is the opposite problem from Spanish: the strings are shorter, but
  // the script has no uppercase and its blocks fill more of the line box, so
  // AppText drops tracking and opens the tight leadings. These check the
  // layouts still hold with that applied. Glyph coverage can't be checked here
  // — widget tests render with a test font, not the device's — so the Hangul
  // fallback is guarded in type_scale_test instead.
  group('Korean layout', () {
    const ko = Locale('ko');

    testWidgets('menu, tutorial, and game lay out — iPhone SE', (tester) async {
      tester.view.physicalSize = seSize;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(app(const MenuScreen(), locale: ko));
      await tester.pump();
      expect(tester.takeException(), isNull, reason: 'menu');
      expect(find.text('게임 시작'), findsOneWidget);

      await tester.pumpWidget(
        app(const GameScreen(playerCount: 5, playerName: 'You'), locale: ko),
      );
      await tester.pump();
      expect(tester.takeException(), isNull, reason: 'game');
      expect(find.text('선택'), findsOneWidget);

      await tester.pumpWidget(
        app(const IntroScreen(isFirstRun: true), locale: ko),
      );
      await tester.pump();
      expect(tester.takeException(), isNull, reason: 'slide 1');

      for (final slide in [2, 3, 4, 5, 6]) {
        await tester.tap(find.text('다음'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(tester.takeException(), isNull, reason: 'slide $slide');

        for (var step = 0; step < 6; step++) {
          await tester.pump(const Duration(milliseconds: 1500));
          expect(
            tester.takeException(),
            isNull,
            reason: 'slide $slide step $step',
          );
        }
      }
    });

    testWidgets('the pause dialog fits over the game — iPhone SE',
        (tester) async {
      tester.view.physicalSize = seSize;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        app(const GameScreen(playerCount: 5, playerName: 'You'), locale: ko),
      );
      await tester.pump();

      await tester.tap(find.byIcon(Icons.menu));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(tester.takeException(), isNull);
      expect(find.text('게임 포기'), findsOneWidget);
      expect(find.text('계속하기'), findsOneWidget);
    });

    // The picker is the one screen a player who can't read the current
    // language has to be able to use, so each row names itself.
    testWidgets('the language picker names every language in itself',
        (tester) async {
      tester.view.physicalSize = seSize;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(app(const MenuScreen(), locale: ko));
      await tester.pump();

      await tester.tap(find.text('설정'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(find.text('언어'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(tester.takeException(), isNull);
      expect(find.text('English'), findsOneWidget);
      expect(find.text('Español'), findsOneWidget);
      expect(find.text('한국어'), findsOneWidget);
    });
  });
}
