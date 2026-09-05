import 'package:flutter/material.dart';
import '../game/game_state.dart';
import '../l10n/app_localizations.dart';
import '../logic/ai_strategy.dart';
import '../models/take_card.dart';
import '../models/take_player.dart';
import '../net/lan_session.dart';
import '../net/net_game.dart';
import '../services/sfx.dart';
import '../services/stats_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_metrics.dart';
import '../theme/app_text.dart';
import '../widgets/app_button.dart';
import '../widgets/app_dialog.dart';
import '../widgets/app_icon_button.dart';
import '../widgets/card_flight.dart';
import '../widgets/game_over_overlay.dart';
import '../widgets/player_hand.dart';
import '../widgets/player_sidebar.dart';
import '../widgets/settings_dialog.dart';
import '../widgets/sky_background.dart';
import '../widgets/table_grid.dart';
import 'menu_screen.dart';

/// Everything a local multiplayer game needs that a solo one doesn't. Bundled
/// so the pieces can't be passed half-set: the seed and the roster are
/// meaningless without each other, and exactly one of [host]/[client] applies.
typedef NetSetup = ({
  List<String> names,
  int localSeat,
  int seed,
  LanHost? host,
  LanClient? client,
});

class GameScreen extends StatefulWidget {
  final int playerCount;
  final String playerName;

  /// Null for a solo game against the AI; set when playing over the network.
  final NetSetup? net;

  /// How hard the AI seats play. Unused over the network, where every seat is
  /// a person. Defaults to normal for the first-run tutorial, which hands
  /// straight into a game without asking.
  final AiLevel aiLevel;

  const GameScreen({
    super.key,
    required this.playerCount,
    required this.playerName,
    this.net,
    this.aiLevel = AiLevel.normal,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final GameState _gs;

  /// Null in a solo game. Owns the sockets for the rest of this game's life —
  /// the lobby hands them over on START and stops touching them.
  NetGame? _net;

  bool get _isNet => _net != null;

  // Measured to fly a card from a player's sidebar slot into a row slot. Sized
  // from the dealt table rather than widget.playerCount, which a networked
  // game doesn't set.
  late final List<GlobalKey> _sidebarKeys;
  final List<List<GlobalKey>> _slotKeys = List.generate(
    4,
    (_) => List.generate(5, (_) => GlobalKey()),
  );

  bool _flightInProgress = false;
  bool _takeInProgress = false;
  TakePlayer? _hiddenSidebarPlayer; // source card, hidden while its copy flies
  int? _takingRowHidden; // row whose cards are hidden while the pile flies

  bool _resultRecorded =
      false; // guards against recording a game's result twice

  /// The lifetime record at the difficulty just played, read back once the
  /// finished game has been counted into it. Null over the network, where
  /// there is no difficulty to file a result under, and null until the read
  /// returns — the overlay shows the line only with a real number behind it.
  ({AiLevel level, LevelRecord record})? _record;

  // The host can drop out more than once as the socket unwinds; the dialog
  // announcing it should only ever appear once.
  bool _hostLostShown = false;

  static const _flightDuration = Duration(milliseconds: 450);
  static const _takePileDuration = Duration(milliseconds: 1400);

  /// Guards [didChangeDependencies], which Flutter calls again on any
  /// inherited-widget change — a language switch, for one. Dealing twice would
  /// throw away a game in progress.
  bool _dealt = false;

  @override
  void initState() {
    super.initState();
    _gs = GameState();
  }

  /// The deal happens here rather than in [initState] because the AI seats are
  /// named from the translations, and looking one up is an inherited-widget
  /// lookup — which isn't allowed until initState has finished.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_dealt) return;
    _dealt = true;

    final net = widget.net;
    if (net == null) {
      _gs.startSinglePlayer(
        widget.playerCount,
        widget.playerName,
        aiName: AppLocalizations.of(context)!.gameAiName,
        aiLevel: widget.aiLevel,
      );
    } else {
      // Same names, same seed on every device, so all of them deal the same
      // hands and rows without a card crossing the wire. No AI seats: a local
      // game is people all the way round.
      _gs.startGame(
        names: net.names,
        localSeat: net.localSeat,
        aiSeats: const {},
        seed: net.seed,
      );
      _net = NetGame(
        gs: _gs,
        host: net.host,
        client: net.client,
        onRestart: _onRedeal,
        onPlayerLeft: _onPlayerLeft,
        onHostLost: _onHostLost,
      );
    }

    _sidebarKeys = List.generate(_gs.players.length, (_) => GlobalKey());
    _gs.addListener(_rebuild);
  }

  void _rebuild() {
    setState(() {});
    // The game moving on is the only thing that can make an early move
    // playable, or leave the table waiting on a seat whose phone has gone.
    _net?.catchUp();
    if (_gs.gameOver && !_resultRecorded) {
      _resultRecorded = true;
      _recordResult();
    }
    // Hold new animations while the menu is open — an overlay entry inserted
    // now would be added above the dialog route and draw on top of it.
    // GameState.resume() notifies, which re-runs this method to pick them up.
    if (_gs.isPaused) return;
    // A row take runs first (pile flies to the taker); committing it stages the
    // new card's flight, which this same method then picks up on a later notify.
    final t = _gs.rowTake;
    if (t != null && !_takeInProgress) {
      _takeInProgress = true;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _runRowTake(t, _gs.generation),
      );
      return;
    }
    final f = _gs.flight;
    if (f != null && !_flightInProgress) {
      _flightInProgress = true;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _runFlight(f, _gs.generation),
      );
    }
  }

  Future<void> _runRowTake(RowTake t, int gen) async {
    if (!mounted) return;
    final fromRects = [
      for (var i = 0; i < t.takenCards.length; i++)
        _rectFor(_slotKeys[t.rowIdx][i]),
    ];
    final sidebarRect = _rectFor(_sidebarKeys[t.player.seat]);

    if (sidebarRect != null && fromRects.every((r) => r != null)) {
      final entry = OverlayEntry(
        builder: (_) => TakePile(
          cards: t.takenCards,
          fromRects: [for (final r in fromRects) r!],
          pileRect: fromRects[0]!,
          sidebarRect: sidebarRect,
          duration: _takePileDuration,
        ),
      );
      Overlay.of(context).insert(entry);
      setState(() => _takingRowHidden = t.rowIdx);
      // Riffle across the gather phase only — by the time the pile is flying
      // to the taker the cards have already been swept up.
      Sfx.rowGather(
        t.takenCards.length,
        _takePileDuration * TakePile.gatherFraction,
      );
      await Future.delayed(_takePileDuration);
      if (!mounted) {
        entry.remove();
        return;
      }
      _takingRowHidden = null;
      _takeInProgress = false;
      _gs.commitRowTake(gen); // empties row + stages the new card's flight
      entry.remove();
    } else {
      _takingRowHidden = null;
      _takeInProgress = false;
      _gs.commitRowTake(gen);
    }
  }

  Future<void> _runFlight(CardFlight f, int gen) async {
    if (!mounted) return;
    final from = _rectFor(_sidebarKeys[f.player.seat]);
    final to = _rectFor(_slotKeys[f.rowIdx][f.slotIdx]);

    // Null rects mean the keys weren't laid out — place without animating.
    OverlayEntry? entry;
    if (from != null && to != null) {
      entry = OverlayEntry(
        builder: (_) => FlyingCard(
          card: f.card,
          from: from,
          to: to,
          duration: _flightDuration,
        ),
      );
      Overlay.of(context).insert(entry);
      setState(() => _hiddenSidebarPlayer = f.player);
      // At the start of the flight, not the end: it's a travel sound, so it
      // has to run under the card's movement rather than mark its arrival.
      Sfx.cardMove();
      await Future.delayed(_flightDuration);
      if (!mounted) {
        entry.remove();
        return;
      }
    }
    // Commit first so the row card is painted, then drop the overlay — the
    // two coincide at the destination, so there's no blank frame.
    _hiddenSidebarPlayer = null;
    _flightInProgress = false;
    _gs.commitFlight(gen);
    entry?.remove();
  }

  Rect? _rectFor(GlobalKey key) {
    final box = key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  /// Clears the per-game state held outside [GameState] when a fresh game is
  /// dealt. Shared by solo PLAY AGAIN and a redeal arriving from the host.
  void _onRedeal() {
    if (!mounted) return;
    setState(() {
      _resultRecorded = false;
      _record = null;
    });
  }

  /// Counts the finished game, then reads the record back so the results
  /// overlay can show a total that already includes it — a counter the player
  /// never sees move is no reason to play again.
  ///
  /// Both halves can fail; [StatsService] logs and swallows, and this leaves
  /// the line hidden rather than showing a count that might be wrong.
  Future<void> _recordResult() async {
    // Networked seats are people, so there's no difficulty to file the game
    // under and no per-level record to show afterwards.
    final level = _isNet ? null : widget.aiLevel;
    await StatsService.recordResult(playerWon: _gs.localWon, level: level);
    if (level == null || !mounted) return;

    final record = (await StatsService.read())?.byLevel[level];
    if (record == null || !mounted) return;
    setState(() => _record = (level: level, record: record));
  }

  /// Host side: somebody's phone went away. The game carries on — the host
  /// answers for the empty seat — so this is news, not an interruption.
  void _onPlayerLeft(String name) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppLocalizations.of(context)!.gamePlayerLeft(name),
          style: AppText.caption,
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  /// Joiner side: the host is gone, and with it the only thing relaying moves
  /// between the phones. There is no game left to be in.
  Future<void> _onHostLost() async {
    if (!mounted || _hostLostShown) return;
    _hostLostShown = true;
    // Freeze first: cards would otherwise keep flying behind the dialog, and
    // an overlay inserted while it is up draws on top of it.
    _gs.pause();

    final l10n = AppLocalizations.of(context)!;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: AppDialog(
          title: l10n.gameOver,
          children: [
            Text(
              l10n.gameHostLeft,
              style: AppText.body,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.md),
            AppButton.dialog(
              label: l10n.gameMenu,
              filled: false,
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    _leaveToMenu();
  }

  /// What this device is waiting on, or null if it's this player's move.
  ///
  /// Solo play never needs this — the AI answers instantly. Over the network
  /// there are real seconds where the board is frozen on somebody else's
  /// thinking, and without a word about whose, a working game looks hung.
  String? get _waitingOn {
    if (!_isNet || _gs.gameOver) return null;
    final l10n = AppLocalizations.of(context)!;

    if (_gs.choosingRow && !_gs.isLocalRowChoice) {
      final seat = _gs.rowChooserSeat;
      final who = (seat != null && seat >= 0 && seat < _gs.players.length)
          ? _gs.players[seat].name
          : l10n.gameSomeone;
      return l10n.gameTakingRow(who);
    }

    // Card played, round not resolved: still short of somebody.
    if (!_gs.revealPhase && _gs.localPlayer.selectedCard != null) {
      final missing = _gs.players.where((p) => p.selectedCard == null).length;
      if (missing == 0) return null;
      return l10n.gameWaitingForPlayers(missing);
    }

    return null;
  }

  /// Plays the highlighted card, and tells the table if it was accepted.
  ///
  /// [GameState.confirmSelection] clears the highlight only on success, which
  /// is what's checked here — a card refused locally must never be announced.
  void _confirm() {
    final card = _gs.selectedCard;
    if (card == null) return;
    _gs.confirmSelection();
    if (_gs.selectedCard == null) _net?.sendPlay(card);
  }

  /// Takes a row, and tells the table if the rules allowed it.
  void _pickRow(int rowIdx) {
    if (_gs.pickRow(_gs.localSeat, rowIdx)) _net?.sendPick(rowIdx);
  }

  /// Deals another game. Solo does it directly; over the network the host
  /// picks the seed, so everyone redeals the same one.
  void _playAgain() {
    final net = _net;
    if (net == null) {
      _onRedeal();
      _gs.reset();
    } else {
      net.requestRestart();
    }
  }

  @override
  void dispose() {
    _gs.removeListener(_rebuild);
    _net?.dispose();
    // The game screen owns the sockets once the lobby hands them over, so
    // leaving the game is what closes them.
    widget.net?.host?.dispose();
    widget.net?.client?.dispose();
    _gs.dispose();
    super.dispose();
  }

  void _openMenu() {
    _gs.pause();
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      barrierDismissible: false,
      // Android's back gesture pops a dialog route even with
      // barrierDismissible: false. Unhandled, that skips RESUME and strands the
      // game paused forever, so back is treated as RESUME.
      builder: (_) => PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          Navigator.pop(context);
          _gs.resume();
        },
        child: AppDialog(
          title: l10n.gameMenu,
          children: [
            AppButton.dialog(
              label: l10n.gameAbandon,
              filled: true,
              onTap: () {
                Navigator.pop(context);
                _leaveToMenu();
              },
            ),
            const SizedBox(height: AppSpacing.md),
            // The same dialog the menu screen opens, rather than a second copy
            // of its controls inline here.
            AppButton.dialog(
              label: l10n.menuSettings,
              filled: false,
              onTap: () => showSettingsDialog(context),
            ),
            const SizedBox(height: AppSpacing.md),
            AppButton.dialog(
              label: l10n.gameResume,
              filled: false,
              onTap: () {
                Navigator.pop(context);
                _gs.resume();
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Returns to the menu. Pops when the game was pushed from it; on a fresh
  /// install the tutorial hands straight off to a game, so this route is the
  /// root and there's nothing to pop back to. Shared by the in-game menu's
  /// ABANDON GAME and the game-over MENU button.
  void _leaveToMenu() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MenuScreen()),
      );
    }
  }

  /// Handles Android's back and iOS's edge-swipe. Both used to pop the route
  /// outright, throwing away a game in progress with no confirmation while
  /// ABANDON GAME sat behind a dialog two taps away. Back now opens that same
  /// dialog, so leaving is always deliberate.
  ///
  /// `Navigator.pop` still works from inside it: `canPop: false` only blocks
  /// the *system* pop, which is what ABANDON GAME and the game-over MENU
  /// button rely on.
  void _onBack() {
    // Nothing left to lose once the results are up — back matches MENU there.
    if (_gs.gameOver) {
      _leaveToMenu();
      return;
    }
    // Already paused means the dialog is up and handling back itself; opening
    // a second one would stack them.
    if (!_gs.isPaused) _openMenu();
  }

  @override
  Widget build(BuildContext context) {
    final isSelecting = !_gs.revealPhase && !_gs.choosingRow && !_gs.gameOver;
    final showSelections = _gs.revealPhase || _gs.choosingRow;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _onBack();
      },
      child: Scaffold(
        backgroundColor: AppColors.backdrop,
        body: Stack(
          children: [
            // No twinkle here — nothing on the table should compete with the
            // cards for attention.
            const Positioned.fill(child: SkyBackground(twinkle: false)),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // The menu heads the sidebar column rather than sitting
                    // in a full-width strip of its own. That strip cost the
                    // table ~52pt of height to show one button, and left the
                    // sidebar needing a hand-tuned offset to hang below it.
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppIconButton(
                          icon: Icons.menu,
                          onTap: _openMenu,
                          semanticLabel: AppLocalizations.of(context)!
                              .gameMenuLabel,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        PlayerSidebar(
                          players: _gs.players,
                          currentPlayer: _gs.lastPlacingPlayer,
                          showSelections: showSelections,
                          cardKeys: _sidebarKeys,
                          hiddenPlayer: _hiddenSidebarPlayer,
                          localSeat: _gs.localSeat,
                        ),
                      ],
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: TableGrid(
                              rows: _gs.rows,
                              lastAffectedRow: _gs.lastAffectedRow,
                              lastWasTake: _gs.lastWasTake,
                              choosingRow: _gs.isLocalRowChoice,
                              onPickRow: _pickRow,
                              slotKeys: _slotKeys,
                              hiddenRow: _takingRowHidden,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          _BottomBar(
                            hand: _gs.localPlayer.hand,
                            selectedCard: _gs.selectedCard,
                            interactive: isSelecting,
                            onSelectCard: _gs.selectCard,
                            onConfirm: isSelecting && _gs.selectedCard != null
                                ? _confirm
                                : null,
                            waitingOn: _waitingOn,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_gs.gameOver)
              GameOverOverlay(
                players: _gs.sortedByStars,
                localWon: _gs.localWon,
                isTie: _gs.isTie,
                localSeat: _gs.localSeat,
                record: _record,
                onPlayAgain: _playAgain,
                onMenu: _leaveToMenu,
              ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════
// BOTTOM BAR (hand + confirm button)
// ═══════════════════════════════════════════

class _BottomBar extends StatelessWidget {
  final List<TakeCard> hand;
  final TakeCard? selectedCard;
  final bool interactive;
  final void Function(TakeCard) onSelectCard;
  final VoidCallback? onConfirm;

  /// Set when the table is waiting on somebody else. Takes the button's place
  /// rather than sitting beside it — a disabled CONFIRM says nothing about who
  /// or how long, and there's no room on a landscape phone for both.
  final String? waitingOn;

  const _BottomBar({
    required this.hand,
    required this.selectedCard,
    required this.interactive,
    required this.onSelectCard,
    required this.onConfirm,
    required this.waitingOn,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: PlayerHand(
            hand: hand,
            selectedCard: selectedCard,
            interactive: interactive,
            onSelectCard: onSelectCard,
          ),
        ),
        SizedBox(
          width: 100,
          child: waitingOn == null
              ? AppButton.primary(
                  label: selectedCard != null
                      ? AppLocalizations.of(context)!.gameConfirm
                      : AppLocalizations.of(context)!.gameSelect,
                  onTap: onConfirm,
                  horizontalPadding: AppSpacing.md,
                  compact: true,
                )
              : Center(
                  child: Text(
                    waitingOn!,
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    style: AppText.chip.copyWith(color: AppColors.mist),
                  ),
                ),
        ),
      ],
    );
  }
}
