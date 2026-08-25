/// Spacing and corner-radius tokens.
///
/// These cover *chrome* — padding inside panels, gaps between UI blocks,
/// margins. They deliberately do not cover the table's card-layout maths
/// (`table_grid.dart`) or the hand's fan geometry (`player_hand.dart`). Those
/// are computed to fit five cards across a landscape phone and are tuned in
/// fractions of a pixel; snapping them to a 4pt grid would cost card size on
/// exactly the screens that have none to spare. They stay as named local
/// constants next to the maths that uses them.
library;

/// The 4pt spacing ramp. Nothing between these values, nothing outside them.
class AppSpacing {
  const AppSpacing._();

  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
}

/// Corner radii, by the size of the thing being rounded.
///
/// A child must never be rounded as much as its parent — a card inside a row
/// reads as an object resting on a surface, and equal radii collapse that.
class AppRadius {
  const AppRadius._();

  /// Playing cards and empty card slots.
  static const card = 8.0;

  /// Mid-size containers: table rows, sidebar entries, leaderboard rows.
  static const surface = 14.0;

  /// Dialogs and full overlays.
  static const panel = 20.0;

  /// Buttons, badges, dots, and icon buttons. Large enough to fully round
  /// anything in this app, so a square icon button becomes a circle.
  static const pill = 999.0;
}
