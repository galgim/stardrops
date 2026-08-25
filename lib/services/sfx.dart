import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The game's sound effects, reachable from any widget.
///
/// Each clip gets its own player, preloaded once at startup. Both details
/// matter: `play()` re-reads the asset on every call, which is audible as a
/// sound arriving after the thing that caused it, and a shared player would
/// let a button tap cut off a card landing.
///
/// Sound is decoration. Every call here swallows its own failures — a missing
/// asset, an unsupported codec, no plugin at all under `flutter test` — so a
/// broken clip costs silence rather than a crash mid-game.
class Sfx {
  const Sfx._();

  static final _tap = AudioPlayer();
  static final _cardMove = AudioPlayer();
  static final _cardSelect = AudioPlayer();
  static final _cardDeselect = AudioPlayer();

  /// One player per card a row can hold. The riffle retriggers faster than the
  /// clip is long, so the hits have to overlap — a single player would cut each
  /// one dead as the next started, which reads as a stutter, not a shuffle.
  static final _gather = [for (var i = 0; i < 5; i++) AudioPlayer()];

  static const _kSoundOn = 'sfx_on';

  static bool _soundOn = true;

  /// Whether sound is switched on. The settings toggle reads this for its
  /// current position; [_replay] checks it before every clip.
  static bool get soundOn => _soundOn;

  /// Loads every clip and the saved sound setting. Call once from `main`. If it
  /// fails, or never runs, the play methods below simply do nothing.
  static Future<void> init() async {
    await _load(_tap, 'audio/button_tap.wav');
    await _load(_cardMove, 'audio/card_move.wav');
    await _load(_cardSelect, 'audio/card_select.wav');
    await _load(_cardDeselect, 'audio/card_deselect.wav');
    for (final player in _gather) {
      await _load(player, 'audio/card_gather.wav');
    }
    _soundOn = await _readSoundOn();
  }

  /// The setting from last launch, defaulting to on. A read failure also lands
  /// on on — a player who wanted silence can switch it off again in two taps,
  /// which is the cheaper of the two failure modes.
  static Future<bool> _readSoundOn() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_kSoundOn) ?? true;
    } catch (e) {
      debugPrint('sfx: could not read sound setting — $e');
      return true;
    }
  }

  /// Switches sound on or off and remembers it for next launch. Takes effect on
  /// the next clip — nothing is playing long enough to need stopping.
  static Future<void> setSoundOn(bool value) async {
    _soundOn = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kSoundOn, value);
    } catch (e) {
      debugPrint('sfx: could not save sound setting — $e');
    }
  }

  static Future<void> _load(AudioPlayer player, String asset) async {
    try {
      // `stop` keeps the decoded clip buffered between plays; the default
      // `release` throws it away and reloads on the next one.
      await player.setReleaseMode(ReleaseMode.stop);
      await player.setSource(AssetSource(asset));
    } catch (e) {
      debugPrint('sfx: could not load $asset — $e');
    }
  }

  /// A button press, anywhere in the app.
  static void tap() => _replay(_tap);

  /// A card travelling to the row it belongs in.
  static void cardMove() => _replay(_cardMove);

  /// The riffle as a taken row is swept up: the gather clip once per card, so
  /// a row taken with two cards in it sounds lighter than a full one.
  ///
  /// The spacing is fixed rather than stretched to fit, so the shuffle keeps
  /// the same rhythm at every size — [window] is how long a full row's riffle
  /// runs, and a shorter row simply finishes sooner. Stretching two hits across
  /// the whole window would read as two taps, not a shuffle.
  static Future<void> rowGather(int cardCount, Duration window) async {
    final hits = cardCount.clamp(0, _gather.length);
    if (hits == 0) return; // nothing taken; also guards the division below
    final gap = window ~/ _gather.length;
    for (var i = 0; i < hits; i++) {
      _replay(_gather[i]);
      await Future.delayed(gap);
    }
  }

  /// Picking a card up out of your hand.
  static void cardSelect() => _replay(_cardSelect);

  /// Putting the picked card back down.
  static void cardDeselect() => _replay(_cardDeselect);

  /// Rewinds, then plays. The rewind is what makes the second and later plays
  /// audible — the player is parked at the end of the clip from last time.
  static Future<void> _replay(AudioPlayer player) async {
    // The single gate for the sound setting. Every clip in the app routes
    // through here, so switching sound off can't miss one.
    if (!_soundOn) return;
    try {
      await player.seek(Duration.zero);
      await player.resume();
    } catch (e) {
      debugPrint('sfx: playback failed — $e');
    }
  }
}
