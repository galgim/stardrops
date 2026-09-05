import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/profile_service.dart';
import '../services/purchase_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_metrics.dart';
import '../theme/app_text.dart';
import '../widgets/app_button.dart';
import '../widgets/app_icon_button.dart';
import '../widgets/difficulty_dialog.dart';
import '../widgets/host_unlock_dialog.dart';
import '../widgets/local_game_dialog.dart';
import '../widgets/profile_dialog.dart';
import '../widgets/settings_dialog.dart';
import '../widgets/sky_background.dart';
import 'game_screen.dart';
import 'intro_screen.dart';
import 'lobby_screen.dart';

/// The app's home screen: the wordmark on the left, the two actions on the
/// right. Every launch after the first lands here.
///
/// The split mirrors the intro slides (text left, content right) so the two
/// screens read as the same app in landscape.
class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  /// The name games are played under. Seeded with the default so the first
  /// frame has something to show while the real one loads.
  String _name = ProfileService.defaultName;

  @override
  void initState() {
    super.initState();
    _loadName();
  }

  /// Loads the saved name. Falls back to the default on a read failure, so the
  /// menu always has a name to play under.
  Future<void> _loadName() async {
    final name = await ProfileService.read();
    if (!mounted) return;
    setState(() => _name = name);
  }

  /// Asks how hard the AI should play, then deals. Dismissing the dialog backs
  /// out entirely — no game is started.
  Future<void> _play() async {
    final level = await showDifficultyDialog(context);
    if (!mounted || level == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GameScreen(
          playerCount: 5,
          playerName: _name,
          aiLevel: level,
        ),
      ),
    );
  }

  /// Opens the name editor, then picks up whatever it stored. The dialog saves
  /// as you type rather than on a button, so there's no result to return and no
  /// dismissal path that loses the edit.
  Future<void> _profile() async {
    await showProfileDialog(context, _name);
    if (!mounted) return;
    await _loadName();
  }

  /// Hosts or joins a game on the local network.
  ///
  /// Hosting is the paid half; joining is free and never meets the paywall.
  /// The gate sits here because this is the only route to [LobbyScreen].
  Future<void> _localGame() async {
    final result = await showLocalGameDialog(context);
    if (!mounted || result == null) return;

    if (result.choice == LocalGameChoice.host &&
        !PurchaseService.instance.canHost) {
      final unlocked = await showHostUnlockDialog(context);
      if (!mounted || unlocked != true) return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LobbyScreen(playerName: _name, joinCode: result.code),
      ),
    );
  }

  void _howToPlay() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const IntroScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: AppColors.backdrop,
      // Nothing on this screen is typed into — the keyboard only ever belongs
      // to a dialog floating above it. Left at its default, Scaffold shrinks
      // this body by the keyboard's height anyway, which squeezed the button
      // column from 375pt to 143 and overflowed it by 49. The menu should
      // simply ignore a keyboard that isn't its own.
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          const Positioned.fill(child: SkyBackground()),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 40,
                vertical: AppSpacing.lg,
              ),
              child: Row(
                children: [
                  // Scaled to fit for the same reason the intro slides are:
                  // a short landscape phone has no room for the block at full
                  // size, and scaling covers every screen height without a
                  // per-device number.
                  Expanded(
                    flex: 6,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: SizedBox(
                        width: 340,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // The wordmark is the app's name, the same in
                            // every language.
                            Text(
                              'STARDROPS',
                              style: AppText.hero,
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              l10n.menuTagline,
                              style: AppText.body,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xl),
                  Expanded(
                    flex: 4,
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 240),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            AppButton.primary(
                              label: l10n.menuPlay,
                              onTap: _play,
                            ),
                            const SizedBox(height: AppSpacing.md),
                            AppButton.ghost(
                              label: l10n.menuLocalGame,
                              onTap: _localGame,
                            ),
                            const SizedBox(height: AppSpacing.md),
                            AppButton.ghost(
                              label: l10n.menuHowToPlay,
                              onTap: _howToPlay,
                            ),
                            const SizedBox(height: AppSpacing.md),
                            AppButton.ghost(
                              label: l10n.menuSettings,
                              onTap: () => showSettingsDialog(context),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Above the Row rather than inside it, so it pins to the corner
          // instead of riding the vertically-centred wordmark. Left-aligned to
          // the same 40pt margin, so it reads as the start of the screen's
          // content rather than something stuck in the gap.
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(left: 40, top: AppSpacing.lg),
              child: Align(
                alignment: Alignment.topLeft,
                child: AppIconButton(
                  icon: Icons.person_rounded,
                  onTap: _profile,
                  semanticLabel: l10n.menuProfileLabel,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
