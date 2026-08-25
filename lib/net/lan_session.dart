/// Local-network play, both ends of it.
///
/// The wire format is one JSON object per line over a plain TCP socket. Every
/// message has a `t` (type); everything else depends on the type. Newlines
/// delimit because JSON never contains a raw one, so no length prefix or
/// framing protocol is needed.
///
/// The host is a relay, not an authority. It doesn't own the game — every
/// device deals an identical `GameState` from a shared seed, and the only
/// thing that ever crosses the wire is which seat played which card. No hands,
/// no rows, no scores: each device works those out for itself.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../services/profile_service.dart';
import 'join_code.dart';

/// The most players the table seats. The host is one of them.
const int kMaxPlayers = 5;

/// Below this the game isn't worth playing.
const int kMinPlayers = 3;

/// Why a local game couldn't start, connect, or continue.
///
/// An enum rather than a ready-made sentence because this layer has no
/// BuildContext to look a translation up with. The screen that shows the
/// failure has one, and maps these to localised text there.
enum LanError {
  /// The device isn't on a network at all.
  noWifi,

  /// On a network, but its address isn't one a join code can carry.
  noAddress,

  /// The listening socket failed after it had been opened.
  dropped,

  /// The port couldn't be opened in the first place.
  cantHost,

  /// The code isn't a code — it doesn't decode to an address at all. The join
  /// dialog catches this before dialling; this is the backstop.
  badCode,

  /// Nothing answered at the address the code decodes to.
  noGameFound,

  /// Something answered, but the connection failed for another reason.
  cantJoin,

  /// The host turned this device away: full table, or already playing.
  tableFull,
}

/// Message types. Small enough to keep in one place, and worth naming so a typo
/// in a string literal can't quietly break a handler.
class Msg {
  const Msg._();

  /// Joiner → host, first thing after connecting: `{name}`.
  static const join = 'join';

  /// Host → joiner, whenever the roster changes: `{names, seat}`. Carries the
  /// recipient's own seat because a player leaving the lobby renumbers
  /// everyone below them.
  static const lobby = 'lobby';

  /// Host → all, the game is on: `{seed, names}`.
  static const start = 'start';

  /// A card played: `{seat, card}`. Sent to the host, which relays it on.
  ///
  /// Choices are relayed one at a time rather than batched per round, because
  /// they don't need ordering: a seat's card is only recorded when it arrives,
  /// and the round doesn't resolve until every seat is in. Resolution sorts by
  /// card number, so the order they landed in can't change the outcome.
  static const play = 'play';

  /// A row taken: `{seat, row}`. Also relayed by the host.
  static const pick = 'pick';

  /// Deal another game. From a joiner it's a request with nothing in it; from
  /// the host it's `{seed}` and everyone redeals.
  static const restart = 'restart';

  /// Host → joiner, then close: the table is full or the game already started.
  static const refused = 'refused';
}

/// Encodes [msg] as one line of the wire format.
String _encodeLine(Map<String, dynamic> msg) => '${jsonEncode(msg)}\n';

/// Parses one line, or null if it isn't a usable message.
///
/// Anything can arrive on a socket, including a truncated line from a phone
/// that died mid-write. Malformed input is dropped rather than thrown.
Map<String, dynamic>? _decodeLine(String line) {
  if (line.trim().isEmpty) return null;
  try {
    final decoded = jsonDecode(line);
    if (decoded is! Map<String, dynamic>) return null;
    if (decoded['t'] is! String) return null;
    return decoded;
  } catch (e) {
    debugPrint('LanSession: dropped malformed line: $e');
    return null;
  }
}

/// One joined player, host side.
class _Peer {
  _Peer(this.socket);

  final Socket socket;
  String name = ProfileService.defaultName;

  /// False until the join message arrives, so a socket that connects and then
  /// says nothing never occupies a seat.
  bool joined = false;

  /// Assigned by the host, and -1 until then.
  ///
  /// Held rather than derived from position in the list, because a player
  /// leaving shifts every position after theirs. That's correct in the lobby
  /// and disastrous once the game is dealt — the remaining players would
  /// silently inherit each other's hands.
  int seat = -1;
}

/// The hosting end: opens a port, collects players, relays the game.
///
/// Seat 0 is always the host; joiners are numbered from 1 in the order they
/// arrived. Leaving the *lobby* renumbers everyone after you, which is why
/// each roster update re-sends every device its own seat. Leaving mid-game
/// does not: by then a seat number says whose hand is whose, and shuffling
/// them would hand players each other's cards.
class LanHost extends ChangeNotifier {
  LanHost({required this.hostName});

  final String hostName;

  ServerSocket? _server;
  final List<_Peer> _peers = [];

  /// Whoever is driving the game right now — the lobby, then the game screen.
  void Function(int seat, Map<String, dynamic> msg)? _handler;

  /// Messages that arrived while nothing was listening. A broadcast stream
  /// drops those, and there is a real gap while the lobby hands over to the
  /// game screen; a card played in that window would be lost and the table
  /// would sit waiting for a player who had already gone.
  final List<({int seat, Map<String, dynamic> msg})> _buffered = [];

  /// The code players type to join. Null until [start] succeeds.
  String? code;

  /// Why hosting failed, for showing on the lobby screen.
  LanError? error;

  /// True once the game is running: the roster is locked, late connections are
  /// refused, and seats stop being reassigned.
  bool started = false;

  /// Called when a seated player's connection goes away *during a game*. Lobby
  /// departures don't come through here — they just change the roster.
  void Function(int seat, String name)? onPlayerLeft;

  /// Set before any teardown work. Closing a socket fires its own done handler
  /// synchronously, so without this the cleanup loop would re-enter [_drop],
  /// mutate the list it's walking, and notify listeners that are already gone.
  bool _disposed = false;

  /// Registers the current consumer of player messages, replaying anything
  /// that arrived while there wasn't one. Pass null when handing over.
  set onMessage(void Function(int seat, Map<String, dynamic> msg)? handler) {
    _handler = handler;
    if (handler == null || _buffered.isEmpty) return;
    final held = [..._buffered];
    _buffered.clear();
    for (final e in held) {
      handler(e.seat, e.msg);
    }
  }

  /// Everyone at the table in seat order, the host first.
  List<String> get names => [
    hostName,
    for (final p in _peers.where((p) => p.joined)) p.name,
  ];

  bool get canStart => names.length >= kMinPlayers;

  /// Opens the port and works out the join code. Returns false and sets
  /// [error] if the device isn't on a network or the port is taken.
  Future<bool> start() async {
    try {
      final address = await JoinCode.localAddress();
      if (address == null) {
        error = LanError.noWifi;
        notifyListeners();
        return false;
      }

      final joinCode = JoinCode.encode(address);
      if (joinCode == null) {
        error = LanError.noAddress;
        notifyListeners();
        return false;
      }

      // Not `shared: true`. Sharing a port silently distributes incoming
      // connections between every listener bound to it, so a host that failed
      // to close would quietly take half the joiners of the next one. Failing
      // the bind is the honest outcome.
      _server = await ServerSocket.bind(InternetAddress.anyIPv4, JoinCode.port);
      _server!.listen(
        _accept,
        onError: (Object e) {
          debugPrint('LanHost: server error: $e');
          error = LanError.dropped;
          notifyListeners();
        },
      );

      code = joinCode;
      error = null;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('LanHost.start failed: $e');
      error = LanError.cantHost;
      notifyListeners();
      return false;
    }
  }

  void _accept(Socket socket) {
    // Refuse before allocating anything: a full table and a game already in
    // progress both mean this connection can't be seated.
    if (started || _peers.length >= kMaxPlayers - 1) {
      unawaited(_refuse(socket));
      return;
    }

    final peer = _Peer(socket);
    _peers.add(peer);

    socket
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(
          (line) => _onLine(peer, line),
          onError: (Object e) {
            debugPrint('LanHost: peer socket error: $e');
            _drop(peer);
          },
          onDone: () => _drop(peer),
          cancelOnError: true,
        );
  }

  /// Turns a connection away with a reason it can actually read.
  ///
  /// `close()` rather than `destroy()`: destroy drops whatever is still
  /// buffered and resets the connection, so the joiner would see "connection
  /// reset by peer" instead of "that game is full". close flushes the refusal
  /// first, then ends the connection cleanly.
  Future<void> _refuse(Socket socket) async {
    try {
      _write(socket, {'t': Msg.refused});
      await socket.close();
    } catch (e) {
      debugPrint('LanHost: refusing a connection failed: $e');
    }
  }

  void _onLine(_Peer peer, String line) {
    final msg = _decodeLine(line);
    if (msg == null) return;

    if (msg['t'] == Msg.join) {
      // Names arrive from another device, so they get the same cleaning as one
      // typed into the profile field: trimmed, capped, never blank.
      peer.name = ProfileService.clean(msg['name'] as String?);
      peer.joined = true;
      _reseat();
      _syncLobby();
      return;
    }

    final seat = peer.seat;
    if (seat < 1) return; // hasn't joined yet; nothing it says counts

    final handler = _handler;
    if (handler == null) {
      _buffered.add((seat: seat, msg: msg));
      return;
    }
    handler(seat, msg);
  }

  /// Numbers the joined players from 1, seat 0 being the host.
  ///
  /// Only ever called before the game starts. Once it has, seats are fixed for
  /// good: they identify whose hand is whose.
  void _reseat() {
    if (started) return;
    var seat = 1;
    for (final peer in _peers) {
      if (peer.joined) peer.seat = seat++;
    }
  }

  void _drop(_Peer peer) {
    if (_disposed) return;
    if (!_peers.remove(peer)) return;
    try {
      peer.socket.destroy();
    } catch (e) {
      debugPrint('LanHost: closing a dropped peer failed: $e');
    }

    if (started) {
      // Mid-game: the seat stays exactly where it is, and the table is told so
      // it can stop waiting on a phone that has gone.
      if (peer.seat >= 1) onPlayerLeft?.call(peer.seat, peer.name);
      notifyListeners();
      return;
    }

    _reseat();
    _syncLobby();
  }

  /// Tells every device the roster and its own seat, which changes underneath
  /// them whenever someone leaves.
  void _syncLobby() {
    if (_disposed) return;
    final roster = names;
    for (final peer in _peers.where((p) => p.joined)) {
      if (peer.seat < 1) continue;
      _write(peer.socket, {'t': Msg.lobby, 'names': roster, 'seat': peer.seat});
    }
    notifyListeners();
  }

  /// Sends [msg] to every joined player. The host isn't on the wire — it
  /// applies its own moves directly.
  void broadcast(Map<String, dynamic> msg) {
    for (final peer in _peers.where((p) => p.joined)) {
      _write(peer.socket, msg);
    }
  }

  void _write(Socket socket, Map<String, dynamic> msg) {
    try {
      socket.write(_encodeLine(msg));
    } catch (e) {
      // A dead socket shouldn't take down the round for everyone else; the
      // done/error handler will drop the peer in a moment.
      debugPrint('LanHost: write failed: $e');
    }
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    _handler = null;
    onPlayerLeft = null;
    _buffered.clear();
    // Over a copy: destroy() fires the socket's done handler synchronously,
    // and _drop removes from _peers.
    for (final peer in [..._peers]) {
      try {
        peer.socket.destroy();
      } catch (e) {
        debugPrint('LanHost.dispose: closing a peer failed: $e');
      }
    }
    _peers.clear();
    try {
      await _server?.close();
    } catch (e) {
      debugPrint('LanHost.dispose: closing the server failed: $e');
    }
    _server = null;
    super.dispose();
  }
}

/// The joining end: dials a code, then mirrors whatever the host relays.
class LanClient extends ChangeNotifier {
  Socket? _socket;

  /// See [LanHost.onMessage] — same handover problem, same fix.
  void Function(Map<String, dynamic> msg)? _handler;
  final List<Map<String, dynamic>> _buffered = [];

  /// This device's seat, once the host has assigned one.
  int? seat;

  /// Everyone at the table in seat order, as last told by the host.
  List<String> names = const [];

  /// Why connecting or playing failed, for showing on screen.
  LanError? error;

  /// True once the host has gone away. The game can't continue without it.
  bool hostLost = false;

  /// See LanHost's copy — destroying the socket runs its done handler right
  /// away, which would otherwise notify listeners that no longer exist.
  bool _disposed = false;

  /// Registers the current consumer of host messages, replaying anything that
  /// arrived while there wasn't one. Pass null when handing over.
  set onMessage(void Function(Map<String, dynamic> msg)? handler) {
    _handler = handler;
    if (handler == null || _buffered.isEmpty) return;
    final held = [..._buffered];
    _buffered.clear();
    for (final msg in held) {
      handler(msg);
    }
  }

  /// Hands a message back to be replayed for the *next* handler.
  ///
  /// For the gap between the host saying START and the game screen installing
  /// its own handler: the lobby is still the registered handler in that window,
  /// and a move it simply returned on would be gone. A move that never arrives
  /// leaves the whole table waiting on a seat that has already played, so it
  /// waits here instead.
  void hold(Map<String, dynamic> msg) => _buffered.add(msg);

  bool get connected => _socket != null;

  /// Dials the host named by [code] and announces [name]. Returns false and
  /// sets [error] on a bad code, a refused table, or no answer.
  Future<bool> connect(String code, String name) async {
    final address = JoinCode.decode(code);
    if (address == null) {
      error = LanError.badCode;
      notifyListeners();
      return false;
    }

    try {
      final socket = await Socket.connect(
        address,
        JoinCode.port,
        // Long enough for a slow phone to answer, short enough that a wrong
        // code doesn't look like a hang.
        timeout: const Duration(seconds: 6),
      );
      _socket = socket;

      socket
          .cast<List<int>>()
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
            _onLine,
            onError: (Object e) {
              debugPrint('LanClient: socket error: $e');
              _onHostLost();
            },
            onDone: _onHostLost,
            cancelOnError: true,
          );

      send({'t': Msg.join, 'name': name});
      error = null;
      notifyListeners();
      return true;
    } on SocketException catch (e) {
      debugPrint('LanClient.connect failed: $e');
      error = LanError.noGameFound;
      notifyListeners();
      return false;
    } catch (e) {
      debugPrint('LanClient.connect failed: $e');
      error = LanError.cantJoin;
      notifyListeners();
      return false;
    }
  }

  void _onLine(String line) {
    if (_disposed) return;
    final msg = _decodeLine(line);
    if (msg == null) return;

    switch (msg['t']) {
      case Msg.lobby:
        // Both are re-read on every roster change: a player leaving the lobby
        // shifts everyone below them up a seat.
        final roster = msg['names'];
        if (roster is List) {
          names = [for (final n in roster) ProfileService.clean(n as String?)];
        }
        final assigned = msg['seat'];
        if (assigned is int) seat = assigned;
        notifyListeners();

      case Msg.refused:
        error = LanError.tableFull;
        notifyListeners();

      default:
        final handler = _handler;
        if (handler == null) {
          _buffered.add(msg);
        } else {
          handler(msg);
        }
    }
  }

  void _onHostLost() {
    if (_disposed || hostLost) return;
    hostLost = true;
    _socket = null;
    notifyListeners();
  }

  void send(Map<String, dynamic> msg) {
    final socket = _socket;
    if (socket == null) return;
    try {
      socket.write(_encodeLine(msg));
    } catch (e) {
      debugPrint('LanClient: write failed: $e');
      _onHostLost();
    }
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    _handler = null;
    _buffered.clear();
    try {
      _socket?.destroy();
    } catch (e) {
      debugPrint('LanClient.dispose: closing the socket failed: $e');
    }
    _socket = null;
    super.dispose();
  }
}
