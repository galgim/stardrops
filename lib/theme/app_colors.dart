import 'package:flutter/material.dart';

/// Stardrop's palette: black, white, navy, and yellow as the highlight.
///
/// The navy values are sampled straight out of `assets/Group 1.svg` and the
/// card faces, so code-drawn surfaces and the artwork stay in the same family.
/// Names describe the *role* a colour plays, not its hue — swapping a colour
/// later shouldn't leave a constant called `amber` holding something blue.
class AppColors {
  const AppColors._();

  // ── Surfaces ──────────────────────────────────────────────

  /// Deepest navy — the app's base, behind the background artwork.
  static const backdrop = Color(0xFF00053D);

  /// Near-black navy. Also the text colour on top of [accent].
  static const ink = Color(0xFF0C0E1F);

  // ── Accent ────────────────────────────────────────────────

  /// Yellow: the player's colour, the primary action, and the row you're
  /// being asked to pick. If it's yellow, it means "act here".
  static const accent = Color(0xFFFFD233);

  /// The darker gold under [accent] buttons, used as their bottom border.
  static const accentEdge = Color(0xFFE0A400);

  // ── Podium ────────────────────────────────────────────────
  //
  // Medals, on the final standings. First place has no entry of its own — it
  // takes [accent], which already reads as gold and keeps the winner in the
  // same colour as everything else marked "this one matters".

  /// Second place. Cool and neutral, so it doesn't get mistaken for the
  /// periwinkle [textSecondary] a line above or below it.
  static const silver = Color(0xFFCBD5E1);

  /// Third place. Warmed and lightened off classic bronze, which goes muddy
  /// against the near-black scrim the standings sit on.
  static const bronze = Color(0xFFD08E45);

  // ── Text ──────────────────────────────────────────────────

  /// Headlines and body copy.
  static const textPrimary = Color(0xFFFFFFFF);

  /// Supporting copy — light periwinkle, readable but a step back from white.
  static const textSecondary = Color(0xFFC2CAF0);

  /// Eyebrow labels on the intro slides.
  static const textFaint = Color(0xFF5F6BA8);

  // ── Feedback ──────────────────────────────────────────────

  /// Periwinkle borrowed from the card art. Marks the row a card just landed
  /// in, names the AI players, and outlines idle diagram rows — neutral, so it
  /// reports what happened without competing with [accent] for attention.
  static const mist = Color(0xFF8E9BD6);

  /// Stars you've been stuck with, and rows that are one card from bursting.
  /// The one deliberate non-brand colour: nothing else reads as "bad" as fast.
  static const penalty = Color(0xFFFF4D5E);

  /// The harder red behind the intro's "you take all 5" warning — rarer than
  /// [penalty], so it's allowed to shout louder.
  static const danger = Color(0xFFFF2D3E);
}
