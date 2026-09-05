import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../net/lan_session.dart';
import '../services/profile_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_metrics.dart';
import '../theme/app_text.dart';
import '../widgets/app_button.dart';
import '../widgets/sky_background.dart';
import 'game_screen.dart';

/// The waiting room, both sides of it.
///
/// Hosting and joining are the same screen because they show the same thing:
/// the code, and who's at the table. The only difference is that the host has
/// the START button and the joiners wait for it. Splitting them into two
/// screens would have duplicated the roster, the layout, and the leave
/// handling to change one button.
class LobbyScreen extends StatefulWidget {
  /// The name this device plays under.
  final String playerName;

  /// Null hosts a new game; a code joins an existing one.
  final String? joinCode;

  const LobbyScreen({super.key, required this.playerName, this.joinCode});

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  LanHost? _host;
  LanClient? _client;

  bool get _isHost => widget.joinCode == null;

  /// True until the host has opened its port or the joiner has connected.
  bool _connecting = true;

  LanError? _error;

  /// Set once the game screen has taken over the sockets, so this screen stops
  /// owning them and doesn't close them on the way out.
  bool _handedOff = false;

  @override
  void initState() {
    super.initState();
    _connect();
  }

  Future<void> _connect() async {
    if (_isHost) {
      final host = LanHost(hostName: widget.playerName)..addListener(_onChange);
      _host = host;
      final ok = await host.start();
      if (!mounted) return;
      setState(() {
        _connecting = false;
        if (!ok) _error = host.error;
      });
    } else {
      final client = LanClient()..addListener(_onChange);
      // Registered before connecting: the host could send START the moment the
      // roster is full, and a message that arrives with nobody listening is
      // held rather than dropped.
      client.onMessage = _onHostMessage;
      _client = client;
      final ok = await client.connect(widget.joinCode!, widget.playerName);
      if (!mounted) return;
      setState(() {
        _connecting = false;
        if (!ok) _error = client.error;
      });
    }
  }

  /// True when the host's socket closed on a device that had been let in.
  /// Tracked separately from [_error] because it isn't a [LanError] — nothing
  /// failed, the other end simply left.
  bool get _hostLeft => (_client?.hostLost ?? false) && _error == null;

  void _onChange() {
    if (!mounted) return;
    setState(() {
      // A specific reason wins over the generic one. Being turned away from a
      // full table also closes the socket, so reporting hostLost ahead of an
      // error would tell someone who was never let in that "the host left".
      _error = _host?.error ?? _client?.error;
    });
  }

  /// Turns a failure into something the player can read, in their language.
  /// Lives here rather than in the net layer, which has no BuildContext.
  static String errorText(AppLocalizations l10n, LanError error) =>
      switch (error) {
        LanError.noWifi => l10n.netNoWifi,
        LanError.noAddress => l10n.netNoAddress,
        LanError.dropped => l10n.netDropped,
        LanError.cantHost => l10n.netCantHost,
        LanError.badCode => l10n.joinBadCode,
        LanError.noGameFound => l10n.netNoGameFound,
        LanError.cantJoin => l10n.netCantJoin,
        LanError.tableFull => l10n.netTableFull,
      };

  @override
  void dispose() {
    _host?.removeListener(_onChange);
    _client?.removeListener(_onChange);
    // Only if the game screen didn't take them: closing the sockets here would
    // end the game that just started.
    if (!_handedOff) {
      _host?.dispose();
      _client?.dispose();
    }
    super.dispose();
  }

  /// The host said the game is on. Everything needed to deal it is in the
  /// message, because every device deals its own.
  void _onHostMessage(Map<String, dynamic> msg) {
    if (msg['t'] != Msg.start) {
      // A game move, arriving after START but before the game screen has taken
      // the handler over. Held for it rather than dropped — but only once the
      // handover is actually under way. Before that there is no next handler
      // coming, and holding would just accumulate messages for a game this
      // device isn't in.
      if (_handedOff) _client?.hold(msg);
      return;
    }

    final seed = msg['seed'];
    final roster = msg['names'];
    final seat = _client?.seat;
    if (seed is! int || roster is! List || seat == null) {
      debugPrint('LobbyScreen: ignoring a malformed start');
      return;
    }

    final names = [for (final n in roster) ProfileService.clean(n as String?)];
    // Checked before the game screen is pushed: GameState.startGame refuses an
    // unplayable roster by returning early, leaving its `late` fields unset,
    // and the game screen reads players.length the moment it's built.
    if (names.length < kMinPlayers || names.length > kMaxPlayers) {
      debugPrint('LobbyScreen: start named an unplayable roster');
      return;
    }
    if (seat < 0 || seat >= names.length) {
      debugPrint('LobbyScreen: start named a seat this device does not hold');
      return;
    }

    _toGame(
      names: names,
      localSeat: seat,
      seed: seed,
      host: null,
      client: _client,
    );
  }

  /// Everyone at the table, in seat order.
  List<String> get _names =>
      _isHost ? (_host?.names ?? const []) : (_client?.names ?? const []);

  /// This device's row in the roster. The host is always seat 0; a joiner is
  /// told its seat, and re-told whenever someone above it leaves.
  int? get _localSeat => _isHost ? 0 : _client?.seat;

  /// Copies the code so the host can paste it into a message.
  Future<void> _copyCode() async {
    final code = _host?.code;
    if (code == null) return;
    try {
      await Clipboard.setData(ClipboardData(text: code));
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.lobbyCodeCopied, style: AppText.caption),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      debugPrint('LobbyScreen._copyCode failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final names = _names;
    final host = _host;
    final l10n = AppLocalizations.of(context)!;
    final error = _error;

    return Scaffold(
      backgroundColor: AppColors.backdrop,
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
                  // Left/right split, matching the menu and the intro slides so
                  // the three read as the same app in landscape.
                  Expanded(
                    flex: 6,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: SizedBox(
                        width: 340,
                        child: _LeftColumn(
                          isHost: _isHost,
                          connecting: _connecting,
                          error: error != null
                              ? errorText(l10n, error)
                              : (_hostLeft ? l10n.netHostLeft : null),
                          code: host?.code,
                          onCopy: _copyCode,
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
                            _Roster(names: names, localSeat: _localSeat),
                            const SizedBox(height: AppSpacing.lg),
                            if (_isHost)
                              AppButton.primary(
                                label: l10n.lobbyStart,
                                // Disabled rather than hidden, so the host can
                                // see the button they're waiting to be able to
                                // press.
                                onTap: (host?.canStart ?? false)
                                    ? _start
                                    : null,
                              ),
                            const SizedBox(height: AppSpacing.md),
                            AppButton.ghost(
                              label: l10n.lobbyLeave,
                              onTap: () => Navigator.pop(context),
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
        ],
      ),
    );
  }

  /// Host only: locks the roster, picks the deal, and tells everyone.
  void _start() {
    final host = _host;
    if (host == null || !host.canStart) return;

    // Locked before anything is sent. From here a late connection is refused,
    // so the roster in the start message is the roster that plays.
    host.started = true;
    final names = host.names;
    final seed = Random().nextInt(1 << 31);

    host.broadcast({'t': Msg.start, 'seed': seed, 'names': names});
    _toGame(
      names: names,
      localSeat: 0,
      seed: seed,
      host: host,
      client: null,
    );
  }

  /// Hands the sockets to the game screen and replaces this route, so leaving
  /// the game goes back to the menu rather than to a lobby that has moved on.
  void _toGame({
    required List<String> names,
    required int localSeat,
    required int seed,
    required LanHost? host,
    required LanClient? client,
  }) {
    if (!mounted) return;
    _handedOff = true;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => GameScreen(
          // Unused on this path — the roster and seat come from net.
          playerCount: names.length,
          playerName: widget.playerName,
          net: (
            names: names,
            localSeat: localSeat,
            seed: seed,
            host: host,
            client: client,
          ),
        ),
      ),
    );
  }
}

/// Left column: what this screen is, and the code if we're hosting.
class _LeftColumn extends StatelessWidget {
  final bool isHost;
  final bool connecting;
  final String? error;
  final String? code;
  final VoidCallback onCopy;

  const _LeftColumn({
    required this.isHost,
    required this.connecting,
    required this.error,
    required this.code,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isHost ? l10n.localGameTitle : l10n.lobbyJoining,
          style: AppText.hero,
        ),
        const SizedBox(height: AppSpacing.sm),
        if (error != null)
          Text(
            error!,
            style: AppText.body.copyWith(color: AppColors.penalty),
          )
        else if (connecting)
          Text(
            isHost ? l10n.lobbyOpening : l10n.lobbyConnecting,
            style: AppText.body,
          )
        else if (isHost && code != null) ...[
          Text(
            l10n.lobbyShareCode,
            style: AppText.body,
          ),
          const SizedBox(height: AppSpacing.lg),
          // Tappable: sending the code beats reading it out, even a short one.
          GestureDetector(
            onTap: onCopy,
            child: Text(
              code!,
              style: AppText.hero.copyWith(color: AppColors.accent),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(l10n.lobbyTapToCopy, style: AppText.label),
        ] else
          Text(l10n.lobbyWaitingForHost, style: AppText.body),
      ],
    );
  }
}

/// Right column: who's at the table, and the empty seats still open.
class _Roster extends StatelessWidget {
  final List<String> names;

  /// Which row is this device. Not always 0 — seat 0 is the host, so on a
  /// joining phone that row is somebody else.
  final int? localSeat;

  const _Roster({required this.names, required this.localSeat});

  @override
  Widget build(BuildContext context) {
    final short = names.length < kMinPlayers;
    final l10n = AppLocalizations.of(context)!;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.lobbyPlayerCount(names.length, kMaxPlayers),
          style: AppText.label,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.md),
        for (final (i, name) in names.indexed) ...[
          if (i > 0) const SizedBox(height: AppSpacing.sm),
          _Seat(label: name, isYou: i == localSeat),
        ],
        if (short) ...[
          const SizedBox(height: AppSpacing.md),
          Text(
            l10n.lobbyNeedMore(kMinPlayers),
            style: AppText.caption.copyWith(color: AppColors.textFaint),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}

class _Seat extends StatelessWidget {
  final String label;
  final bool isYou;

  const _Seat({required this.label, required this.isYou});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: isYou
            ? AppColors.accent.withValues(alpha: 0.2)
            : Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.surface),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: AppText.caption.copyWith(
          color: isYou ? AppColors.accent : AppColors.textSecondary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
