import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/app_localizations.dart';
import 'screens/intro_screen.dart';
import 'screens/menu_screen.dart';
import 'services/locale_service.dart';
import 'services/onboarding_service.dart';
import 'services/sfx.dart';
import 'theme/app_colors.dart';
import 'theme/app_text.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // Read before the first frame so the app opens directly on the right screen.
  // Without this the menu would flash for a moment on a fresh install, before
  // the tutorial replaced it.
  final seenIntro = await OnboardingService.hasSeenIntro();

  // Before the first frame for the same reason: opening in English and
  // switching a frame later would be a visible flash of the wrong language.
  await LocaleService.load();

  // A handful of short local clips, and it logs rather than throws on failure,
  // so this can't meaningfully delay or break startup. Doing it here means the
  // first button tap on the menu is already audible.
  await Sfx.init();

  runApp(StardropApp(showIntro: !seenIntro));
}

class StardropApp extends StatelessWidget {
  /// True on a fresh install: open on the tutorial instead of the menu.
  final bool showIntro;

  const StardropApp({super.key, required this.showIntro});

  @override
  Widget build(BuildContext context) {
    // Rebuilds everything below it whenever the language changes. The listener
    // sits here, at the root, because that's the only place a rebuild reaches
    // every screen — see LocaleService for why setState can't do this job.
    return ValueListenableBuilder<Locale>(
      valueListenable: LocaleService.current,
      builder: (context, locale, _) => MaterialApp(
        // Not localised: it's the app's name, which is the same in every
        // language, and on Android it labels the task switcher.
        title: 'Stardrops',
        debugShowCheckedModeBanner: false,
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: AppColors.backdrop,
            brightness: Brightness.dark,
          ),
          // Set here as well as in AppText so no stray Text can quietly fall
          // back to the platform default and reintroduce the stock-Flutter
          // look. The Hangul fallback is repeated for the same reason — a
          // stray Text in Korean would otherwise render as empty boxes.
          fontFamily: 'SpaceGrotesk',
          fontFamilyFallback: AppText.hangulFallback,
          useMaterial3: true,
        ),
        home: showIntro
            ? const IntroScreen(isFirstRun: true)
            : const MenuScreen(),
      ),
    );
  }
}
