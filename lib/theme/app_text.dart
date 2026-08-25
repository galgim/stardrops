import 'package:flutter/material.dart';
import '../services/locale_service.dart';
import 'app_colors.dart';

/// Stardrop's type scale. Every `TextStyle` in the app comes from here.
///
/// **No call site may pass `fontSize`.** That rule is the whole point: the app
/// once used nine unrelated sizes picked per widget, which is what made the UI
/// feel subtly inconsistent. A named scale replaced them, and then leaked back
/// out through `copyWith(fontSize: ...)` at fifteen call sites until it was
/// nine unrelated sizes again wearing a scale's name. If a size is missing
/// here, add a named role for it rather than overriding one in place.
///
/// `copyWith` is still right for *colour* — a winning headline in
/// [AppColors.accent], a penalty score in [AppColors.penalty]. Colours carry
/// meaning per call site; sizes don't.
///
/// Eight sizes across twelve roles: 40, 30, 16, 15, 14, 13, 12, 11.
///
/// Weights are limited to 300/400/500/700 because those are the only static
/// Space Grotesk files shipped. Asking for w600/w800/w900 silently rounds to
/// the nearest available file, so the declared weight would stop matching what
/// actually renders — don't reintroduce them.
///
/// ## Why most of these are getters
///
/// The language styles adapt to the script being rendered — see [_script].
/// That has to be read at build time rather than baked in at compile time, so
/// they can't be `const`. The data styles below still are: they only ever hold
/// digits, which look the same in every language.
class AppText {
  const AppText._();

  static const _family = 'SpaceGrotesk';

  /// Consulted, in order, for any glyph [_family] doesn't have.
  ///
  /// Space Grotesk covers 731 codepoints and none of them are Hangul, so
  /// without this every Korean string renders as empty boxes. These families
  /// ship with the OS — Apple's on iOS, Noto on Android — which is why no
  /// Korean font is bundled: a full Hangul weight is several megabytes, and
  /// the device already has one.
  ///
  /// This belongs on the styles rather than on `ThemeData.fontFamily`, because
  /// every style here names [_family] explicitly and a style's own family
  /// overrides the theme's. A fallback set only on the theme would never be
  /// reached.
  static const _fallback = [
    'Apple SD Gothic Neo', // iOS, macOS
    'Noto Sans KR', // Android
    'Noto Sans CJK KR', // Android, older naming
    'Malgun Gothic', // Windows
  ];

  /// The same list, for `ThemeData.fontFamilyFallback` — it catches any stray
  /// `Text` that didn't take its style from this scale.
  static const hangulFallback = _fallback;

  /// True while the app is showing a script with no uppercase and no need for
  /// tracking. Korean, for now.
  static bool get _hangul => LocaleService.current.value.languageCode == 'ko';

  /// Adapts a Latin-tuned style to the script in use.
  ///
  /// The design leans on all-caps with wide tracking, and neither idea
  /// survives translation to Hangul: it has no uppercase at all, and its
  /// syllable blocks are already evenly spaced, so tracking that makes Latin
  /// caps read as deliberate makes Korean read as falling apart. Tracking goes
  /// to zero.
  ///
  /// Line height opens up for the same reason a cap-height-tuned leading is
  /// wrong here: a Hangul block fills far more of the em box than Latin
  /// lowercase does, so the tightest lines in the scale clip without it. Only
  /// the sub-1.2 heights are touched; anything already generous is left alone.
  static TextStyle _script(TextStyle s) {
    if (!_hangul) return s;
    final height = s.height;
    return s.copyWith(
      letterSpacing: 0,
      height: height != null && height < 1.2 ? 1.2 : height,
    );
  }

  // ── Language ──────────────────────────────────────────────

  /// The one dominant thing on a screen: the wordmark, the game-over verdict,
  /// the lobby's title, the join code. Never two of these on one screen.
  static TextStyle get hero => _script(_hero);
  static const _hero = TextStyle(
    fontFamily: _family,
    fontFamilyFallback: _fallback,
    fontSize: 40,
    fontWeight: FontWeight.w700,
    height: 1.1,
    letterSpacing: 1,
    color: AppColors.textPrimary,
  );

  /// Below the hero: intro slide titles, and the join-code field being typed
  /// into. Large, but sharing the screen with something else.
  static TextStyle get display => _script(_display);
  static const _display = TextStyle(
    fontFamily: _family,
    fontFamilyFallback: _fallback,
    fontSize: 30,
    fontWeight: FontWeight.w700,
    height: 1.1,
    letterSpacing: 0.5,
    color: AppColors.textPrimary,
  );

  /// Dialog and section headings, and names in the final standings.
  static TextStyle get title => _script(_title);
  static const _title = TextStyle(
    fontFamily: _family,
    fontFamilyFallback: _fallback,
    fontSize: 16,
    fontWeight: FontWeight.w700,
    height: 1.2,
    letterSpacing: 1.2,
    color: AppColors.textPrimary,
  );

  /// Paragraph copy. The only style with a reading line-height.
  static TextStyle get body => _script(_body);
  static const _body = TextStyle(
    fontFamily: _family,
    fontFamilyFallback: _fallback,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.55,
    color: AppColors.textSecondary,
  );

  /// All-caps eyebrows and section labels. Wide tracking is the point — in
  /// Latin. See [_script] for what happens to it in Korean.
  static TextStyle get label => _script(_label);
  static const _label = TextStyle(
    fontFamily: _family,
    fontFamilyFallback: _fallback,
    fontSize: 12,
    fontWeight: FontWeight.w700,
    height: 1.2,
    letterSpacing: 2.5,
    color: AppColors.textFaint,
  );

  /// Supporting text: hints, snackbars, notes under a control.
  static TextStyle get caption => _script(_caption);
  static const _caption = TextStyle(
    fontFamily: _family,
    fontFamilyFallback: _fallback,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.2,
    color: AppColors.textSecondary,
  );

  /// The tightest text in the app — the player sidebar, where five names, five
  /// scores and five cards share a 132pt column on a 375pt-tall screen. A step
  /// below [caption] because the layout has nothing to spare.
  static TextStyle get chip => _script(_chip);
  static const _chip = TextStyle(
    fontFamily: _family,
    fontFamilyFallback: _fallback,
    fontSize: 11,
    fontWeight: FontWeight.w700,
    height: 1.2,
    color: AppColors.textSecondary,
  );

  // ── Controls ──────────────────────────────────────────────

  /// Button labels. Always caps at the call site.
  static TextStyle get button => _script(_button);
  static const _button = TextStyle(
    fontFamily: _family,
    fontFamilyFallback: _fallback,
    fontSize: 15,
    fontWeight: FontWeight.w700,
    height: 1,
    letterSpacing: 1.5,
    color: AppColors.textPrimary,
  );

  /// Buttons where the layout is tight: the in-game confirm beside the hand,
  /// the actions inside a dialog, the sound toggle. Also the intro's inline
  /// warning pill, which is a label in a control's clothing.
  static TextStyle get buttonSmall => _script(_buttonSmall);
  static const _buttonSmall = TextStyle(
    fontFamily: _family,
    fontFamilyFallback: _fallback,
    fontSize: 13,
    fontWeight: FontWeight.w700,
    height: 1,
    letterSpacing: 1,
    color: AppColors.textPrimary,
  );

  // ── Data ──────────────────────────────────────────────────
  //
  // Separate from the language styles because these are read at a glance
  // rather than out loud: heavier, no tracking.
  //
  // Still `const`, and deliberately not run through [_script]: these hold
  // digits and nothing else, so there is no Hangul to make room for and no
  // tracking to remove. Opening their line height would move the sidebar and
  // table-row layouts in Korean for no reason.

  /// Star counts and scores at their normal size.
  static const stat = TextStyle(
    fontFamily: _family,
    fontFamilyFallback: _fallback,
    fontSize: 12,
    fontWeight: FontWeight.w700,
    height: 1,
    color: AppColors.textPrimary,
  );

  /// Scores in the final standings, where they carry the column.
  static const statLarge = TextStyle(
    fontFamily: _family,
    fontFamilyFallback: _fallback,
    fontSize: 16,
    fontWeight: FontWeight.w700,
    height: 1,
    color: AppColors.textPrimary,
  );

  /// Star counts in the tight places: a table row's total, a sidebar score.
  static const statSmall = TextStyle(
    fontFamily: _family,
    fontFamilyFallback: _fallback,
    fontSize: 11,
    fontWeight: FontWeight.w700,
    height: 1,
    color: AppColors.textPrimary,
  );

  /// The number on a card face. The one size computed rather than named: it's
  /// derived from the card's width by the caller, so it scales with the table
  /// instead of sitting on the ramp above.
  ///
  /// `decoration: none` matters: flying cards render in an Overlay with no
  /// Material ancestor to supply a default, and without this the number picks
  /// up a yellow double underline.
  static TextStyle cardNumber(double size, Color color) => TextStyle(
    fontFamily: _family,
    fontFamilyFallback: _fallback,
    fontSize: size,
    fontWeight: FontWeight.w700,
    height: 1,
    color: color,
    decoration: TextDecoration.none,
  );
}
