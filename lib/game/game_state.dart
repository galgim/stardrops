import 'dart:math';

import 'package:flutter/foundation.dart';
import '../models/take_card.dart';
import '../models/game_row.dart';
import '../models/take_player.dart';
import '../logic/ai_strategy.dart';

typedef _Placement = ({TakePlayer player, TakeCard card});

/// A card in flight from a player's sidebar slot to a row slot. While this is
/// non-null the row is *not* yet mutated — the UI animates the card, then calls
/// [GameState.commitFlight] to apply the placement and advance.
typedef CardFlight = ({TakePlayer player, TakeCard card, int rowIdx, int slotIdx});

/// A row being taken. While non-null the row is *not* yet cleared — the UI flies
/// [takenCards] to [player], then calls [GameState.commitRowTake].
typedef RowTake = ({
  TakePlayer player,
  TakeCard newCard,
  int rowIdx,
  List<TakeCard> takenCards,
});

/// How a game was set up, kept so PLAY AGAIN can deal a fresh one without the
/// caller having to hold onto the arguments.
typedef GameSetup = ({
  List<String> names,
  int localSeat,
  Set<int> aiSeats,
  AiLevel aiLevel,
});

class GameState extends ChangeNotifier {
  late List<TakePlayer> players;
  late List<GameRow> rows;
  int round = 0;
  bool gameOver = false;

  /// Which seat this device is playing. Every device runs an identical
  /// [GameState] and differs only in this number and in which hand it shows.
  int localSeat = 0;

  /// How well the AI seats play. Irrelevant in a local multiplayer game, where
  /// there aren't any.
  AiLevel aiLevel = AiLevel.hard;

  GameSetup? _setup;

  TakeCard? selectedCard;

  bool revealPhase = false;
  List<_Placement> _placements = [];
  int _placementIdx = 0;

  /// True on *every* device while some seat is choosing a row to take — the
  /// game is stalled for all of them. [rowChooserSeat] says whose choice it is;
  /// only that device may answer.
  bool choosingRow = false;
  int? rowChooserSeat;
  TakeCard? _pendingRowCard;

  // UI feedback for the currently-resolving placement
  TakePlayer? lastPlacingPlayer;
  int? lastAffectedRow;
  bool lastWasTake = false;

  // Non-null while a placed card is animating into its row slot.
  CardFlight? flight;

  // Non-null while a taken row's cards are animating to the taking player.
  RowTake? rowTake;

  // Bumped on every new game; delayed/flight callbacks captured under an old
  // generation become no-ops so a stale timer can't touch a fresh game.
  int generation = 0;

  bool _disposed = false;
  bool _paused = false;
  void Function()? _pendingAction;

  /// The seat this device plays.
  TakePlayer get localPlayer => players[localSeat];

  /// True while this device is the one being asked to pick a row. Other
  /// devices are in [choosingRow] too, but only watching.
  bool get isLocalRowChoice => choosingRow && rowChooserSeat == localSeat;

  /// The fewest stars anyone holds — the winning score.
  int get _bestScore =>
      players.map((p) => p.totalStars).reduce((a, b) => a < b ? a : b);

  /// True when this device's player holds (or is tied for) the fewest stars. A
  /// tie counts as a win rather than handing it to someone else — which does
  /// mean that in a tied local game, every tied device says it won. That's the
  /// friendlier read of a draw, and [isTie] is there to say so out loud.
  bool get localWon => localPlayer.totalStars == _bestScore;

  /// True when more than one player shares the winning score.
  bool get isTie => players.where((p) => p.totalStars == _bestScore).length > 1;

  /// Players ordered best-first. Ties break toward this device's player, then
  /// by seating order — Dart's sort makes no stability guarantee, so without an
  /// explicit tiebreak the podium order (and the winner) would be arbitrary.
  ///
  /// This is the one piece of state that legitimately differs between devices:
  /// it's a presentation order, not a rule, and each device puts its own player
  /// at the top of a draw.
  List<TakePlayer> get sortedByStars {
    final sorted = [...players];
    sorted.sort((a, b) {
      final byStars = a.totalStars.compareTo(b.totalStars);
      if (byStars != 0) return byStars;
      if ((a.seat == localSeat) != (b.seat == localSeat)) {
        return a.seat == localSeat ? -1 : 1;
      }
      return a.seat.compareTo(b.seat);
    });
    return sorted;
  }

  /// Cards in the deck, numbered 1..[deckSize].
  static const deckSize = 104;

  /// Ten cards per player plus one to start each of the four rows, out of
  /// [deckSize]. Past this the deal runs off the end of the deck.
  static const maxPlayers = 10;

  /// Deals a game. [names] is in seat order, [aiSeats] names the seats that
  /// play themselves, and [localSeat] is the seat this device holds.
  ///
  /// [seed] fixes the shuffle. In a local multiplayer game every device calls
  /// this with the same names and the same seed, which is what makes them deal
  /// identical hands without a single card crossing the network. Null seeds a
  /// fresh game from the system clock, which is what single player wants.
  void startGame({
    required List<String> names,
    required int localSeat,
    required Set<int> aiSeats,
    AiLevel aiLevel = AiLevel.hard,
    int? seed,
  }) {
    // A start arriving from another device could name any number of players.
    // Refusing here beats a RangeError halfway through dealing.
    if (names.isEmpty || names.length > maxPlayers) {
      debugPrint('GameState.startGame: ${names.length} players is not playable');
      return;
    }

    generation++;
    this.localSeat = localSeat.clamp(0, names.length - 1);
    this.aiLevel = aiLevel;
    _setup = (
      names: names,
      localSeat: this.localSeat,
      aiSeats: aiSeats,
      aiLevel: aiLevel,
    );

    final deck = List.generate(deckSize, (i) => TakeCard.fromNumber(i + 1))
      ..shuffle(seed == null ? null : Random(seed));

    players = [
      for (final (i, name) in names.indexed)
        TakePlayer(seat: i, name: name, isAi: aiSeats.contains(i)),
    ];

    for (final p in players) {
      p.hand = deck.sublist(0, 10);
      deck.removeRange(0, 10);
      // Sorted once here rather than on every build; removal preserves order.
      // AI hands are left in deal order — nothing ever displays them, and
      // sorting would silently change which of two equally-scored cards
      // AiStrategy.chooseCard settles on.
      if (!p.isAi) p.hand.sort((a, b) => a.number.compareTo(b.number));
    }

    rows = List.generate(4, (i) => GameRow([deck[i]]));

    round = 1;
    gameOver = false;
    revealPhase = false;
    choosingRow = false;
    rowChooserSeat = null;
    _pendingRowCard = null;
    selectedCard = null;
    _clearFeedback();
    notifyListeners();
  }

  /// Convenience for the one-device game: you in seat 0, AI in the rest, all
  /// of them playing at [aiLevel].
  ///
  /// [aiName] builds the name for computer seat n. Passed in rather than
  /// formatted here because the name is translated, and looking a translation
  /// up needs a BuildContext the rules layer doesn't have. The names are baked
  /// into the setup, so a redeal reuses them without needing the caller again —
  /// which does mean AI seats keep the language the game was dealt in until a
  /// new one is started.
  void startSinglePlayer(
    int playerCount,
    String playerName, {
    required String Function(int) aiName,
    AiLevel aiLevel = AiLevel.normal,
  }) => startGame(
    names: [
      playerName,
      for (int i = 1; i < playerCount; i++) aiName(i),
    ],
    localSeat: 0,
    aiSeats: {for (int i = 1; i < playerCount; i++) i},
    aiLevel: aiLevel,
  );

  /// Deals another game with the same players. [seed] must be supplied (and
  /// shared) in a local multiplayer game so every device deals the same one.
  void reset({int? seed}) {
    final setup = _setup;
    if (setup == null) return; // nothing has been dealt yet; nothing to redeal
    _pendingAction = null;
    _paused = false;
    startGame(
      names: setup.names,
      localSeat: setup.localSeat,
      aiSeats: setup.aiSeats,
      aiLevel: setup.aiLevel,
      seed: seed,
    );
  }

  /// True while the game is suspended by the in-game menu. The UI checks this
  /// before kicking off a new card animation — an overlay inserted while a
  /// dialog is open would draw on top of it.
  bool get isPaused => _paused;

  void pause() {
    if (_paused) return;
    _paused = true;
    notifyListeners();
  }

  void resume() {
    if (!_paused) return;
    _paused = false;
    final action = _pendingAction;
    _pendingAction = null;
    action?.call();
    // Always notify, even with nothing pending: an animation may have been
    // held back while paused and needs the UI to pick it up again.
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _delayed(Duration d, void Function() fn) {
    final gen = generation;
    Future.delayed(d, () {
      if (_disposed || gen != generation) return;
      if (_paused) {
        _pendingAction = fn;
        return;
      }
      fn();
    });
  }

  void _clearFeedback() {
    lastPlacingPlayer = null;
    lastAffectedRow = null;
    lastWasTake = false;
    flight = null;
    rowTake = null;
  }

  void selectCard(TakeCard card) {
    if (revealPhase || choosingRow || gameOver) return;
    selectedCard = selectedCard == card ? null : card;
    notifyListeners();
  }

  /// Commits the card this device has highlighted, then lets any AI seats
  /// answer. In a local multiplayer game the caller is also responsible for
  /// telling the other devices, which reach the same state via [submitCard].
  void confirmSelection() {
    final card = selectedCard;
    if (card == null) return;
    // Cleared only once the card is actually committed — a rejected submission
    // must leave the highlight where the player put it.
    if (!submitCard(localSeat, card)) return;
    selectedCard = null;
    _submitAiSeats();
  }

  /// Records [card] as [seat]'s choice for the round, and resolves the round
  /// once every seat has chosen. Returns false if the submission was rejected.
  ///
  /// This is the single door every choice comes through — a local tap, an AI,
  /// or a message off a socket — so it validates rather than trusting. A
  /// remote device could name a seat that doesn't exist, a card that isn't in
  /// that seat's hand, or send twice for one round; none of those may corrupt
  /// the game, because every device is resolving the same round independently
  /// and one bad input would desync all of them.
  bool submitCard(int seat, TakeCard card) {
    if (revealPhase || choosingRow || gameOver) return false;
    if (seat < 0 || seat >= players.length) return false;

    final player = players[seat];
    if (player.selectedCard != null) return false; // already chose this round

    // Identity by number: a card arriving off the network is a rebuilt object,
    // not the instance sitting in the hand.
    final held = player.hand.indexWhere((c) => c.number == card.number);
    if (held == -1) return false;

    player.selectedCard = player.hand.removeAt(held);
    notifyListeners();

    if (players.any((p) => p.selectedCard == null)) return true;
    _resolveRound();
    return true;
  }

  /// Answers for every AI seat that hasn't played yet. No-op in a local
  /// multiplayer game, where every seat is a person.
  void _submitAiSeats() {
    for (final p in players) {
      // The empty check isn't theoretical: chooseCard falls back to hand.first,
      // which throws on an empty hand.
      if (!p.isAi || p.selectedCard != null || p.hand.isEmpty) continue;
      submitCard(p.seat, AiStrategy.chooseCard(p.hand, rows, level: aiLevel));
    }
  }

  /// Every seat has chosen: reveal, then place the cards in ascending order.
  void _resolveRound() {
    _placements =
        players.map((p) => (player: p, card: p.selectedCard!)).toList()
          ..sort((a, b) => a.card.number.compareTo(b.card.number));
    _placementIdx = 0;
    revealPhase = true;
    notifyListeners();

    _delayed(const Duration(milliseconds: 1400), _processNextPlacement);
  }

  void _processNextPlacement() {
    if (_placementIdx >= _placements.length) {
      _endRound();
      return;
    }

    final placement = _placements[_placementIdx];
    final player = placement.player;
    final card = placement.card;
    lastPlacingPlayer = player;

    final rowIdx = AiStrategy.targetRowIndex(card, rows);

    if (rowIdx == -1) {
      if (player.isAi) {
        _announceTake(player, AiStrategy.chooseBestRow(rows), card);
      } else {
        // Every device stops here, including the ones just watching — the game
        // can't advance until this seat answers, and on their screens the rows
        // aren't tappable because rowChooserSeat isn't theirs.
        _pendingRowCard = card;
        rowChooserSeat = player.seat;
        choosingRow = true;
        notifyListeners();
      }
    } else if (rows[rowIdx].isFull) {
      _announceTake(player, rowIdx, card);
    } else {
      // Announce the flight; the UI animates the card and calls commitFlight,
      // which is what actually adds it to the row and advances the queue.
      lastAffectedRow = rowIdx;
      lastWasTake = false;
      flight = (player: player, card: card, rowIdx: rowIdx, slotIdx: rows[rowIdx].size);
      notifyListeners();
    }
  }

  /// Applies the pending [flight] (called by the UI when the card lands) and
  /// schedules the next placement. Ignored if the game moved on ([gen] stale)
  /// or was disposed.
  void commitFlight(int gen) {
    if (_disposed || gen != generation) return;
    final f = flight;
    if (f == null) return;
    flight = null;
    f.player.selectedCard = null; // the card has left the sidebar
    rows[f.rowIdx] = rows[f.rowIdx].withCard(f.card);
    lastAffectedRow = f.rowIdx;
    lastWasTake = false;
    notifyListeners();
    _delayed(const Duration(milliseconds: 350), () {
      _placementIdx++;
      _processNextPlacement();
    });
  }

  /// Announces a row take. Nothing is mutated yet: the UI flies the row's cards
  /// to [player] (via the pile animation), calls [commitRowTake] when they land,
  /// and that in turn stages [newCard]'s slide-in as a normal placement flight.
  void _announceTake(TakePlayer player, int rowIdx, TakeCard newCard) {
    lastPlacingPlayer = player;
    lastAffectedRow = rowIdx;
    lastWasTake = true;
    rowTake = (
      player: player,
      newCard: newCard,
      rowIdx: rowIdx,
      takenCards: List.of(rows[rowIdx].cards),
    );
    notifyListeners();
  }

  /// Applies the pending [rowTake] (called by the UI when the pile lands on the
  /// taker): credits the stars, empties the row, and stages the new card's
  /// flight into the now-empty slot 0.
  void commitRowTake(int gen) {
    if (_disposed || gen != generation) return;
    final t = rowTake;
    if (t == null) return;
    rowTake = null;
    t.player.totalStars += rows[t.rowIdx].totalStars;
    rows[t.rowIdx] = GameRow(const []); // emptied; new card flies in next
    lastAffectedRow = t.rowIdx;
    lastWasTake = true;
    flight = (player: t.player, card: t.newCard, rowIdx: t.rowIdx, slotIdx: 0);
    notifyListeners();
  }

  /// Takes row [rowIdx] on behalf of [seat]. Called locally by the device whose
  /// choice it is, and by the others when that choice reaches them.
  ///
  /// Validated for the same reason as [submitCard]: it accepts input from the
  /// network, and a row index off the end would take down every device at once.
  /// Returns false if the pick was rejected.
  bool pickRow(int seat, int rowIdx) {
    if (!choosingRow || _pendingRowCard == null) return false;
    if (seat != rowChooserSeat) return false; // not this seat's choice to make
    if (rowIdx < 0 || rowIdx >= rows.length) return false;

    final card = _pendingRowCard!;
    _pendingRowCard = null;
    choosingRow = false;
    rowChooserSeat = null;
    _announceTake(players[seat], rowIdx, card);
    return true;
  }

  void _endRound() {
    for (final p in players) {
      p.selectedCard = null;
    }
    selectedCard = null;
    revealPhase = false;
    _clearFeedback();

    // Any seat will do — every seat plays exactly one card per round, so all
    // hands empty on the same round. Seat 0 rather than the local seat keeps
    // the end of the game a fact about the game, not about the device.
    if (players.first.hand.isEmpty) {
      gameOver = true;
    } else {
      round++;
    }
    notifyListeners();
  }
}
